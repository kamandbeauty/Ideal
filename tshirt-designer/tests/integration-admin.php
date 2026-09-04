<?php
/**
 * Admin integration tests: order production panel, downloads, ZIP,
 * regenerate-from-snapshot, design library filters and product type screen.
 *
 * Runs against a real WordPress + WooCommerce install.
 *
 * @package TShirtDesigner
 */

// phpcs:disable WordPress.Security.NonceVerification, WordPress.PHP.DevelopmentFunctions

require_once __DIR__ . '/bootstrap-wp.php';

update_option(
	'active_plugins',
	array( 'woocommerce/woocommerce.php', 'tshirt-designer/tshirt-designer.php' )
);
require_once WP_PLUGIN_DIR . '/woocommerce/woocommerce.php';
do_action( 'plugins_loaded' );

foreach ( array( 'wc-cart-functions.php', 'wc-notice-functions.php', 'wc-template-functions.php' ) as $wc_inc ) {
	$wc_path = WP_PLUGIN_DIR . '/woocommerce/includes/' . $wc_inc;
	if ( is_readable( $wc_path ) ) {
		require_once $wc_path;
	}
}

if ( class_exists( 'WC_Install' ) && get_option( 'woocommerce_version' ) !== WC()->version ) {
	WC_Install::install();
}

td_test_activate_plugin();
do_action( 'init' );
do_action( 'woocommerce_init' );

$plugin = td_plugin();
wp_set_current_user( 1 );

if ( null === WC()->session ) {
	WC()->initialize_session();
}
if ( null === WC()->cart ) {
	WC()->initialize_cart();
}

// ------------------------------------------------------------- fixtures

$tshirt    = $plugin->models->get_by_slug( 'classic-tshirt' );
$tshirt_id = (int) $tshirt['id'];
$color_id  = (int) $plugin->colors->for_model( $tshirt_id )[0]['id'];
$size_id   = (int) $plugin->sizes->for_model( $tshirt_id )[0]['id'];
$front_id  = 0;
$back_id   = 0;
foreach ( $plugin->print_areas->for_model( $tshirt_id ) as $a ) {
	if ( 'front' === (string) $a['area_type'] ) {
		$front_id = (int) $a['id'];
	}
	if ( 'back' === (string) $a['area_type'] ) {
		$back_id = (int) $a['id'];
	}
}
$asset1 = (int) $plugin->assets->all( true )[0]['id'];
$asset2 = (int) $plugin->assets->all( true )[1]['id'];

$item = static function ( array $o = array() ): array {
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

$wc_product = new WC_Product_Simple();
$wc_product->set_name( 'Admin Test Shirt' );
$wc_product->set_regular_price( '350000' );
$wc_product->set_status( 'publish' );
$wc_product_id = $wc_product->save();
$plugin->models->update( $tshirt_id, array( 'wc_product_id' => $wc_product_id ) );

$design = $plugin->designs->save(
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array(
			(string) $front_id => array( $item( array( 'ref_id' => $asset1 ) ) ),
			(string) $back_id  => array( $item( array( 'ref_id' => $asset2, 'w' => 20.0, 'h' => 16.0 ) ) ),
		),
	),
	1,
	'',
	null
);
$design_id = (int) $design['id'];

WC()->cart->empty_cart();
$plugin->cart->add_to_cart( $design_id, 1, 1, '' );
$order_id = (int) WC()->checkout()->create_order(
	array( 'billing_email' => 'admin@example.org', 'billing_country' => 'IR', 'payment_method' => 'cod' )
);
$order = wc_get_order( $order_id );
$order->payment_complete( 'admin-txn' );
$plugin->orders->generate_for_order( $order_id, true );

$order_item_id = (int) array_key_first( $order->get_items() );

// ============================================================ order panel

TD_Test::group( 'Admin — order production panel' );

$panel = new TShirtDesigner\Admin\Admin_Order_Panel( $plugin );

// The metabox registers on the order screens.
$GLOBALS['wp_meta_boxes'] = array();
$panel->register_meta_box();
TD_Test::ok(
	isset( $GLOBALS['wp_meta_boxes']['shop_order']['normal']['high']['td-order-design'] ),
	'the design panel is registered on the order screen'
);

