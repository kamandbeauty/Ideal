<?php
/**
 * Pure unit tests for the parts of the plugin that do not need WordPress:
 * Print_Area_Bounds and Pricing_Engine.
 *
 * Run: node /home/user/scratch/php.mjs -s tshirt-designer/tests/unit-bounds-pricing.php
 *
 * @package TShirtDesigner
 */

/*
 * Test-only entry point. These files live inside the plugin folder and are
 * therefore reachable over HTTP on a normal install; bootstrap-wp.php also
 * defines TD_TESTING, which relaxes upload validation. Refuse to run for
 * anything that is not a local CLI invocation.
 */
if ( PHP_SAPI !== 'cli' && PHP_SAPI !== 'cli-server' && PHP_SAPI !== 'phpdbg' && PHP_SAPI !== 'embed' && PHP_SAPI !== 'wasm' ) {
	http_response_code( 403 );
	exit( 'Forbidden.' );
}
if ( isset( $_SERVER['REMOTE_ADDR'] ) || isset( $_SERVER['HTTP_USER_AGENT'] ) ) {
	http_response_code( 403 );
	exit( 'Forbidden.' );
}

// --- Minimal environment stubs (the classes under test are WP-free). ------
define( 'ABSPATH', '/tmp/' );

$tests = 0;
$failed = 0;

function check( string $name, bool $ok ): void {
	global $tests, $failed;
	$tests++;
	if ( ! $ok ) {
		$failed++;
		echo "FAIL: {$name}\n";
	}
}

function approx( float $a, float $b, float $eps = 0.011 ): bool {
	return abs( $a - $b ) <= $eps;
}

require __DIR__ . '/../includes/class-print-area-bounds.php';
require __DIR__ . '/../includes/class-pricing-engine.php';

use TShirtDesigner\Print_Area_Bounds;
use TShirtDesigner\Pricing_Engine;

// ---------------------------------------------------------------- bounds

// Unrotated AABB is the item itself.
$aabb = Print_Area_Bounds::rotated_aabb( 10.0, 20.0, 0.0 );
check( 'aabb 0deg w', approx( $aabb['w'], 10.0 ) );
check( 'aabb 0deg h', approx( $aabb['h'], 20.0 ) );

// 90deg swaps sides.
$aabb = Print_Area_Bounds::rotated_aabb( 10.0, 20.0, 90.0 );
check( 'aabb 90deg w', approx( $aabb['w'], 20.0 ) );
check( 'aabb 90deg h', approx( $aabb['h'], 10.0 ) );

// 45deg: 10*0.7071 + 20*0.7071 = 21.21.
$aabb = Print_Area_Bounds::rotated_aabb( 10.0, 20.0, 45.0 );
check( 'aabb 45deg w', approx( $aabb['w'], 21.213 ) );
check( 'aabb 45deg h', approx( $aabb['h'], 21.213 ) );

// Item fully inside stays untouched.
$item = Print_Area_Bounds::clamp_item(
	array( 'x' => 15.0, 'y' => 17.5, 'w' => 10.0, 'h' => 10.0, 'rotation' => 0.0 ),
	30.0, 35.0
);
check( 'clamp inside keeps x', approx( $item['x'], 15.0 ) );
check( 'clamp inside keeps y', approx( $item['y'], 17.5 ) );
check( 'clamp inside keeps w', approx( $item['w'], 10.0 ) );

// Item dragged out to the left is pulled back in.
$item = Print_Area_Bounds::clamp_item(
	array( 'x' => -50.0, 'y' => 5.0, 'w' => 10.0, 'h' => 10.0, 'rotation' => 0.0 ),
	30.0, 35.0
);
check( 'clamp left edge', approx( $item['x'], 5.0 ) );

// Item dragged beyond the right edge.
$item = Print_Area_Bounds::clamp_item(
	array( 'x' => 99.0, 'y' => 5.0, 'w' => 10.0, 'h' => 10.0, 'rotation' => 0.0 ),
	30.0, 35.0
);
check( 'clamp right edge', approx( $item['x'], 25.0 ) );

