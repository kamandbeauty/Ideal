<?php
/**
 * Full integration test suite against a real WordPress install.
 *
 * Run with:
 *   node scratch/php.mjs -s <wp>/wp-content/plugins/tshirt-designer/tests/integration-suite.php
 *
 * Covers the phase-2 acceptance matrix: product types, models, colours,
 * sizes, print areas, uploads, print-area limits, pricing (size tiers, item
 * counts, per-area rules, front/back independence), design save/restore/
 * duplicate/delete/versioning/ownership, guest handling, price-manipulation
 * attempts, REST permissions, production snapshots and production files.
 *
 * @package TShirtDesigner
 */

// phpcs:disable WordPress.Security.NonceVerification, WordPress.PHP.DevelopmentFunctions

require_once __DIR__ . '/bootstrap-wp.php';

td_test_activate_plugin();

$plugin = td_plugin();

// ---------------------------------------------------------------- fixtures

$tshirt = $plugin->models->get_by_slug( 'classic-tshirt' );
$tote   = $plugin->models->get_by_slug( 'classic-tote' );

$tshirt_id = (int) $tshirt['id'];
$tote_id   = (int) $tote['id'];

$ts_colors = $plugin->colors->for_model( $tshirt_id );
$ts_sizes  = $plugin->sizes->for_model( $tshirt_id );
$ts_areas  = $plugin->print_areas->for_model( $tshirt_id );

$tb_colors = $plugin->colors->for_model( $tote_id );
$tb_sizes  = $plugin->sizes->for_model( $tote_id );
$tb_areas  = $plugin->print_areas->for_model( $tote_id );

/** Map area type => area row. */
$area_by_type = static function ( array $areas ): array {
	$out = array();
	foreach ( $areas as $area ) {
		$out[ (string) $area['area_type'] ] = $area;
	}
	return $out;
};
$ts_area = $area_by_type( $ts_areas );
$tb_area = $area_by_type( $tb_areas );

$assets = $plugin->assets->all( true );
$asset1 = (int) $assets[0]['id'];
$asset2 = (int) $assets[1]['id'];

// ============================================================ 1. Core setup

TD_Test::group( 'Core — product types' );

$types = TShirtDesigner\Product_Type_Registry::all();
TD_Test::ok( isset( $types['tshirt'], $types['totebag'] ), 'tshirt and totebag are registered' );
TD_Test::equals(
	array( 'front', 'back', 'left_sleeve', 'right_sleeve', 'other' ),
	TShirtDesigner\Product_Type_Registry::area_types( 'tshirt' ),
	'tshirt exposes 4 print area types + other'
);
TD_Test::equals(
	array( 'front', 'back', 'other' ),
	TShirtDesigner\Product_Type_Registry::area_types( 'totebag' ),
	'totebag exposes front/back only'
);
TD_Test::ok(
	! TShirtDesigner\Product_Type_Registry::area_type_allowed( 'totebag', 'left_sleeve' ),
	'a sleeve is rejected on a tote bag'
);
TD_Test::equals( 'tshirt', TShirtDesigner\Product_Type_Registry::sanitize( 'nope' ), 'unknown type falls back to legacy' );

// A third product type can be added purely by configuration.
add_filter(
	'cpd_product_types',
	static function ( array $t ): array {
		$t['mug'] = array(
			'label'      => 'Mug',
			'area_types' => array( 'wrap' => 'Wrap' ),
			'has_sizes'  => false,
			'print_dpi'  => 300,
		);
		return $t;
	}
);
TShirtDesigner\Product_Type_Registry::flush();
TD_Test::ok( TShirtDesigner\Product_Type_Registry::exists( 'mug' ), 'a new product type can be added by filter alone' );
TD_Test::ok(
	TShirtDesigner\Product_Type_Registry::area_type_allowed( 'mug', 'wrap' ),
	'the new type brings its own print area type'
);

TD_Test::group( 'Core — models, colors, sizes, print areas' );

TD_Test::equals( 'tshirt', (string) $tshirt['product_type'], 't-shirt model has the tshirt product type' );
TD_Test::equals( 'totebag', (string) $tote['product_type'], 'tote model has the totebag product type' );
TD_Test::equals( 4, count( $ts_areas ), 't-shirt has 4 print areas' );
TD_Test::equals( 2, count( $tb_areas ), 'tote bag has 2 print areas' );
TD_Test::ok( isset( $ts_area['front'], $ts_area['back'], $ts_area['left_sleeve'], $ts_area['right_sleeve'] ), 't-shirt areas are front/back/sleeves' );
TD_Test::ok( isset( $tb_area['front'], $tb_area['back'] ), 'tote areas are front/back' );
TD_Test::ok( count( $ts_colors ) >= 4, 't-shirt has colors' );
TD_Test::ok( count( $tb_colors ) >= 4, 'tote bag has colors' );
TD_Test::ok( count( $ts_sizes ) >= 6, 't-shirt has S..3XL' );
TD_Test::equals( 1, count( $tb_sizes ), 'tote bag has a single size entry' );

// Print areas carry real UV rects, so designs land on the 3D surface.
$front_pos = $plugin->print_areas->position( $ts_area['front'] );
TD_Test::ok( is_array( $front_pos['uv_rect'] ) && 4 === count( $front_pos['uv_rect'] ), 't-shirt front has a UV rect' );
$tote_front_pos = $plugin->print_areas->position( $tb_area['front'] );
$tote_back_pos  = $plugin->print_areas->position( $tb_area['back'] );
TD_Test::ok( is_array( $tote_front_pos['uv_rect'] ), 'tote front has a UV rect' );
TD_Test::ok(
	$tote_front_pos['uv_rect'] !== $tote_back_pos['uv_rect'],
	'tote front and back map to different UV regions (independent surfaces)'
);
TD_Test::ok(
	abs( (float) $tote_front_pos['camera']['azimuth'] - (float) $tote_back_pos['camera']['azimuth'] ) > 90,
	'tote front/back have opposite camera presets'
);

// The bundled GLB files really exist.
TD_Test::ok( '' !== $plugin->models->model_file_url( $tshirt ), 't-shirt GLB resolves to a URL' );
TD_Test::ok( '' !== $plugin->models->model_file_url( $tote ), 'tote GLB resolves to a URL' );
TD_Test::ok( file_exists( TD_PLUGIN_DIR . 'assets/models/classic-tshirt.glb' ), 't-shirt GLB file exists on disk' );
TD_Test::ok( file_exists( TD_PLUGIN_DIR . 'assets/models/classic-tote.glb' ), 'tote GLB file exists on disk' );

// Admin can change the tote print size (nothing hard-coded).
$plugin->print_areas->update( (int) $tb_area['front']['id'], array( 'max_width_cm' => 30.0, 'max_height_cm' => 35.0 ) );
$updated = $plugin->print_areas->get( (int) $tb_area['front']['id'] );
TD_Test::equals( 30.0, (float) $updated['max_width_cm'], 'tote front print width is admin-configurable' );
$plugin->print_areas->update( (int) $tb_area['front']['id'], array( 'max_width_cm' => 28.0, 'max_height_cm' => 32.0 ) );

// Migration bookkeeping.
TD_Test::equals( TD_DB_VERSION, (string) get_option( 'td_db_version' ), 'db version option matches the plugin' );
$tables = $plugin->db->tables();
global $wpdb;
$missing = array();
foreach ( $tables as $key ) {
	$name = $plugin->db->table( $key );
	if ( (string) $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $name ) ) !== $name ) {
		$missing[] = $key;
	}
}
TD_Test::equals( array(), $missing, 'every plugin table exists' );

// ======================================================== 2. Uploads

TD_Test::group( 'Assets — upload validation & security' );