// Render it and inspect the markup.
ob_start();
$panel->render( $order );
$html = (string) ob_get_clean();

TD_Test::ok( '' !== $html, 'the panel renders' );
TD_Test::ok( str_contains( $html, (string) $plugin->designs->get_design( $design_id, 1, '' )['uuid'] ), 'the panel shows the design code' );
TD_Test::ok( str_contains( $html, 'Download all print files' ), 'the panel offers a Download All action' );
TD_Test::ok( str_contains( $html, 'Regenerate from snapshot' ), 'the panel offers Regenerate from snapshot' );
TD_Test::ok( substr_count( $html, 'do=download&amp;' ) >= 2 || substr_count( $html, 'do=download&' ) >= 2, 'the panel offers a download link per print area' );
TD_Test::ok( str_contains( $html, '_wpnonce' ), 'every panel action link is nonced' );
TD_Test::ok( str_contains( $html, 'Front' ) && str_contains( $html, 'Back' ), 'the panel lists both designed areas' );
TD_Test::ok( ! str_contains( $html, 'Left sleeve' ), 'undesigned areas are not listed' );
TD_Test::ok( str_contains( $html, '300 DPI' ), 'the panel shows the print resolution' );

// An order without designs degrades gracefully.
$plain_order = wc_create_order();
ob_start();
$panel->render( $plain_order );
$plain_html = (string) ob_get_clean();
TD_Test::ok( str_contains( $plain_html, 'does not contain any custom designs' ), 'a plain order shows a friendly message' );

TD_Test::group( 'Admin — production downloads' );

$files = $plugin->production->for_order( $order_id );
TD_Test::equals( 2, count( $files ), 'two production files exist for the order' );

// Download URLs must be nonced and point at admin-post.
$url = TShirtDesigner\Admin\Admin_Order_Panel::action_url( 'download', $order_id, array( 'file_id' => (int) $files[0]['id'] ) );
TD_Test::ok( str_contains( $url, 'admin-post.php' ), 'download URLs go through admin-post.php' );
TD_Test::ok( str_contains( $url, '_wpnonce=' ), 'download URLs carry a nonce' );
TD_Test::ok( str_contains( $url, 'order_id=' . $order_id ), 'download URLs name the order' );

// The stored file must live inside the protected production directory.
$storage = $plugin->production->storage_dir();
TD_Test::ok( is_array( $storage ), 'the production directory resolves' );
$base = realpath( $storage['dir'] );
foreach ( $files as $f ) {
	$real = realpath( (string) $f['file_path'] );
	TD_Test::ok( is_string( $real ) && str_starts_with( $real, (string) $base ), 'the print file is inside the protected production folder' );
}
TD_Test::ok( file_exists( $storage['dir'] . '/.htaccess' ), 'the production folder denies direct web access' );
TD_Test::ok( file_exists( $storage['dir'] . '/index.html' ), 'the production folder blocks directory listing' );

TD_Test::group( 'Admin — ZIP + regenerate' );

$zip = $plugin->production->build_zip( $order_id );
TD_Test::ok( is_array( $zip ), 'the whole-order ZIP builds' );
TD_Test::equals( 2, (int) $zip['count'], 'the ZIP holds both print files' );
TD_Test::equals( 'ORDER-' . $order_id . '-PRINT-FILES.zip', (string) $zip['name'], 'the ZIP is named after the order' );

$zip_item = $plugin->production->build_zip( $order_id, $order_item_id );
TD_Test::ok( is_array( $zip_item ), 'a per-item ZIP builds' );
TD_Test::ok( str_contains( (string) $zip_item['name'], 'ITEM-' . $order_item_id ), 'the per-item ZIP is named after the item' );

TD_Test::ok( null === $plugin->production->build_zip( 999999 ), 'an order with no print files yields no ZIP' );

// Regenerate must use the snapshot, not the live catalogue.
$before = array();
foreach ( $plugin->production->for_order( $order_id ) as $f ) {
	$before[ (string) $f['area_type'] ] = array( (int) $f['width_px'], (int) $f['height_px'] );
}

$plugin->print_areas->update( $front_id, array( 'max_width_cm' => 8.0, 'max_height_cm' => 8.0 ) );
$plugin->models->update( $tshirt_id, array( 'base_price' => 1.0 ) );

