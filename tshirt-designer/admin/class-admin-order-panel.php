<?php
/**
 * Admin: "Custom Product Design" panel on the WooCommerce order screen.
 *
 * Shows every designed line item of an order together with its preview,
 * price breakdown and production files, and offers per-area downloads, a
 * "Download all" ZIP and a snapshot-based regenerate action.
 *
 * Everything here reads the *order snapshot*, never the live catalogue, so an
 * order keeps showing exactly what was bought even after models, print areas
 * or pricing rules change.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

use TShirtDesigner\Order_Manager;
use TShirtDesigner\Logger;

defined( 'ABSPATH' ) || exit;

final class Admin_Order_Panel {

	/** Nonce action for every download / regenerate request. */
	public const NONCE = 'td_production';

	/** admin-post action name. */
	public const ACTION = 'td_production';

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {
		add_action( 'add_meta_boxes', array( $this, 'register_meta_box' ) );
		add_action( 'admin_post_' . self::ACTION, array( $this, 'handle_request' ) );
	}

	/**
	 * Register the panel on both the legacy post screen and HPOS.
	 */
	public function register_meta_box(): void {
		if ( ! \TShirtDesigner\Woocommerce::is_active() ) {
			return;
		}

		$screens = array( 'shop_order' );
		if ( class_exists( '\Automattic\WooCommerce\Internal\DataStores\Orders\CustomOrdersTableController' )
			&& function_exists( 'wc_get_page_screen_id' ) ) {
			$screens[] = wc_get_page_screen_id( 'shop-order' );
		}

		foreach ( array_unique( array_filter( $screens ) ) as $screen ) {
			add_meta_box(
				'td-order-design',
				__( 'Custom Product Design', 'tshirt-designer' ),
				array( $this, 'render' ),
				$screen,
				'normal',
				'high'
			);
		}
	}

	/**
	 * Render the panel.
	 *
	 * @param mixed $post_or_order Post object or WC_Order (HPOS).
	 */
	public function render( $post_or_order ): void {
		$order = $post_or_order instanceof \WC_Order
			? $post_or_order
			: ( function_exists( 'wc_get_order' ) ? wc_get_order( $post_or_order ) : null );

		if ( ! $order instanceof \WC_Order ) {
			echo '<p>' . esc_html__( 'This order could not be loaded.', 'tshirt-designer' ) . '</p>';
			return;
		}

		$order_id = (int) $order->get_id();
		$designed = array();

		foreach ( $order->get_items() as $item_id => $item ) {
			$snapshot = Order_Manager::snapshot_from_item( $item );
			if ( null === $snapshot ) {
				continue;
			}
			$designed[] = array(
				'item_id'  => (int) $item_id,
				'item'     => $item,
				'snapshot' => $snapshot,
				'pricing'  => Order_Manager::pricing_from_item( $item ),
				'files'    => $this->plugin->production->for_order( $order_id, (int) $item_id ),
			);
		}

		if ( array() === $designed ) {
			echo '<p>' . esc_html__( 'This order does not contain any custom designs.', 'tshirt-designer' ) . '</p>';
			return;
		}

		$production_status = (string) $order->get_meta( Order_Manager::META_PRODUCTION_STATUS );
		$statuses          = Order_Manager::statuses();

		require TD_PLUGIN_DIR . 'admin/views/html-order-panel.php';
	}

	/**
	 * Handle download / download-all / regenerate / status requests.
	 */
	public function handle_request(): void {
		if ( ! current_user_can( Admin::CAPABILITY ) ) {
			wp_die( esc_html__( 'You are not allowed to do that.', 'tshirt-designer' ), '', array( 'response' => 403 ) );
		}
		check_admin_referer( self::NONCE );

		// phpcs:disable WordPress.Security.NonceVerification -- verified above.
		$do       = isset( $_REQUEST['do'] ) ? sanitize_key( (string) wp_unslash( $_REQUEST['do'] ) ) : '';
		$order_id = isset( $_REQUEST['order_id'] ) ? absint( wp_unslash( $_REQUEST['order_id'] ) ) : 0;
		$item_id  = isset( $_REQUEST['item_id'] ) ? absint( wp_unslash( $_REQUEST['item_id'] ) ) : 0;
		$file_id  = isset( $_REQUEST['file_id'] ) ? absint( wp_unslash( $_REQUEST['file_id'] ) ) : 0;
		$status   = isset( $_REQUEST['production_status'] ) ? sanitize_key( (string) wp_unslash( $_REQUEST['production_status'] ) ) : '';
		// phpcs:enable

		$order = $order_id > 0 && function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		if ( ! $order instanceof \WC_Order ) {
			wp_die( esc_html__( 'Order not found.', 'tshirt-designer' ), '', array( 'response' => 404 ) );
		}

		switch ( $do ) {
			case 'download':
				$this->send_file( $file_id, $order_id );
				break;

			case 'download_all':
				$this->send_zip( $order_id, $item_id );
				break;

			case 'regenerate':
				$this->regenerate( $order_id );
				break;

			case 'set_status':
				$this->plugin->orders->set_production_status( $order_id, $status );
				$this->back( $order_id, __( 'Production status updated.', 'tshirt-designer' ) );
				break;

			default:
				wp_die( esc_html__( 'Unknown action.', 'tshirt-designer' ), '', array( 'response' => 400 ) );
		}
	}

	/**
	 * Stream a single production file.
	 *
	 * The file lives outside the web root's reach (deny-all .htaccess), so it
	 * is proxied here after the capability + nonce check, and only when it
	 * really belongs to the order named in the request.
	 */
	private function send_file( int $file_id, int $order_id ): void {
		$file = $this->plugin->production->get_file( $file_id );
		if ( null === $file || (int) $file['order_id'] !== $order_id ) {
			wp_die( esc_html__( 'Production file not found.', 'tshirt-designer' ), '', array( 'response' => 404 ) );
		}

		$path = (string) $file['file_path'];
		$dir  = $this->plugin->production->storage_dir();
		if ( null === $dir ) {
			wp_die( esc_html__( 'The production folder is not writable.', 'tshirt-designer' ), '', array( 'response' => 500 ) );
		}

		// Defence in depth: never serve anything outside the production dir.
		$real = realpath( $path );
		$base = realpath( $dir['dir'] );
		if ( false === $real || false === $base || ! str_starts_with( $real, $base ) || ! is_readable( $real ) ) {
			wp_die( esc_html__( 'Production file is missing on disk.', 'tshirt-designer' ), '', array( 'response' => 404 ) );
		}

		$this->stream( $real, (string) $file['file_name'], 'image/png' );
	}

	/**
	 * Build and stream the "download all" archive.
	 */
	private function send_zip( int $order_id, int $item_id ): void {
		$zip = $this->plugin->production->build_zip( $order_id, $item_id );
		if ( null === $zip ) {
			$this->back( $order_id, '', __( 'There are no production files to download yet.', 'tshirt-designer' ) );
			return;
		}
		$this->stream( (string) $zip['path'], (string) $zip['name'], 'application/zip' );
	}

	/**
	 * Regenerate every production file of the order from its stored snapshot.
	 */
	private function regenerate( int $order_id ): void {
		$result = $this->plugin->orders->generate_for_order( $order_id, true );

		$made   = 0;
		$failed = 0;
		foreach ( (array) $result as $item_result ) {
			if ( ! is_array( $item_result ) ) {
				continue;
			}
			if ( ! empty( $item_result['ok'] ) ) {
				$made += count( (array) ( $item_result['files'] ?? array() ) );
			} else {
				++$failed;
			}
		}

		if ( $failed > 0 ) {
			$this->back(
				$order_id,
				'',
				__( 'Some production files could not be regenerated. Check the plugin log for details.', 'tshirt-designer' )
			);
			return;
		}

		$this->back(
			$order_id,
			sprintf(
				/* translators: %d: number of regenerated files. */
				_n( '%d production file regenerated from the order snapshot.', '%d production files regenerated from the order snapshot.', $made, 'tshirt-designer' ),
				$made
			)
		);
	}

	/**
	 * Send a file to the browser as a download.
	 */
	private function stream( string $path, string $name, string $mime ): void {
		nocache_headers();
		header( 'Content-Type: ' . $mime );
		header( 'Content-Disposition: attachment; filename="' . sanitize_file_name( $name ) . '"' );
		header( 'Content-Length: ' . (string) filesize( $path ) );
		header( 'X-Content-Type-Options: nosniff' );

		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_readfile
		readfile( $path );
		exit;
	}

	/**
	 * Redirect back to the order screen with a notice.
	 */
	private function back( int $order_id, string $message = '', string $error = '' ): void {
		$url = self::order_url( $order_id );
		if ( '' !== $message ) {
			$url = add_query_arg( 'td_notice', rawurlencode( $message ), $url );
		}
		if ( '' !== $error ) {
			$url = add_query_arg( 'td_error', rawurlencode( $error ), $url );
		}
		wp_safe_redirect( $url );
		exit;
	}

	/**
	 * Edit-screen URL of an order (HPOS aware).
	 */
	public static function order_url( int $order_id ): string {
		if ( class_exists( '\Automattic\WooCommerce\Utilities\OrderUtil' )
			&& \Automattic\WooCommerce\Utilities\OrderUtil::custom_orders_table_usage_is_enabled() ) {
			return admin_url( 'admin.php?page=wc-orders&action=edit&id=' . $order_id );
		}
		return admin_url( 'post.php?post=' . $order_id . '&action=edit' );
	}

	/**
	 * Build a nonced action URL for the panel.
	 *
	 * @param array<string, string|int> $args Extra query args.
	 */
	public static function action_url( string $do, int $order_id, array $args = array() ): string {
		$url = add_query_arg(
			array_merge(
				array(
					'action'   => self::ACTION,
					'do'       => $do,
					'order_id' => $order_id,
				),
				$args
			),
			admin_url( 'admin-post.php' )
		);
		return wp_nonce_url( $url, self::NONCE );
	}
}
