<?php
/**
 * Admin page: Print Areas (per model).
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin_Print_Areas {

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	private function current_model_id(): int {
		// phpcs:ignore WordPress.Security.NonceVerification
		$mid = isset( $_GET['model'] ) && ctype_digit( (string) $_GET['model'] ) ? (int) $_GET['model'] : 0;
		if ( $mid > 0 && null !== $this->plugin->models->get( $mid, true ) ) {
			return $mid;
		}
		$first = $this->plugin->models->all( false );
		return $first ? (int) $first[0]['id'] : 0;
	}

	public function render(): void {
		$mid    = $this->current_model_id();
		$model  = $mid > 0 ? $this->plugin->models->get( $mid, true ) : null;
		$areas  = $mid > 0 ? $this->plugin->print_areas->for_model( $mid, false ) : array();
		$models = $this->plugin->models->all( false );
		$edit   = null;
		// phpcs:ignore WordPress.Security.NonceVerification
		$editing = isset( $_GET['edit'] ) && ctype_digit( (string) $_GET['edit'] ) ? (int) $_GET['edit'] : 0;
		if ( $editing > 0 ) {
			foreach ( $areas as $area ) {
				if ( (int) $area['id'] === $editing ) {
					$edit = $area;
					break;
				}
			}
		}
		require TD_PLUGIN_DIR . 'admin/views/html-print-areas.php';
	}

	public function handle_action( string $do ): void {
		$plugin = $this->plugin;

		switch ( $do ) {
			case 'save':
				// phpcs:disable WordPress.Security.NonceVerification
				$id        = (int) ( $_POST['id'] ?? 0 );
				$model_id  = (int) ( $_POST['model_id'] ?? 0 );
				$name      = (string) wp_unslash( $_POST['name'] ?? '' );
				$type      = (string) wp_unslash( $_POST['area_type'] ?? 'other' );
				$max_w     = (float) ( $_POST['max_width_cm'] ?? 30 );
				$max_h     = (float) ( $_POST['max_height_cm'] ?? 35 );
				$position  = (string) wp_unslash( $_POST['position'] ?? '' );
				$is_active = ! empty( $_POST['is_active'] );
				$sort      = (int) ( $_POST['sort_order'] ?? 0 );
				// phpcs:enable

				if ( '' === sanitize_text_field( $name ) || null === $plugin->models->get( $model_id, true ) ) {
					Admin_Models::redirect( 'print-areas', array( 'error' => rawurlencode( __( 'Please provide an area name and a valid model.', 'tshirt-designer' ) ), 'model' => $model_id ) );
				}

				$data = array(
					'model_id'      => $model_id,
					'name'          => $name,
					'area_type'     => $type,
					'max_width_cm'  => $max_w,
					'max_height_cm' => $max_h,
					'position'      => $position,
					'is_active'     => $is_active ? 1 : 0,
					'sort_order'    => $sort,
				);

				if ( $id > 0 ) {
					$plugin->print_areas->update( $id, $data );
					$done = __( 'Print area updated.', 'tshirt-designer' );
				} else {
					$plugin->print_areas->insert( $data );
					$done = __( 'Print area created.', 'tshirt-designer' );
				}
				Admin_Models::redirect( 'print-areas', array( 'updated' => rawurlencode( $done ), 'model' => $model_id ) );
				break;

			case 'delete':
				// phpcs:disable WordPress.Security.NonceVerification
				$id       = (int) ( $_POST['id'] ?? 0 );
				$model_id = (int) ( $_POST['model_id'] ?? 0 );
				// phpcs:enable
				if ( $id > 0 ) {
					$plugin->print_areas->delete( $id );
				}
				Admin_Models::redirect( 'print-areas', array( 'updated' => rawurlencode( __( 'Print area deleted.', 'tshirt-designer' ) ), 'model' => $model_id ) );
				break;
		}
	}
}