$plugin->orders->generate_for_order( $order_id, true );

$after = array();
foreach ( $plugin->production->for_order( $order_id ) as $f ) {
	$after[ (string) $f['area_type'] ] = array( (int) $f['width_px'], (int) $f['height_px'] );
}
TD_Test::equals( $before['front'], $after['front'], 'regenerating after shrinking the print area keeps the purchased size' );
TD_Test::equals( $before['back'], $after['back'], 'the back print file is likewise unchanged' );
TD_Test::equals( 2, count( $plugin->production->for_order( $order_id ) ), 'regenerating does not duplicate file rows' );

$plugin->print_areas->update( $front_id, array( 'max_width_cm' => 30.0, 'max_height_cm' => 35.0 ) );
$plugin->models->update( $tshirt_id, array( 'base_price' => 350000.0 ) );

TD_Test::group( 'Admin — production status' );

$plugin->orders->set_production_status( $order_id, 'in_production' );
TD_Test::equals(
	'in_production',
	(string) wc_get_order( $order_id )->get_meta( TShirtDesigner\Order_Manager::META_PRODUCTION_STATUS ),
	'the panel can move an order into production'
);

ob_start();
$panel->render( wc_get_order( $order_id ) );
$status_html = (string) ob_get_clean();
TD_Test::ok(
	(bool) preg_match( '/value=.in_production.[^>]*selected/', $status_html ),
	'the current production status is preselected'
);

// ==================================================== design library

TD_Test::group( 'Admin — design library' );

$library = new TShirtDesigner\Admin\Admin_Designs( $plugin );

$render_library = static function ( array $query ) use ( $library ): string {
	$backup = $_GET;
	$_GET   = $query;
	set_current_screen( 'tshirt-designer_page_tshirt-designer-designs' );
	ob_start();
	$library->render();
	$html = (string) ob_get_clean();
	$_GET = $backup;
	return $html;
};

// Seed a second, differently-typed design to prove filtering works.
$tote     = $plugin->models->get_by_slug( 'classic-tote' );
$tote_id  = (int) $tote['id'];
$tb_color = (int) $plugin->colors->for_model( $tote_id )[0]['id'];
$tb_size  = (int) $plugin->sizes->for_model( $tote_id )[0]['id'];
$tb_front = 0;
foreach ( $plugin->print_areas->for_model( $tote_id ) as $a ) {
	if ( 'front' === (string) $a['area_type'] ) {
		$tb_front = (int) $a['id'];
	}
}
$tote_design = $plugin->designs->save(
	array(
		'model_id' => $tote_id,
		'color_id' => $tb_color,
		'size_id'  => $tb_size,
		'areas'    => array( (string) $tb_front => array( $item( array( 'ref_id' => $asset1, 'x' => 14.0, 'y' => 16.0 ) ) ) ),
	),
	1,
	'',
	null
);
$tote_design_id   = (int) $tote_design['id'];
$tote_design_uuid = (string) $tote_design['uuid'];
$shirt_uuid       = (string) $plugin->designs->get_design( $design_id, 1, '' )['uuid'];

$all = $render_library( array() );
TD_Test::ok( str_contains( $all, $shirt_uuid ), 'the library lists the t-shirt design' );
TD_Test::ok( str_contains( $all, $tote_design_uuid ), 'the library lists the tote design' );

$by_type = $render_library( array( 'product_type' => 'totebag' ) );
TD_Test::ok( str_contains( $by_type, $tote_design_uuid ), 'filtering by product type keeps matching designs' );
TD_Test::ok( ! str_contains( $by_type, $shirt_uuid ), 'filtering by product type excludes other types' );

$by_model = $render_library( array( 'model_id' => (string) $tshirt_id ) );
TD_Test::ok( str_contains( $by_model, $shirt_uuid ), 'filtering by model works' );
TD_Test::ok( ! str_contains( $by_model, $tote_design_uuid ), 'filtering by model excludes other models' );

// Generating production files moves a paid design on to `production`.
$shirt_status = (string) $plugin->designs->get_design( $design_id, 1, '' )['status'];
TD_Test::ok(
	in_array( $shirt_status, TShirtDesigner\Design_Manager::PROTECTED_STATUSES, true ),
	'the purchased design sits in a protected status after production files exist'
);
$by_status = $render_library( array( 'status' => $shirt_status ) );
TD_Test::ok( str_contains( $by_status, $shirt_uuid ), 'filtering by status finds the purchased design' );
TD_Test::ok( ! str_contains( $by_status, $tote_design_uuid ), 'filtering by status excludes unsold designs' );

