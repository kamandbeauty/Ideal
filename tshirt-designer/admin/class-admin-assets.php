<?php
/**
 * Admin page: Design Assets.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin_Assets {

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	public function render(): void {
		// phpcs:ignore WordPress.Security.NonceVerification
		$cat     = isset( $_GET['category'] ) ? sanitize_key( (string) wp_unslash( $_GET['category'] ) ) : '';
		$editing = isset( $_GET['edit'] ) && ctype_digit( (string) $_GET['edit'] ) ? (int) $_GET['edit'] : 0;
		// phpcs:enable

		$assets = $this->plugin->assets->all( false, $cat );
		$edit   = null;
		if ( $editing > 0 ) {
			foreach ( $assets as $asset ) {
				if ( (int) $asset['id'] === $editing ) {
					$edit = $asset;
					break;
				}
			}
		}
		require TD_PLUGIN_DIR . 'admin/views/html-assets.php';
	}

	public function handle_action( string $do ): void {
		$plugin = $this->plugin;

		switch ( $do ) {
			case 'save':
				// phpcs:disable WordPress.Security.NonceVerification
				$id       = (int) ( $_POST['id'] ?? 0 );
				$name     = (string) wp_unslash( $_POST['name'] ?? '' );
				$category = (string) wp_unslash( $_POST['category'] ?? 'other' );
				$file_id  = (int) ( $_POST['file_id'] ?? 0 );
				$sort     = (int) ( $_POST['sort_order'] ?? 0 );
				// phpcs:enable

				if ( '' === sanitize_text_field( $name ) ) {
					Admin_Models::redirect( 'assets', array( 'error' => rawurlencode( __( 'Please provide a name.', 'tshirt-designer' ) ) ) );
				}

				$data = array(
					'name'       => $name,
					'category'   => $category,
					'file_id'    => $file_id,
					'sort_order' => $sort,
				);

				if ( $id > 0 ) {
					$plugin->assets->update( $id, $data );
					$done = __( 'Asset updated.', 'tshirt-designer' );
				} else {
					$plugin->assets->insert( $data );
					$done = __( 'Asset added.', 'tshirt-designer' );
				}
				Admin_Models::redirect( 'assets', array( 'updated' => rawurlencode( $done ) ) );
				break;

			case 'delete':
				// phpcs:ignore WordPress.Security.NonceVerification
				$id = (int) ( $_POST['id'] ?? 0 );
				// phpcs:enable
				if ( $id > 0 ) {
					$plugin->assets->delete( $id );
				}
				Admin_Models::redirect( 'assets', array( 'updated' => rawurlencode( __( 'Asset deleted.', 'tshirt-designer' ) ) ) );
				break;

			case 'toggle':
				// phpcs:ignore WordPress.Security.NonceVerification
				$id = (int) ( $_POST['id'] ?? 0 );
				// phpcs:enable
				$asset = $id > 0 ? $plugin->assets->get( $id ) : null;
				if ( null !== $asset ) {
					$plugin->assets->update( $id, array( 'is_active' => $asset['is_active'] ? 0 : 1 ) );
				}
				Admin_Models::redirect( 'assets', array( 'updated' => rawurlencode( __( 'Asset status changed.', 'tshirt-designer' ) ) ) );
				break;
		}
	}
}