wp_set_current_user( 1 );

$tmp_png = wp_tempnam( 'td-test.png' );
td_test_make_png( $tmp_png, 400, 400 );

$upload_file = array(
	'name'     => 'artwork.png',
	'type'     => 'image/png',
	'tmp_name' => $tmp_png,
	'size'     => (int) filesize( $tmp_png ),
	'error'    => 0,
);
$error = '';
$valid = $plugin->media->validate_upload( $upload_file, $error );
TD_Test::ok( null !== $valid, 'a real PNG passes validation' );
TD_Test::equals( 'image/png', (string) ( $valid['mime'] ?? '' ), 'mime is detected from content' );

// Executable disguised as an image.
$evil = wp_tempnam( 'td-evil.png' );
file_put_contents( $evil, "<?php echo 'pwned'; ?>" );
$evil_file = array( 'name' => 'evil.php.png', 'type' => 'image/png', 'tmp_name' => $evil, 'size' => (int) filesize( $evil ), 'error' => 0 );
$error = '';
TD_Test::ok( null === $plugin->media->validate_upload( $evil_file, $error ), 'a PHP file renamed to .png is rejected' );

// Wrong extension for real content.
$mismatch = wp_tempnam( 'td-mismatch.jpg' );
td_test_make_png( $mismatch, 20, 20 );
$mismatch_file = array( 'name' => 'shot.jpg', 'type' => 'image/jpeg', 'tmp_name' => $mismatch, 'size' => (int) filesize( $mismatch ), 'error' => 0 );
$error = '';
TD_Test::ok( null === $plugin->media->validate_upload( $mismatch_file, $error ), 'content/extension mismatch is rejected' );

// Oversized file.
td_set_setting( array( 'upload_max_mb' => 0.5 ) );
$big = wp_tempnam( 'td-big.png' );
td_test_make_png( $big, 1400, 1400 );
$big_file = array( 'name' => 'big.png', 'type' => 'image/png', 'tmp_name' => $big, 'size' => 900000, 'error' => 0 );
$error = '';
TD_Test::ok( null === $plugin->media->validate_upload( $big_file, $error ), 'a file over the size limit is rejected' );
td_set_setting( array( 'upload_max_mb' => 5 ) );

// SVG must never be accepted (no sanitizer bundled).
$svg = wp_tempnam( 'td.svg' );
file_put_contents( $svg, '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>' );
$svg_file = array( 'name' => 'logo.svg', 'type' => 'image/svg+xml', 'tmp_name' => $svg, 'size' => (int) filesize( $svg ), 'error' => 0 );
$error = '';
TD_Test::ok( null === $plugin->media->validate_upload( $svg_file, $error ), 'SVG upload is refused' );

// Store a real upload for later design tests.
$stored = $plugin->media->store_upload( $valid, 1, '' );
TD_Test::ok( is_array( $stored ) && (int) $stored['id'] > 0, 'a validated upload is stored' );
$upload_id = (int) ( $stored['id'] ?? 0 );
TD_Test::ok( isset( $stored['url'] ) && str_contains( (string) $stored['url'], 'td-uploads' ), 'uploads live in an isolated directory' );

// Transparency survives the pipeline.
$stored_path = get_attached_file( (int) $stored['attachment_id'] );
$info        = $stored_path ? getimagesize( $stored_path ) : false;
TD_Test::ok( false !== $info && 'image/png' === $info['mime'], 'stored PNG stays a PNG (transparency preserved)' );

// ================================================== 3. Print area validation

TD_Test::group( 'Print — area bounds, rotation, layers' );

$front    = $ts_area['front'];
$front_id = (int) $front['id'];
$color_id = (int) $ts_colors[0]['id'];
$size_id  = (int) $ts_sizes[0]['id'];  // S, +0
$xl_id    = 0;
foreach ( $ts_sizes as $s ) {
	if ( 'XL' === (string) $s['name'] ) {
		$xl_id = (int) $s['id'];
	}
}

$make_item = static function ( array $overrides = array() ): array {
	return array_merge(
		array(
			'id'       => 'i-' . wp_generate_password( 6, false, false ),
			'type'     => 'asset',
			'ref_id'   => 0,
			'x'        => 15.0,
			'y'        => 17.5,
			'w'        => 10.0,
			'h'        => 10.0,
			'rotation' => 0.0,
			'layer'    => 0,
			'opacity'  => 1.0,
		),
		$overrides
	);
};

$design_payload = static function ( int $model_id, int $color_id, int $size_id, array $areas ): array {
	return array( 'model_id' => $model_id, 'color_id' => $color_id, 'size_id' => $size_id, 'areas' => $areas );
};

// Valid item inside the area.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( $r['ok'], 'an item inside the print area validates' );

// Item wider than the area.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 60.0, 'h' => 10.0 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( ! $r['ok'], 'an item wider than the max print width is refused' );

// Item taller than the area.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 90.0 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( ! $r['ok'], 'an item taller than the max print height is refused' );

// Item pushed outside the area.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'x' => 120.0 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( ! $r['ok'], 'an item placed outside the print area is refused' );

// Rotation grows the bounding box: 30x30 rotated 45° no longer fits 30x35.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 30.0, 'h' => 30.0, 'rotation' => 45.0 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( ! $r['ok'], 'rotation is accounted for when checking the bounds' );

// A rotated item that still fits is fine.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 12.0, 'h' => 12.0, 'rotation' => 30.0 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( $r['ok'], 'a rotated item that still fits is accepted' );

// Layer order is normalized (and preserved).
$r = $plugin->designs->validate_design(
	$design_payload(
		$tshirt_id,
		$color_id,
		$size_id,
		array(
			(string) $front_id => array(
				$make_item( array( 'ref_id' => $asset1, 'x' => 8.0, 'y' => 8.0, 'layer' => 5 ) ),
				$make_item( array( 'ref_id' => $asset2, 'x' => 20.0, 'y' => 20.0, 'layer' => 2 ) ),
			),
		)
	),
	1,
	''
);
TD_Test::ok( $r['ok'], 'multiple items on one area validate' );
$layers = array_column( $r['design']['areas'][ (string) $front_id ], 'layer' );
TD_Test::equals( array( 0, 1 ), $layers, 'layers are re-indexed 0..n keeping the stacking order' );
TD_Test::equals(
	$asset2,
	(int) $r['design']['areas'][ (string) $front_id ][0]['ref_id'],
	'the item with the lower layer stays at the bottom'
);

// Unknown print area.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( '999999' => array( $make_item( array( 'ref_id' => $asset1 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( ! $r['ok'], 'an unknown print area id is refused' );

// A tote-bag area cannot be used on a t-shirt design.
$r = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $tb_area['front']['id'] => array( $make_item( array( 'ref_id' => $asset1 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( ! $r['ok'], 'a print area from another product cannot be used' );

// Invalid colour / size.
$r = $plugin->designs->validate_design( $design_payload( $tshirt_id, 999999, $size_id, array() ), 1, '' );
TD_Test::ok( ! $r['ok'], 'an invalid colour is refused' );
$r = $plugin->designs->validate_design( $design_payload( $tshirt_id, $color_id, 999999, array() ), 1, '' );
TD_Test::ok( ! $r['ok'], 'an invalid size is refused' );

// ============================================================== 4. Pricing

TD_Test::group( 'Pricing — server-side computation' );

$base_price = $plugin->models->base_price( $tshirt );
TD_Test::equals( 350000.0, $base_price, 't-shirt base price comes from the model' );

// One 10cm item: tier 0-10 = 50,000.
$q = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 8.0 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( $q['ok'], 'a simple design can be priced' );
TD_Test::equals( 400000.0, (float) $q['breakdown']['total'], 'base 350k + 10cm tier 50k = 400k' );

// 15cm item: tier 10-20 = 80,000.
$q = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 15.0, 'h' => 10.0 ) ) ) ) ),
	1,
	''
);
TD_Test::equals( 430000.0, (float) $q['breakdown']['total'], 'size-based print price uses the longest side (15cm -> 80k)' );

