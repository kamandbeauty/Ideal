<?php
/**
 * Admin page: Models.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin_Models {

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	public function render(): void {
		$models = $this->plugin->models->all( false );
		$edit   = null;
		$editing = isset( $_GET['edit'] ) && ctype_digit( (string) $_GET['edit'] ) ? (int) $_GET['edit'] : 0; // phpcs:ignore WordPress.Security.NonceVerification
		if ( $editing > 0 ) {
			$edit = $this->plugin->models->get( $editing, true );
		}

		$counts = array();
		foreach ( $models as $model ) {
			$mid = (int) $model['id'];
			$counts[ $mid ] = array(
				'colors' => count( $this->plugin->colors->for_model( $mid, false ) ),
				'sizes'  => count( $this->plugin->sizes->for_model( $mid, false ) ),
				'areas'  => count( $this->plugin->print_areas->for_model( $mid, false ) ),
			);
		}

		$next_sort = count( $models );
		require TD_PLUGIN_DIR . 'admin/views/html-models.php';
	}

	public function handle_action( string $do ): void {
		$plugin = $this->plugin;

		switch ( $do ) {
			case 'save':
				// phpcs:disable WordPress.Security.NonceVerification
				$id          = (int) ( $_POST['id'] ?? 0 );
				$name        = (string) wp_unslash( $_POST['name'] ?? '' );
				$description = (string) wp_unslash( $_POST['description'] ?? '' );
				$model_id    = (int) ( $_POST['model_file_id'] ?? 0 );
				$preview_id  = (int) ( $_POST['preview_image_id'] ?? 0 );
				$wc_product  = (int) ( $_POST['wc_product_id'] ?? 0 );
				$base_price  = (float) ( $_POST['base_price'] ?? 0 );
				$is_active   = ! empty( $_POST['is_active'] );
				$sort        = (int) ( $_POST['sort_order'] ?? 0 );
				// phpcs:enable

				if ( '' === sanitize_text_field( $name ) ) {
					self::redirect( 'models', array( 'error' => rawurlencode( __( 'Please enter a model name.', 'tshirt-designer' ) ) ) );
				}

				$data = array(
					'name'             => $name,
					'description'      => $description,
					'model_file_id'    => $model_id,
					'preview_image_id' => $preview_id,
					'wc_product_id'    => $wc_product,
					'base_price'       => $base_price,
					'is_active'        => $is_active ? 1 : 0,
					'sort_order'       => $sort,
				);

				if ( $id > 0 ) {
					$data['slug'] = $plugin->models->unique_slug( $name, $id );
					$plugin->models->update( $id, $data );
					$done = __( 'Model updated.', 'tshirt-designer' );
				} else {
					$data['slug'] = $plugin->models->unique_slug( $name );
					$id = $plugin->models->insert( $data );
					$done = __( 'Model created.', 'tshirt-designer' );
				}

				self::redirect( 'models', array( 'updated' => rawurlencode( $done ), 'edit' => $id ) );

				break;

			case 'delete':
				// phpcs:ignore WordPress.Security.NonceVerification
				$id = (int) ( $_POST['id'] ?? 0 );
				// phpcs:enable
				if ( $id > 0 ) {
					$plugin->models->delete( $id );
				}
				self::redirect( 'models', array( 'updated' => rawurlencode( __( 'Model deleted.', 'tshirt-designer' ) ) ) );
				break;

			case 'toggle':
				// phpcs:ignore WordPress.Security.NonceVerification
				$id = (int) ( $_POST['id'] ?? 0 );
				// phpcs:enable
				$model = $id > 0 ? $plugin->models->get( $id, true ) : null;
				if ( null !== $model ) {
					$plugin->models->update( $id, array( 'is_active' => $model['is_active'] ? 0 : 1 ) );
				}
				self::redirect( 'models', array( 'updated' => rawurlencode( __( 'Model status changed.', 'tshirt-designer' ) ) ) );
				break;
		}
	}

	public static function redirect( string $page, array $args = array() ): void {
		$url = Admin::page_url( $page, $args );

		/**
		 * Fires just before an admin screen redirects after handling a form.
		 *
		 * Lets integration tests observe the outcome instead of having the
		 * process terminate on `exit`.
		 *
		 * @param string $url  Destination URL.
		 * @param string $page Page key.
		 */
		do_action( 'td_admin_before_redirect', $url, $page );

		wp_safe_redirect( $url );
		exit;
	}
}
