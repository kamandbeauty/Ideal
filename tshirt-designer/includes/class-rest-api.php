<?php
/**
 * REST API — /wp-json/tshirt-designer/v1/
 *
 * Public read endpoints feed the designer; POST endpoints are protected by
 * nonce (for logged-in cookie auth), same-origin checks and rate limits.
 * Prices are always computed server-side; client prices are never trusted.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Rest_Api {

	public const NS = 'tshirt-designer/v1';

	public function __construct( private Plugin $plugin ) {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes(): void {
		register_rest_route(
			self::NS,
			'/models',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'list_models' ),
				'permission_callback' => '__return_true',
			)
		);

		register_rest_route(
			self::NS,
			'/models/(?P<id>\d+)',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_model' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'id' => array(
						'required'          => true,
						'validate_callback' => static fn( $v ): bool => is_numeric( $v ),
					),
				),
			)
		);

		register_rest_route(
			self::NS,
			'/assets',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'list_assets' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'category' => array(
						'required'          => false,
						'validate_callback' => static fn( $v ): bool => is_string( $v ),
					),
				),
			)
		);

		register_rest_route(
			self::NS,
			'/uploads',
			array(
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'handle_upload' ),
				'permission_callback' => array( $this, 'can_upload' ),
			)
		);

		register_rest_route(
			self::NS,
			'/price',
			array(
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'calculate_price' ),
				'permission_callback' => array( $this, 'can_post' ),
			)
		);

		register_rest_route(
			self::NS,
			'/designs',
			array(
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'save_design' ),
				'permission_callback' => array( $this, 'can_post' ),
			)
		);

		register_rest_route(
			self::NS,
			'/designs',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'list_designs' ),
				'permission_callback' => array( $this, 'can_post' ),
			)
		);

		register_rest_route(
			self::NS,
			'/designs/(?P<id>\d+)',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_design' ),
				'permission_callback' => array( $this, 'can_post' ),
				'args'                => array(
					'id' => array(
						'required'          => true,
						'validate_callback' => static fn( $v ): bool => is_numeric( $v ),
					),
				),
			)
		);
	}

	// ------------------------------------------------------------- getters

	public function list_models(): \WP_REST_Response {
		$out = array();
		foreach ( $this->plugin->models->all( true ) as $model ) {
			$shape = $this->plugin->models->public_shape( $model );
			if ( '' === $shape['model_url'] ) {
				continue; // Model without a GLB is not usable in the designer.
			}
			$out[] = $shape;
		}
		return rest_ensure_response( $out );
	}

	public function get_model( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$model = $this->plugin->models->get( (int) $request['id'] );
		if ( null === $model ) {
			return new \WP_Error(
				'td_model_not_found',
				__( 'Model not found.', 'tshirt-designer' ),
				array( 'status' => 404 )
			);
		}

		$shape = $this->plugin->models->public_shape( $model );
		if ( '' === $shape['model_url'] ) {
			return new \WP_Error(
				'td_model_no_file',
				__( 'This model has no 3D file yet.', 'tshirt-designer' ),
				array( 'status' => 409 )
			);
		}

		$shape['base_price'] = $this->plugin->models->base_price( $model );

		$shape['colors'] = array_map(
			array( $this->plugin->colors, 'public_shape' ),
			$this->plugin->colors->for_model( (int) $model['id'] )
		);
		$shape['sizes'] = array_map(
			array( $this->plugin->sizes, 'public_shape' ),
			$this->plugin->sizes->for_model( (int) $model['id'] )
		);
		$shape['print_areas'] = array_map(
			array( $this->plugin->print_areas, 'public_shape' ),
			$this->plugin->print_areas->for_model( (int) $model['id'] )
		);

		$shape['currency'] = $this->plugin->settings->all()['currency'];

		return rest_ensure_response( $shape );
	}

	public function list_assets( \WP_REST_Request $request ): \WP_REST_Response {
		$category = sanitize_key( (string) $request->get_param( 'category' ) );
		$out      = array();
		foreach ( $this->plugin->assets->all( true, $category ) as $asset ) {
			$shape = $this->plugin->assets->public_shape( $asset );
			if ( '' === $shape['url'] ) {
				continue;
			}
			$out[] = $shape;
		}
		return rest_ensure_response( $out );
	}

	// ------------------------------------------------------------- posts

	public function handle_upload( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$files = $request->get_file_params();
		$file  = is_array( $files['file'] ?? null ) ? $files['file'] : null;

		$error   = '';
		$valid   = $this->plugin->media->validate_upload( $file, $error );
		if ( null === $valid ) {
			return new \WP_Error( 'td_upload_invalid', $error, array( 'status' => 400 ) );
		}

		$user_id     = get_current_user_id();
		$guest_token = $this->guest_token();
		$ip          = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : '';

		if ( ! $this->plugin->media->check_rate_limit( $user_id, $ip ) ) {
			return new \WP_Error(
				'td_upload_rate_limited',
				__( 'Too many uploads. Please try again later.', 'tshirt-designer' ),
				array( 'status' => 429 )
			);
		}

		$stored = $this->plugin->media->store_upload( $valid, $user_id, $guest_token );
		if ( null === $stored ) {
			return new \WP_Error(
				'td_upload_failed',
				__( 'The file could not be stored.', 'tshirt-designer' ),
				array( 'status' => 500 )
			);
		}

		return rest_ensure_response( array(
			'ok'      => true,
			'upload'  => array(
				'id'     => (int) $stored['id'],
				'url'    => (string) $stored['url'],
				'width'  => (int) $stored['width'],
				'height' => (int) $stored['height'],
				'mime'   => (string) $stored['mime'],
			),
		) );
	}

	/**
	 * Server-side price calculation. Any price sent by the client is ignored.
	 */
	public function calculate_price( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$input = $this->design_payload( $request );

		$result = $this->plugin->designs->quote(
			$input,
			get_current_user_id(),
			$this->guest_token()
		);

		if ( ! $result['ok'] ) {
			return new \WP_Error( 'td_invalid_design', implode( ' ', $result['errors'] ), array( 'status' => 400 ) );
		}

		return rest_ensure_response( array(
			'ok'        => true,
			'breakdown' => $result['breakdown'],
		) );
	}

	public function save_design( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$input  = $this->design_payload( $request );
		$body   = $request->get_json_params();
		$preview = is_array( $body ) && isset( $body['preview'] ) && is_string( $body['preview'] )
			? $body['preview']
			: null;

		$result = $this->plugin->designs->save(
			$input,
			get_current_user_id(),
			$this->guest_token(),
			$preview
		);

		if ( ! $result['ok'] ) {
			return new \WP_Error( 'td_invalid_design', implode( ' ', $result['errors'] ), array( 'status' => 400 ) );
		}

		$quote = $this->plugin->designs->quote( $input, get_current_user_id(), $this->guest_token() );

		return rest_ensure_response( array(
			'ok'        => true,
			'id'        => (int) $result['id'],
			'breakdown' => $quote['ok'] ? $quote['breakdown'] : null,
		) );
	}

	public function list_designs(): \WP_REST_Response {
		$rows = $this->plugin->designs->list_designs( get_current_user_id(), $this->guest_token() );
		$out  = array();
		foreach ( $rows as $row ) {
			$out[] = array(
				'id'          => (int) $row['id'],
				'model_id'    => (int) $row['model_id'],
				'price_total' => (float) $row['price_total'],
				'status'      => (string) $row['status'],
				'updated_at'  => (string) $row['updated_at'],
				'design'      => $row['design_data'],
			);
		}
		return rest_ensure_response( $out );
	}

	public function get_design( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$row = $this->plugin->designs->get_design(
			(int) $request['id'],
			get_current_user_id(),
			$this->guest_token()
		);
		if ( null === $row ) {
			return new \WP_Error( 'td_design_not_found', __( 'Design not found.', 'tshirt-designer' ), array( 'status' => 404 ) );
		}
		return rest_ensure_response( array(
			'id'          => (int) $row['id'],
			'model_id'    => (int) $row['model_id'],
			'price_total' => (float) $row['price_total'],
			'price_breakdown' => $row['price_breakdown'],
			'status'      => (string) $row['status'],
			'updated_at'  => (string) $row['updated_at'],
			'design'      => $row['design_data'],
		) );
	}

	// ------------------------------------------------------------- helpers

	/**
	 * Extract + sanitize the design payload from JSON body.
	 *
	 * @return array<string, mixed>
	 */
	private function design_payload( \WP_REST_Request $request ): array {
		$body = $request->get_json_params();
		if ( ! is_array( $body ) ) {
			return array();
		}
		$payload = array(
			'model_id' => (int) ( $body['model_id'] ?? 0 ),
			'color_id' => (int) ( $body['color_id'] ?? 0 ),
			'size_id'  => (int) ( $body['size_id'] ?? 0 ),
			'areas'    => array(),
		);
		if ( isset( $body['design'] ) && is_array( $body['design'] ) ) {
			// Accept {"design": {...}} wrappers too.
			$d        = $body['design'];
			$payload['model_id'] = (int) ( $d['model_id'] ?? $payload['model_id'] );
			$payload['color_id'] = (int) ( $d['color_id'] ?? $payload['color_id'] );
			$payload['size_id']  = (int) ( $d['size_id'] ?? $payload['size_id'] );
			$body['areas']       = $d['areas'] ?? array();
		}
		if ( isset( $body['areas'] ) && is_array( $body['areas'] ) ) {
			foreach ( $body['areas'] as $area_id => $items ) {
				$aid = (int) $area_id;
				if ( $aid <= 0 || ! is_array( $items ) ) {
					continue;
				}
				$clean_items = array();
				foreach ( $items as $item ) {
					if ( ! is_array( $item ) ) {
						continue;
					}
					$clean_items[] = array(
						'id'       => (string) ( $item['id'] ?? '' ),
						'type'     => (string) ( $item['type'] ?? '' ),
						'ref_id'   => (int) ( $item['ref_id'] ?? 0 ),
						'x'        => (float) ( $item['x'] ?? 0 ),
						'y'        => (float) ( $item['y'] ?? 0 ),
						'w'        => (float) ( $item['w'] ?? 0 ),
						'h'        => (float) ( $item['h'] ?? 0 ),
						'rotation' => (float) ( $item['rotation'] ?? 0 ),
					);
				}
				$payload['areas'][ (string) $aid ] = $clean_items;
			}
		}
		return $payload;
	}

	/**
	 * Guest token from the td_guest cookie (set when rendering the designer).
	 */
	private function guest_token(): string {
		$token = isset( $_COOKIE['td_guest'] ) ? sanitize_text_field( wp_unslash( $_COOKIE['td_guest'] ) ) : '';
		return preg_match( '/^[A-Za-z0-9]{20,64}$/', (string) $token ) ? (string) $token : '';
	}

	/**
	 * POST permission: logged-in users need a valid nonce (cookie auth);
	 * anonymous visitors are subject to a same-origin check; guest access
	 * can be disabled per feature in settings.
	 */
	public function can_upload(): bool|\WP_Error {
		if ( is_user_logged_in() ) {
			return $this->verify_nonce();
		}
		if ( ! $this->same_origin() ) {
			return new \WP_Error( 'td_forbidden', __( 'Forbidden.', 'tshirt-designer' ), array( 'status' => 403 ) );
		}
		if ( ! (int) $this->plugin->settings->get( 'allow_guest_uploads', 1 ) ) {
			return new \WP_Error(
				'td_login_required',
				__( 'Please log in to upload images.', 'tshirt-designer' ),
				array( 'status' => 401 )
			);
		}
		return true;
	}

	public function can_post(): bool|\WP_Error {
		if ( is_user_logged_in() ) {
			return $this->verify_nonce();
		}
		if ( ! $this->same_origin() ) {
			return new \WP_Error( 'td_forbidden', __( 'Forbidden.', 'tshirt-designer' ), array( 'status' => 403 ) );
		}
		if ( ! (int) $this->plugin->settings->get( 'allow_guest_designs', 1 ) ) {
			return new \WP_Error(
				'td_login_required',
				__( 'Please log in to save designs.', 'tshirt-designer' ),
				array( 'status' => 401 )
			);
		}
		return true;
	}

	/**
	 * Verify the wp_rest nonce when the request carries cookie credentials.
	 */
	private function verify_nonce(): bool|\WP_Error {
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
	 * Reject cross-site POSTs from anonymous visitors (CSRF mitigation).
	 */
	private function same_origin(): bool {
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
}