// 25cm item: tier 20-30 = 120,000.
$q = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 25.0, 'h' => 20.0, 'x' => 15.0, 'y' => 17.5 ) ) ) ) ),
	1,
	''
);
TD_Test::equals( 470000.0, (float) $q['breakdown']['total'], '25cm artwork uses the 20-30cm tier (120k)' );

// Size surcharge (XL = +20,000).
$q = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $xl_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 8.0 ) ) ) ) ),
	1,
	''
);
TD_Test::equals( 420000.0, (float) $q['breakdown']['total'], 'XL adds its size surcharge' );

// Item count pricing: 2nd item +20,000, 3rd +40,000.
$q = $plugin->designs->quote(
	$design_payload(
		$tshirt_id,
		$color_id,
		$size_id,
		array(
			(string) $front_id => array(
				$make_item( array( 'ref_id' => $asset1, 'w' => 8.0, 'h' => 8.0, 'x' => 8.0, 'y' => 8.0, 'layer' => 0 ) ),
				$make_item( array( 'ref_id' => $asset2, 'w' => 8.0, 'h' => 8.0, 'x' => 20.0, 'y' => 20.0, 'layer' => 1 ) ),
			),
		)
	),
	1,
	''
);
// 350k + (50k) + (50k + 20k) = 470k
TD_Test::equals( 470000.0, (float) $q['breakdown']['total'], 'the 2nd item on an area adds the item-count surcharge' );

$q3 = $plugin->designs->quote(
	$design_payload(
		$tshirt_id,
		$color_id,
		$size_id,
		array(
			(string) $front_id => array(
				$make_item( array( 'ref_id' => $asset1, 'w' => 8.0, 'h' => 8.0, 'x' => 6.0, 'y' => 6.0, 'layer' => 0 ) ),
				$make_item( array( 'ref_id' => $asset2, 'w' => 8.0, 'h' => 8.0, 'x' => 15.0, 'y' => 15.0, 'layer' => 1 ) ),
				$make_item( array( 'ref_id' => $asset1, 'w' => 8.0, 'h' => 8.0, 'x' => 24.0, 'y' => 26.0, 'layer' => 2 ) ),
			),
		)
	),
	1,
	''
);
// 350k + 50k + (50k+20k) + (50k+40k) = 560k
TD_Test::equals( 560000.0, (float) $q3['breakdown']['total'], 'the 3rd item adds the next item-count tier' );

// Front and back are priced independently and both appear in the breakdown.
$back_id = (int) $ts_area['back']['id'];
$q = $plugin->designs->quote(
	$design_payload(
		$tshirt_id,
		$color_id,
		$size_id,
		array(
			(string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 8.0 ) ) ),
			(string) $back_id  => array( $make_item( array( 'ref_id' => $asset2, 'w' => 15.0, 'h' => 12.0 ) ) ),
		)
	),
	1,
	''
);
TD_Test::equals( 480000.0, (float) $q['breakdown']['total'], 'front (50k) and back (80k) are both charged' );
TD_Test::equals( 2, count( $q['breakdown']['areas'] ), 'the breakdown lists both areas separately' );
TD_Test::ok(
	isset( $q['breakdown']['areas'][ $front_id ], $q['breakdown']['areas'][ $back_id ] ),
	'each area has its own subtotal'
);

// Area-scoped rule beats the global one (t-shirt back becomes pricier).
$rule_id = $plugin->pricing->save_rule(
	array(
		'rule_type'     => TShirtDesigner\Pricing_Engine::RULE_SIZE_TIER,
		'scope'         => 'area',
		'print_area_id' => $back_id,
		'size_from_cm'  => 0.0,
		'size_to_cm'    => 30.0,
		'price'         => 150000.0,
		'is_active'     => 1,
		'sort_order'    => 0,
	)
);
$q = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $back_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 8.0 ) ) ) ) ),
	1,
	''
);
TD_Test::equals( 500000.0, (float) $q['breakdown']['total'], 'an area-scoped rule overrides the global tier' );

// The front is untouched by that back rule.
$q = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 8.0 ) ) ) ) ),
	1,
	''
);
TD_Test::equals( 400000.0, (float) $q['breakdown']['total'], 'the front keeps the global tier (front/back independent)' );
$plugin->pricing->delete_rule( $rule_id );

// Tote bag pricing, including independent front/back rules.
$tb_front_id = (int) $tb_area['front']['id'];
$tb_back_id  = (int) $tb_area['back']['id'];
$tb_color    = (int) $tb_colors[0]['id'];
$tb_size     = (int) $tb_sizes[0]['id'];

$tb_front_rule = $plugin->pricing->save_rule(
	array(
		'rule_type'     => TShirtDesigner\Pricing_Engine::RULE_SIZE_TIER,
		'scope'         => 'area',
		'print_area_id' => $tb_front_id,
		'size_from_cm'  => 0.0,
		'size_to_cm'    => 40.0,
		'price'         => 80000.0,
		'is_active'     => 1,
	)
);
$tb_back_rule = $plugin->pricing->save_rule(
	array(
		'rule_type'     => TShirtDesigner\Pricing_Engine::RULE_SIZE_TIER,
		'scope'         => 'area',
		'print_area_id' => $tb_back_id,
		'size_from_cm'  => 0.0,
		'size_to_cm'    => 40.0,
		'price'         => 90000.0,
		'is_active'     => 1,
	)
);

$q = $plugin->designs->quote(
	$design_payload( $tote_id, $tb_color, $tb_size, array( (string) $tb_front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 12.0, 'h' => 12.0, 'x' => 14.0, 'y' => 16.0 ) ) ) ) ),
	1,
	''
);
TD_Test::equals( 300000.0, (float) $q['breakdown']['total'], 'tote front print = base 220k + 80k' );

$q = $plugin->designs->quote(
	$design_payload( $tote_id, $tb_color, $tb_size, array( (string) $tb_back_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 12.0, 'h' => 12.0, 'x' => 14.0, 'y' => 16.0 ) ) ) ) ),
	1,
	''
);
TD_Test::equals( 310000.0, (float) $q['breakdown']['total'], 'tote back print = base 220k + 90k (independent price)' );

$q = $plugin->designs->quote(
	$design_payload(
		$tote_id,
		$tb_color,
		$tb_size,
		array(
			(string) $tb_front_id => array(
				$make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 10.0, 'x' => 8.0, 'y' => 10.0, 'layer' => 0 ) ),
				$make_item( array( 'ref_id' => $asset2, 'w' => 10.0, 'h' => 10.0, 'x' => 20.0, 'y' => 22.0, 'layer' => 1 ) ),
			),
			(string) $tb_back_id  => array(
				$make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 10.0, 'x' => 14.0, 'y' => 16.0 ) ),
			),
		)
	),
	1,
	''
);
// 220k + (80k) + (80k+20k) + (90k) = 490k
TD_Test::equals( 490000.0, (float) $q['breakdown']['total'], 'tote front(2 items) + back priced independently' );

// ================================================ 5. Price manipulation

TD_Test::group( 'Security — price manipulation' );

$forged = $design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 25.0, 'h' => 20.0 ) ) ) ) );
$forged['price']       = 1.0;
$forged['total']       = 1.0;
$forged['base_price']  = 0.0;
$forged['breakdown']   = array( 'total' => 1.0 );

$q = $plugin->designs->quote( $forged, 1, '' );
TD_Test::equals( 470000.0, (float) $q['breakdown']['total'], 'client-sent price fields are ignored entirely' );

