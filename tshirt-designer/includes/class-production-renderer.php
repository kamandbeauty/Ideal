<?php
/**
 * Production renderer — turns an immutable design snapshot into print files.
 *
 * One transparent PNG per print area that actually carries artwork, sized
 * from the area's physical dimensions and the configured DPI:
 *
 *     px = round( cm / 2.54 * dpi )
 *
 * Items are composited in layer order at their real physical position, with
 * rotation and opacity preserved. Nothing here reads live models, pricing or
 * assets: everything comes from the snapshot, so paid orders never change.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Production_Renderer {

	private const CM_PER_INCH = 2.54;

	/** Hard ceiling so a huge DPI cannot exhaust memory. */
	private const MAX_SIDE_PX = 12000;

	public function __construct(
		private Database $db,
		private Settings $settings
	) {}

	/**
	 * Physical size in pixels for a print area at a given DPI.
	 *
	 * @return array{0:int,1:int}
	 */
	public static function pixel_size( float $width_cm, float $height_cm, int $dpi ): array {
		$dpi = Product_Type_Registry::clamp_dpi( $dpi );
		$w   = (int) round( $width_cm / self::CM_PER_INCH * $dpi );
		$h   = (int) round( $height_cm / self::CM_PER_INCH * $dpi );
		return array(
			max( 1, min( self::MAX_SIDE_PX, $w ) ),
			max( 1, min( self::MAX_SIDE_PX, $h ) ),
		);
	}

	/**
	 * Directory production files live in (protected from directory listing).
	 *
	 * @return array{dir:string,url:string}|null
	 */
	public function storage_dir(): ?array {
		$uploads = wp_upload_dir();
		if ( ! empty( $uploads['error'] ) ) {
			return null;
		}
		$dir = trailingslashit( $uploads['basedir'] ) . 'td-production';
		if ( ! wp_mkdir_p( $dir ) ) {
			return null;
		}
		// Block browsing / direct execution; downloads are proxied by the admin.
		$index = $dir . '/index.html';
		if ( ! file_exists( $index ) ) {
			// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
			@file_put_contents( $index, '' );
		}
		$htaccess = $dir . '/.htaccess';
		if ( ! file_exists( $htaccess ) ) {
			// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
			@file_put_contents( $htaccess, "Options -Indexes\nDeny from all\n" );
		}
		return array(
			'dir' => $dir,
			'url' => trailingslashit( $uploads['baseurl'] ) . 'td-production',
		);
	}

	/**
	 * Generate every production file for one order item snapshot.
	 *
	 * @param array<string, mixed> $snapshot Production snapshot (see Order_Manager).
	 * @param int                  $order_id WooCommerce order id.
	 * @param int                  $item_id  WooCommerce order item id.
	 * @param bool                 $force    Re-render files that already exist.
	 * @return array{ok:bool, files:list<array<string,mixed>>, errors:string[]}
	 */
	public function generate( array $snapshot, int $order_id, int $item_id, bool $force = false ): array {
		$errors = array();
		$files  = array();

		$storage = $this->storage_dir();
		if ( null === $storage ) {
			return array(
				'ok'     => false,
				'files'  => array(),
				'errors' => array( __( 'The uploads directory is not writable.', 'tshirt-designer' ) ),
			);
		}

		if ( ! function_exists( 'imagecreatetruecolor' ) ) {
			return array(
				'ok'     => false,
				'files'  => array(),
				'errors' => array( __( 'The GD image library is required to generate production files.', 'tshirt-designer' ) ),
			);
		}

		$design_id = (int) ( $snapshot['design_id'] ?? 0 );
		$design_uuid = (string) ( $snapshot['design_uuid'] ?? '' );
		$version   = max( 1, (int) ( $snapshot['design_version'] ?? 1 ) );
		$dpi       = Product_Type_Registry::clamp_dpi( (int) ( $snapshot['dpi'] ?? 300 ) );

		$areas = isset( $snapshot['areas'] ) && is_array( $snapshot['areas'] ) ? $snapshot['areas'] : array();

		foreach ( $areas as $area ) {
			if ( ! is_array( $area ) ) {
				continue;
			}
			$items = isset( $area['items'] ) && is_array( $area['items'] ) ? $area['items'] : array();
			if ( array() === $items ) {
				continue; // Only areas that really carry a design produce a file.
			}

			$area_id   = (int) ( $area['id'] ?? 0 );
			$area_type = sanitize_key( (string) ( $area['type'] ?? 'other' ) );
			$file_name = self::file_name( $order_id, $design_uuid ?: (string) $design_id, $area_type );
			$path      = $storage['dir'] . '/' . $file_name;

			$existing = $this->find_file( $order_id, $item_id, $area_id );
			if ( ! $force && null !== $existing && 'ready' === $existing['status'] && file_exists( $existing['file_path'] ) ) {
				$files[] = $existing;
				continue;
			}

			$result = $this->render_area( $area, $dpi, $path );
			if ( ! $result['ok'] ) {
				$errors[] = $result['error'];
				$this->record(
					$order_id,
					$item_id,
					$design_id,
					$version,
					$area_id,
					$area_type,
					$file_name,
					'',
					0,
					0,
					$dpi,
					'failed',
					$result['error']
				);
				continue;
			}

			$row = $this->record(
				$order_id,
				$item_id,
				$design_id,
				$version,
				$area_id,
				$area_type,
				$file_name,
				$path,
				$result['width'],
				$result['height'],
				$dpi,
				'ready',
				''
			);
			$files[] = $row;
		}

		return array(
			'ok'     => array() === $errors,
			'files'  => $files,
			'errors' => $errors,
		);
	}

	/**
	 * Standardised production file name, e.g. ORDER-1001-DESIGN-A123-FRONT.png.
	 */
	public static function file_name( int $order_id, string $design_ref, string $area_type ): string {
		$design_ref = strtoupper( preg_replace( '/[^A-Za-z0-9\-]/', '', $design_ref ) ?? '' );
		if ( '' === $design_ref ) {
			$design_ref = 'DESIGN';
		}
		if ( ! str_starts_with( $design_ref, 'DESIGN' ) ) {
			$design_ref = 'DESIGN-' . $design_ref;
		}
		$area = strtoupper( str_replace( '_', '-', preg_replace( '/[^a-z0-9_]/', '', $area_type ) ?? 'AREA' ) );
		if ( '' === $area ) {
			$area = 'AREA';
		}
		return sprintf( 'ORDER-%d-%s-%s.png', $order_id, $design_ref, $area );
	}

	/**
	 * Render one print area into a transparent PNG.
	 *
	 * @param array<string, mixed> $area Snapshot area (with items).
	 * @return array{ok:bool, width:int, height:int, error:string}
	 */
	private function render_area( array $area, int $dpi, string $path ): array {
		$width_cm  = max( 0.5, (float) ( $area['max_width_cm'] ?? 0 ) );
		$height_cm = max( 0.5, (float) ( $area['max_height_cm'] ?? 0 ) );

		[ $px_w, $px_h ] = self::pixel_size( $width_cm, $height_cm, $dpi );
		$px_per_cm = $px_w / $width_cm;

		$canvas = imagecreatetruecolor( $px_w, $px_h );
		if ( ! $canvas instanceof \GdImage ) {
			return array( 'ok' => false, 'width' => 0, 'height' => 0, 'error' => __( 'Could not allocate the print canvas.', 'tshirt-designer' ) );
		}
		imagealphablending( $canvas, false );
		imagesavealpha( $canvas, true );
		$transparent = imagecolorallocatealpha( $canvas, 0, 0, 0, 127 );
		imagefilledrectangle( $canvas, 0, 0, $px_w, $px_h, $transparent );
		imagealphablending( $canvas, true );

		$items = $area['items'];
		usort(
			$items,
			static fn( array $a, array $b ): int => (int) ( $a['layer'] ?? 0 ) <=> (int) ( $b['layer'] ?? 0 )
		);

		foreach ( $items as $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}
			$this->draw_item( $canvas, $item, $px_per_cm, $px_w, $px_h );
		}

		$ok = imagepng( $canvas, $path, 6 );
		imagedestroy( $canvas );

		if ( ! $ok ) {
			return array( 'ok' => false, 'width' => 0, 'height' => 0, 'error' => __( 'Could not write the production file.', 'tshirt-designer' ) );
		}

		return array( 'ok' => true, 'width' => $px_w, 'height' => $px_h, 'error' => '' );
	}

	/**
	 * Composite a single design item onto the print canvas.
	 *
	 * @param array<string, mixed> $item Snapshot item.
	 */
	private function draw_item( \GdImage $canvas, array $item, float $px_per_cm, int $px_w, int $px_h ): void {
		$w_px = max( 1, (int) round( (float) ( $item['w'] ?? 0 ) * $px_per_cm ) );
		$h_px = max( 1, (int) round( (float) ( $item['h'] ?? 0 ) * $px_per_cm ) );

		$type = (string) ( $item['type'] ?? '' );

		if ( 'text' === $type ) {
			$text = isset( $item['text'] ) && is_array( $item['text'] ) ? $item['text'] : array();
			$src  = Text_Engine::render( $text, $w_px, $h_px );
		} else {
			$src = $this->load_item_image( $item, $w_px, $h_px );
		}

		if ( ! $src instanceof \GdImage ) {
			return;
		}

		$rotation = (float) ( $item['rotation'] ?? 0 );
		if ( abs( $rotation ) > 0.01 && function_exists( 'imagerotate' ) ) {
			$bg = imagecolorallocatealpha( $src, 0, 0, 0, 127 );
			// GD rotates counter-clockwise; the designer's angle is clockwise.
			$rotated = imagerotate( $src, -$rotation, $bg );
			if ( $rotated instanceof \GdImage ) {
				imagealphablending( $rotated, false );
				imagesavealpha( $rotated, true );
				imagedestroy( $src );
				$src  = $rotated;
				$w_px = imagesx( $src );
				$h_px = imagesy( $src );
			}
		}

		// x/y are the item CENTER in cm from the area's top-left corner.
		$cx = (float) ( $item['x'] ?? 0 ) * $px_per_cm;
		$cy = (float) ( $item['y'] ?? 0 ) * $px_per_cm;
		$dst_x = (int) round( $cx - $w_px / 2 );
		$dst_y = (int) round( $cy - $h_px / 2 );

		$opacity = isset( $item['opacity'] ) ? (float) $item['opacity'] : 1.0;
		$opacity = min( 1.0, max( 0.0, $opacity ) );

		if ( $opacity >= 0.999 ) {
			imagecopy( $canvas, $src, $dst_x, $dst_y, 0, 0, $w_px, $h_px );
		} else {
			// imagecopymerge breaks alpha; scale the per-pixel alpha instead.
			$this->copy_with_opacity( $canvas, $src, $dst_x, $dst_y, $w_px, $h_px, $opacity );
		}

		imagedestroy( $src );
	}

	/**
	 * Alpha-correct copy honoring a global opacity factor.
	 */
	private function copy_with_opacity(
		\GdImage $dst,
		\GdImage $src,
		int $dst_x,
		int $dst_y,
		int $w,
		int $h,
		float $opacity
	): void {
		$tmp = imagecreatetruecolor( $w, $h );
		if ( ! $tmp instanceof \GdImage ) {
			return;
		}
		imagealphablending( $tmp, false );
		imagesavealpha( $tmp, true );
		imagecopy( $tmp, $src, 0, 0, 0, 0, $w, $h );

		for ( $y = 0; $y < $h; $y++ ) {
			for ( $x = 0; $x < $w; $x++ ) {
				$rgba  = imagecolorat( $tmp, $x, $y );
				$alpha = ( $rgba >> 24 ) & 0x7F;
				// 0 = opaque, 127 = transparent.
				$new_alpha = (int) round( 127 - ( 127 - $alpha ) * $opacity );
				$color     = imagecolorallocatealpha(
					$tmp,
					( $rgba >> 16 ) & 0xFF,
					( $rgba >> 8 ) & 0xFF,
					$rgba & 0xFF,
					min( 127, max( 0, $new_alpha ) )
				);
				imagesetpixel( $tmp, $x, $y, $color );
			}
		}

		imagecopy( $dst, $tmp, $dst_x, $dst_y, 0, 0, $w, $h );
		imagedestroy( $tmp );
	}

	/**
	 * Load and scale an image item from its snapshot (path first, URL never).
	 *
	 * @param array<string, mixed> $item Snapshot item.
	 */
	private function load_item_image( array $item, int $w_px, int $h_px ): ?\GdImage {
		$path = (string) ( $item['file_path'] ?? '' );
		if ( '' === $path || ! is_readable( $path ) ) {
			return null;
		}

		$info = @getimagesize( $path ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		if ( false === $info ) {
			return null;
		}

		$src = match ( (string) $info['mime'] ) {
			'image/png'  => @imagecreatefrompng( $path ),   // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
			'image/jpeg' => @imagecreatefromjpeg( $path ),  // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
			'image/webp' => function_exists( 'imagecreatefromwebp' )
				? @imagecreatefromwebp( $path )              // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
				: false,
			default      => false,
		};
		if ( ! $src instanceof \GdImage ) {
			return null;
		}

		$out = imagecreatetruecolor( $w_px, $h_px );
		if ( ! $out instanceof \GdImage ) {
			imagedestroy( $src );
			return null;
		}
		imagealphablending( $out, false );
		imagesavealpha( $out, true );
		$transparent = imagecolorallocatealpha( $out, 0, 0, 0, 127 );
		imagefilledrectangle( $out, 0, 0, $w_px, $h_px, $transparent );

		imagecopyresampled(
			$out,
			$src,
			0,
			0,
			0,
			0,
			$w_px,
			$h_px,
			imagesx( $src ),
			imagesy( $src )
		);
		imagedestroy( $src );

		return $out;
	}

	// ------------------------------------------------------------- storage

	/**
	 * Insert/update the production file row.
	 *
	 * @return array<string, mixed>
	 */
	private function record(
		int $order_id,
		int $item_id,
		int $design_id,
		int $version,
		int $area_id,
		string $area_type,
		string $file_name,
		string $file_path,
		int $width,
		int $height,
		int $dpi,
		string $status,
		string $message
	): array {
		global $wpdb;
		$table = $this->db->table( 'production_files' );
		$now   = current_time( 'mysql' );

		$data = array(
			'order_id'       => $order_id,
			'order_item_id'  => $item_id,
			'design_id'      => $design_id,
			'design_version' => $version,
			'print_area_id'  => $area_id,
			'area_type'      => $area_type,
			'file_name'      => $file_name,
			'file_path'      => $file_path,
			'width_px'       => $width,
			'height_px'      => $height,
			'dpi'            => $dpi,
			'status'         => $status,
			'message'        => $message,
			'updated_at'     => $now,
		);

		$existing = $this->find_file( $order_id, $item_id, $area_id );
		if ( null !== $existing ) {
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->update( $table, $data, array( 'id' => (int) $existing['id'] ) );
			$data['id'] = (int) $existing['id'];
		} else {
			$data['created_at'] = $now;
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert( $table, $data );
			$data['id'] = (int) $wpdb->insert_id;
		}

		return $data;
	}

	/**
	 * @return array<string, mixed>|null
	 */
	public function find_file( int $order_id, int $item_id, int $area_id ): ?array {
		global $wpdb;
		$table = $this->db->table( 'production_files' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare(
				"SELECT * FROM {$table} WHERE order_id = %d AND order_item_id = %d AND print_area_id = %d",
				$order_id,
				$item_id,
				$area_id
			),
			ARRAY_A
		);
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	/**
	 * @return array<string, mixed>|null
	 */
	public function get_file( int $id ): ?array {
		global $wpdb;
		$table = $this->db->table( 'production_files' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $id ), ARRAY_A );
		return is_array( $row ) ? $this->cast( $row ) : null;
	}

	/**
	 * All production files of an order (optionally one item).
	 *
	 * @return list<array<string, mixed>>
	 */
	public function for_order( int $order_id, int $item_id = 0 ): array {
		global $wpdb;
		$table = $this->db->table( 'production_files' );
		if ( $item_id > 0 ) {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$rows = $wpdb->get_results(
				$wpdb->prepare(
					"SELECT * FROM {$table} WHERE order_id = %d AND order_item_id = %d ORDER BY id ASC",
					$order_id,
					$item_id
				),
				ARRAY_A
			);
		} else {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$rows = $wpdb->get_results(
				$wpdb->prepare( "SELECT * FROM {$table} WHERE order_id = %d ORDER BY id ASC", $order_id ),
				ARRAY_A
			);
		}
		return array_map( array( $this, 'cast' ), is_array( $rows ) ? $rows : array() );
	}

	/**
	 * Bundle every production file of an order (optionally a single item) into
	 * a ZIP archive for the admin "Download All" action.
	 *
	 * The archive is written into the protected production directory and is
	 * rebuilt on every call so it always matches the current files.
	 *
	 * @param int $order_id Order id.
	 * @param int $item_id  Optional order item id to limit the archive to.
	 * @return array{path:string, name:string, count:int}|null Null when there
	 *         is nothing to zip or the ZIP extension is unavailable.
	 */
	public function build_zip( int $order_id, int $item_id = 0 ): ?array {
		if ( ! class_exists( '\ZipArchive' ) ) {
			Plugin::instance()->logger->error(
				Logger::CHANNEL_PRODUCTION,
				'Cannot build ZIP: the PHP zip extension is not installed',
				array( 'order_id' => $order_id )
			);
			return null;
		}

		$files = $this->for_order( $order_id, $item_id );
		if ( array() === $files ) {
			return null;
		}

		$storage = $this->storage_dir();
		if ( null === $storage ) {
			return null;
		}

		$name = $item_id > 0
			? sprintf( 'ORDER-%d-ITEM-%d-PRINT-FILES.zip', $order_id, $item_id )
			: sprintf( 'ORDER-%d-PRINT-FILES.zip', $order_id );
		$path = trailingslashit( $storage['dir'] ) . $name;

		if ( file_exists( $path ) ) {
			wp_delete_file( $path );
		}

		$zip = new \ZipArchive();
		if ( true !== $zip->open( $path, \ZipArchive::CREATE | \ZipArchive::OVERWRITE ) ) {
			Plugin::instance()->logger->error(
				Logger::CHANNEL_PRODUCTION,
				'Could not create the production ZIP',
				array( 'order_id' => $order_id )
			);
			return null;
		}

		$added = 0;
		$used  = array();
		foreach ( $files as $file ) {
			$file_path = (string) $file['file_path'];
			if ( '' === $file_path || ! is_readable( $file_path ) ) {
				continue;
			}
			$entry = (string) $file['file_name'];
			if ( '' === $entry ) {
				$entry = basename( $file_path );
			}
			// Never let two areas collide inside the archive.
			if ( isset( $used[ $entry ] ) ) {
				$entry = sprintf(
					'%s-%d.%s',
					pathinfo( $entry, PATHINFO_FILENAME ),
					(int) $file['id'],
					pathinfo( $entry, PATHINFO_EXTENSION )
				);
			}
			$used[ $entry ] = true;
			if ( $zip->addFile( $file_path, $entry ) ) {
				++$added;
			}
		}
		$zip->close();

		if ( 0 === $added ) {
			if ( file_exists( $path ) ) {
				wp_delete_file( $path );
			}
			return null;
		}

		return array( 'path' => $path, 'name' => $name, 'count' => $added );
	}

	/**
	 * @param array<string, mixed> $row Raw row.
	 * @return array<string, mixed>
	 */
	public function cast( array $row ): array {
		return array(
			'id'             => (int) $row['id'],
			'order_id'       => (int) $row['order_id'],
			'order_item_id'  => (int) $row['order_item_id'],
			'design_id'      => (int) $row['design_id'],
			'design_version' => (int) $row['design_version'],
			'print_area_id'  => (int) $row['print_area_id'],
			'area_type'      => (string) $row['area_type'],
			'file_name'      => (string) $row['file_name'],
			'file_path'      => (string) $row['file_path'],
			'width_px'       => (int) $row['width_px'],
			'height_px'      => (int) $row['height_px'],
			'dpi'            => (int) $row['dpi'],
			'status'         => (string) $row['status'],
			'message'        => (string) ( $row['message'] ?? '' ),
			'created_at'     => (string) $row['created_at'],
			'updated_at'     => (string) $row['updated_at'],
		);
	}
}
