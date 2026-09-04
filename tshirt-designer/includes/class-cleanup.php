<?php
/**
 * Scheduled cleanup of abandoned drafts and expired guest data.
 *
 * Safety rules (never negotiable):
 *  - designs with an ordered/paid/production status are never touched;
 *  - designs referenced by any production file row are never touched;
 *  - production files themselves are never deleted automatically.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Cleanup {

	public function __construct( private Plugin $plugin ) {
		add_action( 'td_cleanup_designs', array( $this, 'run' ) );
	}

	/**
	 * Delete stale guest designs and their orphan uploads.
	 *
	 * @return array{designs:int, uploads:int}
	 */
	public function run(): array {
		$days = (int) $this->plugin->settings->get( 'guest_retention_days', 30 );
		$days = max( 1, min( 3650, $days ) );

		if ( ! (int) $this->plugin->settings->get( 'cleanup_enabled', 1 ) ) {
			return array( 'designs' => 0, 'uploads' => 0 );
		}

		$designs = $this->purge_designs( $days );
		$uploads = $this->purge_uploads( $days );

		if ( $designs > 0 || $uploads > 0 ) {
			$this->plugin->logger->info(
				Logger::CHANNEL_DESIGN,
				'Cleanup removed stale guest data',
				array( 'designs' => $designs, 'uploads' => $uploads, 'older_than_days' => $days )
			);
		}

		return array( 'designs' => $designs, 'uploads' => $uploads );
	}

	/**
	 * Remove guest designs older than N days that are not part of an order.
	 */
	private function purge_designs( int $days ): int {
		global $wpdb;

		$designs    = $this->plugin->db->table( 'designs' );
		$versions   = $this->plugin->db->table( 'design_versions' );
		$production = $this->plugin->db->table( 'production_files' );

		$protected = Design_Manager::PROTECTED_STATUSES;
		$holders   = implode( ',', array_fill( 0, count( $protected ), '%s' ) );

		$sql = "SELECT d.id FROM {$designs} d
			WHERE d.user_id = 0
			AND d.guest_token != ''
			AND d.status NOT IN ({$holders})
			AND d.updated_at < %s
			AND NOT EXISTS (SELECT 1 FROM {$production} p WHERE p.design_id = d.id)
			LIMIT 200";

		$cutoff = gmdate( 'Y-m-d H:i:s', time() - $days * DAY_IN_SECONDS );
		$params = array_merge( $protected, array( $cutoff ) );

		// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared, WordPress.DB.DirectDatabaseQuery
		$ids = $wpdb->get_col( $wpdb->prepare( $sql, ...$params ) );
		$ids = array_map( 'intval', is_array( $ids ) ? $ids : array() );
		if ( array() === $ids ) {
			return 0;
		}

		$in = implode( ',', array_fill( 0, count( $ids ), '%d' ) );
		// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared, WordPress.DB.DirectDatabaseQuery
		$wpdb->query( $wpdb->prepare( "DELETE FROM {$designs} WHERE id IN ({$in})", ...$ids ) );
		// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared, WordPress.DB.DirectDatabaseQuery
		$wpdb->query( $wpdb->prepare( "DELETE FROM {$versions} WHERE design_id IN ({$in})", ...$ids ) );

		return count( $ids );
	}

	/**
	 * Remove guest uploads older than N days that no surviving design uses.
	 */
	private function purge_uploads( int $days ): int {
		global $wpdb;

		$uploads = $this->plugin->db->table( 'uploads' );
		$designs = $this->plugin->db->table( 'designs' );

		$cutoff = gmdate( 'Y-m-d H:i:s', time() - $days * DAY_IN_SECONDS );

		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT id, attachment_id FROM {$uploads}
				 WHERE user_id = 0 AND guest_token != '' AND created_at < %s
				 LIMIT 200",
				$cutoff
			),
			ARRAY_A
		);
		if ( ! is_array( $rows ) || array() === $rows ) {
			return 0;
		}

		$removed = 0;
		foreach ( $rows as $row ) {
			$upload_id = (int) $row['id'];

			// Still referenced by a design document? Keep it.
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$used = (int) $wpdb->get_var(
				$wpdb->prepare(
					"SELECT COUNT(*) FROM {$designs} WHERE design_data LIKE %s",
					'%' . $wpdb->esc_like( '"ref_id":' . $upload_id ) . '%'
				)
			);
			if ( $used > 0 ) {
				continue;
			}

			$attachment_id = (int) $row['attachment_id'];
			if ( $attachment_id > 0 ) {
				wp_delete_attachment( $attachment_id, true );
			}
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->delete( $uploads, array( 'id' => $upload_id ), array( '%d' ) );
			++$removed;
		}

		return $removed;
	}
}