$save = $plugin->designs->save( $forged, 1, '', null );
TD_Test::ok( $save['ok'], 'the forged payload still saves (prices are just recomputed)' );
$saved_row = $plugin->designs->get_design( (int) $save['id'], 1, '' );
TD_Test::equals( 470000.0, (float) $saved_row['price_total'], 'the stored price is the server price, not the forged one' );

// A forged base price on the model row is likewise ignored.
$forged2 = $forged;
$forged2['model'] = array( 'base_price' => 1.0 );
$q2 = $plugin->designs->quote( $forged2, 1, '' );
TD_Test::equals( 470000.0, (float) $q2['breakdown']['total'], 'a forged nested model price is ignored' );

// ==================================================== 6. Design lifecycle

TD_Test::group( 'Design — save, restore, versioning' );

$payload = $design_payload(
	$tshirt_id,
	$color_id,
	$xl_id,
	array(
		(string) $front_id => array(
			$make_item( array( 'ref_id' => $asset1, 'w' => 12.0, 'h' => 10.0, 'x' => 10.0, 'y' => 12.0, 'rotation' => 15.0, 'layer' => 0 ) ),
			$make_item( array( 'type' => 'upload', 'ref_id' => $upload_id, 'w' => 8.0, 'h' => 8.0, 'x' => 22.0, 'y' => 25.0, 'layer' => 1 ) ),
		),
		(string) $back_id  => array(
			$make_item( array( 'ref_id' => $asset2, 'w' => 20.0, 'h' => 15.0, 'x' => 15.0, 'y' => 17.0 ) ),
		),
	)
);

$saved = $plugin->designs->save( $payload, 1, '', null );
TD_Test::ok( $saved['ok'], 'a full design saves' );
$design_id = (int) $saved['id'];
TD_Test::ok( str_starts_with( (string) $saved['uuid'], 'DESIGN-' ), 'the design gets a DESIGN-xxxxxxx uuid' );
TD_Test::equals( 1, (int) $saved['version'], 'the first save is version 1' );

$restored = $plugin->designs->get_design( $design_id, 1, '' );
TD_Test::ok( null !== $restored, 'the design can be read back' );
$rd = $restored['design_data'];
TD_Test::equals( $tshirt_id, (int) $rd['model_id'], 'restore: model' );
TD_Test::equals( $color_id, (int) $rd['color_id'], 'restore: color' );
TD_Test::equals( $xl_id, (int) $rd['size_id'], 'restore: size' );
TD_Test::equals( 'tshirt', (string) $rd['product_type'], 'restore: product type' );
TD_Test::equals( 2, count( $rd['areas'] ), 'restore: both print areas survive' );
TD_Test::equals( 2, count( $rd['areas'][ (string) $front_id ] ), 'restore: both front items survive' );
$first = $rd['areas'][ (string) $front_id ][0];
TD_Test::equals( 12.0, (float) $first['w'], 'restore: item width' );
TD_Test::equals( 10.0, (float) $first['x'], 'restore: item x' );
TD_Test::equals( 15.0, (float) $first['rotation'], 'restore: item rotation' );
TD_Test::equals( 0, (int) $first['layer'], 'restore: item layer' );
TD_Test::ok( '' !== (string) $first['src'], 'restore: server-resolved artwork src is present' );
$second = $rd['areas'][ (string) $front_id ][1];
TD_Test::equals( 'upload', (string) $second['type'], 'restore: the uploaded item keeps its type' );
TD_Test::equals( $upload_id, (int) $second['ref_id'], 'restore: the uploaded item keeps its reference' );

// Saving again bumps the version and keeps history.
$payload2 = $payload;
$payload2['design_id'] = $design_id;
// 12cm (tier 10-20) -> 25cm (tier 20-30), so the version prices must differ.
$payload2['areas'][ (string) $front_id ][0]['w']        = 25.0;
$payload2['areas'][ (string) $front_id ][0]['h']        = 20.0;
$payload2['areas'][ (string) $front_id ][0]['rotation'] = 0.0;
$payload2['areas'][ (string) $front_id ][0]['x'] = 15.0;
$payload2['areas'][ (string) $front_id ][0]['y'] = 17.5;
$saved2 = $plugin->designs->save( $payload2, 1, '', null );
TD_Test::ok( $saved2['ok'], 'the design can be updated' . ( $saved2['ok'] ? '' : ' :: ' . implode( ' | ', $saved2['errors'] ) ) );
TD_Test::equals( $design_id, (int) $saved2['id'], 'updating keeps the same design id' );
TD_Test::equals( 2, (int) $saved2['version'], 'updating creates version 2' );
TD_Test::equals( (string) $saved['uuid'], (string) $saved2['uuid'], 'the uuid is stable across versions' );

$versions = $plugin->designs->versions( $design_id );
TD_Test::equals( 2, count( $versions ), 'both versions are stored' );

$v1 = $plugin->designs->get_version( $design_id, 1 );
$v2 = $plugin->designs->get_version( $design_id, 2 );
TD_Test::equals( 12.0, (float) $v1['design_data']['areas'][ (string) $front_id ][0]['w'], 'version 1 still holds the original size' );
TD_Test::equals( 25.0, (float) $v2['design_data']['areas'][ (string) $front_id ][0]['w'], 'version 2 holds the new size' );
TD_Test::equals( 12.0, (float) $v1['design_data']['areas'][ (string) $front_id ][0]['w'], 'version 1 is not rewritten by the update' );
TD_Test::ok(
	(float) $v1['price_total'] !== (float) $v2['price_total'],
	'each version keeps its own price snapshot'
);

TD_Test::group( 'Design — duplicate & delete' );

$dup = $plugin->designs->duplicate( $design_id, 1, '' );
TD_Test::ok( $dup['ok'], 'a design can be duplicated' );
TD_Test::ok( (int) $dup['id'] !== $design_id, 'the copy has an independent id' );
TD_Test::ok( (string) $dup['uuid'] !== (string) $saved['uuid'], 'the copy has its own uuid' );

$dup_row = $plugin->designs->get_design( (int) $dup['id'], 1, '' );
TD_Test::equals(
	count( $rd['areas'] ),
	count( $dup_row['design_data']['areas'] ),
	'the copy carries the same artwork layout'
);
TD_Test::equals(
	$asset1,
	(int) $dup_row['design_data']['areas'][ (string) $front_id ][0]['ref_id'],
	'the copy reuses the same asset files'
);

// Editing the copy leaves the original alone.
$edit = $payload;
$edit['design_id'] = (int) $dup['id'];
$edit['areas'][ (string) $front_id ][0]['w'] = 5.0;
$plugin->designs->save( $edit, 1, '', null );
$orig_after = $plugin->designs->get_design( $design_id, 1, '' );
TD_Test::equals(
	25.0,
	(float) $orig_after['design_data']['areas'][ (string) $front_id ][0]['w'],
	'editing the copy does not touch the original'
);

$del = $plugin->designs->delete( (int) $dup['id'], 1, '' );
TD_Test::ok( $del['ok'], 'a design can be deleted' );
TD_Test::ok( null === $plugin->designs->get_design( (int) $dup['id'], 1, '' ), 'the deleted design is gone' );

TD_Test::group( 'Design — ownership' );

// Second customer.
$user2 = wp_insert_user(
	array(
		'user_login' => 'customer2',
		'user_pass'  => 'pass-123456',
		'user_email' => 'c2@example.org',
		'role'       => 'customer',
	)
);
$user2 = is_wp_error( $user2 ) ? (int) get_user_by( 'login', 'customer2' )->ID : (int) $user2;

