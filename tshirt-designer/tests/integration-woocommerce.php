<?php
/**
 * WooCommerce integration tests: cart, persistence, checkout, order meta,
 * production snapshot immutability, production files, ZIP and "order again".
 *
 * Requires a WordPress install with WooCommerce active.
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

// phpcs:disable WordPress.Security.NonceVerification, WordPress.PHP.DevelopmentFunctions

require_once __DIR__ . '/bootstrap-wp.php';

update_option(
	'active_plugins',
	array( 'woocommerce/woocommerce.php', 'tshirt-designer/tshirt-designer.php' )
);
require_once WP_PLUGIN_DIR . '/woocommerce/woocommerce.php';
do_action( 'plugins_loaded' );

if ( class_exists( 'WC_Install' ) && get_option( 'woocommerce_version' ) !== WC()->version ) {
	WC_Install::install();
}

td_test_activate_plugin();
// WooCommerce only loads its cart/checkout helpers on front-end requests.
foreach ( array( 'wc-cart-functions.php', 'wc-notice-functions.php', 'wc-template-functions.php' ) as $wc_inc ) {
	$wc_path = WP_PLUGIN_DIR . '/woocommerce/includes/' . $wc_inc;
	if ( is_readable( $wc_path ) ) {
		require_once $wc_path;
	}
}

do_action( 'init' );
do_action( 'woocommerce_init' );

$plugin = td_plugin();

TD_Test::group( 'WooCommerce — environment' );

TD_Test::ok( class_exists( 'WooCommerce' ), 'WooCommerce is loaded' );
TD_Test::ok( TShirtDesigner\Woocommerce::is_active(), 'the plugin detects WooCommerce' );
TD_Test::ok( null !== $plugin->cart, 'the cart manager is wired' );
TD_Test::ok( null !== $plugin->orders, 'the order manager is wired' );

// WooCommerce needs a session + cart in a CLI-ish context.
if ( null === WC()->session ) {
	WC()->initialize_session();
}
if ( null === WC()->cart ) {
	WC()->initialize_cart();
}
TD_Test::ok( null !== WC()->cart, 'a WooCommerce cart is available' );

// -------------------------------------------------------------- fixtures

wp_set_current_user( 1 );

$tshirt    = $plugin->models->get_by_slug( 'classic-tshirt' );
$tote      = $plugin->models->get_by_slug( 'classic-tote' );
$tshirt_id = (int) $tshirt['id'];
$tote_id   = (int) $tote['id'];

$color_id = (int) $plugin->colors->for_model( $tshirt_id )[0]['id'];
$size_id  = 0;
foreach ( $plugin->sizes->for_model( $tshirt_id ) as $s ) {
	if ( 'XL' === (string) $s['name'] ) {
		$size_id = (int) $s['id'];
	}
}
$front_id = 0;
$back_id  = 0;
foreach ( $plugin->print_areas->for_model( $tshirt_id ) as $a ) {
	if ( 'front' === (string) $a['area_type'] ) {
		$front_id = (int) $a['id'];
	}
	if ( 'back' === (string) $a['area_type'] ) {
		$back_id = (int) $a['id'];
	}
}
$tb_color   = (int) $plugin->colors->for_model( $tote_id )[0]['id'];
$tb_size    = (int) $plugin->sizes->for_model( $tote_id )[0]['id'];
$tb_front   = 0;
foreach ( $plugin->print_areas->for_model( $tote_id ) as $a ) {
	if ( 'front' === (string) $a['area_type'] ) {
		$tb_front = (int) $a['id'];
	}
}
$asset1 = (int) $plugin->assets->all( true )[0]['id'];
$asset2 = (int) $plugin->assets->all( true )[1]['id'];

$make_item = static function ( array $o = array() ): array {
	return array_merge(
		array(
			'id'       => 'i-' . wp_generate_password( 6, false, false ),
			'type'     => 'asset',
			'ref_id'   => 0,
			'x'        => 15.0,
			'y'        => 17.5,
			'w'        => 12.0,
			'h'        => 12.0,
			'rotation' => 0.0,
			'layer'    => 0,
			'opacity'  => 1.0,
		),
		$o
	);
};

// Real WooCommerce products backing the models.
TD_Test::group( 'WooCommerce — product linking' );

$wc_shirt = new WC_Product_Simple();
$wc_shirt->set_name( 'Classic T-Shirt (designable)' );
$wc_shirt->set_regular_price( '350000' );
$wc_shirt->set_catalog_visibility( 'visible' );
$wc_shirt->set_status( 'publish' );
$wc_shirt_id = $wc_shirt->save();

$wc_tote = new WC_Product_Simple();
$wc_tote->set_name( 'Classic Tote (designable)' );
$wc_tote->set_regular_price( '220000' );
$wc_tote->set_status( 'publish' );
$wc_tote_id = $wc_tote->save();

TD_Test::ok( $wc_shirt_id > 0 && $wc_tote_id > 0, 'WooCommerce products can be created' );

// The cart must refuse a model that has no linked product yet.
$unlinked = $plugin->designs->save(
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array( (string) $front_id => array( $make_item( array( 'ref_id' => $asset1 ) ) ) ),
	),
	1,
	'',
	null
);
$refused = $plugin->cart->add_to_cart( (int) $unlinked['id'], 1, 1, '' );
TD_Test::ok( ! $refused['ok'], 'a model without a WooCommerce product cannot be added to the cart' );

$plugin->models->update( $tshirt_id, array( 'wc_product_id' => $wc_shirt_id ) );
$plugin->models->update( $tote_id, array( 'wc_product_id' => $wc_tote_id ) );
TD_Test::equals( $wc_shirt_id, (int) $plugin->models->get( $tshirt_id )['wc_product_id'], 'the t-shirt model links to its product' );

// Base price now comes from WooCommerce.
TD_Test::equals(
	350000.0,
	$plugin->models->base_price( $plugin->models->get( $tshirt_id ) ),
	'the WooCommerce price is used as the base price'
);

// ------------------------------------------------------------- add to cart

TD_Test::group( 'Cart — add to cart' );

WC()->cart->empty_cart();

$design = $plugin->designs->save(
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array(
			(string) $front_id => array(
				$make_item( array( 'ref_id' => $asset1, 'w' => 12.0, 'h' => 12.0, 'x' => 10.0, 'y' => 12.0, 'layer' => 0 ) ),
				$make_item( array( 'ref_id' => $asset2, 'w' => 8.0, 'h' => 8.0, 'x' => 22.0, 'y' => 26.0, 'layer' => 1 ) ),
			),
			(string) $back_id  => array(
				$make_item( array( 'ref_id' => $asset2, 'w' => 25.0, 'h' => 20.0 ) ),
			),
		),
	),
	1,
	'',
	null
);
TD_Test::ok( $design['ok'], 'the design to be purchased saves' );
$design_id  = (int) $design['id'];
$design_ver = (int) $design['version'];
$expected   = (float) $plugin->designs->get_design( $design_id, 1, '' )['price_total'];
// base 350k + XL 20k + front 12cm (80k) + front 8cm (50k + 20k 2nd-item) + back 25cm (120k).
TD_Test::equals( 640000.0, $expected, 'the server price for the purchased design is 640,000' );

$added = $plugin->cart->add_to_cart( $design_id, 2, 1, '' );
TD_Test::ok( $added['ok'], 'the design is added to the cart' . ( $added['ok'] ? '' : ' :: ' . implode( ' | ', $added['errors'] ) ) );
$cart_key = (string) ( $added['cart_item_key'] ?? '' );
TD_Test::ok( '' !== $cart_key, 'a cart item key is returned' );
TD_Test::equals( 1, count( WC()->cart->get_cart() ), 'the cart holds one line' );

$cart_item = WC()->cart->get_cart_item( $cart_key );
TD_Test::ok( is_array( $cart_item ), 'the cart item can be read back' );
$payload = $cart_item[ TShirtDesigner\Cart_Manager::CART_KEY ] ?? array();
TD_Test::equals( $design_id, (int) $payload['design_id'], 'cart item data: design id' );
TD_Test::equals( $design_ver, (int) $payload['design_version'], 'cart item data: design version' );
TD_Test::equals( 'tshirt', (string) $payload['product_type'], 'cart item data: product type' );
TD_Test::equals( $tshirt_id, (int) $payload['model_id'], 'cart item data: model' );
TD_Test::equals( $color_id, (int) $payload['color_id'], 'cart item data: colour' );
TD_Test::equals( $size_id, (int) $payload['size_id'], 'cart item data: size' );
TD_Test::ok( isset( $payload['snapshot']['areas'] ), 'cart item data: production snapshot' );
TD_Test::ok( isset( $payload['pricing']['total'] ), 'cart item data: price snapshot' );
TD_Test::equals( 3, (int) $payload['item_count'], 'cart item data: item count' );
TD_Test::equals( 2, (int) $cart_item['quantity'], 'the requested quantity is honoured' );

// Server-side price wins on the cart line.
WC()->cart->calculate_totals();
$cart_item = WC()->cart->get_cart_item( $cart_key );
TD_Test::equals( 640000.0, (float) $cart_item['data']->get_price(), 'the cart line uses the server-computed unit price' );
TD_Test::equals( 1280000.0, (float) WC()->cart->get_subtotal(), 'the cart subtotal is unit price x quantity' );

// The design is marked as ordered and therefore locked.
TD_Test::equals(
	TShirtDesigner\Design_Manager::STATUS_ORDERED,
	(string) $plugin->designs->get_design( $design_id, 1, '' )['status'],
	'the purchased design is marked as ordered'
);
$locked = $plugin->designs->delete( $design_id, 1, '' );
TD_Test::ok( ! $locked['ok'], 'a design in the cart cannot be deleted' );

TD_Test::group( 'Cart — price manipulation & ownership' );

// Forge the cart line price directly, then let WooCommerce recalculate.
$cart_contents = WC()->cart->get_cart_contents();
$cart_contents[ $cart_key ][ TShirtDesigner\Cart_Manager::CART_KEY ]['unit_price'] = 1.0;
$cart_contents[ $cart_key ]['data']->set_price( '1' );
WC()->cart->set_cart_contents( $cart_contents );
WC()->cart->calculate_totals();
$after = WC()->cart->get_cart_item( $cart_key );
TD_Test::ok(
	(float) $after['data']->get_price() >= 640000.0,
	'tampering with the cart line price is corrected on recalculation'
);

// Another customer cannot add someone else's design.
$user2 = wp_insert_user(
	array( 'user_login' => 'wc_customer2', 'user_pass' => 'pass-123456', 'user_email' => 'wc2@example.org', 'role' => 'customer' )
);
$user2 = is_wp_error( $user2 ) ? (int) get_user_by( 'login', 'wc_customer2' )->ID : (int) $user2;
$steal = $plugin->cart->add_to_cart( $design_id, 1, $user2, '' );
TD_Test::ok( ! $steal['ok'], 'another customer cannot add a foreign design to their cart' );

// A missing design fails cleanly.
$ghost = $plugin->cart->add_to_cart( 99999999, 1, 1, '' );
TD_Test::ok( ! $ghost['ok'], 'adding a non-existent design fails cleanly' );

TD_Test::group( 'Cart — persistence across a page load' );

// Simulate a refresh: WooCommerce serialises the cart into the session and
// rebuilds the objects from it on the next request.
WC()->cart->set_session();
$session_cart = WC()->session->get( 'cart' );
TD_Test::ok( is_array( $session_cart ) && isset( $session_cart[ $cart_key ] ), 'the cart line is stored in the session' );
TD_Test::ok(
	isset( $session_cart[ $cart_key ][ TShirtDesigner\Cart_Manager::CART_KEY ]['snapshot'] ),
	'the design payload survives serialisation into the session'
);

WC()->cart->empty_cart( false );
TD_Test::equals( 0, count( WC()->cart->get_cart() ), 'the in-memory cart is cleared' );

WC()->session->set( 'cart', $session_cart );
WC()->cart->get_cart_from_session();
$restored = WC()->cart->get_cart();
TD_Test::equals( 1, count( $restored ), 'the cart is restored from the session (refresh-safe)' );
$restored_item = WC()->cart->get_cart_item( $cart_key );
$restored_pl   = $restored_item[ TShirtDesigner\Cart_Manager::CART_KEY ] ?? array();
TD_Test::equals( $design_id, (int) ( $restored_pl['design_id'] ?? 0 ), 'the restored line still knows its design' );
TD_Test::equals( $design_ver, (int) ( $restored_pl['design_version'] ?? 0 ), 'the restored line still knows its version' );
TD_Test::ok( isset( $restored_pl['snapshot']['areas'] ), 'the restored line still carries the snapshot' );
WC()->cart->calculate_totals();
TD_Test::equals(
	640000.0,
	(float) WC()->cart->get_cart_item( $cart_key )['data']->get_price(),
	'the restored line is still priced correctly'
);

// Cart display data is human readable.
$display = $plugin->cart->display_cart_item_data( array(), $restored_item );
$labels  = array_column( $display, 'key' );
TD_Test::ok( count( $display ) >= 3, 'the cart shows the design details' );
TD_Test::ok( in_array( __( 'Design', 'tshirt-designer' ), $labels, true ), 'the design code is shown in the cart' );
TD_Test::ok( in_array( __( 'Model', 'tshirt-designer' ), $labels, true ), 'the model is shown in the cart' );
TD_Test::ok( in_array( __( 'Size', 'tshirt-designer' ), $labels, true ), 'the size is shown in the cart' );

// ------------------------------------------------------------- checkout

TD_Test::group( 'Checkout — order creation' );

$customer_id = wp_insert_user(
	array( 'user_login' => 'buyer1', 'user_pass' => 'pass-123456', 'user_email' => 'buyer1@example.org', 'role' => 'customer' )
);
$customer_id = is_wp_error( $customer_id ) ? (int) get_user_by( 'login', 'buyer1' )->ID : (int) $customer_id;

$checkout = WC()->checkout();
$order_id = $checkout->create_order(
	array(
		'billing_first_name' => 'Ali',
		'billing_last_name'  => 'Test',
		'billing_email'      => 'buyer1@example.org',
		'billing_country'    => 'IR',
		'payment_method'     => 'cod',
	)
);
TD_Test::ok( ! is_wp_error( $order_id ) && (int) $order_id > 0, 'an order is created from the cart' );
$order_id = (int) $order_id;
$order    = wc_get_order( $order_id );
TD_Test::ok( $order instanceof WC_Order, 'the order can be loaded' );

$items = $order->get_items();
TD_Test::equals( 1, count( $items ), 'the order has one line item' );
$item = array_values( $items )[0];

TD_Test::group( 'Order — item meta' );

$M = TShirtDesigner\Order_Manager::class;
TD_Test::equals( $design_id, (int) $item->get_meta( TShirtDesigner\Order_Manager::META_DESIGN_ID ), 'order meta: design id' );
TD_Test::equals( $design_ver, (int) $item->get_meta( TShirtDesigner\Order_Manager::META_VERSION ), 'order meta: design version' );
TD_Test::equals( 'tshirt', (string) $item->get_meta( TShirtDesigner\Order_Manager::META_PRODUCT_TYPE ), 'order meta: product type' );
TD_Test::ok( '' !== (string) $item->get_meta( TShirtDesigner\Order_Manager::META_DESIGN_UUID ), 'order meta: design uuid' );
TD_Test::ok( '' !== (string) $item->get_meta( TShirtDesigner\Order_Manager::META_DESIGN_CODE ), 'order meta: customer-visible design code' );
TD_Test::equals( 'XL', (string) $item->get_meta( TShirtDesigner\Order_Manager::META_SIZE ), 'order meta: customer-visible size' );

$order_snapshot = $plugin->orders->snapshot_from_item( $item );
TD_Test::ok( is_array( $order_snapshot ) && isset( $order_snapshot['areas'] ), 'order meta: the production snapshot is stored' );
TD_Test::equals( 2, count( $order_snapshot['areas'] ), 'the order snapshot has both designed areas' );
TD_Test::equals( 3, (int) $order_snapshot['item_count'], 'the order snapshot has all three artwork items' );

$order_pricing = $plugin->orders->pricing_from_item( $item );
TD_Test::equals( 640000.0, (float) $order_pricing['total'], 'order meta: the price snapshot matches what was charged' );
TD_Test::equals( 1280000.0, (float) $item->get_total(), 'the order line total is unit price x 2' );

TD_Test::group( 'Order — snapshot immutability' );

// Change the catalogue after the order.
$plugin->models->update( $tshirt_id, array( 'base_price' => 999000.0, 'name' => 'Totally Different Shirt' ) );
$plugin->print_areas->update( $front_id, array( 'max_width_cm' => 9.0, 'max_height_cm' => 9.0 ) );
$rule = $plugin->pricing->save_rule(
	array(
		'rule_type'    => TShirtDesigner\Pricing_Engine::RULE_SIZE_TIER,
		'scope'        => 'global',
		'size_from_cm' => 0.0,
		'size_to_cm'   => 100.0,
		'price'        => 5000.0,
		'is_active'    => 1,
		'sort_order'   => -10,
	)
);

$order_after = wc_get_order( $order_id );
$item_after  = array_values( $order_after->get_items() )[0];
$snap_after  = $plugin->orders->snapshot_from_item( $item_after );
TD_Test::equals(
	wp_json_encode( $order_snapshot ),
	wp_json_encode( $snap_after ),
	'the stored order snapshot is byte-identical after catalogue changes'
);
TD_Test::equals(
	640000.0,
	(float) $plugin->orders->pricing_from_item( $item_after )['total'],
	'the order price is unchanged by new pricing rules'
);
TD_Test::equals( 1280000.0, (float) $item_after->get_total(), 'the historical order total is untouched' );
TD_Test::equals(
	30.0,
	(float) $snap_after['areas'][0]['max_width_cm'],
	'the snapshot still records the print area size as it was at purchase'
);

// -------------------------------------------------------- payment + files

TD_Test::group( 'Payment — production files' );

$order_after->update_status( 'processing' );
$order_after->payment_complete( 'test-txn-1' );

$gen = $plugin->orders->generate_for_order( $order_id, true );
TD_Test::ok( is_array( $gen ), 'production generation runs for the order' );

$files = $plugin->production->for_order( $order_id );
TD_Test::equals( 2, count( $files ), 'two production files are generated (front + back)' );

$by_type = array();
foreach ( $files as $f ) {
	$by_type[ (string) $f['area_type'] ] = $f;
}
TD_Test::ok( isset( $by_type['front'], $by_type['back'] ), 'the files cover exactly the designed areas' );

foreach ( $by_type as $type => $f ) {
	TD_Test::ok( file_exists( (string) $f['file_path'] ), "the {$type} print file exists on disk" );
	$info = getimagesize( (string) $f['file_path'] );
	TD_Test::equals( 'image/png', (string) $info['mime'], "the {$type} print file is a PNG" );
	$expect_cm = 'front' === $type ? array( 30.0, 35.0 ) : array( 30.0, 35.0 );
	[ $ew, $eh ] = TShirtDesigner\Production_Renderer::pixel_size( $expect_cm[0], $expect_cm[1], (int) $order_snapshot['dpi'] );
	TD_Test::equals( $ew, (int) $info[0], "the {$type} print file is sized from the snapshot, not the live area" );
	TD_Test::equals( $eh, (int) $info[1], "the {$type} print file height is correct" );
	TD_Test::ok(
		str_contains( (string) $f['file_name'], 'ORDER-' . $order_id ) && str_contains( (string) $f['file_name'], strtoupper( $type ) ),
		"the {$type} file name follows the naming contract"
	);
}

// Transparency preserved through the whole purchase pipeline.
$png = imagecreatefrompng( (string) $by_type['front']['file_path'] );
TD_Test::equals( 127, ( imagecolorat( $png, 3, 3 ) >> 24 ) & 0x7F, 'the delivered print file has a transparent background' );
imagedestroy( $png );

// Regeneration is deterministic and driven by the snapshot only.
$before_sizes = array_map( static fn( $f ) => filesize( (string) $f['file_path'] ), $by_type );
$plugin->orders->generate_for_order( $order_id, true );
$files_again = $plugin->production->for_order( $order_id );
TD_Test::equals( 2, count( $files_again ), 'regeneration does not duplicate rows' );
$after_sizes = array();
foreach ( $files_again as $f ) {
	$after_sizes[ (string) $f['area_type'] ] = filesize( (string) $f['file_path'] );
}
TD_Test::equals( $before_sizes['front'], $after_sizes['front'], 'regenerated output is identical (snapshot-driven, not live-data-driven)' );

TD_Test::group( 'Production — ZIP download' );

$zip = $plugin->production->build_zip( $order_id );
TD_Test::ok( is_array( $zip ) && ! empty( $zip['path'] ) && file_exists( (string) $zip['path'] ), 'a ZIP of all print files is produced' );
if ( is_array( $zip ) && ! empty( $zip['path'] ) ) {
	$za = new ZipArchive();
	TD_Test::ok( true === $za->open( (string) $zip['path'] ), 'the ZIP opens' );
	TD_Test::equals( 2, $za->numFiles, 'the ZIP contains both print files' );
	$names = array();
	for ( $i = 0; $i < $za->numFiles; $i++ ) {
		$names[] = (string) $za->getNameIndex( $i );
	}
	$za->close();
	TD_Test::ok(
		(bool) preg_grep( '/FRONT\.png$/', $names ) && (bool) preg_grep( '/BACK\.png$/', $names ),
		'the ZIP entries are named per the contract'
	);
}

TD_Test::group( 'Production — status workflow' );

foreach ( array( 'ready_for_production', 'in_production', 'printed', 'shipped', 'completed' ) as $status ) {
	$plugin->orders->set_production_status( $order_id, $status );
	TD_Test::equals(
		$status,
		(string) wc_get_order( $order_id )->get_meta( TShirtDesigner\Order_Manager::META_PRODUCTION_STATUS ),
		"the order can move to `{$status}`"
	);
}
$plugin->orders->set_production_status( $order_id, 'not-a-status' );
TD_Test::ok(
	in_array( (string) wc_get_order( $order_id )->get_meta( TShirtDesigner\Order_Manager::META_PRODUCTION_STATUS ), array_keys( TShirtDesigner\Order_Manager::statuses() ), true ),
	'an invalid production status is rejected'
);

TD_Test::group( 'Order — cleanup never touches sold work' );

$paid_design = $plugin->designs->get_design( $design_id, 1, '' );
TD_Test::ok(
	in_array( (string) $paid_design['status'], TShirtDesigner\Design_Manager::PROTECTED_STATUSES, true ),
	'the purchased design is in a protected state'
);

global $wpdb;
$wpdb->update(
	$plugin->db->table( 'designs' ),
	array( 'updated_at' => gmdate( 'Y-m-d H:i:s', time() - 900 * DAY_IN_SECONDS ) ),
	array( 'id' => $design_id )
);
( new TShirtDesigner\Cleanup( $plugin ) )->run();
TD_Test::ok( null !== $plugin->designs->get_design( $design_id, 1, '' ), 'cleanup never deletes a paid design, however old' );
TD_Test::equals( 2, count( $plugin->production->for_order( $order_id ) ), 'cleanup never deletes production files of a paid order' );
foreach ( $plugin->production->for_order( $order_id ) as $f ) {
	TD_Test::ok( file_exists( (string) $f['file_path'] ), 'the print file on disk survives cleanup' );
}

// Restore the catalogue before re-ordering so the test exercises the
// re-order path rather than the (already covered) validation path.
$plugin->pricing->delete_rule( $rule );
$plugin->models->update( $tshirt_id, array( 'base_price' => 350000.0, 'name' => 'Classic T-Shirt' ) );
$plugin->print_areas->update( $front_id, array( 'max_width_cm' => 30.0, 'max_height_cm' => 35.0 ) );

TD_Test::group( 'Order again' );

$again = $plugin->orders->order_again( $order_id, (int) $item->get_id(), 1, '' );
TD_Test::ok( $again['ok'], 'a past order can be re-ordered' . ( $again['ok'] ? '' : ' :: ' . implode( ' | ', $again['errors'] ) ) );
TD_Test::ok( (int) $again['id'] !== $design_id, 'ordering again creates a new editable design' );
$again_row = $again['ok'] ? $plugin->designs->get_design( (int) $again['id'], 1, '' ) : null;
TD_Test::ok( null !== $again_row, 'the re-ordered design is readable' );
TD_Test::ok(
	is_array( $again_row ) && ! in_array( (string) $again_row['status'], TShirtDesigner\Design_Manager::PROTECTED_STATUSES, true ),
	'the re-ordered design is editable again'
);
TD_Test::equals(
	3,
	is_array( $again_row ) ? array_sum( array_map( 'count', $again_row['design_data']['areas'] ) ) : 0,
	'the re-ordered design carries the same three artwork items'
);

// The original order is untouched by the re-order.
TD_Test::equals(
	wp_json_encode( $order_snapshot ),
	wp_json_encode( $plugin->orders->snapshot_from_item( array_values( wc_get_order( $order_id )->get_items() )[0] ) ),
	'ordering again does not modify the original order'
);

TD_Test::group( 'Tote bag — full purchase cycle' );

WC()->cart->empty_cart();

$tote_design = $plugin->designs->save(
	array(
		'model_id' => $tote_id,
		'color_id' => $tb_color,
		'size_id'  => $tb_size,
		'areas'    => array( (string) $tb_front => array( $make_item( array( 'ref_id' => $asset1, 'w' => 12.0, 'h' => 12.0, 'x' => 14.0, 'y' => 16.0 ) ) ) ),
	),
	1,
	'',
	null
);
TD_Test::ok( $tote_design['ok'], 'a tote bag design saves' );

$tote_added = $plugin->cart->add_to_cart( (int) $tote_design['id'], 1, 1, '' );
TD_Test::ok( $tote_added['ok'], 'the tote bag is added to the cart' . ( $tote_added['ok'] ? '' : ' :: ' . implode( ' | ', $tote_added['errors'] ) ) );

$tote_order_id = WC()->checkout()->create_order(
	array( 'billing_email' => 'buyer1@example.org', 'billing_country' => 'IR', 'payment_method' => 'cod' )
);
TD_Test::ok( ! is_wp_error( $tote_order_id ), 'the tote bag order is created' );
$tote_order_id = (int) $tote_order_id;
wc_get_order( $tote_order_id )->payment_complete( 'test-txn-2' );
$plugin->orders->generate_for_order( $tote_order_id, true );

$tote_files = $plugin->production->for_order( $tote_order_id );
TD_Test::equals( 1, count( $tote_files ), 'only the designed tote side produces a print file' );
TD_Test::equals( 'front', (string) $tote_files[0]['area_type'], 'the tote print file is the front' );
$ti = getimagesize( (string) $tote_files[0]['file_path'] );
[ $tw, $th ] = TShirtDesigner\Production_Renderer::pixel_size( 28.0, 32.0, 300 );
TD_Test::equals( $tw, (int) $ti[0], 'the tote print file uses the tote print size (28cm), not the t-shirt one' );
TD_Test::equals( $th, (int) $ti[1], 'the tote print file height uses the tote print size (32cm)' );

TD_Test::group( 'Designer boot data — cart integration' );

// The Add to Cart button in templates/designer.php is gated on this flag, so
// the flag flipping to true with WooCommerce active is what actually makes
// the sales cycle reachable from the designer.
$boot = TShirtDesigner\Assets::boot_data( $plugin, 0, 0 );
TD_Test::ok( ! empty( $boot['hasWoo'] ), 'boot data reports WooCommerce as available' );
TD_Test::ok(
	str_contains( (string) $boot['restUrlV2'], TShirtDesigner\Rest_Api_V2::NS ),
	'boot data exposes the v2 REST namespace used by the cart route'
);
TD_Test::ok( ! empty( $boot['i18n']['addToCart'] ), 'the Add to cart label is translated into boot data' );

$designer_tpl = (string) file_get_contents( TD_PLUGIN_DIR . 'templates/designer.php' );
TD_Test::ok(
	str_contains( $designer_tpl, 'data-td-el="addToCart"' ),
	'the designer template renders an Add to cart control'
);

TD_Test::group( 'My Designs — order again' );

// $design_id was ordered and paid earlier in this suite, so it is locked.
$locked = $plugin->designs->get_design( (int) $design_id, 1, '' );
TD_Test::ok(
	in_array( (string) $locked['status'], TShirtDesigner\Design_Manager::PROTECTED_STATUSES, true ),
	'the purchased design is in a protected status'
);

$before_version = (int) $locked['version'];
$before_status  = (string) $locked['status'];

WC()->cart->empty_cart();

// Drive the same private path the nonced My Designs link uses.
$reorder = new ReflectionMethod( TShirtDesigner\My_Designs::class, 'reorder' );
$reorder->setAccessible( true );
$notice = (string) $reorder->invoke( new TShirtDesigner\My_Designs( $plugin ), (int) $design_id, 1 );
TD_Test::equals( 'reordered', $notice, 'ordering again succeeds' );

$after = $plugin->designs->get_design( (int) $design_id, 1, '' );
TD_Test::equals( $before_version, (int) $after['version'], 'the purchased design is not re-versioned' );
TD_Test::equals( $before_status, (string) $after['status'], 'the purchased design keeps its status' );

$cart_rows = array_values( WC()->cart->get_cart() );
TD_Test::equals( 1, count( $cart_rows ), 'exactly one line is added to the cart' );
$carted_id = (int) $cart_rows[0][ TShirtDesigner\Cart_Manager::CART_KEY ]['design_id'];
TD_Test::ok( $carted_id > 0, 'the cart line carries a design id' );
TD_Test::ok(
	$carted_id !== (int) $design_id,
	'the cart holds a COPY, so the historical order record can never be edited'
);

$copy = $plugin->designs->get_design( $carted_id, 1, '' );
TD_Test::equals(
	(string) $locked['uuid'] === (string) $copy['uuid'] ? 'same' : 'different',
	'different',
	'the copy gets its own design code'
);

// A design belonging to somebody else must not be reorderable.
$other = (string) $reorder->invoke( new TShirtDesigner\My_Designs( $plugin ), (int) $design_id, 99999 );
TD_Test::equals( 'error', $other, 'another user cannot order somebody else\'s design again' );

exit( TD_Test::summary() );
