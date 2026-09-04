<?php
/**
 * Print area CRUD + UV position handling.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Print_Area_Manager {

	/**
	 * Legacy list, kept for backward compatibility with phase-1 integrations.
	 * Validation now goes through Product_Type_Registry so each product type
	 * declares its own areas.
	 *
	 * @deprecated 1.1.0 Use Product_Type_Registry::area_types().
	 */
	public const AREA_TYPES = array( 'front', 'back', 'left_sleeve', 'right_sleeve', 'other' );

	public function __construct( private Database $db ) {}

	/**
	 * @return array<int, array<string, mixed>>
	 */
	public function for_model( int $model_id, bool $active_only = true ): array {
		global $wpdb;
		$table = $this->db->table( 'print_areas' );
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
		$table = $this->db->table( 'print_areas' );
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
		$wpdb->insert( $this->db->table( 'print_areas' ), $row );
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
		return false !== $wpdb->update( $this->db->table( 'print_areas' ), $row, array( 'id' => $id ) );
	}

	public function delete( int $id ): void {
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'print_areas' ), array( 'id' => $id ), array( '%d' ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'pricing_rules' ), array( 'print_area_id' => $id, 'scope' => 'area' ), array( '%d', '%s' ) );
	}

	/**
	 * Product type of the model owning an area (defaults to the legacy type).
	 */
	public function product_type_for_model( int $model_id ): string {
		if ( $model_id <= 0 ) {
			return Product_Type_Registry::LEGACY_TYPE;
		}
		global $wpdb;
		$table = $this->db->table( 'models' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$type = $wpdb->get_var( $wpdb->prepare( "SELECT product_type FROM {$table} WHERE id = %d", $model_id ) );
		return Product_Type_Registry::sanitize( is_string( $type ) ? $type : '' );
	}

	/**
	 * Sanitize the position JSON (uv_rect + camera preset).
	 *
	 * @param mixed $value Raw value.
	 * @return string JSON string ('' when invalid).
	 */
	public function sanitize_position( mixed $value ): string {
		if ( is_string( $value ) ) {
			$decoded = json_decode( $value, true );
		} elseif ( is_array( $value ) ) {
			$decoded = $value;
		} else {
			return '';
		}
		if ( ! is_array( $decoded ) ) {
			return '';
		}

		$clean = array();

		if ( isset( $decoded['uv_rect'] ) && is_array( $decoded['uv_rect'] ) ) {
			$rect = array_map( 'floatval', array_slice( array_values( $decoded['uv_rect'] ), 0, 4 ) );
			if ( 4 === count( $rect ) ) {
				// Normalize and order the rectangle inside [0,1].
				$u0 = min( max( $rect[0], 0.0 ), 1.0 );
				$v0 = min( max( $rect[1], 0.0 ), 1.0 );
				$u1 = min( max( $rect[2], 0.0 ), 1.0 );
				$v1 = min( max( $rect[3], 0.0 ), 1.0 );
				$clean['uv_rect'] = array(
					round( min( $u0, $u1 ), 5 ),
					round( min( $v0, $v1 ), 5 ),
					round( max( $u0, $u1 ), 5 ),
					round( max( $v0, $v1 ), 5 ),
				);
				if ( $clean['uv_rect'][2] - $clean['uv_rect'][0] < 1e-4 ||
					$clean['uv_rect'][3] - $clean['uv_rect'][1] < 1e-4 ) {
					unset( $clean['uv_rect'] );
				}
			}
		}

		if ( isset( $decoded['camera'] ) && is_array( $decoded['camera'] ) ) {
			$cam = array();
			foreach ( array( 'azimuth' => 0.0, 'polar' => 75.0, 'distance' => 1.6 ) as $key => $default ) {
				$cam[ $key ] = isset( $decoded['camera'][ $key ] ) && is_numeric( $decoded['camera'][ $key ] )
					? round( (float) $decoded['camera'][ $key ], 3 )
					: $default;
			}
			$cam['distance']    = min( 6.0, max( 0.4, $cam['distance'] ) );
			$cam['polar']       = min( 89.0, max( 5.0, $cam['polar'] ) );
			$clean['camera'] = $cam;
		}

		return array() === $clean ? '' : (string) wp_json_encode( $clean );
	}

	/**
	 * Decoded position for a row (with sensible defaults).
	 *
	 * @param array<string, mixed> $area Print area row.
	 * @return array<string, mixed>
	 */
	public function position( array $area ): array {
		$decoded = json_decode( (string) $area['position'], true );
		$decoded = is_array( $decoded ) ? $decoded : array();

		$defaults = array(
			'uv_rect' => null,
			'camera'  => array( 'azimuth' => 0.0, 'polar' => 75.0, 'distance' => 1.6 ),
		);
		$decoded  = array_merge( $defaults, $decoded );
		if ( ! is_array( $decoded['camera'] ) ) {
			$decoded['camera'] = $defaults['camera'];
		}
		return $decoded;
	}

	/**
	 * Public shape for the designer.
	 *
	 * @param array<string, mixed> $area Print area row.
	 * @return array<string, mixed>
	 */
	public function public_shape( array $area ): array {
		$position = $this->position( $area );
		return array(
			'id'            => (int) $area['id'],
			'name'          => (string) $area['name'],
			'type'          => (string) $area['area_type'],
			'max_width_cm'  => (float) $area['max_width_cm'],
			'max_height_cm' => (float) $area['max_height_cm'],
			'uv_rect'       => $position['uv_rect'],
			'camera'        => $position['camera'],
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
		if ( array_key_exists( 'area_type', $data ) ) {
			$type         = sanitize_key( (string) $data['area_type'] );
			$product_type = isset( $data['product_type'] )
				? Product_Type_Registry::sanitize( (string) $data['product_type'] )
				: $this->product_type_for_model( (int) ( $data['model_id'] ?? 0 ) );
			$row['area_type'] = Product_Type_Registry::area_type_allowed( $product_type, $type ) ? $type : 'other';
		}
		foreach ( array( 'max_width_cm', 'max_height_cm' ) as $key ) {
			if ( array_key_exists( $key, $data ) ) {
				$row[ $key ] = round( min( 200.0, max( 0.5, (float) $data[ $key ] ) ), 2 );
			}
		}
		if ( array_key_exists( 'position', $data ) ) {
			$row['position'] = $this->sanitize_position( $data['position'] );
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
			'id'            => (int) $row['id'],
			'model_id'      => (int) $row['model_id'],
			'name'          => (string) $row['name'],
			'area_type'     => (string) $row['area_type'],
			'max_width_cm'  => (float) $row['max_width_cm'],
			'max_height_cm' => (float) $row['max_height_cm'],
			'position'      => (string) ( $row['position'] ?? '' ),
			'is_active'     => (int) $row['is_active'],
			'sort_order'    => (int) $row['sort_order'],
			'created_at'    => (string) $row['created_at'],
			'updated_at'    => (string) $row['updated_at'],
		);
	}
}