TD_Test::ok( null === $plugin->designs->get_design( $design_id, $user2, '' ), 'another user cannot read the design' );
$other_del = $plugin->designs->delete( $design_id, $user2, '' );
TD_Test::ok( ! $other_del['ok'], 'another user cannot delete the design' );
$other_dup = $plugin->designs->duplicate( $design_id, $user2, '' );
TD_Test::ok( ! $other_dup['ok'], 'another user cannot duplicate the design' );

$hijack = $payload;
$hijack['design_id'] = $design_id;
$hijack_save = $plugin->designs->save( $hijack, $user2, '', null );
TD_Test::ok( ! $hijack_save['ok'], 'another user cannot overwrite the design (IDOR blocked)' );

// Guest ownership.
$guest_a = str_repeat( 'a', 32 );
$guest_b = str_repeat( 'b', 32 );
wp_set_current_user( 0 );
$guest_payload = $design_payload(
	$tshirt_id,
	$color_id,
	$size_id,
	array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 10.0 ) ) ) )
);
$guest_saved = $plugin->designs->save( $guest_payload, 0, $guest_a, null );
TD_Test::ok( $guest_saved['ok'], 'a guest can save a design' . ( $guest_saved['ok'] ? '' : ' :: ' . implode( ' | ', $guest_saved['errors'] ) ) );
$guest_design_id = (int) $guest_saved['id'];
TD_Test::ok( null !== $plugin->designs->get_design( $guest_design_id, 0, $guest_a ), 'the guest can read their own design' );
TD_Test::ok( null === $plugin->designs->get_design( $guest_design_id, 0, $guest_b ), 'another guest token cannot read it' );
TD_Test::ok( null === $plugin->designs->get_design( $guest_design_id, 0, '' ), 'an empty token cannot read it' );
TD_Test::ok( null === $plugin->designs->get_design( $guest_design_id, $user2, '' ), 'a logged-in stranger cannot read it' );

// Guest -> account transfer.
$claimed = $plugin->designs->claim_guest_designs( $user2, $guest_a );
TD_Test::ok( $claimed >= 1, 'guest designs are claimed on login' );
TD_Test::ok( null !== $plugin->designs->get_design( $guest_design_id, $user2, '' ), 'the claimed design belongs to the account' );
TD_Test::ok( null === $plugin->designs->get_design( $guest_design_id, 0, $guest_a ), 'the old guest token no longer works' );

// Admin sees everything.
wp_set_current_user( 1 );
TD_Test::ok( null !== $plugin->designs->get_design( $guest_design_id, 1, '' ), 'an administrator can read any design' );

// Text items.
TD_Test::group( 'Design — text engine' );

$text_payload = $design_payload(
	$tshirt_id,
	$color_id,
	$size_id,
	array(
		(string) $front_id => array(
			$make_item(
				array(
					'type'   => 'text',
					'ref_id' => 0,
					'w'      => 20.0,
					'h'      => 6.0,
					'x'      => 15.0,
					'y'      => 12.0,
					'text'   => array(
						'content'   => 'سلام دنیا',
						'font'      => 'vazir',
						'color'     => '#123456',
						'bold'      => true,
						'align'     => 'center',
					),
				)
			),
		),
	)
);
$r = $plugin->designs->validate_design( $text_payload, 1, '' );
TD_Test::ok( $r['ok'], 'a Persian text item validates' );
$text_item = $r['design']['areas'][ (string) $front_id ][0];
TD_Test::equals( 'text', (string) $text_item['type'], 'the item keeps the text type (not faked as an image)' );
TD_Test::equals( 'rtl', (string) $text_item['text']['direction'], 'Persian text is detected as RTL' );
TD_Test::equals( '#123456', (string) $text_item['text']['color'], 'the text colour is preserved' );
TD_Test::ok( (bool) $text_item['text']['bold'], 'bold is preserved' );

$ltr = $text_payload;
$ltr['areas'][ (string) $front_id ][0]['text']['content'] = 'Hello World';
$r = $plugin->designs->validate_design( $ltr, 1, '' );
TD_Test::equals( 'ltr', (string) $r['design']['areas'][ (string) $front_id ][0]['text']['direction'], 'Latin text is detected as LTR' );

$empty = $text_payload;
$empty['areas'][ (string) $front_id ][0]['text']['content'] = '   ';
$r = $plugin->designs->validate_design( $empty, 1, '' );
TD_Test::ok( ! $r['ok'], 'an empty text item is refused' );

$xss = $text_payload;
$xss['areas'][ (string) $front_id ][0]['text']['content'] = '<script>alert(1)</script>';
$r = $plugin->designs->validate_design( $xss, 1, '' );
$xss_out = $r['ok'] ? (string) $r['design']['areas'][ (string) $front_id ][0]['text']['content'] : '';
TD_Test::ok(
	! $r['ok'] || ! str_contains( $xss_out, '<' ),
	'a script payload is either rejected or fully stripped from the text'
);

$html = $text_payload;
$html['areas'][ (string) $front_id ][0]['text']['content'] = 'Hi <b>there</b> & co';
$r = $plugin->designs->validate_design( $html, 1, '' );
TD_Test::equals(
	'Hi there & co',
	(string) $r['design'][ 'areas' ][ (string) $front_id ][0]['text']['content'],
	'markup is stripped from text while the wording survives'
);

$bad_font = $text_payload;
$bad_font['areas'][ (string) $front_id ][0]['text']['font'] = '../../etc/passwd';
$r = $plugin->designs->validate_design( $bad_font, 1, '' );
TD_Test::ok(
	$r['ok'] && in_array( (string) $r['design']['areas'][ (string) $front_id ][0]['text']['font'], array_keys( TShirtDesigner\Text_Engine::fonts() ), true ),
	'an arbitrary font name falls back to a registered font (no path traversal)'
);

// Bundled fonts really exist.
TD_Test::ok( '' !== TShirtDesigner\Text_Engine::font_path( 'vazir' ), 'the Persian font file is bundled' );
TD_Test::ok( '' !== TShirtDesigner\Text_Engine::font_path( 'sans' ), 'the Latin font file is bundled' );

// ============================================== 7. Production snapshot/files

TD_Test::group( 'Production — snapshot & print files' );

$prod_payload = $design_payload(
	$tshirt_id,
	$color_id,
	$xl_id,
	array(
		(string) $front_id => array(
			$make_item( array( 'ref_id' => $asset1, 'w' => 14.0, 'h' => 14.0, 'x' => 15.0, 'y' => 15.0, 'layer' => 0 ) ),
			$make_item( array( 'type' => 'upload', 'ref_id' => $upload_id, 'w' => 8.0, 'h' => 8.0, 'x' => 8.0, 'y' => 28.0, 'rotation' => 20.0, 'layer' => 1, 'opacity' => 0.6 ) ),
		),
		(string) $back_id  => array(
			$make_item( array( 'ref_id' => $asset2, 'w' => 18.0, 'h' => 18.0, 'x' => 15.0, 'y' => 17.0 ) ),
		),
	)
);
$prod_saved = $plugin->designs->save( $prod_payload, 1, '', null );
$prod_id    = (int) $prod_saved['id'];

$snapshot = $plugin->designs->build_snapshot( $prod_id, (int) $prod_saved['version'] );
TD_Test::ok( is_array( $snapshot ), 'a production snapshot is built' );
TD_Test::equals( 'tshirt', (string) $snapshot['product_type'], 'the snapshot records the product type' );
TD_Test::equals( 2, count( $snapshot['areas'] ), 'only the two designed areas are in the snapshot (sleeves excluded)' );
TD_Test::equals( 3, (int) $snapshot['item_count'], 'the snapshot counts every item' );
TD_Test::equals( 300, (int) $snapshot['dpi'], 'the snapshot records the print DPI' );
TD_Test::ok( isset( $snapshot['model']['name'], $snapshot['color']['hex'], $snapshot['size']['name'] ), 'model/colour/size are copied by value' );
TD_Test::ok(
	'' !== (string) $snapshot['areas'][0]['items'][0]['file_path'] && is_readable( (string) $snapshot['areas'][0]['items'][0]['file_path'] ),
	'artwork is resolved to a real file path in the snapshot'
);

