<?php
/**
 * T-shirt model CRUD.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Model_Manager {

	public function __construct( private Database $db ) {}

	/**
	 * All models (active only by default).
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function all( bool $active_only = true ): array {
		global $wpdb;
		$table = $this->db->table( 'models' );
		$where = $active_only ? 'WHERE is_active = 1' : '';
		// phpcs:disable WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results(
			"SELECT * FROM {$table} {$where} ORDER BY sort_order ASC, id ASC",
			ARRAY_A
		);
		// phpcs:enable
		return array_map( array( $this, 'cast' ), is_array( $rows ) ? $rows : array() );
	}

	/**
	 * One model by id.
	 *
	 * @return array<string, mixed>|null
	 */
	public function get( int $id, bool $any_status = false ): ?array {
		global $wpdb;
		$table = $this->db->table( 'models' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $id ),
			ARRAY_A
		);
		if ( ! is_array( $row ) ) {
			return null;
		}
		$model = $this->cast( $row );
		if ( ! $any_status && ! $model['is_active'] ) {
			return null;
		}
		return $model;
	}

	/**
	 * Model by slug.
	 */
	public function get_by_slug( string $slug ): ?array {
		global $wpdb;
		$table = $this->db->table( 'models' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE slug = %s", $slug ),
			ARRAY_A
		);
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	/**
	 * Insert a model.
	 *
	 * @param array<string, mixed> $data Sanitized input.
	 */
	public function insert( array $data ): int {
		global $wpdb;
		$now  = current_time( 'mysql' );
		$row  = $this->prepare_row( $data );
		$row['created_at'] = $now;
		$row['updated_at'] = $now;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert( $this->db->table( 'models' ), $row );
		return (int) $wpdb->insert_id;
	}

	/**
	 * Update a model.
	 *
	 * @param array<string, mixed> $data Sanitized partial input.
	 */
	public function update( int $id, array $data ): bool {
		global $wpdb;
		$row = $this->prepare_row( $data );
		if ( array() === $row ) {
			return false;
		}
		$row['updated_at'] = current_time( 'mysql' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$result = $wpdb->update(
			$this->db->table( 'models' ),
			$row,
			array( 'id' => $id )
		);
		return false !== $result;
	}

	/**
	 * Delete a model and its child rows.
	 */
	public function delete( int $id ): void {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'models' ), array( 'id' => $id ), array( '%d' ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'model_colors' ), array( 'model_id' => $id ), array( '%d' ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'model_sizes' ), array( 'model_id' => $id ), array( '%d' ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'print_areas' ), array( 'model_id' => $id ), array( '%d' ) );
	}

	/**
	 * Public shape of a model for the designer / REST API.
	 *
	 * @param array<string, mixed> $model Model row.
	 * @return array<string, mixed>
	 */
	public function public_shape( array $model ): array {
		return array(
			'id'          => (int) $model['id'],
			'name'        => (string) $model['name'],
			'slug'        => (string) $model['slug'],
			'description' => (string) $model['description'],
			'model_url'   => $this->model_file_url( $model ),
			'preview_url' => $this->preview_url( $model ),
			'base_price'  => (float) $model['base_price'],
		);
	}

	/**
	 * GLB file URL (attachment wins over bundled path).
	 */
	public function model_file_url( array $model ): string {
		if ( (int) $model['model_file_id'] > 0 ) {
			$url = wp_get_attachment_url( (int) $model['model_file_id'] );
			if ( is_string( $url ) && '' !== $url ) {
				return $url;
			}
		}
		if ( '' !== (string) $model['model_file_path'] ) {
			return Plugin::url( (string) $model['model_file_path'] );
		}
		return '';
	}

	/**
	 * Preview image URL.
	 */
	public function preview_url( array $model ): string {
		if ( (int) $model['preview_image_id'] > 0 ) {
			$url = wp_get_attachment_url( (int) $model['preview_image_id'] );
			if ( is_string( $url ) && '' !== $url ) {
				return $url;
			}
		}
		if ( '' !== (string) $model['preview_image_path'] ) {
			return Plugin::url( (string) $model['preview_image_path'] );
		}
		return '';
	}

	/**
	 * Base price, preferring the linked WooCommerce product when set.
	 */
	public function base_price( array $model ): float {
		$product_id = (int) ( $model['wc_product_id'] ?? 0 );
		if ( $product_id > 0 && function_exists( 'wc_get_product' ) ) {
			$product = wc_get_product( $product_id );
			if ( $product instanceof \WC_Product ) {
				$price = $product->get_price( 'edit' );
				if ( is_numeric( $price ) && (float) $price > 0 ) {
					return (float) $price;
				}
			}
		}
		return (float) $model['base_price'];
	}

	/**
	 * Build a unique slug for a model name.
	 */
	public function unique_slug( string $name, int $ignore_id = 0 ): string {
		$slug = sanitize_title( $name );
		if ( '' === $slug ) {
			$slug = 'model';
		}
		$base = $slug;
		$i    = 2;
		while ( null !== $this->slug_taken( $slug, $ignore_id ) ) {
			$slug = $base . '-' . $i;
			++$i;
		}
		return $slug;
	}

	private function slug_taken( string $slug, int $ignore_id ): ?array {
		global $wpdb;
		$table = $this->db->table( 'models' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE slug = %s AND id != %d", $slug, $ignore_id ),
			ARRAY_A
		);
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	/**
	 * Whitelist + sanitize input into a DB row.
	 *
	 * @param array<string, mixed> $data Input.
	 * @return array<string, mixed>
	 */
	private function prepare_row( array $data ): array {
		$row = array();
		if ( array_key_exists( 'name', $data ) ) {
			$row['name'] = sanitize_text_field( (string) $data['name'] );
		}
		if ( array_key_exists( 'slug', $data ) ) {
			$row['slug'] = sanitize_title( (string) $data['slug'] );
		}
		if ( array_key_exists( 'description', $data ) ) {
			$row['description'] = sanitize_textarea_field( (string) $data['description'] );
		}
		foreach ( array( 'model_file_id', 'preview_image_id', 'wc_product_id' ) as $key ) {
			if ( array_key_exists( $key, $data ) ) {
				$row[ $key ] = max( 0, (int) $data[ $key ] );
			}
		}
		foreach ( array( 'model_file_path', 'preview_image_path' ) as $key ) {
			if ( array_key_exists( $key, $data ) ) {
				$row[ $key ] = preg_replace( '#^[./\\\\]+#', '', (string) $data[ $key ] );
			}
		}
		if ( array_key_exists( 'base_price', $data ) ) {
			$row['base_price'] = max( 0.0, round( (float) $data['base_price'], 2 ) );
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
	 * Cast a raw DB row.
	 *
	 * @param array<string, mixed> $row Raw row.
	 * @return array<string, mixed>
	 */
	public function cast( array $row ): array {
		return array(
			'id'                 => (int) $row['id'],
			'name'               => (string) $row['name'],
			'slug'               => (string) $row['slug'],
			'description'        => (string) ( $row['description'] ?? '' ),
			'model_file_id'      => (int) $row['model_file_id'],
			'model_file_path'    => (string) $row['model_file_path'],
			'preview_image_id'   => (int) $row['preview_image_id'],
			'preview_image_path' => (string) $row['preview_image_path'],
			'wc_product_id'      => (int) $row['wc_product_id'],
			'base_price'         => (float) $row['base_price'],
			'is_active'          => (int) $row['is_active'],
			'sort_order'         => (int) $row['sort_order'],
			'created_at'         => (string) $row['created_at'],
			'updated_at'         => (string) $row['updated_at'],
		);
	}
}
