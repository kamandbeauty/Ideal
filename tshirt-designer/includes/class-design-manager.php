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

	/** Design item types the engine understands. */
	public const ITEM_TYPES = array( 'asset', 'upload', 'text' );

	/** Lifecycle statuses (see docs: file lifecycle). */
	public const STATUS_DRAFT      = 'draft';
	public const STATUS_SAVED      = 'saved';
	public const STATUS_ORDERED    = 'ordered';
	public const STATUS_PAID       = 'paid';
	public const STATUS_PRODUCTION = 'production';

	/** Statuses that must never be auto-deleted by cleanup. */
	public const PROTECTED_STATUSES = array( self::STATUS_ORDERED, self::STATUS_PAID, self::STATUS_PRODUCTION );

	/**
	 * Generate a public design identifier, e.g. DESIGN-8F72A91.
	 */
	public static function new_uuid(): string {
		$bytes = function_exists( 'wp_generate_password' )
			? wp_generate_password( 12, false, false )
			: bin2hex( random_bytes( 6 ) );
		$hash = strtoupper( substr( hash( 'sha256', $bytes . microtime( true ) . random_int( 0, PHP_INT_MAX ) ), 0, 7 ) );
		return 'DESIGN-' . $hash;
	}

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
				// Normalize layer order: respect the client's stacking, then
				// re-index so production and preview always agree.
				usort(
					$clean_items,
					static function ( array $a, array $b ): int {
						return (int) $a['layer'] <=> (int) $b['layer'];
					}
				);
				foreach ( $clean_items as $index => $unused ) {
					$clean_items[ $index ]['layer'] = $index;
				}

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
			'product_type' => (string) $model['product_type'],
			'model_id'     => $model_id,
			'color_id'     => $color_id,
			'size_id'      => $size_id,
			'areas'        => $design_areas,
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
		if ( ! in_array( $type, self::ITEM_TYPES, true ) ) {
			$errors[] = __( 'Invalid design item type.', 'tshirt-designer' );
			return null;
		}

		$ref_id = (int) ( $item['ref_id'] ?? 0 );
		$src    = '';
		$text   = null;

		if ( 'text' === $type ) {
			$text = $this->validate_text( $item, $errors );
			if ( null === $text ) {
				return null;
			}
		} elseif ( 'asset' === $type ) {
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

		$opacity = isset( $item['opacity'] ) && is_numeric( $item['opacity'] )
			? round( min( 1.0, max( 0.05, (float) $item['opacity'] ) ), 3 )
			: 1.0;

		$clean = array(
			'id'       => mb_substr( sanitize_text_field( (string) ( $item['id'] ?? '' ) ), 0, 40 ),
			'type'     => $type,
			'ref_id'   => $ref_id,
			'src'      => $src,
			'x'        => $x,
			'y'        => $y,
			'w'        => $w,
			'h'        => $h,
			'rotation' => max( -360.0, min( 360.0, $r ) ),
			'layer'    => isset( $item['layer'] ) ? max( 0, min( 999, (int) $item['layer'] ) ) : 0,
			'opacity'  => $opacity,
		);

		if ( null !== $text ) {
			$clean['text'] = $text;
		}

		return $clean;
	}

	/**
	 * Validate the typography payload of a text item.
	 *
	 * Text is stored as structured data (never rasterized into a fake image),
	 * so it stays editable and can be re-rendered at print resolution.
	 *
	 * @param array<string, mixed> $item   Raw item.
	 * @param string[]             $errors Collected errors (by-ref).
	 * @return array<string, mixed>|null
	 */
	private function validate_text( array $item, array &$errors ): ?array {
		$raw = isset( $item['text'] ) && is_array( $item['text'] ) ? $item['text'] : array();

		$content = isset( $raw['content'] ) ? (string) $raw['content'] : '';
		$content = sanitize_textarea_field( $content );
		$content = trim( preg_replace( '/[\r\n]+/u', "\n", $content ) ?? '' );
		if ( '' === $content ) {
			$errors[] = __( 'Text items need some text.', 'tshirt-designer' );
			return null;
		}
		if ( mb_strlen( $content ) > 200 ) {
			$content = mb_substr( $content, 0, 200 );
		}

		$fonts = Text_Engine::fonts();
		$font  = isset( $raw['font'] ) ? sanitize_key( (string) $raw['font'] ) : '';
		if ( ! isset( $fonts[ $font ] ) ) {
			$font = (string) array_key_first( $fonts );
		}

		$color = isset( $raw['color'] ) ? sanitize_hex_color( (string) $raw['color'] ) : null;
		if ( ! is_string( $color ) || '' === $color ) {
			$color = '#111111';
		}

		$align = isset( $raw['align'] ) ? sanitize_key( (string) $raw['align'] ) : 'center';
		if ( ! in_array( $align, array( 'left', 'center', 'right' ), true ) ) {
			$align = 'center';
		}

		$direction = isset( $raw['direction'] ) ? sanitize_key( (string) $raw['direction'] ) : '';
		if ( ! in_array( $direction, array( 'rtl', 'ltr' ), true ) ) {
			$direction = Text_Engine::detect_direction( $content );
		}

		return array(
			'content'   => $content,
			'font'      => $font,
			'color'     => $color,
			'bold'      => ! empty( $raw['bold'] ),
			'italic'    => ! empty( $raw['italic'] ),
			'align'     => $align,
			'direction' => $direction,
		);
	}

	/**
	 * Compute the authoritative price for a design payload.
	 *
	 * @return array{ok:bool, errors:string[], breakdown?:array<string,mixed>, design?:array<string,mixed>, items?:array<int,array<string,mixed>>}
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

		return array(
			'ok'        => true,
			'errors'    => array(),
			'breakdown' => $breakdown,
			'design'    => $design,
			'items'     => $result['items'],
		);
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

		$existing = null;
		if ( $design_id > 0 ) {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$candidate = $wpdb->get_row(
				$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $design_id ),
				ARRAY_A
			);
			if ( is_array( $candidate ) && $this->user_owns_design( $candidate, $user_id, $guest_token ) ) {
				$existing = $candidate;
			} elseif ( is_array( $candidate ) ) {
				return array(
					'ok'     => false,
					'errors' => array( __( 'You are not allowed to edit this design.', 'tshirt-designer' ) ),
				);
			}
		}

		$row['product_type'] = (string) $design['product_type'];

		if ( null !== $existing ) {
			// A design attached to a paid order is immutable: branch into a new
			// design instead of mutating history.
			if ( in_array( (string) $existing['status'], self::PROTECTED_STATUSES, true ) ) {
				$existing = null;
			}
		}

		if ( null !== $existing ) {
			$id      = (int) $existing['id'];
			$version = max( 1, (int) $existing['version'] ) + 1;

			$row['version'] = $version;
			if ( $preview_id > 0 ) {
				$row['preview_image_id'] = $preview_id;
			}
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $table, $row, array( 'id' => $id ) );

			$uuid = (string) $existing['uuid'];
			if ( '' === $uuid ) {
				$uuid = self::new_uuid();
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update( $table, array( 'uuid' => $uuid ), array( 'id' => $id ) );
			}
			$preview_for_version = $preview_id > 0 ? $preview_id : (int) $existing['preview_image_id'];
		} else {
			$uuid              = self::new_uuid();
			$version           = 1;
			$row['uuid']       = $uuid;
			$row['version']    = 1;
			$row['created_at'] = $now;
			if ( $preview_id > 0 ) {
				$row['preview_image_id'] = $preview_id;
			}
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert( $table, $row );
			$id = (int) $wpdb->insert_id;
			$preview_for_version = $preview_id;
		}

		if ( $id <= 0 ) {
			Plugin::instance()->logger->error(
				Logger::CHANNEL_DESIGN,
				'Design insert failed',
				array( 'model_id' => $design['model_id'], 'db_error' => $wpdb->last_error )
			);
			return array( 'ok' => false, 'errors' => array( __( 'Could not save the design.', 'tshirt-designer' ) ) );
		}

		$this->store_version( $id, $version, $design, $breakdown, $preview_for_version, $now );

		return array(
			'ok'      => true,
			'errors'  => array(),
			'id'      => $id,
			'uuid'    => $uuid,
			'version' => $version,
		);
	}

	/**
	 * Persist an immutable snapshot of one design version.
	 *
	 * @param array<string, mixed> $design    Validated design document.
	 * @param array<string, mixed> $breakdown Price breakdown.
	 */
	private function store_version(
		int $design_id,
		int $version,
		array $design,
		array $breakdown,
		int $preview_id,
		string $now
	): void {
		global $wpdb;
		$table = $this->db->table( 'design_versions' );

		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$exists = (int) $wpdb->get_var(
			$wpdb->prepare(
				"SELECT COUNT(*) FROM {$table} WHERE design_id = %d AND version = %d",
				$design_id,
				$version
			)
		);
		if ( $exists > 0 ) {
			return; // Versions never change once written.
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$table,
			array(
				'design_id'        => $design_id,
				'version'          => $version,
				'design_data'      => wp_json_encode( $design ),
				'price_breakdown'  => wp_json_encode( $breakdown ),
				'price_total'      => (float) $breakdown['total'],
				'preview_image_id' => $preview_id,
				'created_at'       => $now,
			)
		);
	}

	/**
	 * One stored version of a design.
	 *
	 * @return array<string, mixed>|null
	 */
	public function get_version( int $design_id, int $version ): ?array {
		global $wpdb;
		$table = $this->db->table( 'design_versions' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare(
				"SELECT * FROM {$table} WHERE design_id = %d AND version = %d",
				$design_id,
				$version
			),
			ARRAY_A
		);
		if ( ! is_array( $row ) ) {
			return null;
		}
		return array(
			'id'               => (int) $row['id'],
			'design_id'        => (int) $row['design_id'],
			'version'          => (int) $row['version'],
			'design_data'      => json_decode( (string) $row['design_data'], true ),
			'price_breakdown'  => json_decode( (string) $row['price_breakdown'], true ),
			'price_total'      => (float) $row['price_total'],
			'preview_image_id' => (int) $row['preview_image_id'],
			'created_at'       => (string) $row['created_at'],
		);
	}

	/**
	 * Every version of a design, newest first.
	 *
	 * @return list<array<string, mixed>>
	 */
	public function versions( int $design_id ): array {
		global $wpdb;
		$table = $this->db->table( 'design_versions' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$rows = $wpdb->get_results(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE design_id = %d ORDER BY version DESC", $design_id ),
			ARRAY_A
		);
		$out = array();
		foreach ( is_array( $rows ) ? $rows : array() as $row ) {
			$out[] = array(
				'version'          => (int) $row['version'],
				'price_total'      => (float) $row['price_total'],
				'preview_image_id' => (int) $row['preview_image_id'],
				'created_at'       => (string) $row['created_at'],
			);
		}
		return $out;
	}

	/**
	 * Duplicate a design into a brand new one owned by the same user/guest.
	 *
	 * Files are reused (asset/upload ids are kept); only the design record is
	 * independent, so editing the copy never touches the original.
	 *
	 * @return array{ok:bool, errors:string[], id?:int, uuid?:string}
	 */
	public function duplicate( int $design_id, int $user_id, string $guest_token ): array {
		$source = $this->get_design( $design_id, $user_id, $guest_token );
		if ( null === $source ) {
			return array( 'ok' => false, 'errors' => array( __( 'Design not found.', 'tshirt-designer' ) ) );
		}

		$data = is_array( $source['design_data'] ) ? $source['design_data'] : array();
		$payload = array(
			'model_id' => (int) ( $data['model_id'] ?? $source['model_id'] ),
			'color_id' => (int) ( $data['color_id'] ?? $source['color_id'] ),
			'size_id'  => (int) ( $data['size_id'] ?? $source['size_id'] ),
			'areas'    => isset( $data['areas'] ) && is_array( $data['areas'] ) ? $data['areas'] : array(),
		);

		// Re-validate against the *current* catalogue: a copy must be orderable.
		$result = $this->save( $payload, $user_id, $guest_token, null );
		if ( ! $result['ok'] ) {
			return $result;
		}

		// Carry the preview over so the copy is recognisable straight away.
		if ( (int) $source['preview_image_id'] > 0 ) {
			global $wpdb;
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update(
				$this->db->table( 'designs' ),
				array( 'preview_image_id' => (int) $source['preview_image_id'] ),
				array( 'id' => (int) $result['id'] )
			);
		}

		return $result;
	}

	/**
	 * Delete a design the caller owns (never a design tied to a paid order).
	 *
	 * @return array{ok:bool, errors:string[]}
	 */
	public function delete( int $design_id, int $user_id, string $guest_token ): array {
		$design = $this->get_design( $design_id, $user_id, $guest_token );
		if ( null === $design ) {
			return array( 'ok' => false, 'errors' => array( __( 'Design not found.', 'tshirt-designer' ) ) );
		}
		if ( in_array( (string) $design['status'], self::PROTECTED_STATUSES, true ) ) {
			return array(
				'ok'     => false,
				'errors' => array( __( 'Designs attached to an order cannot be deleted.', 'tshirt-designer' ) ),
			);
		}

		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'designs' ), array( 'id' => $design_id ), array( '%d' ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->delete( $this->db->table( 'design_versions' ), array( 'design_id' => $design_id ), array( '%d' ) );

		return array( 'ok' => true, 'errors' => array() );
	}

	/**
	 * Update a design's lifecycle status (ordered/paid/production).
	 */
	public function set_status( int $design_id, string $status ): void {
		$allowed = array(
			self::STATUS_DRAFT,
			self::STATUS_SAVED,
			self::STATUS_ORDERED,
			self::STATUS_PAID,
			self::STATUS_PRODUCTION,
		);
		if ( ! in_array( $status, $allowed, true ) ) {
			return;
		}
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update(
			$this->db->table( 'designs' ),
			array( 'status' => $status, 'updated_at' => current_time( 'mysql' ) ),
			array( 'id' => $design_id )
		);
	}

	/**
	 * Move guest designs to a user account after login/registration.
	 *
	 * @return int Number of designs transferred.
	 */
	public function claim_guest_designs( int $user_id, string $guest_token ): int {
		if ( $user_id <= 0 || '' === $guest_token ) {
			return 0;
		}
		global $wpdb;
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$count = $wpdb->update(
			$this->db->table( 'designs' ),
			array( 'user_id' => $user_id, 'guest_token' => '' ),
			array( 'guest_token' => $guest_token, 'user_id' => 0 ),
			array( '%d', '%s' ),
			array( '%s', '%d' )
		);
		return is_int( $count ) ? $count : 0;
	}

	/**
	 * Build the immutable production snapshot of a design version.
	 *
	 * Everything the production pipeline needs is copied by value: model,
	 * colour, size, area geometry, item positions and resolved file paths.
	 * Later catalogue edits can therefore never alter a placed order.
	 *
	 * @return array<string, mixed>|null
	 */
	public function build_snapshot( int $design_id, int $version ): ?array {
		global $wpdb;
		$table = $this->db->table( 'designs' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $design_id ), ARRAY_A );
		if ( ! is_array( $row ) ) {
			return null;
		}
		$design = $this->cast( $row );

		$stored = $this->get_version( $design_id, $version );
		if ( null === $stored ) {
			return null;
		}
		$data = is_array( $stored['design_data'] ) ? $stored['design_data'] : array();

		$model = $this->models->get( (int) ( $data['model_id'] ?? 0 ), true );
		if ( null === $model ) {
			return null;
		}

		$color = Plugin::instance()->colors->get( (int) ( $data['color_id'] ?? 0 ) );
		$size  = Plugin::instance()->sizes->get( (int) ( $data['size_id'] ?? 0 ) );

		$areas_by_id = array();
		foreach ( $this->print_areas->for_model( (int) $model['id'], false ) as $area ) {
			$areas_by_id[ (int) $area['id'] ] = $area;
		}

		$product_type = (string) ( $data['product_type'] ?? $model['product_type'] );
		$dpi          = Product_Type_Registry::dpi( $product_type, Plugin::instance()->settings );

		$snapshot_areas = array();
		$item_count     = 0;

		foreach ( ( $data['areas'] ?? array() ) as $area_key => $items ) {
			$area_id = (int) $area_key;
			if ( ! isset( $areas_by_id[ $area_id ] ) || ! is_array( $items ) || array() === $items ) {
				continue;
			}
			$area = $areas_by_id[ $area_id ];

			$snapshot_items = array();
			foreach ( $items as $item ) {
				if ( ! is_array( $item ) ) {
					continue;
				}
				$snapshot_items[] = $this->snapshot_item( $item );
				++$item_count;
			}

			$snapshot_areas[] = array(
				'id'            => $area_id,
				'name'          => (string) $area['name'],
				'type'          => (string) $area['area_type'],
				'max_width_cm'  => (float) $area['max_width_cm'],
				'max_height_cm' => (float) $area['max_height_cm'],
				'items'         => $snapshot_items,
			);
		}

		return array(
			'snapshot_version' => 1,
			'taken_at'         => current_time( 'mysql' ),
			'design_id'        => $design_id,
			'design_uuid'      => (string) $design['uuid'],
			'design_version'   => $version,
			'product_type'     => $product_type,
			'model'            => array(
				'id'   => (int) $model['id'],
				'name' => (string) $model['name'],
				'slug' => (string) $model['slug'],
			),
			'color'            => null === $color
				? null
				: array( 'id' => (int) $color['id'], 'name' => (string) $color['name'], 'hex' => (string) $color['hex'] ),
			'size'             => null === $size
				? null
				: array( 'id' => (int) $size['id'], 'name' => (string) $size['name'] ),
			'areas'            => $snapshot_areas,
			'item_count'       => $item_count,
			'dpi'              => $dpi,
			'preview_image_id' => (int) ( $stored['preview_image_id'] ?: $design['preview_image_id'] ),
			'pricing'          => $stored['price_breakdown'],
			'price_total'      => (float) $stored['price_total'],
		);
	}

	/**
	 * Copy one design item into the snapshot, resolving its file by absolute
	 * path so later media edits cannot change the print output.
	 *
	 * @param array<string, mixed> $item Stored design item.
	 * @return array<string, mixed>
	 */
	private function snapshot_item( array $item ): array {
		$out = array(
			'id'       => (string) ( $item['id'] ?? '' ),
			'type'     => (string) ( $item['type'] ?? '' ),
			'ref_id'   => (int) ( $item['ref_id'] ?? 0 ),
			'x'        => (float) ( $item['x'] ?? 0 ),
			'y'        => (float) ( $item['y'] ?? 0 ),
			'w'        => (float) ( $item['w'] ?? 0 ),
			'h'        => (float) ( $item['h'] ?? 0 ),
			'rotation' => (float) ( $item['rotation'] ?? 0 ),
			'layer'    => (int) ( $item['layer'] ?? 0 ),
			'opacity'  => isset( $item['opacity'] ) ? (float) $item['opacity'] : 1.0,
			'src'      => (string) ( $item['src'] ?? '' ),
		);

		if ( 'text' === $out['type'] ) {
			$out['text'] = isset( $item['text'] ) && is_array( $item['text'] ) ? $item['text'] : array();
			return $out;
		}

		$out['file_path'] = $this->resolve_item_path( $out['type'], $out['ref_id'], $out['src'] );
		return $out;
	}

	/**
	 * Absolute filesystem path of an item's artwork ('' when unresolvable).
	 */
	private function resolve_item_path( string $type, int $ref_id, string $src ): string {
		if ( 'asset' === $type ) {
			$asset = Plugin::instance()->assets->get( $ref_id );
			if ( is_array( $asset ) ) {
				if ( (int) $asset['file_id'] > 0 ) {
					$path = get_attached_file( (int) $asset['file_id'] );
					if ( is_string( $path ) && is_readable( $path ) ) {
						return $path;
					}
				}
				if ( '' !== (string) $asset['file_path'] ) {
					$path = TD_PLUGIN_DIR . ltrim( (string) $asset['file_path'], '/' );
					if ( is_readable( $path ) ) {
						return $path;
					}
				}
			}
		} elseif ( 'upload' === $type ) {
			global $wpdb;
			$table = $this->db->table( 'uploads' );
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$attachment_id = (int) $wpdb->get_var(
				$wpdb->prepare( "SELECT attachment_id FROM {$table} WHERE id = %d", $ref_id )
			);
			if ( $attachment_id > 0 ) {
				$path = get_attached_file( $attachment_id );
				if ( is_string( $path ) && is_readable( $path ) ) {
					return $path;
				}
			}
		}

		// Last resort: map a URL inside the uploads dir back to a path.
		if ( '' !== $src ) {
			$uploads = wp_upload_dir();
			if ( empty( $uploads['error'] ) && str_starts_with( $src, (string) $uploads['baseurl'] ) ) {
				$path = $uploads['basedir'] . substr( $src, strlen( (string) $uploads['baseurl'] ) );
				if ( is_readable( $path ) ) {
					return $path;
				}
			}
		}

		return '';
	}

	/**
	 * Whether the current user/guest owns a design row.
	 *
	 * @param array<string, mixed> $row Design row.
	 */
	public function user_owns_design( array $row, int $user_id, string $guest_token ): bool {
		// Capability is checked against the identity the caller is acting as,
		// never against the ambient current user: passing an explicit
		// $user_id must not inherit an administrator session.
		if ( $user_id > 0 && user_can( $user_id, 'manage_options' ) ) {
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
			'uuid'             => (string) ( $row['uuid'] ?? '' ),
			'version'          => max( 1, (int) ( $row['version'] ?? 1 ) ),
			'product_type'     => (string) ( $row['product_type'] ?? '' ),
			'user_id'          => (int) $row['user_id'],
			'guest_token'      => (string) ( $row['guest_token'] ?? '' ),
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