// Oversized item is scaled down.
$item = Print_Area_Bounds::clamp_item(
	array( 'x' => 15.0, 'y' => 17.0, 'w' => 40.0, 'h' => 40.0, 'rotation' => 0.0 ),
	30.0, 35.0
);
check( 'oversize scaled w', approx( $item['w'], 30.0 ) );
check( 'oversize scaled h', approx( $item['h'], 30.0 ) );
check( 'oversize fits', Print_Area_Bounds::fits( $item, 30.0, 35.0 ) );

// Rotated oversized item: rotated AABB must fit.
$item = Print_Area_Bounds::clamp_item(
	array( 'x' => 15.0, 'y' => 17.0, 'w' => 25.0, 'h' => 25.0, 'rotation' => 45.0 ),
	30.0, 35.0
);
$aabb = Print_Area_Bounds::rotated_aabb( (float) $item['w'], (float) $item['h'], 45.0 );
check( 'rotated oversize aabb w <= max', $aabb['w'] <= 30.0 + 0.001 );
check( 'rotated oversize aabb h <= max', $aabb['h'] <= 35.0 + 0.001 );

// fits() rejects the impossible.
check( 'fits rejects oversized', ! Print_Area_Bounds::fits(
	array( 'w' => 50.0, 'h' => 10.0, 'rotation' => 0.0 ), 30.0, 35.0
) );
check( 'fits accepts normal', Print_Area_Bounds::fits(
	array( 'w' => 29.9, 'h' => 34.9, 'rotation' => 0.0 ), 30.0, 35.0
) );

// ---------------------------------------------------------------- pricing

$engine = new Pricing_Engine();

$areas = array(
	1 => array( 'id' => 1, 'name' => 'Front', 'max_width_cm' => 30.0, 'max_height_cm' => 35.0 ),
	2 => array( 'id' => 2, 'name' => 'Back', 'max_width_cm' => 30.0, 'max_height_cm' => 35.0 ),
);

$rules = array(
	'size_tier'  => array(
		array( 'scope' => 'global', 'print_area_id' => 0, 'size_from_cm' => 0.0, 'size_to_cm' => 10.0, 'price' => 50000.0, 'item_count' => 0, 'sort_order' => 0 ),
		array( 'scope' => 'global', 'print_area_id' => 0, 'size_from_cm' => 10.01, 'size_to_cm' => 20.0, 'price' => 80000.0, 'item_count' => 0, 'sort_order' => 1 ),
		array( 'scope' => 'global', 'print_area_id' => 0, 'size_from_cm' => 20.01, 'size_to_cm' => 30.0, 'price' => 120000.0, 'item_count' => 0, 'sort_order' => 2 ),
		// Area-scoped override for the front area only.
		array( 'scope' => 'area', 'print_area_id' => 1, 'size_from_cm' => 0.0, 'size_to_cm' => 15.0, 'price' => 65000.0, 'item_count' => 0, 'sort_order' => 0 ),
	),
	'item_extra' => array(
		array( 'scope' => 'global', 'print_area_id' => 0, 'item_count' => 2, 'price' => 20000.0, 'size_from_cm' => 0.0, 'size_to_cm' => 0.0, 'sort_order' => 0 ),
		array( 'scope' => 'global', 'print_area_id' => 0, 'item_count' => 3, 'price' => 40000.0, 'size_from_cm' => 0.0, 'size_to_cm' => 0.0, 'sort_order' => 1 ),
	),
);

// 1. Single small item on the front (area rule wins over global).
$b = $engine->compute( 350000.0, 0.0, $areas, array( 1 => array( array( 'w' => 8.0, 'h' => 8.0 ) ) ), $rules );
check( 'single item tier price (area rule)', approx( $b['areas'][1]['items'][0]['base'], 65000.0 ) );
check( 'single item no extra', approx( $b['areas'][1]['items'][0]['extra'], 0.0 ) );
check( 'single item total', approx( $b['total'], 350000.0 + 65000.0 ) );

// 2. Same item on the back (no area rule there -> global tier).
$b = $engine->compute( 350000.0, 0.0, $areas, array( 2 => array( array( 'w' => 8.0, 'h' => 8.0 ) ) ), $rules );
check( 'back uses global tier', approx( $b['areas'][2]['items'][0]['base'], 50000.0 ) );

