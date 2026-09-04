<?php
/**
 * Pricing engine — pure, server-side price computation.
 *
 * The engine never trusts client-provided prices: given a validated design
 * (item sizes in cm per print area) and the rule set loaded from the DB, it
 * computes the full breakdown.
 *
 * Rule semantics:
 *  - size_tier : matched by an item's longest side in cm (from <= size <= to).
 *                Area-scoped rules win over global ones; first match wins.
 *  - item_extra: extra charge for the Nth item in the same print area
 *                (N >= 2). Exact count wins; otherwise the price of the
 *                highest defined count is used.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Pricing_Engine {

	public const RULE_SIZE_TIER  = 'size_tier';
	public const RULE_ITEM_EXTRA = 'item_extra';

	/**
	 * Compute the price of a design.
	 *
	 * Pure function — no DB, no WP calls.
	 *
	 * @param float                     $base_price   Base product price.
	 * @param float                     $size_modifier Size price modifier.
	 * @param array<int, array<string, mixed>>       $print_areas  area_id => row
	 *                                        (needs id, name, max_width_cm, max_height_cm).
	 * @param array<int, list<array<string, float>>> $items        area_id => list of {w, h}.
	 * @param array<string, list<array<string, mixed>>> $rules      {'size_tier': [...], 'item_extra': [...]}
	 *                                              each rule: {scope, print_area_id, size_from_cm,
	 *                                              size_to_cm, item_count, price}.
	 * @return array<string, mixed> Full breakdown with total.
	 */
	public function compute(
		float $base_price,
		float $size_modifier,
		array $print_areas,
		array $items,
		array $rules
	): array {
		$tiers  = $this->sort_rules( $rules[ self::RULE_SIZE_TIER ] ?? array() );
		$extras = $this->sort_rules( $rules[ self::RULE_ITEM_EXTRA ] ?? array() );

		$base_price    = max( 0.0, $base_price );
		$size_modifier = round( $size_modifier, 2 );

		$area_breakdowns = array();
		$print_total     = 0.0;
		$warnings        = array();

		foreach ( $items as $area_id => $area_items ) {
			$area_id = (int) $area_id;
			if ( ! isset( $print_areas[ $area_id ] ) ) {
				continue; // Unknown area — validated earlier; ignore defensively.
			}
			if ( array() === $area_items ) {
				continue;
			}

			$item_lines = array();
			$subtotal   = 0.0;

			foreach ( array_values( $area_items ) as $index => $item ) {
				$nth   = $index + 1;
				$w     = max( 0.0, (float) ( $item['w'] ?? 0 ) );
				$h     = max( 0.0, (float) ( $item['h'] ?? 0 ) );
				$size  = $this->item_size_cm( $w, $h );

				$tier = $this->match_tier( $tiers, $area_id, $size );
				if ( null === $tier ) {
			$warnings[] = array(
					'area_id' => $area_id,
					'item'    => $nth,
					'message' => sprintf(
						/* translators: %d: centimeters. */
						function_exists( '__' ) ? __( 'No pricing tier matches %d cm.', 'tshirt-designer' ) : 'No pricing tier matches %d cm.',
						(int) ceil( $size )
					),
				);
					$tier_price = 0.0;
					$tier_label = '';
				} else {
					$tier_price = (float) $tier['price'];
					$tier_label = $tier['size_from_cm'] . '–' . $tier['size_to_cm'] . ' cm';
				}

				$extra_price = 0.0;
				if ( $nth >= 2 ) {
					$extra = $this->match_extra( $extras, $area_id, $nth );
					if ( null !== $extra ) {
						$extra_price = (float) $extra['price'];
					}
				}

				$line_total   = round( $tier_price + $extra_price, 2 );
				$subtotal    += $line_total;
				$item_lines[] = array(
					'nth'       => $nth,
					'size_cm'   => round( $size, 2 ),
					'tier'      => $tier_label,
					'base'      => round( $tier_price, 2 ),
					'extra'     => round( $extra_price, 2 ),
					'total'     => $line_total,
				);
			}

			$area_breakdowns[ $area_id ] = array(
				'name'     => (string) $print_areas[ $area_id ]['name'],
				'items'    => $item_lines,
				'subtotal' => round( $subtotal, 2 ),
			);
			$print_total += $subtotal;
		}

		$total = round( $base_price + $size_modifier + $print_total, 2 );

		$breakdown = array(
			'base_price'    => round( $base_price, 2 ),
			'size_modifier' => $size_modifier,
			'areas'         => $area_breakdowns,
			'print_total'   => round( $print_total, 2 ),
			'total'         => $total,
			'warnings'      => $warnings,
		);

		/**
		 * Filter the computed price breakdown.
		 *
		 * @param array<string, mixed> $breakdown Computed breakdown.
		 * @param array<string, mixed> $context   {base_price, size_modifier, print_areas, items, rules}.
		 */
		if ( function_exists( 'apply_filters' ) ) {
			$breakdown = apply_filters( 'td_price_breakdown', $breakdown, array(
				'base_price'    => $base_price,
				'size_modifier' => $size_modifier,
				'print_areas'   => $print_areas,
				'items'         => $items,
				'rules'         => $rules,
			) );
		}
		return $breakdown;
	}

	/**
	 * Size of an item used for tier matching (longest side, cm).
	 */
	public function item_size_cm( float $w, float $h ): float {
		$size = max( $w, $h );
		if ( function_exists( 'apply_filters' ) ) {
			/**
			 * Filter how an item's pricing size is derived (e.g. diagonal, area).
			 *
			 * @param float $size Longest side in cm.
			 * @param float $w    Item width in cm.
			 * @param float $h    Item height in cm.
			 */
			$size = (float) apply_filters( 'td_pricing_item_size_cm', $size, $w, $h );
		}
		return $size;
	}

	/**
	 * Sort rules: area-scoped first (by sort_order), then global.
	 *
	 * @param list<array<string, mixed>> $rules Rules.
	 * @return list<array<string, mixed>>
	 */
	private function sort_rules( array $rules ): array {
		usort(
			$rules,
			static function ( array $a, array $b ): int {
				$scope_rank = array( 'area' => 0, 'global' => 1 );
				$ra = $scope_rank[ $a['scope'] ?? 'global' ] ?? 1;
				$rb = $scope_rank[ $b['scope'] ?? 'global' ] ?? 1;
				if ( $ra !== $rb ) {
					return $ra <=> $rb;
				}
				return ( (int) ( $a['sort_order'] ?? 0 ) ) <=> ( (int) ( $b['sort_order'] ?? 0 ) );
			}
		);
		return $rules;
	}

	/**
	 * Find the first size tier matching an item size.
	 *
	 * @param list<array<string, mixed>> $tiers Sorted tiers.
	 */
	private function match_tier( array $tiers, int $area_id, float $size ): ?array {
		foreach ( $tiers as $tier ) {
			if ( 'area' === $tier['scope'] && (int) $tier['print_area_id'] !== $area_id ) {
				continue;
			}
			if ( 'global' === $tier['scope'] ) {
				// A global rule must not shadow an area rule for another area;
				// they are checked in the right order already, so plain match:
			}
			$from = (float) $tier['size_from_cm'];
			$to   = (float) $tier['size_to_cm'];
			if ( $size >= $from && $size <= $to ) {
				return $tier;
			}
		}
		return null;
	}

	/**
	 * Find the item-extra rule for the Nth item.
	 *
	 * @param list<array<string, mixed>> $extras Sorted extras.
	 */
	private function match_extra( array $extras, int $area_id, int $nth ): ?array {
		$fallback = null;
		foreach ( $extras as $extra ) {
			if ( 'area' === $extra['scope'] && (int) $extra['print_area_id'] !== $area_id ) {
				continue;
			}
			$count = (int) $extra['item_count'];
			if ( $count === $nth ) {
				return $extra;
			}
			if ( $count < $nth && ( null === $fallback || $count > (int) $fallback['item_count'] ) ) {
				$fallback = $extra;
			}
		}
		return $fallback;
	}

	/**
	 * Load active rules from the DB grouped by type.
	 *
	 * @return array<string, list<array<string, mixed>>>
	 */
	public function load_rules(): array {
		global $wpdb;
		$table = $this->rules_table();
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results(
			"SELECT * FROM {$table} WHERE is_active = 1 ORDER BY scope ASC, sort_order ASC, id ASC",
			ARRAY_A
		);
		$rules = array(
			self::RULE_SIZE_TIER  => array(),
			self::RULE_ITEM_EXTRA => array(),
		);
		foreach ( is_array( $rows ) ? $rows : array() as $row ) {
			$rule = array(
				'id'            => (int) $row['id'],
				'rule_type'     => (string) $row['rule_type'],
				'scope'         => (string) $row['scope'],
				'print_area_id' => (int) $row['print_area_id'],
				'size_from_cm'  => (float) $row['size_from_cm'],
				'size_to_cm'    => (float) $row['size_to_cm'],
				'item_count'    => (int) $row['item_count'],
				'price'         => (float) $row['price'],
				'sort_order'    => (int) $row['sort_order'],
			);
			if ( isset( $rules[ $rule['rule_type'] ] ) ) {
				$rules[ $rule['rule_type'] ][] = $rule;
			}
		}
		return $rules;
	}

	/**
	 * Insert / update a pricing rule.
	 *
	 * @param array<string, mixed> $data Input.
	 */
	public function save_rule( array $data ): int {
		global $wpdb;
		$id = max( 0, (int) ( $data['id'] ?? 0 ) );

		$rule_type = (string) ( $data['rule_type'] ?? self::RULE_SIZE_TIER );
		if ( ! in_array( $rule_type, array( self::RULE_SIZE_TIER, self::RULE_ITEM_EXTRA ), true ) ) {
			return 0;
		}
		$scope = ( 'area' === ( $data['scope'] ?? '' ) ) ? 'area' : 'global';
		$area  = max( 0, (int) ( $data['print_area_id'] ?? 0 ) );
		if ( 'area' === $scope && $area <= 0 ) {
			$scope = 'global';
		}

		$row = array(
			'rule_type'     => $rule_type,
			'scope'         => $scope,
			'print_area_id' => $area,
			'size_from_cm'  => round( max( 0.0, (float) ( $data['size_from_cm'] ?? 0 ) ), 2 ),
			'size_to_cm'    => round( max( 0.0, (float) ( $data['size_to_cm'] ?? 0 ) ), 2 ),
			'item_count'    => max( 0, (int) ( $data['item_count'] ?? 0 ) ),
			'price'         => round( max( 0.0, (float) ( $data['price'] ?? 0 ) ), 2 ),
			'is_active'     => empty( $data['is_active'] ) ? 0 : 1,
			'sort_order'    => (int) ( $data['sort_order'] ?? 0 ),
		);

		$now = current_time( 'mysql' );
		if ( $id > 0 ) {
			$row['updated_at'] = $now;
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $this->rules_table(), $row, array( 'id' => $id ) );
			return $id;
		}
		$row['created_at'] = $now;
		$row['updated_at'] = $now;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert( $this->rules_table(), $row );
		return (int) $wpdb->insert_id;
	}

	public function delete_rule( int $id ): void {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->rules_table(), array( 'id' => $id ), array( '%d' ) );
	}

	private function rules_table(): string {
		global $wpdb;
		return $wpdb->prefix . 'td_pricing_rules';
	}
}
