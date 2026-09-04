<?php
/**
 * Admin bootstrap: menu, page routing, shared helpers.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

defined( 'ABSPATH' ) || exit;

final class Admin {

	public const CAPABILITY = 'manage_options';
	public const SLUG       = 'tshirt-designer';

	/** @var array<string, object> */
	private array $pages = array();

	public static function register( \TShirtDesigner\Plugin $plugin ): void {
		new self( $plugin );
	}

	private function __construct( private \TShirtDesigner\Plugin $plugin ) {
		$this->pages = array(
			'models'        => new Admin_Models( $plugin ),
			'product-types' => new Admin_Product_Types( $plugin ),
			'colors'      => new Admin_Colors( $plugin ),
			'sizes'       => new Admin_Sizes( $plugin ),
			'print-areas' => new Admin_Print_Areas( $plugin ),
			'assets'      => new Admin_Assets( $plugin ),
			'pricing'     => new Admin_Pricing( $plugin ),
			'designs'     => new Admin_Designs( $plugin ),
			'settings'    => new Admin_Settings( $plugin ),
		);

		// The order panel is not a menu page: it hooks into the WooCommerce
		// order screen and owns its own admin-post endpoint.
		new Admin_Order_Panel( $plugin );

		add_action( 'admin_menu', array( $this, 'menu' ) );
		add_action( 'admin_post_td_action', array( $this, 'route_action' ) );
	}

	/**
	 * Register the admin menu.
	 */
	public function menu(): void {
		add_menu_page(
			__( 'Custom Product Designer', 'tshirt-designer' ),
			__( 'Product Designer', 'tshirt-designer' ),
			self::CAPABILITY,
			self::SLUG,
			array( $this->pages['models'], 'render' ),
			'dashicons-admin-customizer',
			56
		);

		$submenus = array(
			'models'      => __( 'Models', 'tshirt-designer' ),
			'product-types' => __( 'Product Types', 'tshirt-designer' ),
			'colors'      => __( 'Colors', 'tshirt-designer' ),
			'sizes'       => __( 'Sizes', 'tshirt-designer' ),
			'print-areas' => __( 'Print Areas', 'tshirt-designer' ),
			'assets'      => __( 'Design Assets', 'tshirt-designer' ),
			'pricing'     => __( 'Pricing', 'tshirt-designer' ),
			'designs'     => __( 'Designs', 'tshirt-designer' ),
			'settings'    => __( 'Settings', 'tshirt-designer' ),
		);

		foreach ( $submenus as $slug => $title ) {
			add_submenu_page(
				self::SLUG,
				__( 'Custom Product Designer', 'tshirt-designer' ) . ' — ' . $title,
				$title,
				self::CAPABILITY,
				self::SLUG . '-' . $slug,
				array( $this->pages[ $slug ], 'render' )
			);
		}
	}

	/**
	 * Route form submissions: all pages POST to admin-post.php?action=td_action
	 * with a per-page "do" field. Nonce + capability checked centrally.
	 */
	public function route_action(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You are not allowed to do that.', 'tshirt-designer' ) );
		}

		// phpcs:disable WordPress.Security.NonceVerification -- verified below via check_admin_referer
		$do   = isset( $_POST['do'] ) ? sanitize_key( (string) wp_unslash( $_POST['do'] ) ) : '';
		$page = isset( $_POST['page_key'] ) ? sanitize_key( (string) wp_unslash( $_POST['page_key'] ) ) : '';
		// phpcs:enable

		check_admin_referer( 'td_admin_' . $page );

		if ( '' === $page || ! isset( $this->pages[ $page ] ) ) {
			wp_die( esc_html__( 'Unknown page.', 'tshirt-designer' ) );
		}

		$handler = array( $this->pages[ $page ], 'handle_action' );
		if ( is_callable( $handler ) ) {
			call_user_func( $handler, $do );
		}

		// Handlers redirect themselves; safety net:
		wp_safe_redirect( admin_url( 'admin.php?page=' . self::SLUG . '-' . $page ) );
		exit;
	}

	/**
	 * Page URL helper.
	 */
	public static function page_url( string $key, array $args = array() ): string {
		$url = admin_url( 'admin.php?page=' . self::SLUG . '-' . $key );
		if ( array() !== $args ) {
			$url .= '&' . http_build_query( $args );
		}
		return $url;
	}

	/**
	 * Admin POST url (single endpoint for every form).
	 */
	public static function action_url( string $page_key ): string {
		return admin_url( 'admin-post.php?action=td_action' );
	}

	/**
	 * Shared notice rendering.
	 */
	public static function notices(): void {
		// phpcs:disable WordPress.Security.NonceVerification
		$updated = isset( $_GET['updated'] ) ? sanitize_text_field( wp_unslash( $_GET['updated'] ) ) : '';
		$error   = isset( $_GET['error'] ) ? sanitize_text_field( wp_unslash( $_GET['error'] ) ) : '';
		// phpcs:enable
		if ( '' !== $updated ) {
			printf( '<div class="notice notice-success is-dismissible"><p>%s</p></div>', esc_html( $updated ) );
		}
		if ( '' !== $error ) {
			printf( '<div class="notice notice-error is-dismissible"><p>%s</p></div>', esc_html( $error ) );
		}
	}
}
