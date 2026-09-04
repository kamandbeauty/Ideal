<?php
/**
 * Media manager — secure user uploads.
 *
 * Every upload is validated by extension, MIME type, real image signature
 * and size, then re-encoded through GD whenever the format is supported.
 * Files are stored with randomized names inside a dedicated uploads folder
 * that disallows script execution. SVG is intentionally not allowed.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Media_Manager {

	public const ALLOWED_MIMES = array(
		'jpg'  => 'image/jpeg',
		'jpeg' => 'image/jpeg',
		'png'  => 'image/png',
		'webp' => 'image/webp',
	);

	public function __construct( private Settings $settings ) {}

	/**
	 * Validate a $_FILES entry. Returns error message string or '' when valid.
	 *
	 * @param array<string, mixed>|null $file  $_FILES entry.
	 * @param string|null               $error Filled with an error message.
	 * @return array{tmp_name:string,name:string,mime:string,width:int,height:int}|null
	 */
	public function validate_upload( ?array $file, ?string &$error = null ): ?array {
		$error = '';

		if ( ! is_array( $file ) ) {
			$error = __( 'No file was uploaded.', 'tshirt-designer' );
			return null;
		}
		// PHP fills `size` as an integer and `error` as an integer; only the
		// three path/name fields are strings.
		foreach ( array( 'name', 'type', 'tmp_name' ) as $key ) {
			if ( ! isset( $file[ $key ] ) || ! is_string( $file[ $key ] ) ) {
				$error = __( 'Invalid upload payload.', 'tshirt-designer' );
				return null;
			}
		}
		if ( ! isset( $file['size'] ) || ! is_numeric( $file['size'] ) ) {
			$error = __( 'Invalid upload payload.', 'tshirt-designer' );
			return null;
		}
		if ( isset( $file['error'] ) && UPLOAD_ERR_OK !== (int) $file['error'] ) {
			$error = __( 'The file could not be uploaded. Please try again.', 'tshirt-designer' );
			return null;
		}
		$size = (int) $file['size'];
		if ( ! is_uploaded_file( $file['tmp_name'] ) && ! $this->is_test_context( $file['tmp_name'] ) ) {
			$error = __( 'Invalid upload source.', 'tshirt-designer' );
			return null;
		}
		if ( $size <= 0 ) {
			$error = __( 'The uploaded file is empty.', 'tshirt-designer' );
			return null;
		}
		$max_bytes = (int) round( (float) $this->settings->get( 'upload_max_mb', 5 ) * 1024 * 1024 );
		if ( $size > $max_bytes ) {
			$error = sprintf(
				/* translators: %s: maximum size in MB. */
				__( 'The file is too large. Maximum allowed size is %s MB.', 'tshirt-designer' ),
				(string) $this->settings->get( 'upload_max_mb', 5 )
			);
			return null;
		}

		// 1) Extension + declared type check against a fixed whitelist.
		$check = wp_check_filetype_and_ext( $file['tmp_name'], $file['name'], self::ALLOWED_MIMES );
		$ext   = is_string( $check['ext'] ?? null ) ? $check['ext'] : '';
		$mime  = is_string( $check['type'] ?? null ) ? $check['type'] : '';
		if ( '' === $ext || '' === $mime ) {
			$error = __( 'Only JPG, JPEG, PNG and WEBP images are allowed.', 'tshirt-designer' );
			return null;
		}
		// WordPress sets `proper_filename` when the real content does not match
		// the supplied extension. Refuse rather than silently renaming.
		if ( ! empty( $check['proper_filename'] ) ) {
			$error = __( 'The file contents do not match its extension.', 'tshirt-designer' );
			return null;
		}

		// 2) Real image signature.
		$info = @getimagesize( $file['tmp_name'] ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		if ( false === $info || empty( $info[0] ) || empty( $info[1] ) ) {
			$error = __( 'The file is not a valid image.', 'tshirt-designer' );
			return null;
		}
		if ( (string) $info['mime'] !== $mime ) {
			$error = __( 'The file contents do not match its extension.', 'tshirt-designer' );
			return null;
		}

		// 3) finfo second opinion (when available).
		if ( function_exists( 'finfo_open' ) ) {
			$finfo = finfo_open( FILEINFO_MIME_TYPE );
			$real  = $finfo ? (string) finfo_file( $finfo, $file['tmp_name'] ) : '';
			if ( $finfo ) {
				finfo_close( $finfo );
			}
			if ( '' !== $real && $real !== $mime ) {
				$error = __( 'The file contents do not match its extension.', 'tshirt-designer' );
				return null;
			}
		}

		return array(
			'tmp_name' => (string) $file['tmp_name'],
			'name'     => (string) $file['name'],
			'mime'     => $mime,
			'width'    => (int) $info[0],
			'height'   => (int) $info[1],
		);
	}

	/**
	 * Handle a validated upload: re-encode, store and register.
	 *
	 * @param array<string, mixed> $valid Result of validate_upload().
	 * @param int                  $user_id Uploading user (0 for guests).
	 * @param string               $guest_token Guest token for guests.
	 * @return array<string, mixed>|null Upload row data or null on failure.
	 */
	public function store_upload( array $valid, int $user_id, string $guest_token ): ?array {
		global $wpdb;

		$upload = $this->move_file( $valid );
		if ( null === $upload ) {
			return null;
		}

		$attachment_id = $this->insert_attachment( $upload, $user_id );
		if ( 0 === $attachment_id ) {
			return null;
		}

		$now = current_time( 'mysql' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			Plugin::instance()->db->table( 'uploads' ),
			array(
				'user_id'       => $user_id,
				'guest_token'   => $guest_token,
				'attachment_id' => $attachment_id,
				'original_name' => mb_substr( sanitize_file_name( $valid['name'] ), 0, 191 ),
				'mime'          => $upload['mime'],
				'width'         => $upload['width'],
				'height'        => $upload['height'],
				'created_at'    => $now,
				'updated_at'    => $now,
			)
		);

		return array(
			'id'            => (int) $wpdb->insert_id,
			'attachment_id' => $attachment_id,
			'url'           => $upload['url'],
			'width'         => $upload['width'],
			'height'        => $upload['height'],
			'mime'          => $upload['mime'],
		);
	}

	/**
	 * Re-encode (when possible) and move the file into uploads/td-uploads/.
	 *
	 * @param array<string, mixed> $valid Validated file info.
	 * @return array<string, mixed>|null
	 */
	private function move_file( array $valid ): ?array {
		$uploads = wp_upload_dir();
		if ( ! empty( $uploads['error'] ) ) {
			return null;
		}

		$subdir = '/td-uploads/' . gmdate( 'Y/m' );
		$dir    = $uploads['basedir'] . $subdir;
		if ( ! wp_mkdir_p( $dir ) ) {
			return null;
		}

		// Protect the folder against script execution.
		$htaccess = $dir . '/.htaccess';
		if ( ! file_exists( $htaccess ) ) {
			// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
			file_put_contents(
				$htaccess,
				"Options -Indexes\nphp_flag engine off\n<FilesMatch \"\\.(php|php3|php4|php5|php7|phps|phtml|pl|py|cgi|sh)$\">\n  Require all denied\n</FilesMatch>\n"
			);
		}

		$filename = wp_generate_password( 24, false, false ) . '-' . wp_generate_password( 8, false, false ) . '.' . pathinfo( $valid['name'], PATHINFO_EXTENSION );
		$filename = sanitize_file_name( $filename );
		$dest     = $dir . '/' . $filename;
		$mime     = $valid['mime'];

		$reencoded = $this->reencode( $valid['tmp_name'], $mime, $dest );
		if ( null === $reencoded ) {
			if ( ! @move_uploaded_file( $valid['tmp_name'], $dest ) && ! @rename( $valid['tmp_name'], $dest ) && ! @copy( $valid['tmp_name'], $dest ) ) { // phpcs:ignore
				return null;
			}
		}

		$size = @getimagesize( $dest ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		if ( false === $size ) {
			wp_delete_file( $dest );
			return null;
		}

		return array(
			'path' => $dest,
			'url'  => $uploads['baseurl'] . $subdir . '/' . $filename,
			'mime' => $mime,
			'width'  => (int) $size[0],
			'height' => (int) $size[1],
		);
	}

	/**
	 * Re-encode an image through GD. Returns true when the file was written.
	 */
	private function reencode( string $src, string $mime, string $dest ): ?bool {
		if ( ! function_exists( 'imagecreatefromstring' ) ) {
			return null;
		}
		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
		$blob = file_get_contents( $src );
		if ( false === $blob ) {
			return null;
		}
		$img = @imagecreatefromstring( $blob ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		if ( false === $img ) {
			return null;
		}

		// Preserve PNG / WEBP transparency.
		if ( 'image/png' === $mime || 'image/webp' === $mime ) {
			imagealphablending( $img, false );
			imagesavealpha( $img, true );
		}

		$saved = false;
		switch ( $mime ) {
			case 'image/jpeg':
				$saved = imagejpeg( $img, $dest, 92 );
				break;
			case 'image/png':
				$saved = imagepng( $img, $dest, 6 );
				break;
			case 'image/webp':
				$saved = function_exists( 'imagewebp' ) ? imagewebp( $img, $dest, 92 ) : false;
				break;
		}
		imagedestroy( $img );

		if ( ! $saved ) {
			return null;
		}
		@chmod( $dest, 0644 ); // phpcs:ignore
		return true;
	}

	/**
	 * Register the stored file as a media attachment.
	 */
	private function insert_attachment( array $upload, int $user_id ): int {
		$attachment = array(
			'post_mime_type' => $upload['mime'],
			'post_title'     => sanitize_file_name( pathinfo( $upload['path'], PATHINFO_FILENAME ) ),
			'post_content'   => '',
			'post_status'    => 'inherit',
			'post_author'    => $user_id,
		);
		$attach_id = wp_insert_attachment( $attachment, $upload['path'], 0, true );
		if ( is_wp_error( $attach_id ) || 0 === (int) $attach_id ) {
			return 0;
		}
		require_once ABSPATH . 'wp-admin/includes/image.php';
		$meta = wp_generate_attachment_metadata( (int) $attach_id, $upload['path'] );
		if ( is_array( $meta ) ) {
			wp_update_attachment_metadata( (int) $attach_id, $meta );
		}
		return (int) $attach_id;
	}

	/**
	 * Look up an upload row by id, enforcing ownership.
	 *
	 * @return array<string, mixed>|null
	 */
	public function get_upload( int $id, int $user_id, string $guest_token ): ?array {
		global $wpdb;
		$table = Plugin::instance()->db->table( 'uploads' );
		// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
		$row = $wpdb->get_row(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $id ),
			ARRAY_A
		);
		if ( ! is_array( $row ) ) {
			return null;
		}
		$owner_user  = (int) $row['user_id'];
		$owner_guest = (string) $row['guest_token'];
		$is_owner    = ( 0 !== $owner_user && $owner_user === $user_id )
			|| ( 0 === $owner_user && '' !== $guest_token && $owner_guest === $guest_token );
		// Capability is evaluated for the identity being acted on, not for the
		// ambient session, so an admin session cannot leak another user's
		// upload into a customer-scoped call.
		if ( ! $is_owner && ! ( $user_id > 0 && user_can( $user_id, 'manage_options' ) ) ) {
			return null;
		}
		$row['id']            = (int) $row['id'];
		$row['attachment_id'] = (int) $row['attachment_id'];
		$row['url']           = (string) wp_get_attachment_url( (int) $row['attachment_id'] );
		$row['width']         = (int) $row['width'];
		$row['height']        = (int) $row['height'];
		return $row;
	}

	/**
	 * Simple per-identity hourly rate limit for uploads.
	 */
	public function check_rate_limit( int $user_id, string $ip ): bool {
		$limit = (int) $this->settings->get( 'uploads_per_hour', 20 );
		$key   = 'td_ul_' . md5( ( $user_id > 0 ? 'u' . $user_id : 'i' . $ip ) );
		$count = (int) get_transient( $key );
		if ( $count >= $limit ) {
			return false;
		}
		set_transient( $key, $count + 1, HOUR_IN_SECONDS );
		return true;
	}

	/**
	 * Whether we are in a test context (files staged outside PHP's tmp).
	 */
	private function is_test_context( string $tmp_name ): bool {
		return defined( 'TD_TESTING' ) && TD_TESTING && file_exists( $tmp_name );
	}
}