// Pixel maths.
[ $pw, $ph ] = TShirtDesigner\Production_Renderer::pixel_size( 30.0, 35.0, 300 );
TD_Test::equals( 3543, $pw, '30cm at 300dpi = 3543px' );
TD_Test::equals( 4134, $ph, '35cm at 300dpi = 4134px' );
[ $pw2, ] = TShirtDesigner\Production_Renderer::pixel_size( 30.0, 35.0, 150 );
TD_Test::equals( 1772, $pw2, 'DPI is honoured (150dpi halves the resolution)' );

// File naming.
TD_Test::equals(
	'ORDER-1001-DESIGN-A123-FRONT.png',
	TShirtDesigner\Production_Renderer::file_name( 1001, 'DESIGN-A123', 'front' ),
	'production files use the standard naming scheme'
);
TD_Test::equals(
	'ORDER-7-DESIGN-XYZ-LEFT-SLEEVE.png',
	TShirtDesigner\Production_Renderer::file_name( 7, 'DESIGN-XYZ', 'left_sleeve' ),
	'sleeve names are normalised'
);

// Render at a low DPI to keep the test quick, then verify the output.
$snapshot_lowdpi        = $snapshot;
$snapshot_lowdpi['dpi'] = 72;
$gen = $plugin->production->generate( $snapshot_lowdpi, 1001, 55, true );
TD_Test::ok( $gen['ok'], 'production files generate without errors' );
TD_Test::equals( 2, count( $gen['files'] ), 'one file per designed area (2 of 4 t-shirt areas)' );

$front_file = null;
foreach ( $gen['files'] as $file ) {
	if ( 'front' === $file['area_type'] ) {
		$front_file = $file;
	}
}
TD_Test::ok( null !== $front_file, 'the front production file exists' );
TD_Test::ok( file_exists( (string) $front_file['file_path'] ), 'the PNG was written to disk' );
TD_Test::equals( 'ORDER-1001-' . $snapshot['design_uuid'] . '-FRONT.png', (string) $front_file['file_name'], 'the file name follows the convention' );

$img_info = getimagesize( (string) $front_file['file_path'] );
TD_Test::equals( 'image/png', (string) $img_info['mime'], 'the production file is a PNG' );
[ $exp_w, $exp_h ] = TShirtDesigner\Production_Renderer::pixel_size( 30.0, 35.0, 72 );
TD_Test::equals( $exp_w, (int) $img_info[0], 'the production file has the correct physical width in pixels' );
TD_Test::equals( $exp_h, (int) $img_info[1], 'the production file has the correct physical height in pixels' );

// Transparency check: the corner must be fully transparent.
$png    = imagecreatefrompng( (string) $front_file['file_path'] );
$corner = imagecolorat( $png, 2, 2 );
TD_Test::equals( 127, ( $corner >> 24 ) & 0x7F, 'the background stays fully transparent' );
// Centre must carry ink (the 14cm artwork sits at the middle of the area).
$centre       = imagecolorat( $png, (int) ( $exp_w / 2 ), (int) ( $exp_h * 15.0 / 35.0 ) );
$centre_alpha = ( $centre >> 24 ) & 0x7F;
TD_Test::ok( $centre_alpha < 127, 'the artwork is actually painted into the file' );
imagedestroy( $png );

// Areas without artwork produce nothing.
$types_generated = array_column( $gen['files'], 'area_type' );
sort( $types_generated );
TD_Test::equals( array( 'back', 'front' ), $types_generated, 'sleeves without artwork produce no file' );

// Tote bag production: exactly front + back.
$tote_prod = $plugin->designs->save(
	$design_payload(
		$tote_id,
		$tb_color,
		$tb_size,
		array(
			(string) $tb_front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 12.0, 'h' => 12.0, 'x' => 14.0, 'y' => 16.0 ) ) ),
			(string) $tb_back_id  => array( $make_item( array( 'ref_id' => $asset2, 'w' => 10.0, 'h' => 10.0, 'x' => 14.0, 'y' => 16.0 ) ) ),
		)
	),
	1,
	'',
	null
);
$tote_snapshot        = $plugin->designs->build_snapshot( (int) $tote_prod['id'], (int) $tote_prod['version'] );
$tote_snapshot['dpi'] = 72;
$tote_gen             = $plugin->production->generate( $tote_snapshot, 1002, 56, true );
TD_Test::ok( $tote_gen['ok'], 'tote bag production files generate' );
TD_Test::equals( 2, count( $tote_gen['files'] ), 'the tote bag produces exactly 2 files' );
$tote_types = array_column( $tote_gen['files'], 'area_type' );
sort( $tote_types );
TD_Test::equals( array( 'back', 'front' ), $tote_types, 'tote files are front and back' );

$tote_front_file = null;
foreach ( $tote_gen['files'] as $f ) {
	if ( 'front' === $f['area_type'] ) {
		$tote_front_file = $f;
	}
}
[ $tb_w, $tb_h ] = TShirtDesigner\Production_Renderer::pixel_size( 28.0, 32.0, 72 );
$tb_info = getimagesize( (string) $tote_front_file['file_path'] );
TD_Test::equals( $tb_w, (int) $tb_info[0], 'the tote print file uses the tote area size, not the t-shirt one' );
TD_Test::equals( $tb_h, (int) $tb_info[1], 'the tote print file height matches its own area' );

// Layer order is preserved in the output pipeline.
$snapshot_layers = array_column( $snapshot['areas'][0]['items'], 'layer' );
TD_Test::equals( array( 0, 1 ), $snapshot_layers, 'the snapshot preserves the layer order' );

// ===================================================== 8. Order immutability

TD_Test::group( 'Order — immutability of a stored snapshot' );

$before = wp_json_encode( $snapshot );

// Change everything the design depends on.
$plugin->models->update( $tshirt_id, array( 'base_price' => 999000.0, 'name' => 'Renamed Shirt' ) );
$plugin->print_areas->update( $front_id, array( 'max_width_cm' => 12.0, 'max_height_cm' => 12.0 ) );
$plugin->colors->update( $color_id, array( 'name' => 'Changed', 'hex' => '#000000' ) );
$new_rule = $plugin->pricing->save_rule(
	array(
		'rule_type'    => TShirtDesigner\Pricing_Engine::RULE_SIZE_TIER,
		'scope'        => 'global',
		'size_from_cm' => 0.0,
		'size_to_cm'   => 100.0,
		'price'        => 777000.0,
		'is_active'    => 1,
		'sort_order'   => -5,
	)
);

TD_Test::equals( $before, wp_json_encode( $snapshot ), 'the in-memory snapshot is untouched by catalogue edits' );

// Re-rendering from the snapshot yields the same geometry as before.
$regen = $plugin->production->generate( $snapshot_lowdpi, 1001, 55, true );
$regen_front = null;
foreach ( $regen['files'] as $f ) {
	if ( 'front' === $f['area_type'] ) {
		$regen_front = $f;
	}
}
$regen_info = getimagesize( (string) $regen_front['file_path'] );
TD_Test::equals( $exp_w, (int) $regen_info[0], 'regenerating from the snapshot keeps the original print size' );
TD_Test::equals(
	(string) $front_file['file_name'],
	(string) $regen_front['file_name'],
	'regeneration reuses the same deterministic file name'
);

