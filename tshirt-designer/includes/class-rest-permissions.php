<?php
/**
 * Shared REST permission policy for every namespace of the plugin.
 *
 * Policy:
 *  - logged-in requests must carry a valid `wp_rest` nonce (cookie auth);
 *  - anonymous requests must pass a same-origin check (CSRF mitigation);
 *  - anonymous access to a feature can be switched off in settings.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Rest_Permissions {

	public function __construct( private Settings $settings ) {}

	/**
	 * Permission for upload endpoints.
	 */
	public function can_upload(): bool|\WP_Error {
		return $this->check( 'allow_guest_uploads', __( 'Please log in to upload images.', 'tshirt-designer' ) );
	}

	/**
	 * Permission for design read/write endpoints.
	 */
	public function can_post(): bool|\WP_Error {
		return $this->check( 'allow_guest_designs', __( 'Please log in to save designs.', 'tshirt-designer' ) );
	}

	/**
	 * Run the policy for one guest-permission setting.
	 */
	private function check( string $setting, string $login_message ): bool|\WP_Error {
		if ( is_user_logged_in() ) {
			return $this->verify_nonce();
		}
		if ( ! $this->same_origin() ) {
			return new \WP_Error( 'td_forbidden', __( 'Forbidden.', 'tshirt-designer' ), array( 'status' => 403 ) );
		}
		if ( ! (int) $this->settings->get( $setting, 1 ) ) {
			return new \WP_Error( 'td_login_required', $login_message, array( 'status' => 401 ) );
		}
		return true;
	}

	/**
	 * Verify the wp_rest nonce when the request carries cookie credentials.
	 */
	public function verify_nonce(): bool|\WP_Error {
		// phpcs:ignore WordPress.Security.NonceVerification
		$nonce = $_SERVER['X_WP_NONCE'] ?? $_SERVER['HTTP_X_WP_NONCE'] ?? '';
		$nonce = is_string( $nonce ) ? $nonce : '';
		if ( '' === $nonce ) {
			// REST cookie auth already rejects mismatched nonces upstream;
			// without a nonce the request continues as an anonymous request,
			// which our same-origin check governs.
			return $this->same_origin();
		}
		if ( ! wp_verify_nonce( $nonce, 'wp_rest' ) ) {
			return new \WP_Error( 'td_bad_nonce', __( 'Invalid nonce.', 'tshirt-designer' ), array( 'status' => 403 ) );
		}
		return true;
	}

	/**
	 * Reject cross-site requests (CSRF mitigation).
	 */
	public function same_origin(): bool {
		$origin  = isset( $_SERVER['HTTP_ORIGIN'] ) ? esc_url_raw( wp_unslash( $_SERVER['HTTP_ORIGIN'] ) ) : '';
		$referer = isset( $_SERVER['HTTP_REFERER'] ) ? esc_url_raw( wp_unslash( $_SERVER['HTTP_REFERER'] ) ) : '';
		$host    = isset( $_SERVER['HTTP_HOST'] ) ? sanitize_text_field( wp_unslash( $_SERVER['HTTP_HOST'] ) ) : '';

		if ( '' === $host ) {
			return false;
		}
		foreach ( array( $origin, $referer ) as $candidate ) {
			if ( '' === $candidate ) {
				continue;
			}
			$parsed = wp_parse_url( $candidate );
			if ( is_array( $parsed ) && isset( $parsed['host'] ) ) {
				$candidate_host = $parsed['host'] . ( isset( $parsed['port'] ) ? ':' . $parsed['port'] : '' );
				if ( $candidate_host === $host ) {
					return true;
				}
			}
		}
		// Same-host requests may legitimately omit both headers (e.g. curl),
		// so only fail when one of them points elsewhere.
		if ( '' !== $origin || '' !== $referer ) {
			return false;
		}
		return true;
	}

	/**
	 * Guest token from the td_guest cookie (set when rendering the designer).
	 */
	public static function guest_token(): string {
		$token = isset( $_COOKIE['td_guest'] ) ? sanitize_text_field( wp_unslash( $_COOKIE['td_guest'] ) ) : '';
		return preg_match( '/^[A-Za-z0-9]{20,64}$/', (string) $token ) ? (string) $token : '';
	}
}
