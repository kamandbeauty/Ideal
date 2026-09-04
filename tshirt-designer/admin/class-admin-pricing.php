<?php
/**
 * Admin page: Pricing (size tiers + item extras, global or per print area).
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin_Pricing {

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	private function current_area_id(): int {
		// phpcs:ignore WordPress.Security.NonceVerification
		$aid = isset( $_GET['area'] ) && ctype_digit( (string) $_GET['area'] ) ? (int) $_GET['area'] : 0;
		return $aid;
	}

	public function render(): void {
		global $wpdb;

		$area_id  = $this->current_area_id();
		$areas    = array();
		foreach ( $this->plugin->models->all( false ) as $model ) {
			foreach ( $this->plugin->print_areas->for_model( (int) $model['id'], false ) as $area ) {
				$areas[] = $area;
			}
		}
		$area = null;
		foreach ( $areas as $a ) {
			if ( (int) $a['id'] === $area_id ) {
				$area = $a;
				break;
			}
		}
		if ( null === $area ) {
			$area_id = 0; // Global scope.
		}

		$table = $this->plugin->db->table( 'pricing_rules' );
		$scope = $area_id > 0 ? "AND (scope = 'global' OR (scope = 'area' AND print_area_id = " . (int) $area_id . '))' : "AND scope = 'global'";
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rules = $wpdb->get_results(
			"SELECT * FROM {$table} WHERE is_active = 1 {$scope} ORDER BY rule_type ASC, sort_order ASC, id ASC",
			ARRAY_A
		);

		$tiers  = array();
		$extras = array();
		foreach ( is_array( $rules ) ? $rules : array() as $rule ) {
			if ( 'size_tier' === $rule['rule_type'] ) {
				$tiers[] = $rule;
			} elseif ( 'item_extra' === $rule['rule_type'] ) {
				$extras[] = $rule;
			}
		}

		require TD_PLUGIN_DIR . 'admin/views/html-pricing.php';
	}

	public function handle_action( string $do ): void {
		$plugin = $this->plugin;

		switch ( $do ) {
			case 'save_rule':
				// phpcs:disable WordPress.Security.NonceVerification
				$id       = (int) ( $_POST['id'] ?? 0 );
				$area_id  = (int) ( $_POST['print_area_id'] ?? 0 );
				$type     = (string) wp_unslash( $_POST['rule_type'] ?? '' );
				$from     = (float) ( $_POST['size_from_cm'] ?? 0 );
				$to       = (float) ( $_POST['size_to_cm'] ?? 0 );
				$count    = (int) ( $_POST['item_count'] ?? 0 );
				$price    = (float) ( $_POST['price'] ?? 0 );
				$sort     = (int) ( $_POST['sort_order'] ?? 0 );
				// phpcs:enable

				$plugin->pricing->save_rule( array(
					'id'            => $id,
					'rule_type'     => $type,
					'scope'         => $area_id > 0 ? 'area' : 'global',
					'print_area_id' => $area_id,
					'size_from_cm'  => $from,
					'size_to_cm'    => $to,
					'item_count'    => $count,
					'price'         => $price,
					'is_active'     => 1,
					'sort_order'    => $sort,
				) );

				Admin_Models::redirect( 'pricing', array(
					'updated' => rawurlencode( __( 'Pricing rule saved.', 'tshirt-designer' ) ),
					'area'    => $area_id ?: null,
				) );
				break;

			case 'delete_rule':
				// phpcs:disable WordPress.Security.NonceVerification
				$id      = (int) ( $_POST['id'] ?? 0 );
				$area_id = (int) ( $_POST['print_area_id'] ?? 0 );
				// phpcs:enable
				if ( $id > 0 ) {
					$plugin->pricing->delete_rule( $id );
				}
				Admin_Models::redirect( 'pricing', array(
					'updated' => rawurlencode( __( 'Pricing rule deleted.', 'tshirt-designer' ) ),
					'area'    => $area_id ?: null,
				) );
				break;
		}
	}
}
