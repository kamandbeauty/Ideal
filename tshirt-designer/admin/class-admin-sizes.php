<?php
/**
 * Admin page: Sizes (per model).
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin_Sizes {

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
		$sizes  = $mid > 0 ? $this->plugin->sizes->for_model( $mid, false ) : array();
		$models = $this->plugin->models->all( false );
		$edit   = null;
		// phpcs:ignore WordPress.Security.NonceVerification
		$editing = isset( $_GET['edit'] ) && ctype_digit( (string) $_GET['edit'] ) ? (int) $_GET['edit'] : 0;
		if ( $editing > 0 ) {
			foreach ( $sizes as $size ) {
				if ( (int) $size['id'] === $editing ) {
					$edit = $size;
					break;
				}
			}
		}
		require TD_PLUGIN_DIR . 'admin/views/html-sizes.php';
	}

	public function handle_action( string $do ): void {
		$plugin = $this->plugin;

		switch ( $do ) {
			case 'save':
				// phpcs:disable WordPress.Security.NonceVerification
				$id        = (int) ( $_POST['id'] ?? 0 );
				$model_id  = (int) ( $_POST['model_id'] ?? 0 );
				$name      = (string) wp_unslash( $_POST['name'] ?? '' );
				$modifier  = (float) ( $_POST['price_modifier'] ?? 0 );
				$is_active = ! empty( $_POST['is_active'] );
				$sort      = (int) ( $_POST['sort_order'] ?? 0 );
				// phpcs:enable

				if ( '' === sanitize_text_field( $name ) || null === $plugin->models->get( $model_id, true ) ) {
					Admin_Models::redirect( 'sizes', array( 'error' => rawurlencode( __( 'Please provide a size name and a valid model.', 'tshirt-designer' ) ), 'model' => $model_id ) );
				}

				$data = array(
					'model_id'       => $model_id,
					'name'           => $name,
					'price_modifier' => $modifier,
					'is_active'      => $is_active ? 1 : 0,
					'sort_order'     => $sort,
				);

				if ( $id > 0 ) {
					$plugin->sizes->update( $id, $data );
					$done = __( 'Size updated.', 'tshirt-designer' );
				} else {
					$plugin->sizes->insert( $data );
					$done = __( 'Size added.', 'tshirt-designer' );
				}
				Admin_Models::redirect( 'sizes', array( 'updated' => rawurlencode( $done ), 'model' => $model_id ) );
				break;

			case 'delete':
				// phpcs:disable WordPress.Security.NonceVerification
				$id       = (int) ( $_POST['id'] ?? 0 );
				$model_id = (int) ( $_POST['model_id'] ?? 0 );
				// phpcs:enable
				if ( $id > 0 ) {
					$plugin->sizes->delete( $id );
				}
				Admin_Models::redirect( 'sizes', array( 'updated' => rawurlencode( __( 'Size deleted.', 'tshirt-designer' ) ), 'model' => $model_id ) );
				break;
		}
	}
}