$by_search = $render_library( array( 's' => $tote_design_uuid ) );
TD_Test::ok( str_contains( $by_search, $tote_design_uuid ), 'searching by design code finds it' );
TD_Test::ok( ! str_contains( $by_search, $shirt_uuid ), 'searching by design code excludes others' );

$by_id = $render_library( array( 's' => (string) $tote_design_id ) );
TD_Test::ok( str_contains( $by_id, $tote_design_uuid ), 'searching by numeric id works' );

$by_order = $render_library( array( 'order_id' => (string) $order_id ) );
TD_Test::ok( str_contains( $by_order, $shirt_uuid ), 'filtering by order id finds the ordered design' );
TD_Test::ok( ! str_contains( $by_order, $tote_design_uuid ), 'filtering by order id excludes unrelated designs' );

$no_order = $render_library( array( 'order_id' => '987654' ) );
TD_Test::ok( ! str_contains( $no_order, $shirt_uuid ), 'filtering by an unknown order returns nothing' );

$by_user = $render_library( array( 'user_id' => '1' ) );
TD_Test::ok( str_contains( $by_user, $shirt_uuid ), 'filtering by user works' );

$future = $render_library( array( 'date_from' => gmdate( 'Y-m-d', time() + 7 * DAY_IN_SECONDS ) ) );
TD_Test::ok( ! str_contains( $future, $shirt_uuid ), 'a future date range returns nothing' );

// A SQL injection attempt in the search box must be harmless.
$evil = $render_library( array( 's' => "' OR 1=1 -- " ) );
TD_Test::ok( ! str_contains( $evil, $shirt_uuid ), 'a SQL injection attempt in search matches nothing' );
global $wpdb;
TD_Test::equals( '', (string) $wpdb->last_error, 'the injection attempt produced no database error' );
TD_Test::ok(
	null !== $plugin->designs->get_design( $design_id, 1, '' ),
	'the data survived the injection attempt'
);

TD_Test::group( 'Admin — design deletion rules' );

// A paid design must never be deletable from the library.
$_POST    = array( 'id' => (string) $design_id );
$redirect = td_capture_redirect( static fn() => $library->handle_action( 'delete' ) );
$_POST    = array();
TD_Test::ok(
	null !== $plugin->designs->get_design( $design_id, 1, '' ),
	'the admin cannot delete a design attached to a paid order'
);
TD_Test::ok(
	'' !== $redirect && str_contains( rawurldecode( rawurldecode( $redirect ) ), 'cannot be deleted' ),
	'the admin is told why the deletion was refused'
);

// An unsold design can be removed through Design_Manager.
$scratch = $plugin->designs->save(
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array( (string) $front_id => array( $item( array( 'ref_id' => $asset1 ) ) ) ),
	),
	1,
	'',
	null
);
$removed = $plugin->designs->delete( (int) $scratch['id'], 1, '' );
TD_Test::ok( $removed['ok'], 'an unsold design can be deleted' );

// ==================================================== product types page

TD_Test::group( 'Admin — product types page' );

$types_page = new TShirtDesigner\Admin\Admin_Product_Types( $plugin );

ob_start();
$types_page->render();
$types_html = (string) ob_get_clean();

TD_Test::ok( str_contains( $types_html, 'T-Shirt' ), 'the product types page lists the t-shirt type' );
TD_Test::ok( str_contains( $types_html, 'Tote Bag' ), 'the product types page lists the tote bag type' );
TD_Test::ok( str_contains( $types_html, 'tshirt' ) && str_contains( $types_html, 'totebag' ), 'the slugs are shown' );
TD_Test::ok( str_contains( $types_html, 'Print DPI' ), 'the page exposes the print DPI setting' );
TD_Test::ok( str_contains( $types_html, 'name="dpi[tshirt]"' ), 'each type has its own DPI field' );
TD_Test::ok( str_contains( $types_html, '3543' ), 'the page previews the pixel size at the chosen DPI' );