// A *new* quote on the same design now reflects the new rules — proving the
// snapshot is a copy, not a live view.
$live = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 8.0 ) ) ) ) ),
	1,
	''
);
TD_Test::ok(
	(float) $live['breakdown']['total'] !== 400000.0,
	'a fresh quote does follow the new pricing rules'
);
$frozen_v1 = $plugin->designs->get_version( $design_id, 1 );
TD_Test::equals(
	(float) $v1['price_total'],
	(float) $frozen_v1['price_total'],
	'a stored version price never changes when pricing rules change'
);

// Restore the catalogue.
$plugin->pricing->delete_rule( $new_rule );
$plugin->models->update( $tshirt_id, array( 'base_price' => 350000.0, 'name' => 'Classic T-Shirt' ) );
$plugin->print_areas->update( $front_id, array( 'max_width_cm' => 30.0, 'max_height_cm' => 35.0 ) );
$plugin->colors->update( $color_id, array( 'name' => 'White', 'hex' => '#FFFFFF' ) );

// A design tied to a paid order can never be mutated or deleted.
$plugin->designs->set_status( $prod_id, TShirtDesigner\Design_Manager::STATUS_PAID );
$mutate = $prod_payload;
$mutate['design_id'] = $prod_id;
$mutate_result = $plugin->designs->save( $mutate, 1, '', null );
TD_Test::ok( $mutate_result['ok'], 'saving over a paid design succeeds…' );
TD_Test::ok( (int) $mutate_result['id'] !== $prod_id, '…but it branches into a NEW design instead of editing the paid one' );

$paid_delete = $plugin->designs->delete( $prod_id, 1, '' );
TD_Test::ok( ! $paid_delete['ok'], 'a paid design cannot be deleted' );

// Cleanup must never touch protected designs.
$cleanup = new TShirtDesigner\Cleanup( $plugin );
$plugin->designs->set_status( $guest_design_id, TShirtDesigner\Design_Manager::STATUS_PAID );
$cleanup->run();
TD_Test::ok( null !== $plugin->designs->get_design( $prod_id, 1, '' ), 'cleanup keeps paid designs' );

// ============================================================ 9. REST layer

TD_Test::group( 'REST — v1 compatibility' );

wp_set_current_user( 1 );

$res = td_rest( 'GET', '/tshirt-designer/v1/models' );
TD_Test::equals( 200, $res->get_status(), 'GET /tshirt-designer/v1/models still works' );
$models_out = $res->get_data();
TD_Test::ok( is_array( $models_out ) && count( $models_out ) >= 2, 'v1 lists both models' );
TD_Test::ok( isset( $models_out[0]['model_url'], $models_out[0]['base_price'] ), 'the v1 model shape is unchanged' );

$res = td_rest( 'GET', '/tshirt-designer/v1/models/' . $tshirt_id );
TD_Test::equals( 200, $res->get_status(), 'GET a single model works' );
$model_out = $res->get_data();
foreach ( array( 'colors', 'sizes', 'print_areas', 'currency', 'base_price' ) as $key ) {
	TD_Test::ok( isset( $model_out[ $key ] ), "the v1 detail response still contains `{$key}`" );
}
TD_Test::equals( 4, count( $model_out['print_areas'] ), 'the model detail lists all print areas' );
TD_Test::ok( isset( $model_out['print_areas'][0]['uv_rect'] ), 'print areas expose their UV rect to the 3D viewer' );

$res = td_rest( 'GET', '/tshirt-designer/v1/assets' );
TD_Test::equals( 200, $res->get_status(), 'GET assets works' );
TD_Test::ok( count( $res->get_data() ) >= 10, 'the artwork library is populated' );

$res = td_rest(
	'POST',
	'/tshirt-designer/v1/price',
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'price'    => 1,
		'areas'    => array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1, 'w' => 10.0, 'h' => 8.0 ) ) ) ),
	)
);
TD_Test::equals( 200, $res->get_status(), 'POST /price works' );
$price_data = $res->get_data();
TD_Test::equals( 400000.0, (float) $price_data['breakdown']['total'], 'the REST price ignores the client price field' );

TD_Test::group( 'REST — v2 (custom-product-designer/v1)' );

$res = td_rest( 'GET', '/custom-product-designer/v1/product-types' );
TD_Test::equals( 200, $res->get_status(), 'GET product-types works' );
$pt = $res->get_data();
TD_Test::ok( count( $pt ) >= 2, 'the product type list is populated' );

$res = td_rest( 'GET', '/custom-product-designer/v1/models', array(), array( 'product_type' => 'totebag' ) );
TD_Test::equals( 200, $res->get_status(), 'models can be filtered by product type' );
$tote_models = $res->get_data();
TD_Test::equals( 1, count( $tote_models ), 'only the tote bag is returned for product_type=totebag' );
TD_Test::equals( 'classic-tote', (string) $tote_models[0]['slug'], 'the returned model is the tote bag' );

$res = td_rest( 'GET', '/custom-product-designer/v1/fonts' );
TD_Test::equals( 200, $res->get_status(), 'GET fonts works' );
TD_Test::ok( count( $res->get_data() ) >= 2, 'the font list is populated' );

$res = td_rest( 'GET', '/custom-product-designer/v1/designs/' . $design_id . '/versions' );
TD_Test::equals( 200, $res->get_status(), 'GET design versions works' );
$ver_data = $res->get_data();
TD_Test::equals( 2, count( is_array( $ver_data['versions'] ?? null ) ? $ver_data['versions'] : array() ), 'the version list is returned' );

$res = td_rest( 'POST', '/custom-product-designer/v1/designs/' . $design_id . '/duplicate' );
TD_Test::equals( 200, $res->get_status(), 'POST duplicate works' );
$dup2_id = (int) $res->get_data()['id'];
TD_Test::ok( $dup2_id > 0, 'the duplicate returns a new id' );

$res = td_rest( 'DELETE', '/custom-product-designer/v1/designs/' . $dup2_id );
TD_Test::equals( 200, $res->get_status(), 'DELETE design works' );

TD_Test::group( 'REST — permissions & IDOR' );

// Another user cannot read someone else's design over REST.
wp_set_current_user( $user2 );
$res = td_rest( 'GET', '/tshirt-designer/v1/designs/' . $design_id );
TD_Test::ok( 200 !== $res->get_status(), 'another user gets an error reading a foreign design' );

$res = td_rest( 'POST', '/custom-product-designer/v1/designs/' . $design_id . '/duplicate' );
TD_Test::ok( 200 !== $res->get_status(), 'another user cannot duplicate a foreign design over REST' );

$res = td_rest( 'DELETE', '/custom-product-designer/v1/designs/' . $design_id );
TD_Test::ok( 200 !== $res->get_status(), 'another user cannot delete a foreign design over REST' );
TD_Test::ok( null !== $plugin->designs->get_design( $design_id, 1, '' ), 'the design survived the attack' );

// Cross-origin anonymous POST is rejected.
wp_set_current_user( 0 );
unset( $_SERVER['HTTP_X_WP_NONCE'] );
$_SERVER['HTTP_ORIGIN'] = 'http://evil.example.com';
$request = new WP_REST_Request( 'POST', '/tshirt-designer/v1/price' );
$request->set_header( 'Content-Type', 'application/json' );
$request->set_body( (string) wp_json_encode( array( 'model_id' => $tshirt_id ) ) );
$res = rest_get_server()->dispatch( $request );
TD_Test::equals( 403, $res->get_status(), 'a cross-origin anonymous POST is rejected (CSRF)' );

$_SERVER['HTTP_ORIGIN'] = 'http://example.org';

