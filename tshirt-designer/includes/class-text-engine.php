<?php
/**
 * Text engine — structured typography for design items.
 *
 * Text items are stored as data (content + font + color + style), never as a
 * rasterized "fake image". The browser renders them with Canvas 2D for the
 * live preview and the server re-renders them at print DPI for production
 * files, so the same item stays editable forever.
 *
 * Persian/Arabic (RTL) and Latin (LTR) are both supported; the bundled fonts
 * are picked so a Persian string always has a real glyph source.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Text_Engine {

	/**
	 * Available fonts, keyed by slug.
	 *
	 * `stack` is the CSS font-family used in the browser compositor.
	 * `file`  is a bundled TTF used by the server-side production renderer
	 *          (relative to the plugin dir; empty = fall back to GD's built-in).
	 *
	 * @return array<string, array<string, mixed>>
	 */
	public static function fonts(): array {
		$fonts = array(
			'vazir'   => array(
				'label'    => function_exists( '__' ) ? __( 'Vazirmatn (Persian)', 'tshirt-designer' ) : 'Vazirmatn (Persian)',
				'stack'    => "'Vazirmatn', 'Tahoma', 'Iranian Sans', sans-serif",
				'file'     => 'assets/fonts/Vazirmatn-Regular.ttf',
				'bold'     => 'assets/fonts/Vazirmatn-Bold.ttf',
				'supports' => array( 'rtl', 'ltr' ),
			),
			'sans'    => array(
				'label'    => function_exists( '__' ) ? __( 'Sans (Latin)', 'tshirt-designer' ) : 'Sans (Latin)',
				'stack'    => "'Helvetica Neue', Arial, sans-serif",
				'file'     => 'assets/fonts/DejaVuSans.ttf',
				'bold'     => 'assets/fonts/DejaVuSans-Bold.ttf',
				'supports' => array( 'ltr' ),
			),
			'serif'   => array(
				'label'    => function_exists( '__' ) ? __( 'Serif', 'tshirt-designer' ) : 'Serif',
				'stack'    => "Georgia, 'Times New Roman', serif",
				'file'     => 'assets/fonts/DejaVuSerif.ttf',
				'bold'     => 'assets/fonts/DejaVuSerif-Bold.ttf',
				'supports' => array( 'ltr' ),
			),
			'display' => array(
				'label'    => function_exists( '__' ) ? __( 'Display', 'tshirt-designer' ) : 'Display',
				'stack'    => "Impact, 'Arial Black', sans-serif",
				'file'     => 'assets/fonts/DejaVuSans-Bold.ttf',
				'bold'     => 'assets/fonts/DejaVuSans-Bold.ttf',
				'supports' => array( 'ltr' ),
			),
		);

		if ( function_exists( 'apply_filters' ) ) {
			/**
			 * Filter the fonts offered by the text engine.
			 *
			 * @param array<string, array<string, mixed>> $fonts Font definitions.
			 */
			$filtered = apply_filters( 'cpd_text_fonts', $fonts );
			if ( is_array( $filtered ) && array() !== $filtered ) {
				$fonts = $filtered;
			}
		}

		return $fonts;
	}

	/**
	 * Font definition (falls back to the first registered font).
	 *
	 * @return array<string, mixed>
	 */
	public static function font( string $slug ): array {
		$fonts = self::fonts();
		if ( isset( $fonts[ $slug ] ) ) {
			return $fonts[ $slug ];
		}
		return reset( $fonts );
	}

	/**
	 * Shapes handed to the frontend (no server paths leak out).
	 *
	 * @return list<array<string, mixed>>
	 */
	public static function public_fonts(): array {
		$out = array();
		foreach ( self::fonts() as $slug => $font ) {
			$out[] = array(
				'slug'  => $slug,
				'label' => (string) $font['label'],
				'stack' => (string) $font['stack'],
			);
		}
		return $out;
	}

	/**
	 * Absolute path of the TTF to use for a text item (or '' when missing).
	 */
	public static function font_path( string $slug, bool $bold = false ): string {
		$font = self::font( $slug );
		$rel  = $bold && ! empty( $font['bold'] ) ? (string) $font['bold'] : (string) ( $font['file'] ?? '' );
		if ( '' === $rel ) {
			return '';
		}
		$path = TD_PLUGIN_DIR . ltrim( $rel, '/' );
		return is_readable( $path ) ? $path : '';
	}

	/**
	 * Detect writing direction from the content (Arabic/Hebrew ranges => RTL).
	 */
	public static function detect_direction( string $text ): string {
		return preg_match( '/[\x{0590}-\x{05FF}\x{0600}-\x{06FF}\x{0750}-\x{077F}\x{FB50}-\x{FDFF}\x{FE70}-\x{FEFF}]/u', $text )
			? 'rtl'
			: 'ltr';
	}

	/**
	 * Render a text item into a transparent GD image at print resolution.
	 *
	 * @param array<string, mixed> $text    Validated text payload.
	 * @param int                  $width   Target width in pixels.
	 * @param int                  $height  Target height in pixels.
	 * @return \GdImage|null Null when GD/FreeType is unavailable.
	 */
	public static function render( array $text, int $width, int $height ): ?\GdImage {
		if ( ! function_exists( 'imagecreatetruecolor' ) || $width < 1 || $height < 1 ) {
			return null;
		}

		$img = imagecreatetruecolor( $width, $height );
		if ( ! $img instanceof \GdImage ) {
			return null;
		}
		imagealphablending( $img, false );
		imagesavealpha( $img, true );
		$transparent = imagecolorallocatealpha( $img, 0, 0, 0, 127 );
		imagefilledrectangle( $img, 0, 0, $width, $height, $transparent );
		imagealphablending( $img, true );

		$content = (string) $text['content'];
		$rgb     = self::hex_to_rgb( (string) ( $text['color'] ?? '#111111' ) );
		$color   = imagecolorallocate( $img, $rgb[0], $rgb[1], $rgb[2] );

		$lines = explode( "\n", $content );
		$count = max( 1, count( $lines ) );
		$path  = self::font_path( (string) ( $text['font'] ?? '' ), ! empty( $text['bold'] ) );

		if ( '' !== $path && function_exists( 'imagettftext' ) ) {
			// Binary-search the point size that fills the box.
			$size = self::fit_font_size( $path, $lines, $width, $height );
			$line_height = $height / $count;

			foreach ( $lines as $i => $line ) {
				if ( '' === trim( $line ) ) {
					continue;
				}
				$box = imagettfbbox( $size, 0, $path, $line );
				if ( ! is_array( $box ) ) {
					continue;
				}
				$text_w = abs( $box[2] - $box[0] );
				$text_h = abs( $box[7] - $box[1] );

				$x = match ( (string) ( $text['align'] ?? 'center' ) ) {
					'left'  => 0,
					'right' => (int) ( $width - $text_w ),
					default => (int) ( ( $width - $text_w ) / 2 ),
				};
				$y = (int) ( $line_height * $i + ( $line_height + $text_h ) / 2 );

				imagettftext( $img, $size, 0, $x, $y, $color, $path, $line );
			}
		} else {
			// No FreeType font available — fall back to GD's bitmap font so
			// production files still carry the text rather than failing.
			$font_id = 5;
			$char_w  = imagefontwidth( $font_id );
			$char_h  = imagefontheight( $font_id );
			$line_height = $height / $count;
			foreach ( $lines as $i => $line ) {
				$text_w = $char_w * mb_strlen( $line );
				$x = match ( (string) ( $text['align'] ?? 'center' ) ) {
					'left'  => 0,
					'right' => (int) ( $width - $text_w ),
					default => (int) ( ( $width - $text_w ) / 2 ),
				};
				$y = (int) ( $line_height * $i + ( $line_height - $char_h ) / 2 );
				imagestring( $img, $font_id, $x, $y, $line, $color );
			}
		}

		return $img;
	}

	/**
	 * Largest point size where every line fits the box.
	 *
	 * @param list<string> $lines Text lines.
	 */
	private static function fit_font_size( string $path, array $lines, int $width, int $height ): float {
		$count = max( 1, count( $lines ) );
		$lo    = 4.0;
		$hi    = max( 6.0, $height / $count );

		for ( $i = 0; $i < 24; $i++ ) {
			$mid = ( $lo + $hi ) / 2;
			$fits = true;
			foreach ( $lines as $line ) {
				if ( '' === $line ) {
					continue;
				}
				$box = imagettfbbox( $mid, 0, $path, $line );
				if ( ! is_array( $box ) ) {
					$fits = false;
					break;
				}
				if ( abs( $box[2] - $box[0] ) > $width * 0.98 ||
					abs( $box[7] - $box[1] ) > ( $height / $count ) * 0.82 ) {
					$fits = false;
					break;
				}
			}
			if ( $fits ) {
				$lo = $mid;
			} else {
				$hi = $mid;
			}
		}
		return $lo;
	}

	/**
	 * #RRGGBB (or #RGB) to [r, g, b].
	 *
	 * @return array{0:int,1:int,2:int}
	 */
	public static function hex_to_rgb( string $hex ): array {
		$hex = ltrim( trim( $hex ), '#' );
		if ( 3 === strlen( $hex ) ) {
			$hex = $hex[0] . $hex[0] . $hex[1] . $hex[1] . $hex[2] . $hex[2];
		}
		if ( 6 !== strlen( $hex ) || ! ctype_xdigit( $hex ) ) {
			return array( 17, 17, 17 );
		}
		return array(
			(int) hexdec( substr( $hex, 0, 2 ) ),
			(int) hexdec( substr( $hex, 2, 2 ) ),
			(int) hexdec( substr( $hex, 4, 2 ) ),
		);
	}
}
