<?php
/**
 * Design asset (ready-made artwork) CRUD.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Asset_Manager {

	public const CATEGORIES = array(
		'logo'    => 'Logo',
		'text'    => 'Text',
		'sport'   => 'Sport',
		'animal'  => 'Animal',
		'nature'  => 'Nature',
		'kids'    => 'Kids',
		'fantasy' => 'Fantasy',
		'other'   => 'Other',
	);

	public function __construct( private Database $db ) {}

	/**
	 * List assets, optionally filtered by category.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function all( bool $active_only = true, string $category = '' ): array {
		global $wpdb;
		$table = $this->db->table( 'design_assets' );
		$where = array();
		if ( $active_only ) {
			$where[] = 'is_active = 1';
		}
		if ( '' !== $category && array_key_exists( $category, self::CATEGORIES ) ) {
			$where[] = $wpdb->prepare( 'category = %s', $category );
		}
		$where_sql = $where ? 'WHERE ' . implode( ' AND ', $where ) : '';
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results(
			"SELECT * FROM {$table} {$where_sql} ORDER BY category ASC, sort_order ASC, id ASC",
			ARRAY_A
		);
		return array_map( array( $this, 'cast' ), is_array( $rows ) ? $rows : array() );
	}

	/**
	 * @return array<string, mixed>|null
	 */
	public function get( int $id ): ?array {
		global $wpdb;
		$table = $this->db->table( 'design_assets' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $id ),
			ARRAY_A
		);
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	/**
	 * Assets by ids (for design validation).
	 *
	 * @param int[] $ids Asset ids.
	 * @return array<int, array<string, mixed>> Indexed by id.
	 */
	public function get_many( array $ids ): array {
		$ids   = array_values( array_unique( array_map( 'intval', $ids ) ) );
		$found = array();
		foreach ( $ids as $id ) {
			if ( $id <= 0 ) {
				continue;
			}
			$asset = $this->get( $id );
			if ( null !== $asset && $asset['is_active'] ) {
				$found[ $id ] = $asset;
			}
		}
		return $found;
	}

	public function insert( array $data ): int {
		global $wpdb;
		$now = current_time( 'mysql' );
		$row = $this->prepare_row( $data );
		$row['created_at'] = $now;
		$row['updated_at'] = $now;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert( $this->db->table( 'design_assets' ), $row );
		return (int) $wpdb->insert_id;
	}

	public function update( int $id, array $data ): bool {
		global $wpdb;
		$row = $this->prepare_row( $data );
		if ( array() === $row ) {
			return false;
		}
		$row['updated_at'] = current_time( 'mysql' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		return false !== $wpdb->update( $this->db->table( 'design_assets' ), $row, array( 'id' => $id ) );
	}

	public function delete( int $id ): void {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'design_assets' ), array( 'id' => $id ), array( '%d' ) );
	}

	/**
	 * File URL for an asset (attachment wins over bundled path).
	 */
	public function file_url( array $asset ): string {
		if ( (int) $asset['file_id'] > 0 ) {
			$url = wp_get_attachment_url( (int) $asset['file_id'] );
			if ( is_string( $url ) && '' !== $url ) {
				return $url;
			}
		}
		if ( '' !== (string) $asset['file_path'] ) {
			return Plugin::url( (string) $asset['file_path'] );
		}
		return '';
	}

	/**
	 * Public shape for the designer.
	 *
	 * @param array<string, mixed> $asset Asset row.
	 * @return array<string, mixed>
	 */
	public function public_shape( array $asset ): array {
		return array(
			'id'        => (int) $asset['id'],
			'name'      => (string) $asset['name'],
			'category'  => (string) $asset['category'],
			'url'       => $this->file_url( $asset ),
			'thumb_url' => $this->file_url( $asset ),
		);
	}

	/**
	 * @param array<string, mixed> $data Input.
	 * @return array<string, mixed>
	 */
	private function prepare_row( array $data ): array {
		$row = array();
		if ( array_key_exists( 'name', $data ) ) {
			$row['name'] = sanitize_text_field( (string) $data['name'] );
		}
		if ( array_key_exists( 'category', $data ) ) {
			$cat = sanitize_key( (string) $data['category'] );
			$row['category'] = array_key_exists( $cat, self::CATEGORIES ) ? $cat : 'other';
		}
		if ( array_key_exists( 'file_id', $data ) ) {
			$row['file_id'] = max( 0, (int) $data['file_id'] );
		}
		if ( array_key_exists( 'file_path', $data ) ) {
			$row['file_path'] = preg_replace( '#^[./\\\\]+#', '', (string) $data['file_path'] );
		}
		if ( array_key_exists( 'is_active', $data ) ) {
			$row['is_active'] = empty( $data['is_active'] ) ? 0 : 1;
		}
		if ( array_key_exists( 'sort_order', $data ) ) {
			$row['sort_order'] = (int) $data['sort_order'];
		}
		return $row;
	}

	/**
	 * @param array<string, mixed> $row Raw row.
	 * @return array<string, mixed>
	 */
	public function cast( array $row ): array {
		return array(
			'id'         => (int) $row['id'],
			'name'       => (string) $row['name'],
			'category'   => (string) $row['category'],
			'file_id'    => (int) $row['file_id'],
			'file_path'  => (string) $row['file_path'],
			'is_active'  => (int) $row['is_active'],
			'sort_order' => (int) $row['sort_order'],
			'created_at' => (string) $row['created_at'],
			'updated_at' => (string) $row['updated_at'],
		);
	}
}