// 3. Tier boundary: exactly 10cm is the 0-10 tier (inclusive).
$b = $engine->compute( 0.0, 0.0, $areas, array( 2 => array( array( 'w' => 10.0, 'h' => 4.0 ) ) ), $rules );
check( 'tier boundary 10 inclusive', approx( $b['areas'][2]['items'][0]['base'], 50000.0 ) );

// 4. 15cm on front hits the area rule (0-15) even though a global 10-20 exists.
$b = $engine->compute( 0.0, 0.0, $areas, array( 1 => array( array( 'w' => 12.0, 'h' => 15.0 ) ) ), $rules );
check( 'area rule beats global', approx( $b['areas'][1]['items'][0]['base'], 65000.0 ) );

// 5. Longest side counts: 6x21cm -> 21cm -> third global tier.
$b = $engine->compute( 0.0, 0.0, $areas, array( 2 => array( array( 'w' => 6.0, 'h' => 21.0 ) ) ), $rules );
check( 'longest side tier', approx( $b['areas'][2]['items'][0]['base'], 120000.0 ) );

// 6. Multiple items: 2nd +20000, 3rd +40000 (exact count match).
$b = $engine->compute( 0.0, 0.0, $areas, array(
	2 => array(
		array( 'w' => 8.0, 'h' => 8.0 ),
		array( 'w' => 12.0, 'h' => 12.0 ),
		array( 'w' => 6.0, 'h' => 6.0 ),
	),
), $rules );
check( 'item1 no extra', approx( $b['areas'][2]['items'][0]['extra'], 0.0 ) );
check( 'item2 extra 20000', approx( $b['areas'][2]['items'][1]['extra'], 20000.0 ) );
check( 'item3 extra 40000', approx( $b['areas'][2]['items'][2]['extra'], 40000.0 ) );
$expected = 50000 + ( 80000 + 20000 ) + ( 50000 + 40000 );
check( 'multi-item subtotal', approx( $b['areas'][2]['subtotal'], (float) $expected ) );

// 7. 4th item has no exact rule -> highest count < 4 (3rd rule) applies.
$b = $engine->compute( 0.0, 0.0, $areas, array(
	2 => array(
		array( 'w' => 8.0, 'h' => 8.0 ),
		array( 'w' => 8.0, 'h' => 8.0 ),
		array( 'w' => 8.0, 'h' => 8.0 ),
		array( 'w' => 8.0, 'h' => 8.0 ),
	),
), $rules );
check( 'item4 extra falls back to 3rd rule', approx( $b['areas'][2]['items'][3]['extra'], 40000.0 ) );

// 8. Size modifier and negative base price clamping.
$b = $engine->compute( 350000.0, 50000.0, $areas, array(), $rules );
check( 'no items -> base + size only', approx( $b['total'], 400000.0 ) );
$b = $engine->compute( -100.0, 0.0, $areas, array(), $rules );
check( 'negative base clamped', approx( $b['total'], 0.0 ) );

// 9. Items in two areas are both charged.
$b = $engine->compute( 0.0, 0.0, $areas, array(
	1 => array( array( 'w' => 8.0, 'h' => 8.0 ) ),
	2 => array( array( 'w' => 8.0, 'h' => 8.0 ) ),
), $rules );
check( 'two areas charged', approx( $b['print_total'], 65000.0 + 50000.0 ) );

// 10. Unmatched tier produces warning + zero price.
$odd_rules = array( 'size_tier' => array( array( 'scope' => 'global', 'print_area_id' => 0, 'size_from_cm' => 0.0, 'size_to_cm' => 5.0, 'price' => 10000.0, 'item_count' => 0, 'sort_order' => 0 ) ) );
$b = $engine->compute( 0.0, 0.0, $areas, array( 2 => array( array( 'w' => 20.0, 'h' => 20.0 ) ) ), $odd_rules );
check( 'unmatched tier warns', count( $b['warnings'] ) === 1 );
check( 'unmatched tier zero price', approx( $b['areas'][2]['items'][0]['base'], 0.0 ) );

// ---------------------------------------------------------------- summary

echo "\n{$tests} tests, {$failed} failures\n";
exit( $failed > 0 ? 1 : 0 );
