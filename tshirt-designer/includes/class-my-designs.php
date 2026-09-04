<?php
/**
 * Customer-facing "My Designs" area inside WooCommerce My Account.
 *
 * Lists the logged-in customer's designs with view / edit / duplicate /
 * delete / order-again actions. Every action re-checks ownership; nothing
 * here trusts an id coming from the request.
 *
 * Guest designs are claimed into the account on login, so a customer who
 * designed before registering keeps their work.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class My_Designs {

	public const ENDPOINT = 'my-designs';

	public function __construct( private Plugin $plugin ) {
		add_action( 'init', array( $this, 'add_endpoint' ) );
		add_filter( 'woocommerce_account_menu_items', array( $this, 'menu_item' ) );
		add_action( 'woocommerce_account_' . self::ENDPOINT . '_endpoint', array( $this, 'render' ) );
		add_filter( 'query_vars', array( $this, 'query_vars' ) );
		add_action( 'template_redirect', array( $this, 'handle_action' ) );
		add_action( 'wp_login', array( $this, 'claim_guest_designs' ), 10, 2 );
		add_action( 'user_register', array( $this, 'claim_on_register' ) );
	}

	public function add_endpoint(): void {
		add_rewrite_endpoint( self::ENDPOINT, EP_ROOT | EP_PAGES );
	}

	/**
	 * @param array<string, string> $vars Query vars.
	 * @return array<string, string>
	 */
	public function query_vars( $vars ) {
		$vars[] = self::ENDPOINT;
		return is_array( $vars ) ? $vars : array();
	}

	/**
	 * Add the tab to the My Account menu (before "Logout").
	 *
	 * @param array<string, string> $items Menu items.
	 * @return array<string, string>
	 */
	public function menu_item( $items ) {
		if ( ! is_array( $items ) ) {
			return $items;
		}
		$new = array();
		foreach ( $items as $key => $label ) {
			if ( 'customer-logout' === $key ) {
				$new[ self::ENDPOINT ] = __( 'My Designs', 'tshirt-designer' );
			}
			$new[ $key ] = $label;
		}
		if ( ! isset( $new[ self::ENDPOINT ] ) ) {
			$new[ self::ENDPOINT ] = __( 'My Designs', 'tshirt-designer' );
		}
		return $new;
	}

	/**
	 * Move guest designs into the account right after login.
	 *
	 * @param string   $user_login Username.
	 * @param \WP_User $user       User object.
	 */
	public function claim_guest_designs( $user_login, $user ): void {
		if ( ! $user instanceof \WP_User ) {
			return;
		}
		$token = isset( $_COOKIE['td_guest'] ) ? sanitize_text_field( wp_unslash( $_COOKIE['td_guest'] ) ) : '';
		if ( '' === $token ) {
			return;
		}
		$this->plugin->designs->claim_guest_designs( (int) $user->ID, $token );
	}

	/**
	 * Same, for a fresh registration.
	 */
	public function claim_on_register( $user_id ): void {
		$token = isset( $_COOKIE['td_guest'] ) ? sanitize_text_field( wp_unslash( $_COOKIE['td_guest'] ) ) : '';
		if ( '' === $token ) {
			return;
		}
		$this->plugin->designs->claim_guest_designs( (int) $user_id, $token );
	}

	/**
	 * Handle duplicate / delete / order-again links (nonce protected).
	 */
	public function handle_action(): void {
		if ( ! is_user_logged_in() || ! isset( $_GET['td_action'], $_GET['design'] ) ) {
			return;
		}
		$action    = sanitize_key( wp_unslash( (string) $_GET['td_action'] ) );
		$design_id = (int) $_GET['design'];
		if ( $design_id <= 0 ) {
			return;
		}

		$nonce = isset( $_GET['_wpnonce'] ) ? sanitize_text_field( wp_unslash( (string) $_GET['_wpnonce'] ) ) : '';
		if ( ! wp_verify_nonce( $nonce, 'td_my_designs_' . $action . '_' . $design_id ) ) {
			wp_die( esc_html__( 'This link has expired. Please try again.', 'tshirt-designer' ) );
		}

		$user_id = get_current_user_id();
		$notice  = '';

		if ( 'duplicate' === $action ) {
			$result = $this->plugin->designs->duplicate( $design_id, $user_id, '' );
			$notice = $result['ok'] ? 'duplicated' : 'error';
		} elseif ( 'delete' === $action ) {
			$result = $this->plugin->designs->delete( $design_id, $user_id, '' );
			$notice = $result['ok'] ? 'deleted' : 'error';
		} elseif ( 'reorder' === $action ) {
			$notice = $this->reorder( $design_id, $user_id );
		} else {
			return;
		}

		// A successful reorder goes straight to the cart; everything else
		// stays on the designs list with a notice.
		$target = ( 'reordered' === $notice && function_exists( 'wc_get_cart_url' ) )
			? wc_get_cart_url()
			: add_query_arg( 'td_notice', $notice, wc_get_account_endpoint_url( self::ENDPOINT ) );

		wp_safe_redirect( $target );
		exit;
	}

	/**
	 * Put a previously ordered design back in the cart.
	 *
	 * The design is duplicated first and the *copy* is carted. A design that
	 * has been ordered is immutable - its snapshot is what the customer paid
	 * for and what production printed - so re-carting the original would drag
	 * a historical record back into an open cart where editing it could
	 * change the record of a completed sale.
	 *
	 * @return string Notice key.
	 */
	private function reorder( int $design_id, int $user_id ): string {
		if ( null === $this->plugin->cart ) {
			return 'nocart';
		}

		// duplicate() re-checks ownership, so an id belonging to someone else
		// never gets this far.
		$copy = $this->plugin->designs->duplicate( $design_id, $user_id, '' );
		if ( empty( $copy['ok'] ) ) {
			return 'error';
		}

		$added = $this->plugin->cart->add_to_cart( (int) $copy['id'], 1, $user_id, '' );
		if ( empty( $added['ok'] ) ) {
			return 'error';
		}

		return 'reordered';
	}

	/**
	 * Render the My Designs table.
	 */
	public function render(): void {
		$user_id = get_current_user_id();
		if ( $user_id <= 0 ) {
			return;
		}

		$designs = $this->plugin->designs->list_designs( $user_id, '', 100 );
		$notice  = isset( $_GET['td_notice'] ) ? sanitize_key( wp_unslash( (string) $_GET['td_notice'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification

		$designer_url = (string) $this->plugin->settings->get( 'designer_page_url', '' );

		include TD_PLUGIN_DIR . 'templates/my-designs.php';
	}

	/**
	 * URL that opens a design in the designer (empty when not configured).
	 */
	public static function edit_url( string $designer_url, int $design_id ): string {
		if ( '' === $designer_url ) {
			return '';
		}
		return add_query_arg( 'td_design', $design_id, $designer_url );
	}

	/**
	 * Nonced action URL.
	 */
	public static function action_url( string $action, int $design_id ): string {
		return wp_nonce_url(
			add_query_arg(
				array( 'td_action' => $action, 'design' => $design_id ),
				wc_get_account_endpoint_url( self::ENDPOINT )
			),
			'td_my_designs_' . $action . '_' . $design_id
		);
	}
}
