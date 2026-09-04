<?php
/**
 * Admin page: Product Types.
 *
 * Product types are declared in code / via the `cpd_product_types` filter so
 * that adding a new printable product never requires a Core rewrite. This
 * screen exposes what is registered, what each type owns (models, colours,
 * sizes, print areas, pricing rules) and the settings an administrator may
 * legitimately change per type — currently the print resolution.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

use TShirtDesigner\Product_Type_Registry;

defined( 'ABSPATH' ) || exit;

final class Admin_Product_Types {

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	public function render(): void {
		$types    = Product_Type_Registry::all();
		$settings = $this->plugin->settings->all();
		$dpi_map  = is_array( $settings['print_dpi_by_type'] ?? null ) ? $settings['print_dpi_by_type'] : array();

		$summary = array();
		foreach ( $types as $slug => $definition ) {
			$models      = $this->plugin->models->all( false, $slug );
			$model_ids   = array_map( static fn( array $m ): int => (int) $m['id'], $models );
			$colors      = 0;
			$sizes       = 0;
			$print_areas = 0;
			foreach ( $model_ids as $model_id ) {
				$colors      += count( $this->plugin->colors->for_model( $model_id, false ) );
				$sizes       += count( $this->plugin->sizes->for_model( $model_id, false ) );
				$print_areas += count( $this->plugin->print_areas->for_model( $model_id, false ) );
			}

			$summary[ $slug ] = array(
				'definition'  => $definition,
				'models'      => $models,
				'colors'      => $colors,
				'sizes'       => $sizes,
				'print_areas' => $print_areas,
				'designs'     => $this->count_designs( $slug ),
				'dpi'         => Product_Type_Registry::dpi( $slug, $this->plugin->settings ),
				'dpi_custom'  => isset( $dpi_map[ $slug ] ) ? (int) $dpi_map[ $slug ] : 0,
			);
		}

		$default_dpi = (int) $settings['print_dpi'];

		require TD_PLUGIN_DIR . 'admin/views/html-product-types.php';
	}

	/**
	 * How many saved designs exist for a product type.
	 */
	private function count_designs( string $slug ): int {
		global $wpdb;
		$table = $this->plugin->db->table( 'designs' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		return (int) $wpdb->get_var(
			$wpdb->prepare( "SELECT COUNT(*) FROM {$table} WHERE product_type = %s", $slug )
		);
	}

	public function handle_action( string $do ): void {
		if ( 'save_dpi' !== $do ) {
			Admin_Models::redirect( 'product-types', array() );
			return;
		}

		// phpcs:disable WordPress.Security.NonceVerification -- verified in Admin::route_action().
		$default_dpi = isset( $_POST['print_dpi'] ) ? (int) $_POST['print_dpi'] : 300;
		$raw_map     = isset( $_POST['dpi'] ) && is_array( $_POST['dpi'] )
			? array_map( 'sanitize_text_field', wp_unslash( $_POST['dpi'] ) )
			: array();
		// phpcs:enable

		$map = array();
		foreach ( $raw_map as $slug => $value ) {
			$slug = sanitize_key( (string) $slug );
			if ( '' === $slug || ! Product_Type_Registry::exists( $slug ) ) {
				continue;
			}
			// An empty field means "use the global default".
			if ( '' === trim( (string) $value ) ) {
				continue;
			}
			$map[ $slug ] = Product_Type_Registry::clamp_dpi( (int) $value );
		}

		$settings = $this->plugin->settings->all();
		$this->plugin->settings->update_from_input(
			array_merge(
				$settings,
				array(
					'print_dpi'         => Product_Type_Registry::clamp_dpi( $default_dpi ),
					'print_dpi_by_type' => $map,
				)
			)
		);

		Admin_Models::redirect(
			'product-types',
			array( 'updated' => rawurlencode( __( 'Print resolution saved.', 'tshirt-designer' ) ) )
		);
	}
}