// Saving a per-type DPI is applied and clamped.
$_POST = array(
	'print_dpi' => '300',
	'dpi'       => array( 'totebag' => '150', 'tshirt' => '' ),
);
td_capture_redirect( static fn() => $types_page->handle_action( 'save_dpi' ) );
$_POST = array();

TD_Test::equals( 150, TShirtDesigner\Product_Type_Registry::dpi( 'totebag', $plugin->settings ), 'a per-type DPI is saved' );
TD_Test::equals( 300, TShirtDesigner\Product_Type_Registry::dpi( 'tshirt', $plugin->settings ), 'an empty field falls back to the global DPI' );

// And it really changes the production output size.
$tote_snapshot        = $plugin->designs->build_snapshot( $tote_design_id, 1 );
TD_Test::equals( 150, (int) $tote_snapshot['dpi'], 'a new tote snapshot picks up the per-type DPI' );
[ $exp_w, $exp_h ] = TShirtDesigner\Production_Renderer::pixel_size( 28.0, 32.0, 150 );
$tote_gen = $plugin->production->generate( $tote_snapshot, 4242, 1, true );
TD_Test::ok( $tote_gen['ok'], 'the tote print file generates at the new DPI' );
$info = getimagesize( (string) $tote_gen['files'][0]['file_path'] );
TD_Test::equals( $exp_w, (int) $info[0], 'the print file honours the per-type DPI' );
TD_Test::equals( $exp_h, (int) $info[1], 'the print file height honours the per-type DPI' );

// Restore.
$_POST = array( 'print_dpi' => '300', 'dpi' => array() );
td_capture_redirect( static fn() => $types_page->handle_action( 'save_dpi' ) );
$_POST = array();

// An out-of-range DPI is clamped rather than accepted.
$_POST = array( 'print_dpi' => '300', 'dpi' => array( 'tshirt' => '99999' ) );
td_capture_redirect( static fn() => $types_page->handle_action( 'save_dpi' ) );
$_POST = array();
$clamped = TShirtDesigner\Product_Type_Registry::dpi( 'tshirt', $plugin->settings );
TD_Test::ok( $clamped >= 72 && $clamped <= 1200, 'an absurd DPI is clamped into a printable range' );

$_POST = array( 'print_dpi' => '300', 'dpi' => array() );
td_capture_redirect( static fn() => $types_page->handle_action( 'save_dpi' ) );
$_POST = array();

TD_Test::group( 'Admin — menu & escaping' );

TD_Test::ok(
	class_exists( 'TShirtDesigner\Admin\Admin_Product_Types' ),
	'the product types page class autoloads'
);
TD_Test::ok(
	class_exists( 'TShirtDesigner\Admin\Admin_Order_Panel' ),
	'the order panel class autoloads'
);
TD_Test::equals(
	'T-Shirt',
	TShirtDesigner\Product_Type_Registry::label( 'tshirt' ),
	'product type labels resolve'
);
TD_Test::equals(
	'Unknown Type',
	TShirtDesigner\Product_Type_Registry::label( 'unknown_type' ),
	'an unregistered slug still renders a readable label'
);

// Output escaping: a hostile model name must never reach the page as markup.
// Script tags are already stripped on write, so nothing dangerous is stored…
$plugin->models->update( $tshirt_id, array( 'name' => '<script>alert(1)</script>' ) );
TD_Test::ok(
	! str_contains( (string) $plugin->models->get( $tshirt_id, true )['name'], '<script' ),
	'a script tag is stripped before a model name is stored'
);
$escaped = $render_library( array() );
TD_Test::ok( ! str_contains( $escaped, '<script>alert(1)</script>' ), 'a hostile model name never renders as markup' );

// …and a name with legitimate special characters is escaped, not mangled.
$plugin->models->update( $tshirt_id, array( 'name' => 'Tee "Pro" & Co <3' ) );
$escaped2 = $render_library( array() );
TD_Test::ok( str_contains( $escaped2, '&amp;' ), 'special characters in a model name are HTML-escaped on output' );
TD_Test::ok( ! str_contains( $escaped2, 'Co <3' ), 'the raw unescaped form is not present' );

$plugin->models->update( $tshirt_id, array( 'name' => 'Classic T-Shirt' ) );

exit( TD_Test::summary() );
