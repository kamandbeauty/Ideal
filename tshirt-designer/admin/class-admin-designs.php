<?php
/**
 * Admin page: Designs (saved customer designs).
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin_Designs {

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	public function render(): void {
		global $wpdb;

		// phpcs:ignore WordPress.Security.NonceVerification
		$view = isset( $_GET['view'] ) && ctype_digit( (string) $_GET['view'] ) ? (int) $_GET['view'] : 0;

		$table = $this->plugin->db->table( 'designs' );

		if ( $view > 0 ) {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$row = $wpdb->get_row(
				$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $view ),
				ARRAY_A
			);
			$design = is_array( $row ) ? $this->plugin->designs->cast( $row ) : null;
			require TD_PLUGIN_DIR . 'admin/views/html-designs-view.php';
			return;
		}

		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results( "SELECT * FROM {$table} ORDER BY id DESC LIMIT 100", ARRAY_A );
		$designs = array_map( array( $this->plugin->designs, 'cast' ), is_array( $rows ) ? $rows : array() );

		$models = array();
		foreach ( $this->plugin->models->all( false ) as $model ) {
			$models[ (int) $model['id'] ] = $model['name'];
		}
		$users = array();
		foreach ( $designs as $design ) {
			$uid = (int) $design['user_id'];
			if ( $uid > 0 && ! isset( $users[ $uid ] ) ) {
				$user = get_userdata( $uid );
				$users[ $uid ] = $user ? $user->user_login : ( '#' . $uid );
			}
		}
		require TD_PLUGIN_DIR . 'admin/views/html-designs.php';
	}

	public function handle_action( string $do ): void {
		if ( 'delete' === $do ) {
			// phpcs:ignore WordPress.Security.NonceVerification
			$id = (int) ( $_POST['id'] ?? 0 );
			// phpcs:enable
			global $wpdb;
			if ( $id > 0 ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->delete( $this->plugin->db->table( 'designs' ), array( 'id' => $id ), array( '%d' ) );
			}
			Admin_Models::redirect( 'designs', array( 'updated' => rawurlencode( __( 'Design deleted.', 'tshirt-designer' ) ) ) );
		}
	}
}
