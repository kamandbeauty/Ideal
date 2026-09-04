<?php
/**
 * Production REST routes — namespace `custom-product-designer/v1`.
 *
 * Phase 3. Every route here is admin-only: the permission callback demands the
 * production capability, so a logged-in customer cannot read, move or download
 * anyone's production job (§29/§30). Nothing in this file trusts a client for
 * status legality — Production_Status is always consulted server-side.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Rest_Production {

	public function __construct( private Plugin $plugin ) {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes(): void {
		$ns    = Rest_Api_V2::NS;
		$admin = array( $this, 'can_manage' );

		register_rest_route(
			$ns,
			'/production',
			array(
				'methods'             => 'GET',
				'callback'            => array( $this, 'list_jobs' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)',
			array(
				'methods'             => 'GET',
				'callback'            => array( $this, 'get_job' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)/status',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'set_status' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)/regenerate',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'regenerate' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)/retry',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'retry' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)/files',
			array(
				'methods'             => 'GET',
				'callback'            => array( $this, 'files' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)/notes',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'add_note' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)/history',
			array(
				'methods'             => 'GET',
				'callback'            => array( $this, 'history' ),
				'permission_callback' => $admin,
			)
		);

		register_rest_route(
			$ns,
			'/production/(?P<id>\d+)/quality-check',
			array(
				'methods'             => 'POST',
				'callback'            => array( $this, 'quality_check' ),
				'permission_callback' => $admin,
			)
		);
	}

	/**
	 * Admin-only gate for every production route.
	 */
	public function can_manage(): bool|\WP_Error {
		if ( ! Production_Manager::can_manage() ) {
			return new \WP_Error(
				'td_forbidden',
				__( 'You are not allowed to manage production.', 'tshirt-designer' ),
				array( 'status' => rest_authorization_required_code() )
			);
		}
		return true;
	}

	// ------------------------------------------------------------- handlers

	public function list_jobs( \WP_REST_Request $request ): \WP_REST_Response {
		$result = $this->plugin->production_jobs->query(
			array(
				'status'       => sanitize_text_field( (string) $request->get_param( 'status' ) ),
				'product_type' => sanitize_key( (string) $request->get_param( 'product_type' ) ),
				'model_id'     => (int) $request->get_param( 'model_id' ),
				'priority'     => sanitize_key( (string) $request->get_param( 'priority' ) ),
				'order_id'     => (int) $request->get_param( 'order_id' ),
				'design_id'    => (int) $request->get_param( 'design_id' ),
				'search'       => sanitize_text_field( (string) $request->get_param( 'search' ) ),
				'date_from'    => sanitize_text_field( (string) $request->get_param( 'date_from' ) ),
				'date_to'      => sanitize_text_field( (string) $request->get_param( 'date_to' ) ),
				'orderby'      => sanitize_key( (string) $request->get_param( 'orderby' ) ),
				'page'         => max( 1, (int) $request->get_param( 'page' ) ),
				'per_page'     => (int) ( $request->get_param( 'per_page' ) ?: 20 ),
			)
		);
		$result['counts'] = $this->plugin->production_jobs->status_counts();
		return new \WP_REST_Response( $result, 200 );
	}

	public function get_job( \WP_REST_Request $request ): \WP_REST_Response {
		$id  = (int) $request['id'];
		$job = $this->plugin->production_jobs->get( $id );
		if ( null === $job ) {
			return new \WP_REST_Response( array( 'message' => __( 'Production job not found.', 'tshirt-designer' ) ), 404 );
		}

		$job['snapshot']    = $this->plugin->production_jobs->snapshot( $id );
		$job['files']       = $this->plugin->production_service->files( $id );
		$job['history']     = $this->plugin->production_jobs->history( $id );
		$job['next']        = Production_Status::next( (string) $job['status'] );
		$job['next_labels'] = array_map(
			static fn( $s ) => array( 'status' => $s, 'label' => Production_Status::label( $s ) ),
			$job['next']
		);
		return new \WP_REST_Response( $job, 200 );
	}

	public function set_status( \WP_REST_Request $request ): \WP_REST_Response {
		$id     = (int) $request['id'];
		$to     = sanitize_key( (string) $request->get_param( 'status' ) );
		$note   = sanitize_textarea_field( (string) $request->get_param( 'note' ) );
		$result = $this->plugin->production_jobs->transition( $id, $to, get_current_user_id(), $note );

		if ( ! $result['ok'] ) {
			return new \WP_REST_Response( array( 'message' => $result['error'] ), 400 );
		}
		return new \WP_REST_Response( $result['job'], 200 );
	}

	public function quality_check( \WP_REST_Request $request ): \WP_REST_Response {
		$id     = (int) $request['id'];
		$passed = rest_sanitize_boolean( $request->get_param( 'passed' ) );
		$note   = sanitize_textarea_field( (string) $request->get_param( 'note' ) );
		$result = $this->plugin->production_jobs->quality_check( $id, $passed, get_current_user_id(), $note );

		if ( ! $result['ok'] ) {
			return new \WP_REST_Response( array( 'message' => $result['error'] ), 400 );
		}
		return new \WP_REST_Response( $result['job'], 200 );
	}

	public function regenerate( \WP_REST_Request $request ): \WP_REST_Response {
		$id     = (int) $request['id'];
		$reason = sanitize_textarea_field( (string) $request->get_param( 'reason' ) );
		$result = $this->plugin->production_service->regenerate( $id, get_current_user_id(), $reason );

		return new \WP_REST_Response(
			array(
				'ok'     => $result['ok'],
				'files'  => $result['files'],
				// Renderer messages are already translated + user-safe.
				'errors' => $result['errors'],
			),
			$result['ok'] ? 200 : 500
		);
	}

	public function retry( \WP_REST_Request $request ): \WP_REST_Response {
		$id     = (int) $request['id'];
		$reason = sanitize_textarea_field( (string) $request->get_param( 'reason' ) );
		$result = $this->plugin->production_service->retry( $id, get_current_user_id(), $reason );

		return new \WP_REST_Response(
			array( 'ok' => $result['ok'], 'files' => $result['files'], 'errors' => $result['errors'] ),
			$result['ok'] ? 200 : 500
		);
	}

	public function files( \WP_REST_Request $request ): \WP_REST_Response {
		$id = (int) $request['id'];
		if ( null === $this->plugin->production_jobs->get( $id ) ) {
			return new \WP_REST_Response( array( 'message' => __( 'Production job not found.', 'tshirt-designer' ) ), 404 );
		}
		return new \WP_REST_Response( array( 'files' => $this->plugin->production_service->files( $id ) ), 200 );
	}

	public function add_note( \WP_REST_Request $request ): \WP_REST_Response {
		$id   = (int) $request['id'];
		$note = sanitize_textarea_field( (string) $request->get_param( 'note' ) );
		if ( '' === trim( $note ) ) {
			return new \WP_REST_Response( array( 'message' => __( 'The note cannot be empty.', 'tshirt-designer' ) ), 400 );
		}
		if ( ! $this->plugin->production_jobs->add_note( $id, $note, get_current_user_id() ) ) {
			return new \WP_REST_Response( array( 'message' => __( 'Production job not found.', 'tshirt-designer' ) ), 404 );
		}
		return new \WP_REST_Response( array( 'notes' => $this->plugin->production_jobs->notes( $id ) ), 200 );
	}

	public function history( \WP_REST_Request $request ): \WP_REST_Response {
		$id = (int) $request['id'];
		if ( null === $this->plugin->production_jobs->get( $id ) ) {
			return new \WP_REST_Response( array( 'message' => __( 'Production job not found.', 'tshirt-designer' ) ), 404 );
		}
		return new \WP_REST_Response( array( 'history' => $this->plugin->production_jobs->history( $id ) ), 200 );
	}
}
