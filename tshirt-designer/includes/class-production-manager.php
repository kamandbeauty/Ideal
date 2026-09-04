<?php
/**
 * Production job lifecycle: creation, status transitions, events, notes.
 *
 * Phase 3 "Fulfillment Source". WooCommerce remains the commerce source; this
 * class owns everything that happens after payment. It never renders pixels
 * itself (Production_Renderer does) and never reads the live catalogue — a job
 * is always resolved through the immutable snapshot stored on the order item.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Production_Manager {

	public const CAP = 'manage_woocommerce';

	// Event types recorded in td_production_events.
	public const EVENT_CREATED     = 'created';
	public const EVENT_STATUS      = 'status_changed';
	public const EVENT_NOTE        = 'note';
	public const EVENT_RENDER      = 'rendered';
	public const EVENT_REGENERATE  = 'regenerated';
	public const EVENT_RETRY       = 'retry';
	public const EVENT_DOWNLOAD    = 'downloaded';
	public const EVENT_FAILED      = 'failed';
	public const EVENT_QC          = 'quality_check';

	public function __construct( private Plugin $plugin ) {}

	private function jobs_table(): string {
		return $this->plugin->db->table( 'production_jobs' );
	}

	private function events_table(): string {
		return $this->plugin->db->table( 'production_events' );
	}

	/**
	 * Can the current user administer production?
	 */
	public static function can_manage(): bool {
		return current_user_can( self::CAP ) || current_user_can( 'manage_options' );
	}

	// ---------------------------------------------------------------- create

	/**
	 * Create (or fetch) the production job for one paid order line.
	 *
	 * Idempotent: the (order_id, order_item_id) pair is UNIQUE, so replaying a
	 * payment webhook cannot produce duplicates.
	 *
	 * @param array<string, mixed> $snapshot Immutable design snapshot.
	 * @return array<string, mixed>|null
	 */
	public function create_job( int $order_id, int $item_id, array $snapshot, string $status = Production_Status::PAID ): ?array {
		global $wpdb;

		$existing = $this->find_by_item( $order_id, $item_id );
		if ( null !== $existing ) {
			return $existing;
		}

		$order    = function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		$customer = '';
		$email    = '';
		if ( $order instanceof \WC_Order ) {
			$customer = trim( $order->get_billing_first_name() . ' ' . $order->get_billing_last_name() );
			$email    = (string) $order->get_billing_email();
		}

		$now  = current_time( 'mysql' );
		$data = array(
			'order_id'       => $order_id,
			'order_item_id'  => $item_id,
			'design_id'      => (int) ( $snapshot['design_id'] ?? 0 ),
			'design_version' => max( 1, (int) ( $snapshot['version'] ?? 1 ) ),
			'product_type'   => (string) ( $snapshot['product_type'] ?? '' ),
			'model_id'       => (int) ( $snapshot['model']['id'] ?? 0 ),
			'color_id'       => (int) ( $snapshot['color']['id'] ?? 0 ),
			'size_id'        => (int) ( $snapshot['size']['id'] ?? 0 ),
			'status'         => Production_Status::is_status( $status ) ? $status : Production_Status::PAID,
			'priority'       => Production_Status::PRIORITY_NORMAL,
			'customer_name'  => $customer,
			'customer_email' => $email,
			'created_at'     => $now,
			'updated_at'     => $now,
		);

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$inserted = $wpdb->insert( $this->jobs_table(), $data );
		if ( ! $inserted ) {
			// Lost a race against a concurrent webhook: the row now exists.
			return $this->find_by_item( $order_id, $item_id );
		}

		$job_id = (int) $wpdb->insert_id;
		$this->record_event( $job_id, self::EVENT_CREATED, '', $data['status'], 0, '' );
		$this->plugin->logger->info(
			'production',
			'Production job created',
			array( 'job_id' => $job_id, 'order_id' => $order_id, 'item_id' => $item_id )
		);

		/**
		 * Fires when a production job is created.
		 *
		 * Integration seam for future email/SMS/webhook layers (§45/§46).
		 */
		do_action( 'td_production_created', $job_id, $order_id, $item_id );

		return $this->get( $job_id );
	}

	/**
	 * Create jobs for every designed line on an order. Called on payment.
	 *
	 * @return int[] Job IDs.
	 */
	public function create_jobs_for_order( int $order_id ): array {
		$order = function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		if ( ! $order instanceof \WC_Order ) {
			return array();
		}

		$made = array();
		foreach ( $order->get_items() as $item_id => $item ) {
			$snapshot = Order_Manager::snapshot_from_item( $item );
			if ( null === $snapshot ) {
				continue; // Not a designed line.
			}
			$job = $this->create_job( $order_id, (int) $item_id, $snapshot );
			if ( null !== $job ) {
				$made[] = (int) $job['id'];
			}
		}
		return $made;
	}

	// ----------------------------------------------------------------- reads

	/**
	 * @return array<string, mixed>|null
	 */
	public function get( int $job_id ): ?array {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL
		$row = $wpdb->get_row(
			$wpdb->prepare( 'SELECT * FROM ' . $this->jobs_table() . ' WHERE id = %d', $job_id ),
			ARRAY_A
		);
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	/**
	 * @return array<string, mixed>|null
	 */
	public function find_by_item( int $order_id, int $item_id ): ?array {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL
		$row = $wpdb->get_row(
			$wpdb->prepare(
				'SELECT * FROM ' . $this->jobs_table() . ' WHERE order_id = %d AND order_item_id = %d',
				$order_id,
				$item_id
			),
			ARRAY_A
		);
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	/**
	 * All jobs belonging to an order.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function for_order( int $order_id ): array {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL
		$rows = $wpdb->get_results(
			$wpdb->prepare( 'SELECT * FROM ' . $this->jobs_table() . ' WHERE order_id = %d ORDER BY id ASC', $order_id ),
			ARRAY_A
		);
		return array_map( array( $this, 'cast' ), is_array( $rows ) ? $rows : array() );
	}

	/**
	 * Paginated, filtered query for the dashboard (§10/§11/§48).
	 *
	 * @param array<string, mixed> $args
	 * @return array{items:array<int, array<string,mixed>>, total:int, pages:int, page:int, per_page:int}
	 */
	public function query( array $args = array() ): array {
		global $wpdb;

		$defaults = array(
			'status'       => '',
			'product_type' => '',
			'model_id'     => 0,
			'priority'     => '',
			'order_id'     => 0,
			'design_id'    => 0,
			'search'       => '',
			'date_from'    => '',
			'date_to'      => '',
			'orderby'      => 'newest',
			'page'         => 1,
			'per_page'     => 20,
		);
		$args = array_merge( $defaults, $args );

		$where  = array( '1=1' );
		$params = array();

		if ( '' !== $args['status'] ) {
			if ( 'queue' === $args['status'] ) {
				$queue         = Production_Status::queue();
				$placeholders  = implode( ',', array_fill( 0, count( $queue ), '%s' ) );
				$where[]       = "status IN ($placeholders)";
				$params        = array_merge( $params, $queue );
			} elseif ( Production_Status::is_status( (string) $args['status'] ) ) {
				$where[]  = 'status = %s';
				$params[] = $args['status'];
			}
		}
		if ( '' !== $args['product_type'] ) {
			$where[]  = 'product_type = %s';
			$params[] = $args['product_type'];
		}
		if ( $args['model_id'] > 0 ) {
			$where[]  = 'model_id = %d';
			$params[] = (int) $args['model_id'];
		}
		if ( '' !== $args['priority'] && Production_Status::is_priority( (string) $args['priority'] ) ) {
			$where[]  = 'priority = %s';
			$params[] = $args['priority'];
		}
		if ( $args['order_id'] > 0 ) {
			$where[]  = 'order_id = %d';
			$params[] = (int) $args['order_id'];
		}
		if ( $args['design_id'] > 0 ) {
			$where[]  = 'design_id = %d';
			$params[] = (int) $args['design_id'];
		}
		if ( '' !== $args['date_from'] ) {
			$where[]  = 'created_at >= %s';
			$params[] = $args['date_from'] . ' 00:00:00';
		}
		if ( '' !== $args['date_to'] ) {
			$where[]  = 'created_at <= %s';
			$params[] = $args['date_to'] . ' 23:59:59';
		}
		if ( '' !== trim( (string) $args['search'] ) ) {
			$term = trim( (string) $args['search'] );
			// Order ID / job ID / design ID / customer name / customer email.
			$like     = '%' . $wpdb->esc_like( $term ) . '%';
			$where[]  = '(customer_name LIKE %s OR customer_email LIKE %s OR order_id = %d OR id = %d OR design_id = %d)';
			$params[] = $like;
			$params[] = $like;
			$params[] = ctype_digit( $term ) ? (int) $term : 0;
			$params[] = ctype_digit( $term ) ? (int) $term : 0;
			$params[] = ctype_digit( $term ) ? (int) $term : 0;
		}

		$where_sql = implode( ' AND ', $where );

		$order_sql = match ( (string) $args['orderby'] ) {
			'oldest'   => 'created_at ASC, id ASC',
			'priority' => "CASE priority WHEN 'urgent' THEN 2 WHEN 'high' THEN 1 ELSE 0 END DESC, created_at DESC",
			default    => 'created_at DESC, id DESC',
		};

		$per_page = max( 1, min( 100, (int) $args['per_page'] ) );
		$page     = max( 1, (int) $args['page'] );
		$offset   = ( $page - 1 ) * $per_page;

		$count_sql = 'SELECT COUNT(*) FROM ' . $this->jobs_table() . " WHERE $where_sql";
		// phpcs:ignore WordPress.DB.PreparedSQL, WordPress.DB.DirectDatabaseQuery
		$total = (int) $wpdb->get_var( $params ? $wpdb->prepare( $count_sql, $params ) : $count_sql );

		$sql = 'SELECT * FROM ' . $this->jobs_table() . " WHERE $where_sql ORDER BY $order_sql LIMIT %d OFFSET %d";
		$all = array_merge( $params, array( $per_page, $offset ) );
		// phpcs:ignore WordPress.DB.PreparedSQL, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results( $wpdb->prepare( $sql, $all ), ARRAY_A );

		return array(
			'items'    => array_map( array( $this, 'cast' ), is_array( $rows ) ? $rows : array() ),
			'total'    => $total,
			'pages'    => (int) ceil( $total / $per_page ),
			'page'     => $page,
			'per_page' => $per_page,
		);
	}

	/**
	 * Count jobs per status, for the dashboard tabs.
	 *
	 * @return array<string, int>
	 */
	public function status_counts(): array {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL
		$rows = $wpdb->get_results( 'SELECT status, COUNT(*) AS n FROM ' . $this->jobs_table() . ' GROUP BY status', ARRAY_A );
		$out  = array();
		foreach ( (array) $rows as $r ) {
			$out[ (string) $r['status'] ] = (int) $r['n'];
		}
		return $out;
	}

	// ----------------------------------------------------------- transitions

	/**
	 * Move a job to a new status.
	 *
	 * Concurrency-safe (§50): the UPDATE is guarded by `WHERE status = <from>`,
	 * so if another admin already moved the job the affected-row count is 0 and
	 * we refuse rather than silently overwriting their transition.
	 *
	 * @return array{ok:bool, error?:string, job?:array<string,mixed>}
	 */
	public function transition( int $job_id, string $to, int $user_id = 0, string $note = '' ): array {
		global $wpdb;

		$job = $this->get( $job_id );
		if ( null === $job ) {
			return array( 'ok' => false, 'error' => __( 'Production job not found.', 'tshirt-designer' ) );
		}

		$from = (string) $job['status'];
		if ( ! Production_Status::can( $from, $to ) ) {
			return array( 'ok' => false, 'error' => Production_Status::reason( $from, $to ) );
		}

		// A failed quality check must say why (§21).
		if ( Production_Status::QC === $from && Production_Status::IN_PROD === $to && '' === trim( $note ) ) {
			return array(
				'ok'    => false,
				'error' => __( 'A note is required when a quality check fails.', 'tshirt-designer' ),
			);
		}

		$now  = current_time( 'mysql' );
		$data = array(
			'status'     => $to,
			'updated_at' => $now,
		);
		if ( Production_Status::IN_PROD === $to && empty( $job['started_at'] ) ) {
			$data['started_at'] = $now;
		}
		if ( Production_Status::COMPLETED === $to ) {
			$data['completed_at'] = $now;
		}
		if ( Production_Status::FAILED !== $to ) {
			$data['error_message'] = '';
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$affected = $wpdb->update(
			$this->jobs_table(),
			$data,
			array(
				'id'     => $job_id,
				'status' => $from, // Optimistic lock.
			)
		);

		if ( ! $affected ) {
			$fresh = $this->get( $job_id );
			$now_s = $fresh ? Production_Status::label( (string) $fresh['status'] ) : '';
			return array(
				'ok'    => false,
				/* translators: %s: current status label. */
				'error' => sprintf(
					__( 'Someone else changed this job first — it is now %s. Reload and try again.', 'tshirt-designer' ),
					$now_s
				),
			);
		}

		$this->record_event( $job_id, self::EVENT_STATUS, $from, $to, $user_id, $note );
		$this->plugin->logger->info(
			'production',
			'Production status changed',
			array( 'job_id' => $job_id, 'from' => $from, 'to' => $to, 'user' => $user_id )
		);

		do_action( 'td_production_status_changed', $job_id, $from, $to );
		if ( Production_Status::COMPLETED === $to ) {
			do_action( 'td_production_completed', $job_id );
		}

		return array( 'ok' => true, 'job' => $this->get( $job_id ) );
	}

	/**
	 * Record a quality-check outcome (§21).
	 *
	 * @return array{ok:bool, error?:string, job?:array<string,mixed>}
	 */
	public function quality_check( int $job_id, bool $passed, int $user_id = 0, string $note = '' ): array {
		$job = $this->get( $job_id );
		if ( null === $job ) {
			return array( 'ok' => false, 'error' => __( 'Production job not found.', 'tshirt-designer' ) );
		}
		if ( Production_Status::QC !== (string) $job['status'] ) {
			return array( 'ok' => false, 'error' => __( 'This job is not awaiting a quality check.', 'tshirt-designer' ) );
		}
		if ( ! $passed && '' === trim( $note ) ) {
			return array( 'ok' => false, 'error' => __( 'A note is required when a quality check fails.', 'tshirt-designer' ) );
		}

		$this->record_event(
			$job_id,
			self::EVENT_QC,
			Production_Status::QC,
			$passed ? Production_Status::PACKED : Production_Status::IN_PROD,
			$user_id,
			( $passed ? __( 'Quality check passed.', 'tshirt-designer' ) : __( 'Quality check failed.', 'tshirt-designer' ) )
				. ( '' !== trim( $note ) ? ' ' . $note : '' )
		);

		return $this->transition(
			$job_id,
			$passed ? Production_Status::PACKED : Production_Status::IN_PROD,
			$user_id,
			$note
		);
	}

	/**
	 * Flag a job as failed and store an admin-safe message (§22).
	 */
	public function mark_failed( int $job_id, string $message, int $user_id = 0 ): bool {
		global $wpdb;
		$job = $this->get( $job_id );
		if ( null === $job ) {
			return false;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update(
			$this->jobs_table(),
			array(
				'status'        => Production_Status::FAILED,
				'error_message' => $message,
				'updated_at'    => current_time( 'mysql' ),
			),
			array( 'id' => $job_id )
		);

		$this->record_event( $job_id, self::EVENT_FAILED, (string) $job['status'], Production_Status::FAILED, $user_id, $message );
		$this->plugin->logger->error( 'production', 'Production failed', array( 'job_id' => $job_id, 'message' => $message ) );
		do_action( 'td_production_failed', $job_id, $message );
		return true;
	}

	/**
	 * Set priority (§25).
	 */
	public function set_priority( int $job_id, string $priority, int $user_id = 0 ): bool {
		global $wpdb;
		if ( ! Production_Status::is_priority( $priority ) ) {
			return false;
		}
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update(
			$this->jobs_table(),
			array( 'priority' => $priority, 'updated_at' => current_time( 'mysql' ) ),
			array( 'id' => $job_id )
		);
		$this->record_event(
			$job_id,
			self::EVENT_NOTE,
			'',
			'',
			$user_id,
			/* translators: %s: priority label. */
			sprintf( __( 'Priority set to %s.', 'tshirt-designer' ), Production_Status::priorities()[ $priority ] )
		);
		return true;
	}

	// -------------------------------------------------------- events / notes

	/**
	 * Append an event to a job's history.
	 *
	 * @param array<string, mixed> $context
	 */
	public function record_event(
		int $job_id,
		string $type,
		string $from = '',
		string $to = '',
		int $user_id = 0,
		string $note = '',
		array $context = array()
	): int {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$this->events_table(),
			array(
				'job_id'      => $job_id,
				'event_type'  => $type,
				'from_status' => $from,
				'to_status'   => $to,
				'user_id'     => $user_id,
				'note'        => $note,
				'context'     => $context ? (string) wp_json_encode( Logger::redact( $context ) ) : null,
				'created_at'  => current_time( 'mysql' ),
			)
		);
		return (int) $wpdb->insert_id;
	}

	/**
	 * Add an admin note (§19).
	 */
	public function add_note( int $job_id, string $note, int $user_id = 0 ): bool {
		$note = trim( $note );
		if ( '' === $note ) {
			return false;
		}
		if ( null === $this->get( $job_id ) ) {
			return false;
		}
		$this->record_event( $job_id, self::EVENT_NOTE, '', '', $user_id, $note );
		return true;
	}

	/**
	 * Full activity history, oldest first (§20).
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function history( int $job_id, int $limit = 200 ): array {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				'SELECT * FROM ' . $this->events_table() . ' WHERE job_id = %d ORDER BY created_at ASC, id ASC LIMIT %d',
				$job_id,
				max( 1, min( 500, $limit ) )
			),
			ARRAY_A
		);

		$out = array();
		foreach ( (array) $rows as $r ) {
			$user       = (int) $r['user_id'];
			$user_name  = '';
			if ( $user > 0 ) {
				$u         = get_userdata( $user );
				$user_name = $u ? $u->display_name : '';
			}
			$out[] = array(
				'id'          => (int) $r['id'],
				'job_id'      => (int) $r['job_id'],
				'event_type'  => (string) $r['event_type'],
				'from_status' => (string) $r['from_status'],
				'to_status'   => (string) $r['to_status'],
				'user_id'     => $user,
				'user_name'   => $user_name,
				'note'        => (string) ( $r['note'] ?? '' ),
				'created_at'  => (string) $r['created_at'],
			);
		}
		return $out;
	}

	/**
	 * Only the notes, newest first.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function notes( int $job_id ): array {
		return array_values(
			array_filter(
				array_reverse( $this->history( $job_id ) ),
				static fn( $e ) => self::EVENT_NOTE === $e['event_type'] && '' !== $e['note']
			)
		);
	}

	// ------------------------------------------------------------- snapshots

	/**
	 * The immutable snapshot behind a job. Always read from the order item —
	 * never from the live catalogue (§17).
	 *
	 * @return array<string, mixed>|null
	 */
	public function snapshot( int $job_id ): ?array {
		$job = $this->get( $job_id );
		if ( null === $job ) {
			return null;
		}
		$order = function_exists( 'wc_get_order' ) ? wc_get_order( (int) $job['order_id'] ) : null;
		if ( ! $order instanceof \WC_Order ) {
			return null;
		}
		$item = $order->get_item( (int) $job['order_item_id'] );
		if ( ! $item ) {
			return null;
		}
		return Order_Manager::snapshot_from_item( $item );
	}

	// ----------------------------------------------------------------- utils

	/**
	 * @param array<string, mixed> $row
	 * @return array<string, mixed>
	 */
	public function cast( array $row ): array {
		return array(
			'id'             => (int) $row['id'],
			'order_id'       => (int) $row['order_id'],
			'order_item_id'  => (int) $row['order_item_id'],
			'design_id'      => (int) $row['design_id'],
			'design_version' => (int) $row['design_version'],
			'product_type'   => (string) $row['product_type'],
			'model_id'       => (int) $row['model_id'],
			'color_id'       => (int) $row['color_id'],
			'size_id'        => (int) $row['size_id'],
			'status'         => (string) $row['status'],
			'status_label'   => Production_Status::label( (string) $row['status'] ),
			'badge'          => Production_Status::badge( (string) $row['status'] ),
			'priority'       => (string) $row['priority'],
			'assigned_to'    => (int) $row['assigned_to'],
			'error_message'  => (string) ( $row['error_message'] ?? '' ),
			'customer_name'  => (string) $row['customer_name'],
			'customer_email' => (string) $row['customer_email'],
			'created_at'     => (string) $row['created_at'],
			'updated_at'     => (string) $row['updated_at'],
			'started_at'     => $row['started_at'] ? (string) $row['started_at'] : '',
			'completed_at'   => $row['completed_at'] ? (string) $row['completed_at'] : '',
		);
	}
}
