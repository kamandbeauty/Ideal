<?php
/**
 * Admin page: Production dashboard and job detail.
 *
 * Server-rendered on purpose (§42): the fulfilment team needs a fast, robust,
 * RTL-friendly screen that works without a heavy JS bundle. Every mutating
 * action goes through admin-post with a nonce and a capability check, and the
 * legality of a status move is always decided by Production_Status on the
 * server — the UI only hides buttons it knows are pointless.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

use TShirtDesigner\Production_Manager;
use TShirtDesigner\Production_Status;
use TShirtDesigner\Product_Type_Registry;

defined( 'ABSPATH' ) || exit;

final class Admin_Production {

	private const PER_PAGE = 20;

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {
		add_action( 'admin_post_td_production_download', array( $this, 'handle_download' ) );
		add_action( 'admin_post_td_production_zip', array( $this, 'handle_zip' ) );
	}

	/**
	 * Capability for the whole screen.
	 */
	public static function can(): bool {
		return Production_Manager::can_manage();
	}

	// ------------------------------------------------------------- rendering

	public function render(): void {
		if ( ! self::can() ) {
			wp_die( esc_html__( 'You are not allowed to manage production.', 'tshirt-designer' ) );
		}

		// phpcs:ignore WordPress.Security.NonceVerification -- read-only routing.
		$job_id = isset( $_GET['job'] ) && ctype_digit( (string) $_GET['job'] ) ? (int) $_GET['job'] : 0;

		if ( $job_id > 0 ) {
			$this->render_detail( $job_id );
			return;
		}
		$this->render_list();
	}

	private function render_list(): void {
		// phpcs:disable WordPress.Security.NonceVerification -- read-only listing filters.
		$args = array(
			'status'       => isset( $_GET['status'] ) ? sanitize_key( (string) wp_unslash( $_GET['status'] ) ) : '',
			'product_type' => isset( $_GET['product_type'] ) ? sanitize_key( (string) wp_unslash( $_GET['product_type'] ) ) : '',
			'model_id'     => isset( $_GET['model_id'] ) ? absint( wp_unslash( $_GET['model_id'] ) ) : 0,
			'priority'     => isset( $_GET['priority'] ) ? sanitize_key( (string) wp_unslash( $_GET['priority'] ) ) : '',
			'order_id'     => isset( $_GET['order_id'] ) ? absint( wp_unslash( $_GET['order_id'] ) ) : 0,
			'design_id'    => isset( $_GET['design_id'] ) ? absint( wp_unslash( $_GET['design_id'] ) ) : 0,
			'search'       => isset( $_GET['s'] ) ? sanitize_text_field( wp_unslash( $_GET['s'] ) ) : '',
			'date_from'    => isset( $_GET['date_from'] ) ? sanitize_text_field( wp_unslash( $_GET['date_from'] ) ) : '',
			'date_to'      => isset( $_GET['date_to'] ) ? sanitize_text_field( wp_unslash( $_GET['date_to'] ) ) : '',
			'orderby'      => isset( $_GET['orderby'] ) ? sanitize_key( (string) wp_unslash( $_GET['orderby'] ) ) : 'newest',
			'page'         => isset( $_GET['paged'] ) ? max( 1, absint( wp_unslash( $_GET['paged'] ) ) ) : 1,
			'per_page'     => self::PER_PAGE,
		);
		// phpcs:enable

		$result = $this->plugin->production_jobs->query( $args );
		$counts = $this->plugin->production_jobs->status_counts();
		$models = $this->plugin->models->all();
		$types  = Product_Type_Registry::all();

		$title = __( 'Production', 'tshirt-designer' );
		require TD_PLUGIN_DIR . 'admin/views/html-header.php';
		require TD_PLUGIN_DIR . 'admin/views/html-production.php';
		require TD_PLUGIN_DIR . 'admin/views/html-footer.php';
	}

	private function render_detail( int $job_id ): void {
		$job = $this->plugin->production_jobs->get( $job_id );
		if ( null === $job ) {
			$title = __( 'Production', 'tshirt-designer' );
			require TD_PLUGIN_DIR . 'admin/views/html-header.php';
			echo '<div class="notice notice-error"><p>'
				. esc_html__( 'That production job does not exist.', 'tshirt-designer' )
				. '</p></div>';
			require TD_PLUGIN_DIR . 'admin/views/html-footer.php';
			return;
		}

		$snapshot = $this->plugin->production_jobs->snapshot( $job_id );
		$files    = $this->plugin->production_service->files( $job_id );
		$history  = $this->plugin->production_jobs->history( $job_id );
		$next     = Production_Status::next( (string) $job['status'] );
		$order    = function_exists( 'wc_get_order' ) ? wc_get_order( (int) $job['order_id'] ) : null;

		$title = sprintf(
			/* translators: %d: production job id. */
			__( 'Production job #%d', 'tshirt-designer' ),
			$job_id
		);
		require TD_PLUGIN_DIR . 'admin/views/html-header.php';
		require TD_PLUGIN_DIR . 'admin/views/html-production-detail.php';
		require TD_PLUGIN_DIR . 'admin/views/html-footer.php';
	}

	// --------------------------------------------------------------- actions

	/**
	 * Routed from Admin::route_action() (nonce + capability already verified).
	 */
	public function handle_action( string $do ): void {
		if ( ! self::can() ) {
			wp_die( esc_html__( 'You are not allowed to manage production.', 'tshirt-designer' ) );
		}

		// phpcs:disable WordPress.Security.NonceVerification -- verified in Admin::route_action().
		$job_id = isset( $_POST['job_id'] ) ? absint( wp_unslash( $_POST['job_id'] ) ) : 0;
		$note   = isset( $_POST['note'] ) ? sanitize_textarea_field( wp_unslash( $_POST['note'] ) ) : '';
		$user   = get_current_user_id();

		switch ( $do ) {
			case 'status':
				$to  = isset( $_POST['status'] ) ? sanitize_key( (string) wp_unslash( $_POST['status'] ) ) : '';
				$res = $this->plugin->production_jobs->transition( $job_id, $to, $user, $note );
				$this->redirect_detail( $job_id, $res['ok'] ? __( 'Status updated.', 'tshirt-designer' ) : '', $res['ok'] ? '' : (string) $res['error'] );
				return;

			case 'quality_check':
				$passed = isset( $_POST['passed'] ) && '1' === (string) wp_unslash( $_POST['passed'] );
				$res    = $this->plugin->production_jobs->quality_check( $job_id, $passed, $user, $note );
				$this->redirect_detail( $job_id, $res['ok'] ? __( 'Quality check recorded.', 'tshirt-designer' ) : '', $res['ok'] ? '' : (string) $res['error'] );
				return;

			case 'note':
				$ok = $this->plugin->production_jobs->add_note( $job_id, $note, $user );
				$this->redirect_detail( $job_id, $ok ? __( 'Note added.', 'tshirt-designer' ) : '', $ok ? '' : __( 'The note could not be added.', 'tshirt-designer' ) );
				return;

			case 'priority':
				$priority = isset( $_POST['priority'] ) ? sanitize_key( (string) wp_unslash( $_POST['priority'] ) ) : '';
				$ok       = $this->plugin->production_jobs->set_priority( $job_id, $priority, $user );
				$this->redirect_detail( $job_id, $ok ? __( 'Priority updated.', 'tshirt-designer' ) : '', $ok ? '' : __( 'That priority is not valid.', 'tshirt-designer' ) );
				return;

			case 'regenerate':
				$reason = '' !== $note ? $note : __( 'Manual regeneration from the dashboard.', 'tshirt-designer' );
				$res    = $this->plugin->production_service->regenerate( $job_id, $user, $reason );
				$this->redirect_detail(
					$job_id,
					$res['ok'] ? __( 'Production files regenerated from the purchased snapshot.', 'tshirt-designer' ) : '',
					$res['ok'] ? '' : implode( ' ', $res['errors'] )
				);
				return;

			case 'retry':
				$res = $this->plugin->production_service->retry( $job_id, $user, $note );
				$this->redirect_detail(
					$job_id,
					$res['ok'] ? __( 'Production retried successfully.', 'tshirt-designer' ) : '',
					$res['ok'] ? '' : implode( ' ', $res['errors'] )
				);
				return;

			case 'bulk':
				$this->handle_bulk();
				return;
		}
		// phpcs:enable

		wp_safe_redirect( Admin::page_url( 'production' ) );
		exit;
	}

	/**
	 * Bulk status transitions (§44). Every job is validated individually and
	 * each move is logged; jobs that cannot legally move are reported, not
	 * forced.
	 */
	private function handle_bulk(): void {
		// phpcs:disable WordPress.Security.NonceVerification -- verified in Admin::route_action().
		$ids = isset( $_POST['jobs'] ) && is_array( $_POST['jobs'] )
			? array_map( 'absint', wp_unslash( $_POST['jobs'] ) )
			: array();
		$to  = isset( $_POST['bulk_status'] ) ? sanitize_key( (string) wp_unslash( $_POST['bulk_status'] ) ) : '';
		// phpcs:enable

		$ids = array_values( array_filter( $ids ) );
		if ( array() === $ids || '' === $to ) {
			wp_safe_redirect( add_query_arg( 'error', rawurlencode( __( 'Select at least one job and an action.', 'tshirt-designer' ) ), Admin::page_url( 'production' ) ) );
			exit;
		}

		$user = get_current_user_id();
		$done = 0;
		$bad  = 0;
		foreach ( $ids as $id ) {
			$res = $this->plugin->production_jobs->transition( $id, $to, $user, __( 'Bulk action.', 'tshirt-designer' ) );
			if ( $res['ok'] ) {
				++$done;
			} else {
				++$bad;
			}
		}

		$msg = sprintf(
			/* translators: %d: number of jobs updated. */
			_n( '%d job updated.', '%d jobs updated.', $done, 'tshirt-designer' ),
			$done
		);
		$err = $bad > 0
			? sprintf(
				/* translators: %d: number of jobs skipped. */
				_n( '%d job could not make that transition and was skipped.', '%d jobs could not make that transition and were skipped.', $bad, 'tshirt-designer' ),
				$bad
			)
			: '';

		$url = Admin::page_url( 'production' );
		if ( $done > 0 ) {
			$url = add_query_arg( 'updated', rawurlencode( $msg ), $url );
		}
		if ( '' !== $err ) {
			$url = add_query_arg( 'error', rawurlencode( $err ), $url );
		}
		wp_safe_redirect( $url );
		exit;
	}

	private function redirect_detail( int $job_id, string $updated, string $error ): void {
		$url = Admin::page_url( 'production', array( 'job' => $job_id ) );
		if ( '' !== $updated ) {
			$url = add_query_arg( 'updated', rawurlencode( $updated ), $url );
		}
		if ( '' !== $error ) {
			$url = add_query_arg( 'error', rawurlencode( $error ), $url );
		}
		wp_safe_redirect( $url );
		exit;
	}

	// ------------------------------------------------------------- downloads

	/**
	 * Stream a single production file (§14/§31).
	 *
	 * Capability, nonce, job ownership of the file and path containment are all
	 * checked before a single byte is written.
	 */
	public function handle_download(): void {
		if ( ! self::can() ) {
			wp_die( esc_html__( 'You are not allowed to download production files.', 'tshirt-designer' ) );
		}
		$file_id = isset( $_GET['file'] ) ? absint( wp_unslash( $_GET['file'] ) ) : 0;
		$job_id  = isset( $_GET['job'] ) ? absint( wp_unslash( $_GET['job'] ) ) : 0;
		check_admin_referer( 'td_production_download_' . $file_id );

		$auth = $this->plugin->production_service->authorise_file( $file_id, $job_id );
		if ( ! $auth['ok'] ) {
			wp_die( esc_html( (string) $auth['error'] ) );
		}

		$this->plugin->production_jobs->record_event(
			$job_id,
			Production_Manager::EVENT_DOWNLOAD,
			'',
			'',
			get_current_user_id(),
			(string) $auth['name']
		);

		$this->plugin->production_service->stream( (string) $auth['path'], (string) $auth['name'], (string) $auth['mime'] );
		exit;
	}

	/**
	 * Stream a ZIP of every file on a job (§15).
	 */
	public function handle_zip(): void {
		if ( ! self::can() ) {
			wp_die( esc_html__( 'You are not allowed to download production files.', 'tshirt-designer' ) );
		}
		$job_id = isset( $_GET['job'] ) ? absint( wp_unslash( $_GET['job'] ) ) : 0;
		check_admin_referer( 'td_production_zip_' . $job_id );

		if ( null === $this->plugin->production_jobs->get( $job_id ) ) {
			wp_die( esc_html__( 'That production job does not exist.', 'tshirt-designer' ) );
		}

		$zip = $this->plugin->production_service->zip( $job_id );
		if ( null === $zip || ! file_exists( (string) $zip['path'] ) ) {
			wp_die( esc_html__( 'There are no production files to export for this job yet.', 'tshirt-designer' ) );
		}

		$this->plugin->production_jobs->record_event(
			$job_id,
			Production_Manager::EVENT_DOWNLOAD,
			'',
			'',
			get_current_user_id(),
			(string) $zip['name']
		);

		$this->plugin->production_service->stream( (string) $zip['path'], (string) $zip['name'], 'application/zip' );
		exit;
	}

	/**
	 * URL for downloading one file.
	 */
	public static function download_url( int $file_id, int $job_id ): string {
		return wp_nonce_url(
			admin_url( 'admin-post.php?action=td_production_download&file=' . $file_id . '&job=' . $job_id ),
			'td_production_download_' . $file_id
		);
	}

	/**
	 * URL for the ZIP of a whole job.
	 */
	public static function zip_url( int $job_id ): string {
		return wp_nonce_url(
			admin_url( 'admin-post.php?action=td_production_zip&job=' . $job_id ),
			'td_production_zip_' . $job_id
		);
	}
}
