<?php
/**
 * Design manager — validates user designs, computes authoritative prices,
 * persists designs and previews.
 *
 * Design document (JSON):
 * {
 *   "model_id": 1, "color_id": 2, "size_id": 3,
 *   "areas": {
 *     "<print_area_id>": [
 *       {"id":"x","type":"asset|upload","ref_id":7,
 *        "x":5.0,"y":3.0,"w":12.0,"h":8.0,"rotation":15}
 *     ]
 *   }
 * }
 *
 * x/y are the item CENTER in centimeters from the print area's top-left
 * corner; w/h are the unrotated size in cm; rotation is degrees clockwise.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Design_Manager {

	public const MIN_ITEM_CM = 1.0;
	public const MAX_ITEMS_PER_AREA = 20;

	public function __construct(
		private Database $db,
		private Model_Manager $models,
		private Print_Area_Manager $print_areas,
		private Pricing_Engine $pricing,
		private Media_Manager $media
	) {}

	/**
	 * Validate a design payload coming from the REST API.
	 *
	 * @param array<string, mixed> $input       Raw design payload.
	 * @param int                  $user_id     Current user id (0 = guest).
	 * @param string               $guest_token Guest token.
	 * @return array{ok:bool, errors:string[], design?:array<string,mixed>, items?:array<int,list<array<string,float>>>}
	 */
	public function validate_design( array $input, int $user_id, string $guest_token ): array {
		$errors = array();

		$model_id = (int) ( $input['model_id'] ?? 0 );
		$color_id = (int) ( $input['color_id'] ?? 0 );
		$size_id  = (int) ( $input['size_id'] ?? 0 );

		$model = $model_id > 0 ? $this->models->get( $model_id ) : null;
		if ( null === $model ) {
			$errors[] = __( 'The selected model is not available.', 'tshirt-designer' );
			return array( 'ok' => false, 'errors' => $errors );
		}

		$color_ok = false;
		foreach ( Plugin::instance()->colors->for_model( $model_id ) as $color ) {
			if ( (int) $color['id'] === $color_id ) {
				$color_ok = true;
				break;
			}
		}
		if ( ! $color_ok ) {
			$errors[] = __( 'Please choose a valid color.', 'tshirt-designer' );
		}

		$size_ok = false;
		foreach ( Plugin::instance()->sizes->for_model( $model_id ) as $size ) {
			if ( (int) $size['id'] === $size_id ) {
				$size_ok = true;
				break;
			}
		}
		if ( ! $size_ok ) {
			$errors[] = __( 'Please choose a valid size.', 'tshirt-designer' );
		}

		$areas_raw = isset( $input['areas'] ) && is_array( $input['areas'] )
			? $input['areas']
			: array();

		$print_areas = array();
		foreach ( $this->print_areas->for_model( $model_id ) as $area ) {
			$print_areas[ (int) $area['id'] ] = $area;
		}

		$design_areas = array();
		$items        = array();

		foreach ( $areas_raw as $area_key => $area_items ) {
			$area_id = (int) $area_key;
			if ( ! isset( $print_areas[ $area_id ] ) ) {
				$errors[] = __( 'Unknown print area in design.', 'tshirt-designer' );
				continue;
			}
			if ( ! is_array( $area_items ) ) {
				$errors[] = __( 'Invalid print area contents.', 'tshirt-designer' );
				continue;
			}
			if ( count( $area_items ) > self::MAX_ITEMS_PER_AREA ) {
				$errors[] = sprintf(
					/* translators: %d: maximum items. */
					__( 'A print area can hold at most %d items.', 'tshirt-designer' ),
					self::MAX_ITEMS_PER_AREA
				);
				continue;
			}

			$area = $print_areas[ $area_id ];
			$max_w = (float) $area['max_width_cm'];
			$max_h = (float) $area['max_height_cm'];

			$clean_items = array();
			foreach ( array_values( $area_items ) as $item ) {
				$clean = $this->validate_item( $item, $area, $user_id, $guest_token, $errors );
				if ( null === $clean ) {
					continue;
				}

				// Enforce print-area bounds with the rotated AABB.
				$clamped = Print_Area_Bounds::clamp_item( $clean, $max_w, $max_h );
				if ( $clamped['w'] !== $clean['w'] || $clamped['h'] !== $clean['h'] ) {
					$errors[] = sprintf(
						/* translators: 1: item width, 2: item height. */
						__( 'An item (%1$s × %2$s cm) is larger than the print area.', 'tshirt-designer' ),
						number_format( (float) $clean['w'], 1 ),
						number_format( (float) $clean['h'], 1 )
					);
				} elseif ( abs( $clamped['x'] - $clean['x'] ) > 0.05 || abs( $clamped['y'] - $clean['y'] ) > 0.05 ) {
					$errors[] = __( 'An item is placed outside the print area.', 'tshirt-designer' );
				}
				$clean = $clamped;
				$clean_items[] = $clean;
			}

			if ( array() !== $clean_items ) {
				$design_areas[ (string) $area_id ] = $clean_items;
				$items[ $area_id ] = array_map(
					static fn( array $it ): array => array( 'w' => $it['w'], 'h' => $it['h'] ),
					$clean_items
				);
			}
		}

		if ( $errors ) {
			return array( 'ok' => false, 'errors' => $errors );
		}

		$design = array(
			'model_id' => $model_id,
			'color_id' => $color_id,
			'size_id'  => $size_id,
			'areas'    => $design_areas,
		);

		return array(
			'ok'     => true,
			'errors' => array(),
			'design' => $design,
			'items'  => $items,
		);
	}

	/**
	 * Validate a single design item.
	 *
	 * @param array<string, mixed>  $item Raw item.
	 * @param array<string, mixed>  $area Print area row.
	 * @param int                   $user_id Current user.
	 * @param string                $guest_token Guest token.
	 * @param string[]              $errors Collected errors (by-ref).
	 * @return array<string, mixed>|null
	 */
	private function validate_item(
		array $item,
		array $area,
		int $user_id,
		string $guest_token,
		array &$errors
	): ?array {
		$type = (string) ( $item['type'] ?? '' );
		if ( ! in_array( $type, array( 'asset', 'upload' ), true ) ) {
			$errors[] = __( 'Invalid design item type.', 'tshirt-designer' );
			return null;
		}

		$ref_id = (int) ( $item['ref_id'] ?? 0 );
		$src    = '';

		if ( 'asset' === $type ) {
			$asset = Plugin::instance()->assets->get( $ref_id );
			if ( null === $asset || ! $asset['is_active'] ) {
				$errors[] = __( 'A design item references an unavailable artwork.', 'tshirt-designer' );
				return null;
			}
			$src = Plugin::instance()->assets->file_url( $asset );
		} else {
			$upload = $this->media->get_upload( $ref_id, $user_id, $guest_token );
			if ( null === $upload ) {
				$errors[] = __( 'A design item references an unavailable upload.', 'tshirt-designer' );
				return null;
			}
			$src = (string) $upload['url'];
		}

		$w = round( (float) ( $item['w'] ?? 0 ), 2 );
		$h = round( (float) ( $item['h'] ?? 0 ), 2 );
		$x = round( (float) ( $item['x'] ?? 0 ), 2 );
		$y = round( (float) ( $item['y'] ?? 0 ), 2 );
		$r = round( (float) ( $item['rotation'] ?? 0 ), 2 );

		if ( $w < self::MIN_ITEM_CM || $h < self::MIN_ITEM_CM ) {
			$errors[] = sprintf(
				/* translators: %d: minimum item size in cm. */
				__( 'Design items must be at least %d cm wide and tall.', 'tshirt-designer' ),
				(int) self::MIN_ITEM_CM
			);
			return null;
		}

		return array(
			'id'       => mb_substr( sanitize_text_field( (string) ( $item['id'] ?? '' ) ), 0, 40 ),
			'type'     => $type,
			'ref_id'   => $ref_id,
			'src'      => $src,
			'x'        => $x,
			'y'        => $y,
			'w'        => $w,
			'h'        => $h,
			'rotation' => max( -360.0, min( 360.0, $r ) ),
		);
	}

	/**
	 * Compute the authoritative price for a design payload.
	 *
	 * @return array{ok:bool, errors:string[], breakdown?:array<string,mixed>}
	 */
	public function quote( array $input, int $user_id, string $guest_token ): array {
		$result = $this->validate_design( $input, $user_id, $guest_token );
		if ( ! $result['ok'] ) {
			return array( 'ok' => false, 'errors' => $result['errors'] );
		}

		$design = $result['design'];

		$model = $this->models->get( (int) $design['model_id'] );
		if ( null === $model ) {
			return array( 'ok' => false, 'errors' => array( __( 'Model not found.', 'tshirt-designer' ) ) );
		}

		$base_price = $this->models->base_price( $model );

		$size_modifier = 0.0;
		$size_name     = '';
		$size_row      = Plugin::instance()->sizes->get( (int) $design['size_id'] );
		if ( null !== $size_row ) {
			$size_modifier = (float) $size_row['price_modifier'];
			$size_name     = (string) $size_row['name'];
		}

		$print_areas = array();
		foreach ( $this->print_areas->for_model( (int) $design['model_id'] ) as $area ) {
			$print_areas[ (int) $area['id'] ] = $area;
		}

		$breakdown = $this->pricing->compute(
			$base_price,
			$size_modifier,
			$print_areas,
			$result['items'],
			$this->pricing->load_rules()
		);

		$breakdown['size_name'] = $size_name;
		$breakdown['currency']  = Plugin::instance()->settings->all()['currency'];

		return array( 'ok' => true, 'errors' => array(), 'breakdown' => $breakdown );
	}

	/**
	 * Save a design (validated + priced server-side).
	 *
	 * @return array{ok:bool, errors:string[], id?:int}
	 */
	public function save( array $input, int $user_id, string $guest_token, ?string $preview_data_url ): array {
		$result = $this->quote( $input, $user_id, $guest_token );
		if ( ! $result['ok'] ) {
			return array( 'ok' => false, 'errors' => $result['errors'] );
		}

		$design    = $result['design'];
		$breakdown = $result['breakdown'];
		$design_id = (int) ( $input['design_id'] ?? 0 );

		$preview_id = 0;
		if ( is_string( $preview_data_url ) && '' !== $preview_data_url ) {
			$preview_id = $this->store_preview( $preview_data_url, $user_id );
		}

		global $wpdb;
		$now = current_time( 'mysql' );
		$row = array(
			'user_id'         => $user_id,
			'guest_token'     => $user_id > 0 ? '' : $guest_token,
			'model_id'        => (int) $design['model_id'],
			'color_id'        => (int) $design['color_id'],
			'size_id'         => (int) $design['size_id'],
			'design_data'     => wp_json_encode( $design ),
			'price_total'     => (float) $breakdown['total'],
			'price_breakdown' => wp_json_encode( $breakdown ),
			'status'          => 'saved',
			'updated_at'      => $now,
		);

		$table = $this->db->table( 'designs' );

		$update = false;
		if ( $design_id > 0 ) {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$existing = $wpdb->get_row(
				$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $design_id ),
				ARRAY_A
			);
			if ( is_array( $existing ) && $this->user_owns_design( $existing, $user_id, $guest_token ) ) {
				$update = true;
			}
		}

		if ( $update ) {
			if ( $preview_id > 0 ) {
				$row['preview_image_id'] = $preview_id;
			}
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $table, $row, array( 'id' => $design_id ) );
			$id = $design_id;
		} else {
			$row['created_at'] = $now;
			if ( $preview_id > 0 ) {
				$row['preview_image_id'] = $preview_id;
			}
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert( $table, $row );
			$id = (int) $wpdb->insert_id;
		}

		if ( $id <= 0 ) {
			return array( 'ok' => false, 'errors' => array( __( 'Could not save the design.', 'tshirt-designer' ) ) );
		}

		return array( 'ok' => true, 'errors' => array(), 'id' => $id );
	}

	/**
	 * Whether the current user/guest owns a design row.
	 *
	 * @param array<string, mixed> $row Design row.
	 */
	public function user_owns_design( array $row, int $user_id, string $guest_token ): bool {
		if ( current_user_can( 'manage_options' ) ) {
			return true;
		}
		$owner_user  = (int) $row['user_id'];
		$owner_guest = (string) $row['guest_token'];
		if ( 0 !== $owner_user && $owner_user === $user_id ) {
			return true;
		}
		return 0 === $owner_user && '' !== $guest_token && $owner_guest === $guest_token;
	}

	/**
	 * Get one design (ownership enforced).
	 *
	 * @return array<string, mixed>|null
	 */
	public function get_design( int $id, int $user_id, string $guest_token ): ?array {
		global $wpdb;
		$table = $this->db->table( 'designs' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $id ),
			ARRAY_A
		);
		if ( ! is_array( $row ) ) {
			return null;
		}
		if ( ! $this->user_owns_design( $row, $user_id, $guest_token ) ) {
			return null;
		}
		return $this->cast( $row );
	}

	/**
	 * List designs for a user/guest.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function list_designs( int $user_id, string $guest_token, int $limit = 50 ): array {
		global $wpdb;
		$table = $this->db->table( 'designs' );
		if ( $user_id > 0 ) {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$rows = $wpdb->get_results(
				$wpdb->prepare( "SELECT * FROM {$table} WHERE user_id = %d ORDER BY id DESC LIMIT %d", $user_id, $limit ),
				ARRAY_A
			);
		} elseif ( '' !== $guest_token ) {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$rows = $wpdb->get_results(
				$wpdb->prepare( "SELECT * FROM {$table} WHERE user_id = 0 AND guest_token = %s ORDER BY id DESC LIMIT %d", $guest_token, $limit ),
				ARRAY_A
			);
		} else {
			return array();
		}
		return array_map( array( $this, 'cast' ), is_array( $rows ) ? $rows : array() );
	}

	/**
	 * Store a base64 PNG preview from the client (strictly validated).
	 */
	private function store_preview( string $data_url, int $user_id ): int {
		if ( ! preg_match( '#^data:image/(png|jpeg);base64,#i', $data_url, $m ) ) {
			return 0;
		}
		$mime = strtolower( $m[1] );
		$blob = base64_decode( substr( $data_url, strlen( $m[0] ) ), true );
		if ( false === $blob || strlen( $blob ) < 64 || strlen( $blob ) > 3 * 1024 * 1024 ) {
			return 0;
		}
		$sig = substr( $blob, 0, 8 );
		if ( 'png' === $mime && "\x89PNG\r\n\x1a\n" !== $sig ) {
			return 0;
		}

		$uploads = wp_upload_dir();
		if ( ! empty( $uploads['error'] ) ) {
			return 0;
		}
		$dir = $uploads['basedir'] . '/td-uploads/previews';
		if ( ! wp_mkdir_p( $dir ) ) {
			return 0;
		}
		$filename = 'design-' . wp_generate_password( 24, false, false ) . '.' . $mime;
		$path     = $dir . '/' . $filename;
		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
		if ( false === file_put_contents( $path, $blob ) ) {
			return 0;
		}

		// Re-verify the stored file is a real image.
		$info = @getimagesize( $path ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		if ( false === $info ) {
			wp_delete_file( $path );
			return 0;
		}

		$attachment = array(
			'post_mime_type' => 'image/' . $mime,
			'post_title'     => 'tshirt-design-preview',
			'post_status'    => 'inherit',
			'post_author'    => $user_id,
		);
		$attach_id = wp_insert_attachment( $attachment, $path, 0, true );
		return is_wp_error( $attach_id ) ? 0 : (int) $attach_id;
	}

	/**
	 * @param array<string, mixed> $row Raw row.
	 * @return array<string, mixed>
	 */
	public function cast( array $row ): array {
		return array(
			'id'               => (int) $row['id'],
			'user_id'          => (int) $row['user_id'],
			'model_id'         => (int) $row['model_id'],
			'color_id'         => (int) $row['color_id'],
			'size_id'          => (int) $row['size_id'],
			'design_data'      => json_decode( (string) $row['design_data'], true ),
			'preview_image_id' => (int) $row['preview_image_id'],
			'price_total'      => (float) $row['price_total'],
			'price_breakdown'  => json_decode( (string) $row['price_breakdown'], true ),
			'status'           => (string) $row['status'],
			'created_at'       => (string) $row['created_at'],
			'updated_at'       => (string) $row['updated_at'],
		);
	}
}
