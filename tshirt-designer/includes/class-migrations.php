<?php
/**
 * Versioned database migrations.
 *
 * `Database::install()` owns the current CREATE TABLE schema (dbDelta keeps
 * it in sync). Migrations handle everything dbDelta cannot do safely: data
 * back-fills, renames and one-off fixes. Every step is idempotent so a
 * partially applied upgrade can always be re-run.
 *
 * Order sites are upgraded through: run dbDelta first (adds new columns),
 * then the data steps for versions the site has not seen yet.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Migrations {

	public const OPTION_DB_VERSION  = 'td_db_version';
	public const OPTION_APPLIED     = 'td_migrations_applied';

	public function __construct( private Database $db ) {}

	/**
	 * Ordered migration steps: version => method name.
	 *
	 * @return array<string, string>
	 */
	public function steps(): array {
		return array(
			'1.1.0' => 'migrate_110_product_types_and_versioning',
		);
	}

	/**
	 * Run the full upgrade routine (schema + pending data steps).
	 *
	 * Safe to call on every request where the stored version differs.
	 */
	public function run(): void {
		// 1. Schema — dbDelta adds new tables/columns without touching data.
		$this->db->install();

		// 2. Data steps.
		$applied = get_option( self::OPTION_APPLIED, array() );
		$applied = is_array( $applied ) ? array_map( 'strval', $applied ) : array();

		foreach ( $this->steps() as $version => $method ) {
			if ( in_array( $version, $applied, true ) ) {
				continue;
			}
			if ( ! method_exists( $this, $method ) ) {
				continue;
			}
			$this->{$method}();
			$applied[] = $version;
			update_option( self::OPTION_APPLIED, array_values( array_unique( $applied ) ), false );
		}

		update_option( self::OPTION_DB_VERSION, TD_DB_VERSION );
	}

	/**
	 * Mark every step as applied without running it (fresh installs — the
	 * CREATE TABLE schema already contains everything the steps back-fill).
	 */
	public function mark_all_applied(): void {
		update_option( self::OPTION_APPLIED, array_keys( $this->steps() ), false );
		update_option( self::OPTION_DB_VERSION, TD_DB_VERSION );
	}

	// ------------------------------------------------------------- steps

	/**
	 * 1.1.0 — product types, design uuid/version, layer/opacity/type on items.
	 *
	 * Back-fills:
	 *  - td_models.product_type       -> 'tshirt' for every existing row.
	 *  - td_designs.product_type      -> from the design's model.
	 *  - td_designs.uuid              -> generated for rows without one.
	 *  - td_designs.version           -> 1.
	 *  - td_design_versions           -> one v1 snapshot per existing design.
	 *  - design_data items            -> item_type/layer/opacity defaults.
	 */
	private function migrate_110_product_types_and_versioning(): void {
		global $wpdb;

		$models  = $this->db->table( 'models' );
		$designs = $this->db->table( 'designs' );

		// Models without a product type -> legacy tshirt.
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$wpdb->query(
			$wpdb->prepare(
				"UPDATE {$models} SET product_type = %s WHERE product_type = '' OR product_type IS NULL",
				Product_Type_Registry::LEGACY_TYPE
			)
		);

		// Designs: uuid, version, product_type, then a v1 snapshot each.
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results( "SELECT * FROM {$designs}", ARRAY_A );
		if ( ! is_array( $rows ) ) {
			return;
		}

		$versions_table = $this->db->table( 'design_versions' );

		foreach ( $rows as $row ) {
			$id     = (int) $row['id'];
			$update = array();

			if ( '' === (string) ( $row['uuid'] ?? '' ) ) {
				$update['uuid'] = Design_Manager::new_uuid();
			}
			if ( (int) ( $row['version'] ?? 0 ) < 1 ) {
				$update['version'] = 1;
			}
			if ( '' === (string) ( $row['product_type'] ?? '' ) ) {
				$model = null;
				if ( (int) $row['model_id'] > 0 ) {
					// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
					$model = $wpdb->get_var(
						$wpdb->prepare( "SELECT product_type FROM {$models} WHERE id = %d", (int) $row['model_id'] )
					);
				}
				$update['product_type'] = is_string( $model ) && '' !== $model
					? $model
					: Product_Type_Registry::LEGACY_TYPE;
			}

			// Normalize stored design items to the richer item shape.
			$data = json_decode( (string) ( $row['design_data'] ?? '' ), true );
			if ( is_array( $data ) && isset( $data['areas'] ) && is_array( $data['areas'] ) ) {
				$changed = false;
				foreach ( $data['areas'] as $area_id => $items ) {
					if ( ! is_array( $items ) ) {
						continue;
					}
					foreach ( $items as $index => $item ) {
						if ( ! is_array( $item ) ) {
							continue;
						}
						if ( ! isset( $item['layer'] ) ) {
							$data['areas'][ $area_id ][ $index ]['layer'] = (int) $index;
							$changed = true;
						}
						if ( ! isset( $item['opacity'] ) ) {
							$data['areas'][ $area_id ][ $index ]['opacity'] = 1.0;
							$changed = true;
						}
					}
				}
				if ( $changed ) {
					$update['design_data'] = wp_json_encode( $data );
				}
			}

			if ( array() !== $update ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update( $designs, $update, array( 'id' => $id ) );
			}

			// One v1 snapshot per legacy design, if not present.
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$has = (int) $wpdb->get_var(
				$wpdb->prepare( "SELECT COUNT(*) FROM {$versions_table} WHERE design_id = %d", $id )
			);
			if ( 0 === $has ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$versions_table,
					array(
						'design_id'       => $id,
						'version'         => max( 1, (int) ( $update['version'] ?? $row['version'] ?? 1 ) ),
						'design_data'     => (string) ( $update['design_data'] ?? $row['design_data'] ?? '' ),
						'price_breakdown' => (string) ( $row['price_breakdown'] ?? '' ),
						'price_total'     => (float) ( $row['price_total'] ?? 0 ),
						'preview_image_id' => (int) ( $row['preview_image_id'] ?? 0 ),
						'created_at'      => (string) ( $row['created_at'] ?? current_time( 'mysql' ) ),
					)
				);
			}
		}
	}
}