// Guest designs can be switched off.
td_set_setting( array( 'allow_guest_designs' => 0 ) );
$res = td_rest( 'POST', '/tshirt-designer/v1/price', array( 'model_id' => $tshirt_id ) );
TD_Test::equals( 401, $res->get_status(), 'guests are locked out when guest designs are disabled' );
td_set_setting( array( 'allow_guest_designs' => 1 ) );

$res = td_rest( 'POST', '/tshirt-designer/v1/price', array( 'model_id' => $tshirt_id, 'color_id' => $color_id, 'size_id' => $size_id, 'areas' => array() ) );
TD_Test::equals( 200, $res->get_status(), 'guests work again once re-enabled' );

// Guest uploads can be switched off independently.
td_set_setting( array( 'allow_guest_uploads' => 0 ) );
$res = td_rest( 'POST', '/tshirt-designer/v1/uploads' );
TD_Test::equals( 401, $res->get_status(), 'guest uploads can be disabled separately' );
td_set_setting( array( 'allow_guest_uploads' => 1 ) );

// Every registered route declares a permission callback.
wp_set_current_user( 1 );
$routes  = rest_get_server()->get_routes();
$no_perm = array();
foreach ( $routes as $route => $handlers ) {
	if ( ! str_contains( $route, 'tshirt-designer' ) && ! str_contains( $route, 'custom-product-designer' ) ) {
		continue;
	}
	// The bare namespace index route is registered by WordPress itself.
	if ( '/tshirt-designer/v1' === $route || '/custom-product-designer/v1' === $route ) {
		continue;
	}
	foreach ( $handlers as $handler ) {
		if ( empty( $handler['permission_callback'] ) ) {
			$no_perm[] = $route;
		}
	}
}
TD_Test::equals( array(), $no_perm, 'every plugin REST route has a permission callback' );

// ==================================================== 10. Cleanup semantics

TD_Test::group( 'Lifecycle — cleanup safety' );

$stale_guest = str_repeat( 'c', 32 );
$stale = $plugin->designs->save( $guest_payload, 0, $stale_guest, null );
$stale_id = (int) $stale['id'];
global $wpdb;
$wpdb->update(
	$plugin->db->table( 'designs' ),
	array( 'updated_at' => gmdate( 'Y-m-d H:i:s', time() - 400 * DAY_IN_SECONDS ) ),
	array( 'id' => $stale_id )
);
$result = $cleanup->run();
TD_Test::ok( $result['designs'] >= 1, 'cleanup removes stale guest drafts' );
TD_Test::ok( null === $plugin->designs->get_design( $stale_id, 0, $stale_guest ), 'the stale draft is gone' );
TD_Test::ok( null !== $plugin->designs->get_design( $design_id, 1, '' ), 'account designs are never touched by cleanup' );

// ==================================================== 11. Error handling

TD_Test::group( 'Errors — graceful degradation' );

$deleted_model = $plugin->models->insert(
	array( 'name' => 'Temp', 'slug' => 'temp-model', 'product_type' => 'tshirt', 'base_price' => 100.0, 'is_active' => 1 )
);
$temp_saved = $plugin->designs->save(
	$design_payload( $deleted_model, 0, 0, array() ),
	1,
	'',
	null
);
TD_Test::ok( ! $temp_saved['ok'], 'a design without a valid colour/size is refused rather than fataling' );

$plugin->models->update( $tshirt_id, array( 'is_active' => 0 ) );
$q = $plugin->designs->quote(
	$design_payload( $tshirt_id, $color_id, $size_id, array() ),
	1,
	''
);
TD_Test::ok( ! $q['ok'], 'an inactive model produces an error, not a crash' );
$plugin->models->update( $tshirt_id, array( 'is_active' => 1 ) );

$missing_asset = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'ref_id' => 999999 ) ) ) ) ),
	1,
	''
);
TD_Test::ok( ! $missing_asset['ok'], 'a deleted asset produces a clear error' );

$foreign_upload = $plugin->designs->validate_design(
	$design_payload( $tshirt_id, $color_id, $size_id, array( (string) $front_id => array( $make_item( array( 'type' => 'upload', 'ref_id' => $upload_id ) ) ) ) ),
	$user2,
	''
);
TD_Test::ok( ! $foreign_upload['ok'], 'a user cannot place another user\'s upload on their design' );

$no_snapshot = $plugin->designs->build_snapshot( 99999999, 1 );
TD_Test::ok( null === $no_snapshot, 'building a snapshot for a missing design returns null' );

TD_Test::group( 'Logging' );

$plugin->logger->error( TShirtDesigner\Logger::CHANNEL_ORDER, 'Test failure', array( 'order_id' => 5, 'guest_token' => 'secret-token-value', 'email' => 'a@b.c' ) );
$logs = $plugin->logger->recent( 5, TShirtDesigner\Logger::CHANNEL_ORDER );
TD_Test::ok( count( $logs ) >= 1, 'log rows are written' );
$ctx = $logs[0]['context'];
TD_Test::equals( 5, (int) $ctx['order_id'], 'the safe context is kept' );
TD_Test::equals( '[redacted]', (string) $ctx['guest_token'], 'guest tokens are redacted from logs' );
TD_Test::equals( '[redacted]', (string) $ctx['email'], 'emails are redacted from logs' );

// ======================================================= 12. WooCommerce

TD_Test::group( 'WooCommerce integration' );

if ( TShirtDesigner\Woocommerce::is_active() ) {
	TD_Test::ok( null !== $plugin->cart, 'the cart manager is wired when WooCommerce is active' );
} else {
	TD_Test::ok( null === $plugin->cart, 'the plugin degrades gracefully without WooCommerce' );
	TD_Test::ok( true, 'WooCommerce is not installed in this test environment (cart/order tested separately)' );
}

// Order manager statuses are complete.
$statuses = TShirtDesigner\Order_Manager::statuses();
foreach ( array( 'new', 'paid', 'ready_for_production', 'in_production', 'printed', 'quality_check', 'shipped', 'completed', 'cancelled' ) as $needed ) {
	TD_Test::ok( isset( $statuses[ $needed ] ), "production status `{$needed}` exists" );
}

TD_Test::group( 'Localization' );

// A malformed .mo is silently ignored by WordPress: every string just falls
// back to English with no warning anywhere. That is exactly how the Persian
// catalog shipped broken, so the file is now parsed for real in tests.
$td_mo = TD_PLUGIN_DIR . 'languages/tshirt-designer-fa_IR.mo';
TD_Test::ok( file_exists( $td_mo ), 'the Persian .mo file ships with the plugin' );

$td_catalog = new MO();
TD_Test::ok( $td_catalog->import_from_file( $td_mo ), 'WordPress can actually parse the Persian .mo' );
TD_Test::ok( count( $td_catalog->entries ) > 300, 'the catalog holds the full string set' );

foreach ( array( 'Add to cart', 'Order again', 'Add text', 'Custom Product Designer' ) as $td_string ) {
	$td_entry = $td_catalog->entries[ $td_string ] ?? null;
	TD_Test::ok(
		null !== $td_entry && '' !== (string) $td_entry->translations[0] && $td_entry->translations[0] !== $td_string,
		sprintf( '"%s" is translated into Persian', $td_string )
	);
}

// Nothing may ship untranslated: this shop is Persian-facing.
$td_missing = array();
foreach ( $td_catalog->entries as $td_key => $td_entry ) {
	if ( '' === $td_key ) {
		continue;
	}
	if ( '' === trim( (string) ( $td_entry->translations[0] ?? '' ) ) ) {
		$td_missing[] = $td_key;
	}
}
TD_Test::equals( 0, count( $td_missing ), 'no string is left untranslated' . ( $td_missing ? ' :: ' . implode( ' | ', array_slice( $td_missing, 0, 5 ) ) : '' ) );

exit( TD_Test::summary() );
