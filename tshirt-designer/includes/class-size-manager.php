<?php
/**
 * Per-model size CRUD.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Size_Manager {

	public function __construct( private Database $db ) {}

	/**
	 * @return array<int, array<string, mixed>>
	 */
	public function for_model( int $model_id, bool $active_only = true ): array {
		global $wpdb;
		$table = $this->db->table( 'model_sizes' );
		$where = $active_only ? 'AND is_active = 1' : '';
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT * FROM {$table} WHERE model_id = %d {$where} ORDER BY sort_order ASC, id ASC",
				$model_id
			),
			ARRAY_A
		);
		return array_map( array( $this, 'cast' ), is_array( $rows ) ? $rows : array() );
	}

	/**
	 * @return array<string, mixed>|null
	 */
	public function get( int $id ): ?array {
		global $wpdb;
		$table = $this->db->table( 'model_sizes' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $id ),
			ARRAY_A
		);
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	public function insert( array $data ): int {
		global $wpdb;
		$now = current_time( 'mysql' );
		$row = $this->prepare_row( $data );
		$row['created_at'] = $now;
		$row['updated_at'] = $now;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert( $this->db->table( 'model_sizes' ), $row );
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
		return false !== $wpdb->update( $this->db->table( 'model_sizes' ), $row, array( 'id' => $id ) );
	}

	public function delete( int $id ): void {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'model_sizes' ), array( 'id' => $id ), array( '%d' ) );
	}

	/**
	 * @param array<string, mixed> $size Size row.
	 * @return array<string, mixed>
	 */
	public function public_shape( array $size ): array {
		return array(
			'id'             => (int) $size['id'],
			'name'           => (string) $size['name'],
			'price_modifier' => (float) $size['price_modifier'],
		);
	}

	/**
	 * @param array<string, mixed> $data Input.
	 * @return array<string, mixed>
	 */
	private function prepare_row( array $data ): array {
		$row = array();
		if ( array_key_exists( 'model_id', $data ) ) {
			$row['model_id'] = max( 0, (int) $data['model_id'] );
		}
		if ( array_key_exists( 'name', $data ) ) {
			$row['name'] = sanitize_text_field( (string) $data['name'] );
		}
		if ( array_key_exists( 'price_modifier', $data ) ) {
			$row['price_modifier'] = round( (float) $data['price_modifier'], 2 );
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
			'id'             => (int) $row['id'],
			'model_id'       => (int) $row['model_id'],
			'name'           => (string) $row['name'],
			'price_modifier' => (float) $row['price_modifier'],
			'is_active'      => (int) $row['is_active'],
			'sort_order'     => (int) $row['sort_order'],
			'created_at'     => (string) $row['created_at'],
			'updated_at'     => (string) $row['updated_at'],
		);
	}
}
