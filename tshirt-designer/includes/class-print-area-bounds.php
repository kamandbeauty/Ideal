<?php
/**
 * Print-area bounds math — pure and mirrored in the frontend editor.
 *
 * All functions operate on the item format produced by Design_Manager:
 * x/y = center (cm, origin = print area top-left), w/h = unrotated size,
 * rotation = clockwise degrees.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Print_Area_Bounds {

	/**
	 * Axis-aligned bounding box of a rotated item.
	 *
	 * @return array{w:float, h:float}
	 */
	public static function rotated_aabb( float $w, float $h, float $rotation ): array {
		$a  = deg2rad( $rotation );
		$c  = abs( cos( $a ) );
		$s  = abs( sin( $a ) );
		return array(
			'w' => $w * $c + $h * $s,
			'h' => $w * $s + $h * $c,
		);
	}

	/**
	 * Clamp an item so it fits and stays inside a print area.
	 *
	 * The rotated bounding box must fit inside the area; the item is scaled
	 * down when too large and translated back inside when out of bounds.
	 *
	 * @param array<string, mixed> $item  Validated item (x, y, w, h, rotation).
	 * @param float                $max_w Area width (cm).
	 * @param float                $max_h Area height (cm).
	 * @return array<string, mixed> Clamped item (or null-equivalent oversized marker).
	 */
	public static function clamp_item( array $item, float $max_w, float $max_h ): array {
		$w = (float) $item['w'];
		$h = (float) $item['h'];
		$r = (float) ( $item['rotation'] ?? 0 );

		// Scale down (uniformly) until the rotated AABB fits the area.
		$aabb = self::rotated_aabb( $w, $h, $r );
		if ( $aabb['w'] > $max_w + 1e-9 || $aabb['h'] > $max_h + 1e-9 ) {
			$scale = min( $max_w / $aabb['w'], $max_h / $aabb['h'] );
			$w    *= $scale;
			$h    *= $scale;
			$aabb  = self::rotated_aabb( $w, $h, $r );
		}

		// Keep the AABB inside the area by translating the center.
		$half_w = $aabb['w'] / 2;
		$half_h = $aabb['h'] / 2;
		$x      = min( max( (float) $item['x'], $half_w ), max( 0.0, $max_w - $half_w ) );
		$y      = min( max( (float) $item['y'], $half_h ), max( 0.0, $max_h - $half_h ) );

		$item['x'] = round( $x, 2 );
		$item['y'] = round( $y, 2 );
		$item['w'] = round( $w, 2 );
		$item['h'] = round( $h, 2 );
		return $item;
	}

	/**
	 * Whether an item fits (after clamping it was not oversized).
	 */
	public static function fits( array $item, float $max_w, float $max_h ): bool {
		$aabb = self::rotated_aabb( (float) $item['w'], (float) $item['h'], (float) ( $item['rotation'] ?? 0 ) );
		return $aabb['w'] <= $max_w + 1e-6 && $aabb['h'] <= $max_h + 1e-6;
	}
}
