<?php
/**
 * Structured logging for the critical paths (design, pricing, cart, order,
 * production).
 *
 * Rows land in `{$prefix}td_logs`; sensitive values are stripped before the
 * context is stored. Logging never throws — a failing logger must not break
 * a checkout.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Logger {

	public const LEVEL_ERROR   = 'error';
	public const LEVEL_WARNING = 'warning';
	public const LEVEL_INFO    = 'info';

	public const CHANNEL_DESIGN     = 'design';
	public const CHANNEL_PRICING    = 'pricing';
	public const CHANNEL_CART       = 'cart';
	public const CHANNEL_ORDER      = 'order';
	public const CHANNEL_PRODUCTION = 'production';
	public const CHANNEL_SECURITY   = 'security';

	/** Context keys that must never be persisted. */
	private const REDACT = array(
		'guest_token',
		'token',
		'nonce',
		'password',
		'pass',
		'cookie',
		'authorization',
		'email',
		'ip',
		'user_email',
		'billing_email',
		'phone',
		'address',
	);

	/** Keep the table bounded. */
	private const MAX_ROWS = 5000;

	public function __construct( private Database $db ) {}

	/**
	 * @param array<string, mixed> $context Extra data (redacted before storage).
	 */
	public function error( string $channel, string $message, array $context = array() ): void {
		$this->log( self::LEVEL_ERROR, $channel, $message, $context );
	}

	/**
	 * @param array<string, mixed> $context Extra data.
	 */
	public function warning( string $channel, string $message, array $context = array() ): void {
		$this->log( self::LEVEL_WARNING, $channel, $message, $context );
	}

	/**
	 * @param array<string, mixed> $context Extra data.
	 */
	public function info( string $channel, string $message, array $context = array() ): void {
		$this->log( self::LEVEL_INFO, $channel, $message, $context );
	}

	/**
	 * Write a log row.
	 *
	 * @param array<string, mixed> $context Extra data.
	 */
	public function log( string $level, string $channel, string $message, array $context = array() ): void {
		global $wpdb;

		if ( ! isset( $wpdb ) ) {
			return;
		}

		$level   = in_array( $level, array( self::LEVEL_ERROR, self::LEVEL_WARNING, self::LEVEL_INFO ), true )
			? $level
			: self::LEVEL_INFO;
		$channel = sanitize_key( $channel ) ?: 'general';

		$row = array(
			'level'      => $level,
			'channel'    => $channel,
			'message'    => mb_substr( sanitize_text_field( $message ), 0, 500 ),
			'context'    => (string) wp_json_encode( self::redact( $context ) ),
			'user_id'    => function_exists( 'get_current_user_id' ) ? (int) get_current_user_id() : 0,
			'created_at' => current_time( 'mysql' ),
		);

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert( $this->db->table( 'logs' ), $row );

		// Opportunistic trim (cheap: only when the insert id is a round number).
		if ( 0 === (int) $wpdb->insert_id % 200 ) {
			$this->trim();
		}
	}

	/**
	 * Remove keys that could carry personal or secret data, recursively.
	 *
	 * @param array<string, mixed> $context Raw context.
	 * @return array<string, mixed>
	 */
	public static function redact( array $context ): array {
		$clean = array();
		foreach ( $context as $key => $value ) {
			$lower = strtolower( (string) $key );
			$hit   = false;
			foreach ( self::REDACT as $needle ) {
				if ( str_contains( $lower, $needle ) ) {
					$hit = true;
					break;
				}
			}
			if ( $hit ) {
				$clean[ $key ] = '[redacted]';
				continue;
			}
			if ( is_array( $value ) ) {
				$clean[ $key ] = self::redact( $value );
			} elseif ( is_scalar( $value ) || null === $value ) {
				$clean[ $key ] = is_string( $value ) ? mb_substr( $value, 0, 300 ) : $value;
			} else {
				$clean[ $key ] = '[object]';
			}
		}
		return $clean;
	}

	/**
	 * Recent log rows.
	 *
	 * @return list<array<string, mixed>>
	 */
	public function recent( int $limit = 100, string $channel = '', string $level = '' ): array {
		global $wpdb;
		$table = $this->db->table( 'logs' );
		$limit = max( 1, min( 500, $limit ) );

		$where  = array( '1=1' );
		$params = array();
		if ( '' !== $channel ) {
			$where[]  = 'channel = %s';
			$params[] = sanitize_key( $channel );
		}
		if ( '' !== $level ) {
			$where[]  = 'level = %s';
			$params[] = sanitize_key( $level );
		}
		$params[] = $limit;

		$sql = 'SELECT * FROM ' . $table . ' WHERE ' . implode( ' AND ', $where ) . ' ORDER BY id DESC LIMIT %d';
		// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results( $wpdb->prepare( $sql, ...$params ), ARRAY_A );

		return array_map(
			static function ( array $row ): array {
				$row['context'] = json_decode( (string) $row['context'], true );
				return $row;
			},
			is_array( $rows ) ? $rows : array()
		);
	}

	/**
	 * Delete every log row.
	 */
	public function clear(): void {
		global $wpdb;
		$table = $this->db->table( 'logs' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$wpdb->query( "DELETE FROM {$table}" );
	}

	/**
	 * Keep only the newest MAX_ROWS entries.
	 */
	public function trim(): void {
		global $wpdb;
		$table = $this->db->table( 'logs' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$cutoff = $wpdb->get_var(
			$wpdb->prepare( "SELECT id FROM {$table} ORDER BY id DESC LIMIT 1 OFFSET %d", self::MAX_ROWS )
		);
		if ( null === $cutoff ) {
			return;
		}
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$wpdb->query( $wpdb->prepare( "DELETE FROM {$table} WHERE id <= %d", (int) $cutoff ) );
	}
}
