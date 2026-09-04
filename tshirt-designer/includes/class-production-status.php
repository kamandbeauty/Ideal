<?php
/**
 * Production status vocabulary and transition rules.
 *
 * Phase 3. This is the single source of truth for "which status may become
 * which"; both the admin UI and the REST layer consult it, and the backend is
 * authoritative — the UI only ever *hides* buttons, it never grants a move.
 *
 * The vocabulary intentionally reuses the status slugs Phase 2 already stored
 * in `Order_Manager::META_PRODUCTION_STATUS` so existing orders keep meaning.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Production_Status {

	public const NEW_JOB    = 'new';
	public const PAID       = 'paid';
	public const READY      = 'ready_for_production';
	public const IN_PROD    = 'in_production';
	public const PRINTED    = 'printed';
	public const QC         = 'quality_check';
	public const PACKED     = 'packed';
	public const SHIPPED    = 'shipped';
	public const COMPLETED  = 'completed';
	public const CANCELLED  = 'cancelled';
	public const FAILED     = 'production_error';

	public const PRIORITY_NORMAL = 'normal';
	public const PRIORITY_HIGH   = 'high';
	public const PRIORITY_URGENT = 'urgent';

	/**
	 * Terminal states: nothing may leave them.
	 *
	 * @return string[]
	 */
	public static function terminal(): array {
		return array( self::COMPLETED, self::CANCELLED );
	}

	/**
	 * The forward pipeline, in order. Used for display and for the dashboard
	 * tabs; transition legality still comes from transitions().
	 *
	 * @return string[]
	 */
	public static function pipeline(): array {
		return array(
			self::NEW_JOB,
			self::PAID,
			self::READY,
			self::IN_PROD,
			self::PRINTED,
			self::QC,
			self::PACKED,
			self::SHIPPED,
			self::COMPLETED,
		);
	}

	/**
	 * Human labels.
	 *
	 * @return array<string, string>
	 */
	public static function labels(): array {
		return array(
			self::NEW_JOB   => __( 'New', 'tshirt-designer' ),
			self::PAID      => __( 'Paid', 'tshirt-designer' ),
			self::READY     => __( 'Ready for production', 'tshirt-designer' ),
			self::IN_PROD   => __( 'In production', 'tshirt-designer' ),
			self::PRINTED   => __( 'Printed', 'tshirt-designer' ),
			self::QC        => __( 'Quality check', 'tshirt-designer' ),
			self::PACKED    => __( 'Packed', 'tshirt-designer' ),
			self::SHIPPED   => __( 'Shipped', 'tshirt-designer' ),
			self::COMPLETED => __( 'Completed', 'tshirt-designer' ),
			self::CANCELLED => __( 'Cancelled', 'tshirt-designer' ),
			self::FAILED    => __( 'Production error', 'tshirt-designer' ),
		);
	}

	/**
	 * A CSS modifier per status so the admin can render a coloured badge.
	 *
	 * @return array<string, string>
	 */
	public static function badges(): array {
		return array(
			self::NEW_JOB   => 'muted',
			self::PAID      => 'info',
			self::READY     => 'info',
			self::IN_PROD   => 'work',
			self::PRINTED   => 'work',
			self::QC        => 'warn',
			self::PACKED    => 'ok',
			self::SHIPPED   => 'ok',
			self::COMPLETED => 'done',
			self::CANCELLED => 'muted',
			self::FAILED    => 'error',
		);
	}

	public static function label( string $status ): string {
		$all = self::labels();
		return $all[ $status ] ?? $status;
	}

	public static function badge( string $status ): string {
		$all = self::badges();
		return $all[ $status ] ?? 'muted';
	}

	public static function is_status( string $status ): bool {
		return array_key_exists( $status, self::labels() );
	}

	/**
	 * Allowed priorities.
	 *
	 * @return array<string, string>
	 */
	public static function priorities(): array {
		return array(
			self::PRIORITY_NORMAL => __( 'Normal', 'tshirt-designer' ),
			self::PRIORITY_HIGH   => __( 'High', 'tshirt-designer' ),
			self::PRIORITY_URGENT => __( 'Urgent', 'tshirt-designer' ),
		);
	}

	public static function is_priority( string $priority ): bool {
		return array_key_exists( $priority, self::priorities() );
	}

	/**
	 * Priority sort weight (higher = more urgent) for ORDER BY.
	 */
	public static function priority_weight( string $priority ): int {
		return array(
			self::PRIORITY_NORMAL => 0,
			self::PRIORITY_HIGH   => 1,
			self::PRIORITY_URGENT => 2,
		)[ $priority ] ?? 0;
	}

	/**
	 * The transition table: status => statuses it may move to.
	 *
	 * Cancellation is allowed from any non-terminal state. QUALITY_CHECK may
	 * fall back to IN_PRODUCTION (a QC failure). PRODUCTION_ERROR may return to
	 * READY so a retry can re-enter the pipeline.
	 *
	 * @return array<string, string[]>
	 */
	public static function transitions(): array {
		return array(
			self::NEW_JOB   => array( self::PAID, self::CANCELLED ),
			self::PAID      => array( self::READY, self::CANCELLED ),
			self::READY     => array( self::IN_PROD, self::FAILED, self::CANCELLED ),
			self::IN_PROD   => array( self::PRINTED, self::FAILED, self::CANCELLED ),
			self::PRINTED   => array( self::QC, self::CANCELLED ),
			// A QC failure sends the job back to the press.
			self::QC        => array( self::PACKED, self::IN_PROD, self::CANCELLED ),
			self::PACKED    => array( self::SHIPPED, self::CANCELLED ),
			self::SHIPPED   => array( self::COMPLETED, self::CANCELLED ),
			self::COMPLETED => array(),
			self::CANCELLED => array(),
			self::FAILED    => array( self::READY, self::CANCELLED ),
		);
	}

	/**
	 * Statuses reachable from $from.
	 *
	 * @return string[]
	 */
	public static function next( string $from ): array {
		$map = self::transitions();
		return $map[ $from ] ?? array();
	}

	/**
	 * Is moving $from -> $to legal?
	 *
	 * A no-op move (same status) is explicitly NOT a valid transition: callers
	 * treat it as "nothing to do" rather than silently logging an event.
	 */
	public static function can( string $from, string $to ): bool {
		if ( ! self::is_status( $from ) || ! self::is_status( $to ) ) {
			return false;
		}
		return in_array( $to, self::next( $from ), true );
	}

	/**
	 * Explain why a transition is refused — surfaced to the admin, never raw.
	 */
	public static function reason( string $from, string $to ): string {
		if ( ! self::is_status( $to ) ) {
			return __( 'That production status does not exist.', 'tshirt-designer' );
		}
		if ( ! self::is_status( $from ) ) {
			return __( 'This job has an unrecognised status.', 'tshirt-designer' );
		}
		if ( $from === $to ) {
			return __( 'The job already has that status.', 'tshirt-designer' );
		}
		if ( in_array( $from, self::terminal(), true ) ) {
			/* translators: %s: status label. */
			return sprintf( __( 'This job is %s and can no longer change.', 'tshirt-designer' ), self::label( $from ) );
		}
		/* translators: 1: current status, 2: requested status. */
		return sprintf(
			__( 'A job cannot go from %1$s to %2$s.', 'tshirt-designer' ),
			self::label( $from ),
			self::label( $to )
		);
	}

	/**
	 * Statuses the production queue actively works on (§24).
	 *
	 * @return string[]
	 */
	public static function queue(): array {
		return array( self::READY, self::IN_PROD, self::QC, self::PACKED, self::SHIPPED );
	}
}
