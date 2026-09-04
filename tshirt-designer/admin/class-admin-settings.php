<?php
/**
 * Admin page: Settings.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin_Settings {

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	public function render(): void {
		$settings = $this->plugin->settings->all();
		require TD_PLUGIN_DIR . 'admin/views/html-settings.php';
	}

	public function handle_action( string $do ): void {
		if ( 'save' !== $do ) {
			return;
		}

		// phpcs:disable WordPress.Security.NonceVerification
		$raw = array(
			'currency'                 => array(
				'symbol'       => (string) wp_unslash( $_POST['currency_symbol'] ?? '' ),
				'position'     => (string) wp_unslash( $_POST['currency_position'] ?? 'after' ),
				'decimals'     => (int) ( $_POST['currency_decimals'] ?? 0 ),
				'thousand_sep' => (string) wp_unslash( $_POST['currency_thousand_sep'] ?? ',' ),
				'decimal_sep'  => (string) wp_unslash( $_POST['currency_decimal_sep'] ?? '.' ),
			),
			'upload_max_mb'            => (float) ( $_POST['upload_max_mb'] ?? 5 ),
			'allow_guest_uploads'      => ! empty( $_POST['allow_guest_uploads'] ),
			'allow_guest_designs'      => ! empty( $_POST['allow_guest_designs'] ),
			'uploads_per_hour'         => (int) ( $_POST['uploads_per_hour'] ?? 20 ),
			'delete_data_on_uninstall' => ! empty( $_POST['delete_data_on_uninstall'] ),
		);
		// phpcs:enable

		$this->plugin->settings->update_from_input( $raw );
		Admin_Models::redirect( 'settings', array( 'updated' => rawurlencode( __( 'Settings saved.', 'tshirt-designer' ) ) ) );
	}
}
