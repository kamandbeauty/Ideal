<?php
/**
 * [tshirt_designer] shortcode + guest cookie bootstrap.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Shortcode {

	public const GUEST_COOKIE = 'td_guest';

	public function __construct( private Plugin $plugin ) {
		add_shortcode( 'tshirt_designer', array( $this, 'render' ) );
	}

	/**
	 * Render the designer app.
	 *
	 * @param array<string, string>|string $atts Shortcode attributes.
	 */
	public function render( $atts = array() ): string {
		$atts = shortcode_atts(
			array(
				'model' => '',
			),
			$atts,
			'tshirt_designer'
		);

		$this->ensure_guest_cookie();

		if ( ! is_user_logged_in() ) {
			$this->ensure_guest_cookie();
		}

		$initial_model = 0;
		$model_attr    = sanitize_text_field( (string) $atts['model'] );
		if ( '' !== $model_attr ) {
			if ( ctype_digit( $model_attr ) ) {
				$initial_model = (int) $model_attr;
			} else {
				$by_slug = $this->plugin->models->get_by_slug( $model_attr );
				if ( null !== $by_slug ) {
					$initial_model = (int) $by_slug['id'];
				}
			}
		}

		// ?td_design=123 preload (shared design links).
		$preload_design = 0;
		if ( isset( $_GET['td_design'] ) && ctype_digit( (string) $_GET['td_design'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification
			$preload_design = (int) $_GET['td_design']; // phpcs:ignore WordPress.Security.NonceVerification
		}

		ob_start();
		require TD_PLUGIN_DIR . 'templates/designer.php';
		return (string) ob_get_clean();
	}

	/**
	 * Give guests a stable token so their uploads/designs stay theirs.
	 */
	private function ensure_guest_cookie(): void {
		if ( is_user_logged_in() || is_admin() ) {
			return;
		}
		if ( headers_sent() ) {
			return;
		}
		$existing = isset( $_COOKIE[ self::GUEST_COOKIE ] )
			? sanitize_text_field( wp_unslash( $_COOKIE[ self::GUEST_COOKIE ] ) )
			: '';
		if ( preg_match( '/^[A-Za-z0-9]{20,64}$/', $existing ) ) {
			return;
		}
		$token = wp_generate_password( 32, false, false );
		setcookie( self::GUEST_COOKIE, $token, time() + 30 * DAY_IN_SECONDS, COOKIEPATH ?: '/', COOKIE_DOMAIN, is_ssl(), true );
		$_COOKIE[ self::GUEST_COOKIE ] = $token;
	}
}
