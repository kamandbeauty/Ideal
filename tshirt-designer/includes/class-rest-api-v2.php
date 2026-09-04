<?php
/**
 * Custom Product Designer REST API — namespace `custom-product-designer/v1`.
 *
 * Phase-1's `tshirt-designer/v1` routes stay untouched and fully supported.
 * Everything added in phase 2 (product types, versions, duplicate/delete,
 * cart, text fonts) lives here behind the new, product-agnostic namespace.
 *
 * Every route declares a permission callback; every write re-checks
 * ownership; no route ever accepts a price from the client.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Rest_Api_V2 {

	public const NS = 'custom-product-designer/v1';

	public function __construct( private Plugin $plugin ) {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes(): void {
		$public = array( $this, 'allow_read' );
		$write  = array( $this, 'can_write' );

		register_rest_route(
			self::NS,
			'/product-types',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'list_product_types' ),
				'permission_callback' => $public,
			)
		);

		register_rest_route(
			self::NS,
			'/models',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'list_models' ),
				'permission_callback' => $public,
				'args'                => array(
					'product_type' => array(
						'required'          => false,
						'validate_callback' => static fn( $v ): bool => is_string( $v ),
						'sanitize_callback' => 'sanitize_key',
					),
				),
			)
		);

		register_rest_route(
			self::NS,
			'/fonts',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'list_fonts' ),
				'permission_callback' => $public,
			)
		);

		register_rest_route(
			self::NS,
			'/designs/(?P<id>\d+)/versions',
			array(
				'methods'             => \WP_REST_Server::READABLE,
				'callback'            => array( $this, 'list_versions' ),
				'permission_callback' => $write,
				'args'                => array( 'id' => $this->id_arg() ),
			)
		);

		register_rest_route(
			self::NS,
			'/designs/(?P<id>\d+)/duplicate',
			array(
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'duplicate_design' ),
				'permission_callback' => $write,
				'args'                => array( 'id' => $this->id_arg() ),
			)
		);

		register_rest_route(
			self::NS,
			'/designs/(?P<id>\d+)',
			array(
				'methods'             => \WP_REST_Server::DELETABLE,
				'callback'            => array( $this, 'delete_design' ),
				'permission_callback' => $write,
				'args'                => array( 'id' => $this->id_arg() ),
			)
		);

		register_rest_route(
			self::NS,
			'/cart',
			array(
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'add_to_cart' ),
				'permission_callback' => $write,
				'args'                => array(
					'design_id' => $this->id_arg(),
					'quantity'  => array(
						'required'          => false,
						'validate_callback' => static fn( $v ): bool => is_numeric( $v ),
					),
				),
			)
		);
	}

	/**
	 * @return array<string, mixed>
	 */
	private function id_arg(): array {
		return array(
			'required'          => true,
			'validate_callback' => static fn( $v ): bool => is_numeric( $v ) && (int) $v > 0,
		);
	}

	// --------------------------------------------------------------- reads

	public function list_product_types(): \WP_REST_Response {
		$out = array();
		foreach ( Product_Type_Registry::all() as $slug => $type ) {
			$areas = array();
			foreach ( $type['area_types'] as $key => $label ) {
				$areas[] = array( 'type' => $key, 'label' => $label );
			}
			$out[] = array(
				'slug'       => $slug,
				'label'      => (string) $type['label'],
				'has_sizes'  => (bool) $type['has_sizes'],
				'area_types' => $areas,
			);
		}
		return rest_ensure_response( $out );
	}

	public function list_models( \WP_REST_Request $request ): \WP_REST_Response {
		$product_type = (string) ( $request->get_param( 'product_type' ) ?? '' );
		if ( '' !== $product_type && ! Product_Type_Registry::exists( $product_type ) ) {
			return rest_ensure_response( array() );
		}

		$out = array();
		foreach ( $this->plugin->models->all( true, $product_type ) as $model ) {
			$shape = $this->plugin->models->public_shape( $model );
			if ( '' === $shape['model_url'] ) {
				continue;
			}
			$out[] = $shape;
		}
		return rest_ensure_response( $out );
	}

	public function list_fonts(): \WP_REST_Response {
		return rest_ensure_response( Text_Engine::public_fonts() );
	}

	public function list_versions( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$id     = (int) $request['id'];
		$design = $this->plugin->designs->get_design( $id, get_current_user_id(), $this->guest_token() );
		if ( null === $design ) {
			return $this->not_found();
		}
		return rest_ensure_response(
			array(
				'ok'       => true,
				'uuid'     => (string) $design['uuid'],
				'current'  => (int) $design['version'],
				'versions' => $this->plugin->designs->versions( $id ),
			)
		);
	}

	// -------------------------------------------------------------- writes

	public function duplicate_design( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$result = $this->plugin->designs->duplicate(
			(int) $request['id'],
			get_current_user_id(),
			$this->guest_token()
		);
		if ( ! $result['ok'] ) {
			return new \WP_Error(
				'td_duplicate_failed',
				implode( ' ', $result['errors'] ),
				array( 'status' => 400 )
			);
		}
		return rest_ensure_response( $result );
	}

	public function delete_design( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		$result = $this->plugin->designs->delete(
			(int) $request['id'],
			get_current_user_id(),
			$this->guest_token()
		);
		if ( ! $result['ok'] ) {
			return new \WP_Error(
				'td_delete_failed',
				implode( ' ', $result['errors'] ),
				array( 'status' => 400 )
			);
		}
		return rest_ensure_response( array( 'ok' => true ) );
	}

	public function add_to_cart( \WP_REST_Request $request ): \WP_REST_Response|\WP_Error {
		if ( null === $this->plugin->cart ) {
			return new \WP_Error(
				'td_no_woocommerce',
				__( 'WooCommerce is not available.', 'tshirt-designer' ),
				array( 'status' => 501 )
			);
		}

		$result = $this->plugin->cart->add_to_cart(
			(int) $request->get_param( 'design_id' ),
			(int) ( $request->get_param( 'quantity' ) ?? 1 ),
			get_current_user_id(),
			$this->guest_token()
		);

		if ( ! $result['ok'] ) {
			return new \WP_Error(
				'td_cart_failed',
				implode( ' ', $result['errors'] ),
				array( 'status' => 400 )
			);
		}

		return rest_ensure_response(
			array(
				'ok'        => true,
				'cart_url'  => function_exists( 'wc_get_cart_url' ) ? wc_get_cart_url() : '',
				'breakdown' => $result['breakdown'],
			)
		);
	}

	// --------------------------------------------------------- permissions

	public function allow_read(): bool {
		return true;
	}

	/**
	 * Same policy as v1 writes: nonce for logged-in users, same-origin +
	 * guest setting for anonymous visitors.
	 */
	public function can_write(): bool|\WP_Error {
		return ( new Rest_Permissions( $this->plugin->settings ) )->can_post();
	}

	private function guest_token(): string {
		return Rest_Permissions::guest_token();
	}

	private function not_found(): \WP_Error {
		return new \WP_Error(
			'td_not_found',
			__( 'Design not found.', 'tshirt-designer' ),
			array( 'status' => 404 )
		);
	}
}
