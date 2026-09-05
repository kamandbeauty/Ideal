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
			'1.2.0' => 'migrate_120_production_jobs',
			'1.2.1' => 'migrate_121_tshirt_uv_rects',
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

	/**
	 * Phase 3: back-fill production jobs for orders that were paid before the
	 * production system existed (§55).
	 *
	 * Purely additive: no order, design, snapshot or file is modified. Orders
	 * whose lines carry no design snapshot are skipped. Re-running is safe
	 * because create_job() is keyed on the UNIQUE (order_id, order_item_id).
	 */
	/**
	 * 1.2.1 — re-map the t-shirt print areas onto the replacement 3D model and
	 * open them up to full-garment coverage.
	 *
	 * The bundled t-shirt was replaced with a properly modelled mesh whose UV
	 * layout is a set of garment panels, not the four equal quadrants the old
	 * procedural mesh used. Existing installs still hold the old uv_rect
	 * values, which would put artwork in the wrong place on the new model.
	 *
	 * Only rows that still carry the OLD rect are touched, so a shop that has
	 * tuned its own print areas keeps them. Nothing is deleted, and designs are
	 * untouched: uv_rect only affects where the texture lands on the 3D
	 * preview, and print files are rendered from centimetre coordinates.
	 */
	private function migrate_121_tshirt_uv_rects(): void {
		global $wpdb;

		// Known stock rects, newest first. A site may be on the original
		// procedural-model values or on the first Sketchfab mapping, and both
		// must land on the current full-coverage rect.
		$old_to_new = array(
			'front'        => array(
				'old' => array(
					array( 0.10577, 0.09286, 0.39423, 0.34286 ),
					array( 0.11168, 0.2324, 0.34932, 0.5228 ),
				),
				'new' => array( 0.006, 0.012, 0.455, 0.664 ),
				'cm'  => array( 52.0, 70.0 ),
			),
			'back'         => array(
				'old' => array(
					array( 0.60577, 0.07857, 0.89423, 0.32857 ),
					array( 0.604, 0.21376, 0.838, 0.49668 ),
				),
				'new' => array( 0.5, 0.012, 0.942, 0.647 ),
				'cm'  => array( 52.0, 70.0 ),
			),
			'left_sleeve'  => array(
				'old' => array(
					array( 0.189, 0.625, 0.311, 0.975 ),
					array( 0.1872, 0.76766, 0.2598, 0.87934 ),
				),
				'new' => array( 0.145, 0.653, 0.302, 0.994 ),
				'cm'  => array( 20.0, 26.0 ),
			),
			'right_sleeve' => array(
				'old' => array(
					array( 0.689, 0.625, 0.811, 0.975 ),
					array( 0.3772, 0.76698, 0.4498, 0.87802 ),
				),
				'new' => array( 0.335, 0.653, 0.492, 0.992 ),
				'cm'  => array( 20.0, 26.0 ),
			),
		);

		$areas_table  = $this->db->table( 'print_areas' );
		$models_table = $this->db->table( 'models' );

		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results(
			"SELECT a.id, a.area_type, a.position FROM {$areas_table} a
			 INNER JOIN {$models_table} m ON m.id = a.model_id
			 WHERE m.product_type = 'tshirt'",
			ARRAY_A
		);
		if ( ! $rows ) {
			return;
		}

		foreach ( $rows as $row ) {
			$type = (string) $row['area_type'];
			if ( ! isset( $old_to_new[ $type ] ) ) {
				continue;
			}

			$position = json_decode( (string) $row['position'], true );
			if ( ! is_array( $position ) || empty( $position['uv_rect'] ) ) {
				continue;
			}

			$current = array_map( 'floatval', (array) $position['uv_rect'] );
			if ( count( $current ) !== 4 ) {
				continue;
			}

			// Float comparison with a tolerance: only rewrite rows that still
			// hold one of the stock rects, so a shop that tuned its own print
			// areas keeps them.
			$matches = false;
			foreach ( $old_to_new[ $type ]['old'] as $expected ) {
				$same = true;
				foreach ( $expected as $i => $value ) {
					if ( abs( $current[ $i ] - $value ) > 0.0005 ) {
						$same = false;
						break;
					}
				}
				if ( $same ) {
					$matches = true;
					break;
				}
			}
			if ( ! $matches ) {
				continue;
			}

			$position['uv_rect'] = $old_to_new[ $type ]['new'];

			// The printable size must grow with the area, or the designer would
			// still cap artwork at the old chest-patch dimensions.
			list( $width_cm, $height_cm ) = $old_to_new[ $type ]['cm'];

			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update(
				$areas_table,
				array(
					'position'      => wp_json_encode( $position ),
					'max_width_cm'  => $width_cm,
					'max_height_cm' => $height_cm,
				),
				array( 'id' => (int) $row['id'] ),
				array( '%s', '%f', '%f' ),
				array( '%d' )
			);
		}
	}

	private function migrate_120_production_jobs(): void {
		if ( ! function_exists( 'wc_get_orders' ) ) {
			return; // WooCommerce absent: nothing to back-fill.
		}

		$plugin = Plugin::instance();

		// Only orders that actually reached a paid state deserve a job.
		$orders = wc_get_orders(
			array(
				'limit'      => 500,
				'status'     => array( 'processing', 'completed', 'on-hold' ),
				'meta_key'   => '_td_paid_handled', // phpcs:ignore WordPress.DB.SlowDBQuery
				'return'     => 'ids',
			)
		);

		foreach ( (array) $orders as $order_id ) {
			$order = wc_get_order( (int) $order_id );
			if ( ! $order instanceof \WC_Order ) {
				continue;
			}
			foreach ( $order->get_items() as $item_id => $item ) {
				$snapshot = Order_Manager::snapshot_from_item( $item );
				if ( null === $snapshot ) {
					continue;
				}
				// Preserve whatever production status the order already had.
				$status = (string) $order->get_meta( Order_Manager::META_PRODUCTION_STATUS );
				if ( ! Production_Status::is_status( $status ) ) {
					$status = Production_Status::PAID;
				}
				$plugin->production_jobs->create_job( (int) $order_id, (int) $item_id, $snapshot, $status );
			}
		}
	}

}
