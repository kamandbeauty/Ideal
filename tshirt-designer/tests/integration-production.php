<?php
/**
 * Phase 3 integration tests: production jobs, statuses, files, ZIP, security.
 *
 * Runs a REAL end-to-end flow against a real WooCommerce install: design ->
 * cart -> checkout -> payment -> production job -> the whole status pipeline,
 * then verifies the produced PNGs on disk.
 *
 * Not loaded in production.
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
foreach ( array( 'wc-cart-functions.php', 'wc-notice-functions.php', 'wc-template-functions.php' ) as $wc_inc ) {
	$wc_path = WP_PLUGIN_DIR . '/woocommerce/includes/' . $wc_inc;
	if ( is_readable( $wc_path ) ) {
		require_once $wc_path;
	}
}

do_action( 'init' );
do_action( 'woocommerce_init' );

$plugin = td_plugin();

use TShirtDesigner\Production_Status as PS;
use TShirtDesigner\Production_Manager as PM;

// ---------------------------------------------------------------- fixtures

// WooCommerce needs a session + cart in a CLI-ish context.
if ( null === WC()->session ) {
	WC()->initialize_session();
}
if ( null === WC()->cart ) {
	WC()->initialize_cart();
}

wp_set_current_user( 1 );

$tshirt    = $plugin->models->get_by_slug( 'classic-tshirt' );
$tote      = $plugin->models->get_by_slug( 'classic-tote' );
$tshirt_id = (int) $tshirt['id'];
$tote_id   = (int) $tote['id'];

$color_id = (int) $plugin->colors->for_model( $tshirt_id )[0]['id'];
$size_id  = (int) $plugin->sizes->for_model( $tshirt_id )[0]['id'];

$areas_shirt = array();
foreach ( $plugin->print_areas->for_model( $tshirt_id ) as $a ) {
	$areas_shirt[ (string) $a['area_type'] ] = (int) $a['id'];
}
$areas_tote = array();
foreach ( $plugin->print_areas->for_model( $tote_id ) as $a ) {
	$areas_tote[ (string) $a['area_type'] ] = (int) $a['id'];
}

$tb_color = (int) $plugin->colors->for_model( $tote_id )[0]['id'];
$tb_size  = (int) $plugin->sizes->for_model( $tote_id )[0]['id'];

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

// Real WooCommerce products.
$wc_shirt = new WC_Product_Simple();
$wc_shirt->set_name( 'P3 T-Shirt' );
$wc_shirt->set_regular_price( '350000' );
$wc_shirt->set_status( 'publish' );
$wc_shirt_id = $wc_shirt->save();

$wc_tote = new WC_Product_Simple();
$wc_tote->set_name( 'P3 Tote' );
$wc_tote->set_regular_price( '220000' );
$wc_tote->set_status( 'publish' );
$wc_tote_id = $wc_tote->save();

$plugin->models->update( $tshirt_id, array( 'wc_product_id' => $wc_shirt_id ) );
$plugin->models->update( $tote_id, array( 'wc_product_id' => $wc_tote_id ) );

$buyer = wp_insert_user(
	array( 'user_login' => 'p3buyer', 'user_pass' => 'pass-123456', 'user_email' => 'p3buyer@example.org', 'role' => 'customer' )
);
$buyer = is_wp_error( $buyer ) ? (int) get_user_by( 'login', 'p3buyer' )->ID : (int) $buyer;

/**
 * Design -> cart -> order -> paid. Returns the order id.
 */
$checkout_design = static function ( int $design_id, string $email ) use ( $plugin ): int {
	WC()->cart->empty_cart();
	$added = $plugin->cart->add_to_cart( $design_id, 1, 1, '' );
	if ( ! $added['ok'] ) {
		return 0;
	}
	$order_id = WC()->checkout()->create_order(
		array(
			'billing_first_name' => 'Ali',
			'billing_last_name'  => 'Producer',
			'billing_email'      => $email,
			'billing_country'    => 'IR',
			'payment_method'     => 'cod',
		)
	);
	return is_wp_error( $order_id ) ? 0 : (int) $order_id;
};

// =========================================================== status machine

TD_Test::group( 'Production status — transition rules' );

TD_Test::ok( PS::can( PS::NEW_JOB, PS::PAID ), 'new -> paid is allowed' );
TD_Test::ok( PS::can( PS::PAID, PS::READY ), 'paid -> ready is allowed' );
TD_Test::ok( PS::can( PS::READY, PS::IN_PROD ), 'ready -> in production is allowed' );
TD_Test::ok( PS::can( PS::IN_PROD, PS::PRINTED ), 'in production -> printed is allowed' );
TD_Test::ok( PS::can( PS::PRINTED, PS::QC ), 'printed -> quality check is allowed' );
TD_Test::ok( PS::can( PS::QC, PS::PACKED ), 'quality check -> packed is allowed' );
TD_Test::ok( PS::can( PS::PACKED, PS::SHIPPED ), 'packed -> shipped is allowed' );
TD_Test::ok( PS::can( PS::SHIPPED, PS::COMPLETED ), 'shipped -> completed is allowed' );

// Illegal jumps.
TD_Test::ok( ! PS::can( PS::PAID, PS::SHIPPED ), 'paid cannot jump straight to shipped' );
TD_Test::ok( ! PS::can( PS::NEW_JOB, PS::COMPLETED ), 'new cannot jump straight to completed' );
TD_Test::ok( ! PS::can( PS::READY, PS::PACKED ), 'ready cannot skip to packed' );
TD_Test::ok( ! PS::can( PS::PRINTED, PS::IN_PROD ), 'printed cannot silently go back to production' );
TD_Test::ok( ! PS::can( PS::PAID, PS::PAID ), 'a no-op transition is not a valid transition' );
TD_Test::ok( ! PS::can( PS::PAID, 'teleport' ), 'an unknown status is refused' );

// Terminal states.
TD_Test::ok( ! PS::can( PS::COMPLETED, PS::CANCELLED ), 'completed is terminal' );
TD_Test::ok( ! PS::can( PS::CANCELLED, PS::READY ), 'cancelled is terminal' );
TD_Test::equals( array(), PS::next( PS::COMPLETED ), 'nothing follows completed' );

// Cancellation is reachable from every live state.
foreach ( array( PS::NEW_JOB, PS::PAID, PS::READY, PS::IN_PROD, PS::PRINTED, PS::QC, PS::PACKED, PS::SHIPPED ) as $live ) {
	TD_Test::ok( PS::can( $live, PS::CANCELLED ), "cancellation is allowed from {$live}" );
}

// QC failure path and error recovery.
TD_Test::ok( PS::can( PS::QC, PS::IN_PROD ), 'a failed quality check returns the job to production' );
TD_Test::ok( PS::can( PS::IN_PROD, PS::FAILED ), 'production can enter the error state' );
TD_Test::ok( PS::can( PS::FAILED, PS::READY ), 'a failed job can be requeued' );

TD_Test::ok( PS::is_priority( 'urgent' ), 'urgent is a valid priority' );
TD_Test::ok( ! PS::is_priority( 'whenever' ), 'an unknown priority is refused' );

// ====================================================== T-Shirt acceptance

TD_Test::group( 'Acceptance — T-Shirt end to end (§63)' );

$shirt_design = $plugin->designs->save(
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array(
			(string) $areas_shirt['front'] => array( $make_item( array( 'ref_id' => $asset1 ) ) ),
			(string) $areas_shirt['back']  => array( $make_item( array( 'ref_id' => $asset2, 'x' => 14.0 ) ) ),
		),
	),
	1,
	'',
	null
);
$shirt_design_id = (int) $shirt_design['id'];
TD_Test::ok( $shirt_design_id > 0, 'a two-area t-shirt design is saved' );

$order_id = $checkout_design( $shirt_design_id, 'p3buyer@example.org' );
TD_Test::ok( $order_id > 0, 'the t-shirt design reaches checkout' );

// No production job should exist before payment.
TD_Test::equals( 0, count( $plugin->production_jobs->for_order( $order_id ) ), 'no production job exists before payment' );

wc_get_order( $order_id )->payment_complete( 'p3-txn-1' );

$jobs = $plugin->production_jobs->for_order( $order_id );
TD_Test::equals( 1, count( $jobs ), 'payment creates exactly one production job' );
$job    = $jobs[0];
$job_id = (int) $job['id'];

TD_Test::equals( PS::PAID, (string) $job['status'], 'a new job starts in the paid state' );
TD_Test::equals( $shirt_design_id, (int) $job['design_id'], 'the job is linked to the design' );
TD_Test::equals( 1, (int) $job['design_version'], 'the job records the design version' );
TD_Test::equals( 'tshirt', (string) $job['product_type'], 'the job records the product type' );
TD_Test::equals( $tshirt_id, (int) $job['model_id'], 'the job records the model' );
TD_Test::ok( '' !== (string) $job['customer_email'], 'the job captures the customer email' );

// Replaying payment must not duplicate the job (§5 idempotency).
$plugin->production_jobs->create_jobs_for_order( $order_id );
$plugin->production_jobs->create_jobs_for_order( $order_id );
TD_Test::equals( 1, count( $plugin->production_jobs->for_order( $order_id ) ), 'replaying payment does not duplicate jobs' );

// --- walk the whole pipeline ------------------------------------------------
$admin_user = 1;

$step = $plugin->production_jobs->transition( $job_id, PS::READY, $admin_user );
TD_Test::ok( $step['ok'], 'paid -> ready succeeds' );

// An illegal jump must be refused by the BACKEND, not just hidden in the UI.
$bad = $plugin->production_jobs->transition( $job_id, PS::SHIPPED, $admin_user );
TD_Test::ok( ! $bad['ok'], 'ready -> shipped is refused by the backend' );
TD_Test::ok( ! empty( $bad['error'] ), 'the refusal explains itself' );
TD_Test::equals( PS::READY, (string) $plugin->production_jobs->get( $job_id )['status'], 'the refused transition did not change the status' );

TD_Test::ok( $plugin->production_jobs->transition( $job_id, PS::IN_PROD, $admin_user )['ok'], 'ready -> in production succeeds' );
TD_Test::ok( '' !== (string) $plugin->production_jobs->get( $job_id )['started_at'], 'started_at is stamped' );
TD_Test::ok( $plugin->production_jobs->transition( $job_id, PS::PRINTED, $admin_user )['ok'], 'in production -> printed succeeds' );
TD_Test::ok( $plugin->production_jobs->transition( $job_id, PS::QC, $admin_user )['ok'], 'printed -> quality check succeeds' );

// §21 a failing QC needs a note.
$qc_fail_nonote = $plugin->production_jobs->quality_check( $job_id, false, $admin_user, '' );
TD_Test::ok( ! $qc_fail_nonote['ok'], 'a failed quality check without a note is refused' );

$qc_fail = $plugin->production_jobs->quality_check( $job_id, false, $admin_user, 'Colour is off.' );
TD_Test::ok( $qc_fail['ok'], 'a failed quality check with a note is accepted' );
TD_Test::equals( PS::IN_PROD, (string) $plugin->production_jobs->get( $job_id )['status'], 'a failed quality check returns the job to production' );

// Back up the pipeline and pass this time.
$plugin->production_jobs->transition( $job_id, PS::PRINTED, $admin_user );
$plugin->production_jobs->transition( $job_id, PS::QC, $admin_user );
$qc_pass = $plugin->production_jobs->quality_check( $job_id, true, $admin_user );
TD_Test::ok( $qc_pass['ok'], 'a passing quality check is accepted' );
TD_Test::equals( PS::PACKED, (string) $plugin->production_jobs->get( $job_id )['status'], 'a passing quality check packs the job' );

TD_Test::ok( $plugin->production_jobs->transition( $job_id, PS::SHIPPED, $admin_user )['ok'], 'packed -> shipped succeeds' );
TD_Test::ok( $plugin->production_jobs->transition( $job_id, PS::COMPLETED, $admin_user )['ok'], 'shipped -> completed succeeds' );

$final = $plugin->production_jobs->get( $job_id );
TD_Test::equals( PS::COMPLETED, (string) $final['status'], 'the job reaches completed' );
TD_Test::ok( '' !== (string) $final['completed_at'], 'completed_at is stamped' );

// Terminal: nothing more may happen.
TD_Test::ok( ! $plugin->production_jobs->transition( $job_id, PS::CANCELLED, $admin_user )['ok'], 'a completed job cannot be cancelled' );

// --- activity log -----------------------------------------------------------
TD_Test::group( 'Production — activity log (§20)' );

$history = $plugin->production_jobs->history( $job_id );
TD_Test::ok( count( $history ) >= 10, 'the job accumulated a full history' );
TD_Test::equals( PM::EVENT_CREATED, (string) $history[0]['event_type'], 'the first event is job creation' );

$types = array_column( $history, 'event_type' );
TD_Test::ok( in_array( PM::EVENT_STATUS, $types, true ), 'status changes are logged' );
TD_Test::ok( in_array( PM::EVENT_QC, $types, true ), 'quality checks are logged' );

$statuses_logged = array_filter( $history, static fn( $e ) => PM::EVENT_STATUS === $e['event_type'] );
$one             = array_values( $statuses_logged )[0];
TD_Test::ok( '' !== (string) $one['created_at'], 'events carry a timestamp' );
TD_Test::equals( $admin_user, (int) $one['user_id'], 'events record who acted' );

// The QC failure note must be preserved verbatim.
$notes_text = implode( ' ', array_column( $history, 'note' ) );
TD_Test::ok( str_contains( $notes_text, 'Colour is off.' ), 'the quality-check note is preserved' );

// --- notes ------------------------------------------------------------------
TD_Test::group( 'Production — notes (§19)' );

TD_Test::ok( $plugin->production_jobs->add_note( $job_id, 'Needs a colour check.', $admin_user ), 'a note can be added' );
TD_Test::ok( ! $plugin->production_jobs->add_note( $job_id, '   ', $admin_user ), 'an empty note is refused' );
TD_Test::ok( ! $plugin->production_jobs->add_note( 999999, 'ghost', $admin_user ), 'a note on a missing job is refused' );

$notes = $plugin->production_jobs->notes( $job_id );
TD_Test::ok( count( $notes ) >= 1, 'notes can be read back' );
TD_Test::ok( '' !== (string) $notes[0]['created_at'], 'notes have a timestamp' );

// ================================================= production files (T-Shirt)

TD_Test::group( 'Production files — T-Shirt (§14/§35/§54)' );

$gen = $plugin->production_service->generate( $job_id, true, $admin_user );
TD_Test::ok( $gen['ok'], 'production files generate from the snapshot' );
TD_Test::equals( 2, count( $gen['files'] ), 'exactly the two designed areas produce files' );

$by_area = array();
foreach ( $gen['files'] as $f ) {
	$by_area[ (string) $f['area_type'] ] = $f;
}
TD_Test::ok( isset( $by_area['front'] ), 'a FRONT file exists' );
TD_Test::ok( isset( $by_area['back'] ), 'a BACK file exists' );
TD_Test::ok( ! isset( $by_area['left_sleeve'] ), 'no file is produced for an undesigned sleeve (§7)' );

// Real pixels on disk: 30x35 cm @300dpi = 3543x4134.
$front = $by_area['front'];
TD_Test::ok( file_exists( (string) $front['file_path'] ), 'the FRONT PNG really exists on disk' );
TD_Test::equals( 3543, (int) $front['width_px'], 'FRONT width is 3543 px' );
TD_Test::equals( 4134, (int) $front['height_px'], 'FRONT height is 4134 px' );
TD_Test::equals( 300, (int) $front['dpi'], 'FRONT is 300 DPI' );

$size_on_disk = getimagesize( (string) $front['file_path'] );
TD_Test::equals( 3543, (int) $size_on_disk[0], 'the file on disk really is 3543 px wide' );
TD_Test::equals( 4134, (int) $size_on_disk[1], 'the file on disk really is 4134 px tall' );
TD_Test::equals( 'image/png', (string) $size_on_disk['mime'], 'the production file is a PNG' );

// Alpha must survive.
$img = imagecreatefrompng( (string) $front['file_path'] );
TD_Test::ok( $img instanceof GdImage, 'the PNG can be reopened' );
$corner = imagecolorat( $img, 5, 5 );
$alpha  = ( $corner & 0x7F000000 ) >> 24;
TD_Test::equals( 127, $alpha, 'the corner of the print file is fully transparent (no background)' );
imagedestroy( $img );

// §8 metadata.
TD_Test::ok( (float) $front['width_cm'] > 0, 'the file records its width in cm' );
TD_Test::ok( (float) $front['height_cm'] > 0, 'the file records its height in cm' );
TD_Test::equals( 'image/png', (string) $front['mime_type'], 'the file records its mime type' );
TD_Test::ok( (int) $front['file_size'] > 0, 'the file records its size' );
TD_Test::equals( $job_id, (int) $front['job_id'], 'the file is linked to its production job' );
TD_Test::equals( $shirt_design_id, (int) $front['design_id'], 'the file records the design id' );
TD_Test::equals( 1, (int) $front['design_version'], 'the file records the design version' );

// Deterministic, path-safe file name.
TD_Test::ok( str_contains( (string) $front['file_name'], 'ORDER-' . $order_id ), 'the file name carries the order' );
TD_Test::ok( str_ends_with( (string) $front['file_name'], 'FRONT.png' ), 'the file name carries the area' );
TD_Test::ok( ! str_contains( (string) $front['file_name'], '..' ), 'the file name cannot traverse' );
TD_Test::ok( ! str_contains( (string) $front['file_name'], '/' ), 'the file name contains no separator' );

// §49 caching: an unforced regenerate reuses the file.
$hash_before = (string) $front['file_hash'];
TD_Test::ok( '' !== $hash_before, 'the file records a content hash' );
$cached = $plugin->production_service->generate( $job_id, false, $admin_user );
TD_Test::ok( $cached['ok'], 'a cached generation succeeds' );
$cached_front = null;
foreach ( $cached['files'] as $f ) {
	if ( 'front' === (string) $f['area_type'] ) {
		$cached_front = $f;
	}
}
TD_Test::equals( (int) $front['id'], (int) $cached_front['id'], 'an existing valid file is reused, not re-rendered' );

// §54 determinism: forced regeneration from an unchanged snapshot is identical.
$regen = $plugin->production_service->regenerate( $job_id, $admin_user, 'determinism check' );
TD_Test::ok( $regen['ok'], 'a forced regeneration succeeds' );
$regen_front = null;
foreach ( $regen['files'] as $f ) {
	if ( 'front' === (string) $f['area_type'] ) {
		$regen_front = $f;
	}
}
TD_Test::equals(
	$hash_before,
	(string) hash_file( 'sha256', (string) $regen_front['file_path'] ),
	'regenerating from an unchanged snapshot produces a byte-identical file'
);

// ================================================== snapshot immutability

TD_Test::group( 'Snapshot immutability under catalogue change (§17/§53)' );

$snap_before = $plugin->production_jobs->snapshot( $job_id );
TD_Test::ok( is_array( $snap_before ) && isset( $snap_before['areas'] ), 'the job resolves its snapshot' );
$snap_json_before = wp_json_encode( $snap_before );

// Now vandalise the live catalogue in every way that matters.
$plugin->models->update( $tshirt_id, array( 'name' => 'RENAMED SHIRT' ) );
$plugin->print_areas->update(
	$areas_shirt['front'],
	array( 'max_width_cm' => 10.0, 'max_height_cm' => 10.0 )
);
$wc_shirt = wc_get_product( $wc_shirt_id );
$wc_shirt->set_regular_price( '999999' );
$wc_shirt->save();

$snap_after = $plugin->production_jobs->snapshot( $job_id );
TD_Test::equals( $snap_json_before, wp_json_encode( $snap_after ), 'the purchased snapshot is unchanged by catalogue edits' );

// And regeneration must still use the PURCHASED geometry, not the new 10x10.
$regen2 = $plugin->production_service->regenerate( $job_id, $admin_user, 'after catalogue change' );
TD_Test::ok( $regen2['ok'], 'regeneration after a catalogue change succeeds' );
$regen2_front = null;
foreach ( $regen2['files'] as $f ) {
	if ( 'front' === (string) $f['area_type'] ) {
		$regen2_front = $f;
	}
}
TD_Test::equals( 3543, (int) $regen2_front['width_px'], 'regeneration still uses the PURCHASED 30 cm width, not the new 10 cm' );
TD_Test::equals( 4134, (int) $regen2_front['height_px'], 'regeneration still uses the PURCHASED 35 cm height' );
TD_Test::equals(
	$hash_before,
	(string) hash_file( 'sha256', (string) $regen2_front['file_path'] ),
	'the regenerated file is still byte-identical to the purchased output'
);

// Restore the catalogue for later tests.
$plugin->print_areas->update(
	$areas_shirt['front'],
	array( 'max_width_cm' => 30.0, 'max_height_cm' => 35.0 )
);

// §18 regeneration history.
$regen_events = array_filter(
	$plugin->production_jobs->history( $job_id ),
	static fn( $e ) => PM::EVENT_REGENERATE === $e['event_type']
);
TD_Test::ok( count( $regen_events ) >= 2, 'each regeneration is logged' );
$last_regen = array_values( $regen_events )[ count( $regen_events ) - 1 ];
TD_Test::ok( str_contains( (string) $last_regen['note'], 'catalogue' ), 'the regeneration reason is recorded' );
TD_Test::equals( $admin_user, (int) $last_regen['user_id'], 'the regenerating admin is recorded' );

// ============================================================ design version

TD_Test::group( 'Production is pinned to a design version (§38)' );

// Customer edits the design after ordering -> new version.
$v2 = $plugin->designs->save(
	array(
		'design_id' => $shirt_design_id,
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array(
			(string) $areas_shirt['front'] => array( $make_item( array( 'ref_id' => $asset2, 'x' => 15.0, 'y' => 17.5, 'w' => 10.0, 'h' => 10.0 ) ) ),
		),
	),
	1,
	'',
	null
);
// A design attached to a PAID order is immutable: Design_Manager branches the
// edit into a brand-new design rather than mutating purchased history. That is
// an even stronger guarantee than a version bump, so assert exactly that.
TD_Test::ok( $v2['ok'], 'the customer can keep editing after ordering' );
TD_Test::ok(
	(int) $v2['id'] !== $shirt_design_id,
	'editing a paid design branches into a new design instead of mutating it'
);
TD_Test::equals( 1, (int) $v2['version'], 'the branched design starts at version 1' );
TD_Test::equals(
	$shirt_design_id,
	(int) $plugin->production_jobs->get( $job_id )['design_id'],
	'the production job still points at the purchased design'
);
TD_Test::equals( 1, (int) $plugin->production_jobs->get( $job_id )['design_version'], 'the production job still points at version 1' );

$snap_v1 = $plugin->production_jobs->snapshot( $job_id );
TD_Test::equals( $snap_json_before, wp_json_encode( $snap_v1 ), 'the job snapshot is untouched by a new design version' );

// ==================================================== Tote Bag acceptance

TD_Test::group( 'Acceptance — Tote Bag end to end (§64)' );

$tote_design = $plugin->designs->save(
	array(
		'model_id' => $tote_id,
		'color_id' => $tb_color,
		'size_id'  => $tb_size,
		'areas'    => array(
			(string) $areas_tote['front'] => array( $make_item( array( 'ref_id' => $asset1, 'x' => 14.0, 'y' => 16.0 ) ) ),
			(string) $areas_tote['back']  => array( $make_item( array( 'ref_id' => $asset2, 'x' => 14.0, 'y' => 16.0 ) ) ),
		),
	),
	1,
	'',
	null
);
$tote_design_id = (int) $tote_design['id'];
$tote_order_id  = $checkout_design( $tote_design_id, 'p3buyer@example.org' );
TD_Test::ok( $tote_order_id > 0, 'the tote design reaches checkout' );

wc_get_order( $tote_order_id )->payment_complete( 'p3-txn-2' );
$tote_jobs = $plugin->production_jobs->for_order( $tote_order_id );
TD_Test::equals( 1, count( $tote_jobs ), 'the tote order gets a production job' );
$tote_job_id = (int) $tote_jobs[0]['id'];
TD_Test::equals( 'totebag', (string) $tote_jobs[0]['product_type'], 'the tote job records its product type' );

$tote_gen = $plugin->production_service->generate( $tote_job_id, true, $admin_user );
TD_Test::ok( $tote_gen['ok'], 'tote production files generate' );
TD_Test::equals( 2, count( $tote_gen['files'] ), 'the tote produces FRONT and BACK files' );

$tote_by_area = array();
foreach ( $tote_gen['files'] as $f ) {
	$tote_by_area[ (string) $f['area_type'] ] = $f;
}
TD_Test::ok( isset( $tote_by_area['front'], $tote_by_area['back'] ), 'both tote sides are present' );

// 28x32 cm @300dpi = 3307x3780.
$tf = $tote_by_area['front'];
TD_Test::equals( 3307, (int) $tf['width_px'], 'tote FRONT width is 3307 px' );
TD_Test::equals( 3780, (int) $tf['height_px'], 'tote FRONT height is 3780 px' );
$tote_disk = getimagesize( (string) $tf['file_path'] );
TD_Test::equals( 3307, (int) $tote_disk[0], 'the tote file on disk really is 3307 px wide' );
TD_Test::equals( 3780, (int) $tote_disk[1], 'the tote file on disk really is 3780 px tall' );

$timg  = imagecreatefrompng( (string) $tf['file_path'] );
$tc    = imagecolorat( $timg, 3, 3 );
$talph = ( $tc & 0x7F000000 ) >> 24;
TD_Test::equals( 127, $talph, 'the tote print file is transparent (no background)' );
imagedestroy( $timg );

// ================================================================ ZIP export

TD_Test::group( 'ZIP export (§15/§16)' );

$zip = $plugin->production_service->zip( $tote_job_id );
TD_Test::ok( is_array( $zip ) && file_exists( (string) $zip['path'] ), 'a ZIP is produced for the job' );
TD_Test::equals( 2, (int) $zip['count'], 'the ZIP holds both tote sides' );

$za = new ZipArchive();
TD_Test::ok( true === $za->open( (string) $zip['path'] ), 'the ZIP opens' );
$entries = array();
for ( $i = 0; $i < $za->numFiles; $i++ ) {
	$entries[] = (string) $za->getNameIndex( $i );
}
$za->close();

TD_Test::equals( 2, count( $entries ), 'the ZIP contains exactly the two files' );
foreach ( $entries as $e ) {
	TD_Test::ok( ! str_contains( $e, '..' ), "ZIP entry '{$e}' cannot traverse" );
	TD_Test::ok( ! str_starts_with( $e, '/' ), "ZIP entry '{$e}' is not absolute" );
	TD_Test::ok( (bool) preg_match( '/^[A-Za-z0-9._-]+$/', $e ), "ZIP entry '{$e}' is a sanitised flat name" );
	TD_Test::ok( str_ends_with( $e, '.png' ), "ZIP entry '{$e}' is a PNG" );
}

// Only files in the snapshot get in: an undesigned area is absent.
TD_Test::ok( ! in_array( 'LEFT-SLEEVE.png', $entries, true ), 'the ZIP has no file for an undesigned area' );

// ======================================================= error handling

TD_Test::group( 'Production error handling and retry (§22/§23)' );

$fail_ok = $plugin->production_jobs->mark_failed( $tote_job_id, 'Renderer ran out of memory.', $admin_user );
TD_Test::ok( $fail_ok, 'a job can be flagged as failed' );
$failed_job = $plugin->production_jobs->get( $tote_job_id );
TD_Test::equals( PS::FAILED, (string) $failed_job['status'], 'the job enters the error state' );
TD_Test::ok( str_contains( (string) $failed_job['error_message'], 'memory' ), 'the error message is stored for the admin' );

$fail_events = array_filter(
	$plugin->production_jobs->history( $tote_job_id ),
	static fn( $e ) => PM::EVENT_FAILED === $e['event_type']
);
TD_Test::ok( count( $fail_events ) >= 1, 'the failure is logged, never silent' );

$retry = $plugin->production_service->retry( $tote_job_id, $admin_user, 'printer export failed' );
TD_Test::ok( $retry['ok'], 'a retry re-renders from the snapshot' );
TD_Test::equals( PS::READY, (string) $plugin->production_jobs->get( $tote_job_id )['status'], 'a successful retry requeues the job' );

$retry_events = array_filter(
	$plugin->production_jobs->history( $tote_job_id ),
	static fn( $e ) => PM::EVENT_RETRY === $e['event_type']
);
TD_Test::ok( count( $retry_events ) >= 1, 'the retry is logged' );
TD_Test::ok( str_contains( (string) array_values( $retry_events )[0]['note'], 'printer export failed' ), 'the retry reason is recorded' );

// A job with no snapshot must fail loudly rather than produce a blank file.
$orphan = $plugin->production_jobs->create_job( 987654, 987654, array( 'design_id' => 0, 'design_version' => 1 ) );
TD_Test::ok( is_array( $orphan ), 'a job can be created for a missing order (back-fill edge case)' );
$orphan_gen = $plugin->production_service->generate( (int) $orphan['id'], true, $admin_user );
TD_Test::ok( ! $orphan_gen['ok'], 'a job with no snapshot refuses to render' );
TD_Test::ok( ! empty( $orphan_gen['errors'] ), 'the refusal reports an error' );
TD_Test::equals( PS::FAILED, (string) $plugin->production_jobs->get( (int) $orphan['id'] )['status'], 'the snapshot-less job is flagged failed' );

// ========================================================== concurrency

TD_Test::group( 'Concurrency — optimistic locking (§50)' );

$c_design = $plugin->designs->save(
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array( (string) $areas_shirt['front'] => array( $make_item( array( 'ref_id' => $asset1 ) ) ) ),
	),
	1,
	'',
	null
);
$c_order = $checkout_design( (int) $c_design['id'], 'p3buyer@example.org' );
wc_get_order( $c_order )->payment_complete( 'p3-txn-3' );
$c_job = (int) $plugin->production_jobs->for_order( $c_order )[0]['id'];

$plugin->production_jobs->transition( $c_job, PS::READY, 1 );

// Admin A moves READY -> IN_PRODUCTION.
$a = $plugin->production_jobs->transition( $c_job, PS::IN_PROD, 1 );
TD_Test::ok( $a['ok'], 'admin A moves the job into production' );

// Admin B, holding a stale view, tries the same transition.
$b = $plugin->production_jobs->transition( $c_job, PS::IN_PROD, 2 );
TD_Test::ok( ! $b['ok'], 'admin B cannot repeat a transition that already happened' );
TD_Test::ok( str_contains( (string) $b['error'], 'already' ) || str_contains( (string) $b['error'], 'cannot' ), 'admin B is told why' );
TD_Test::equals( PS::IN_PROD, (string) $plugin->production_jobs->get( $c_job )['status'], 'the job kept admin A\'s status' );

// ============================================================== dashboard

TD_Test::group( 'Dashboard queries — filters, search, paging (§10/§11/§48)' );

$all = $plugin->production_jobs->query( array( 'per_page' => 100 ) );
TD_Test::ok( $all['total'] >= 3, 'the dashboard can list jobs' );
TD_Test::ok( isset( $all['pages'], $all['page'], $all['per_page'] ), 'the listing is paginated' );

$paged = $plugin->production_jobs->query( array( 'per_page' => 1, 'page' => 1 ) );
TD_Test::equals( 1, count( $paged['items'] ), 'per_page is honoured (no unbounded load)' );
TD_Test::ok( $paged['pages'] >= 3, 'the page count is reported' );

$by_status = $plugin->production_jobs->query( array( 'status' => PS::COMPLETED, 'per_page' => 100 ) );
foreach ( $by_status['items'] as $j ) {
	TD_Test::equals( PS::COMPLETED, (string) $j['status'], 'the status filter only returns matching jobs' );
}

$by_type = $plugin->production_jobs->query( array( 'product_type' => 'totebag', 'per_page' => 100 ) );
TD_Test::ok( $by_type['total'] >= 1, 'the product type filter finds the tote job' );
foreach ( $by_type['items'] as $j ) {
	TD_Test::equals( 'totebag', (string) $j['product_type'], 'the product type filter is exact' );
}

$by_order = $plugin->production_jobs->query( array( 'order_id' => $order_id ) );
TD_Test::equals( 1, $by_order['total'], 'searching by order id finds the job' );

$by_design = $plugin->production_jobs->query( array( 'design_id' => $shirt_design_id ) );
TD_Test::equals( 1, $by_design['total'], 'searching by design id finds the job' );

$by_email = $plugin->production_jobs->query( array( 'search' => 'p3buyer@example.org', 'per_page' => 100 ) );
TD_Test::ok( $by_email['total'] >= 3, 'searching by customer email finds jobs' );

$by_name = $plugin->production_jobs->query( array( 'search' => 'Producer', 'per_page' => 100 ) );
TD_Test::ok( $by_name['total'] >= 3, 'searching by customer name finds jobs' );

$by_job_id = $plugin->production_jobs->query( array( 'search' => (string) $job_id ) );
TD_Test::ok( $by_job_id['total'] >= 1, 'searching by production job id finds the job' );

// A search term must never be interpreted as SQL.
$evil = $plugin->production_jobs->query( array( 'search' => "'; DROP TABLE wp_td_production_jobs; --" ) );
TD_Test::equals( 0, $evil['total'], 'an injection attempt simply matches nothing' );
TD_Test::ok( $plugin->production_jobs->get( $job_id ) !== null, 'the jobs table survived the injection attempt' );

// Priority.
TD_Test::ok( $plugin->production_jobs->set_priority( $c_job, PS::PRIORITY_URGENT, 1 ), 'priority can be set' );
TD_Test::ok( ! $plugin->production_jobs->set_priority( $c_job, 'immediately', 1 ), 'an invalid priority is refused' );
$urgent = $plugin->production_jobs->query( array( 'priority' => PS::PRIORITY_URGENT, 'per_page' => 100 ) );
TD_Test::ok( $urgent['total'] >= 1, 'jobs can be filtered by priority' );

$sorted = $plugin->production_jobs->query( array( 'orderby' => 'priority', 'per_page' => 100 ) );
TD_Test::equals( PS::PRIORITY_URGENT, (string) $sorted['items'][0]['priority'], 'priority sorting puts urgent first' );

$counts = $plugin->production_jobs->status_counts();
TD_Test::ok( is_array( $counts ) && array_sum( $counts ) >= 3, 'status counts are available for the tabs' );

// ================================================================ security

TD_Test::group( 'Production security (§29/§30/§31)' );

// File download authorisation as a plain customer.
wp_set_current_user( $buyer );
TD_Test::ok( ! PM::can_manage(), 'a customer cannot manage production' );

$files_for_job = $plugin->production_service->files( $job_id );
$a_file_id     = (int) $files_for_job[0]['id'];
$denied        = $plugin->production_service->authorise_file( $a_file_id, $job_id );
TD_Test::ok( ! $denied['ok'], 'a customer cannot download a production file' );

wp_set_current_user( 1 );
TD_Test::ok( PM::can_manage(), 'an administrator can manage production' );
$allowed = $plugin->production_service->authorise_file( $a_file_id, $job_id );
TD_Test::ok( $allowed['ok'], 'an administrator can download a production file' );
TD_Test::ok( str_ends_with( (string) $allowed['path'], '.png' ), 'the authorised path is the PNG' );

// A file id must not be usable against the wrong job (IDOR).
$mismatch = $plugin->production_service->authorise_file( $a_file_id, $tote_job_id );
TD_Test::ok( ! $mismatch['ok'], 'a file cannot be fetched through a job it does not belong to' );

// Unknown ids.
TD_Test::ok( ! $plugin->production_service->authorise_file( 99999999, $job_id )['ok'], 'an unknown file id is refused' );

// Path containment: point a row outside the store and make sure it is refused.
global $wpdb;
$ptable   = $plugin->db->table( 'production_files' );
$real_row = $plugin->production->get_file( $a_file_id );
$wpdb->update( $ptable, array( 'file_path' => '/etc/passwd' ), array( 'id' => $a_file_id ) );
$escaped = $plugin->production_service->authorise_file( $a_file_id, $job_id );
TD_Test::ok( ! $escaped['ok'], 'a tampered file_path outside the production dir is refused' );
$wpdb->update( $ptable, array( 'file_path' => (string) $real_row['file_path'] ), array( 'id' => $a_file_id ) );

// Traversal attempt in the stored path.
$wpdb->update( $ptable, array( 'file_path' => (string) $real_row['file_path'] . '/../../../../etc/passwd' ), array( 'id' => $a_file_id ) );
TD_Test::ok( ! $plugin->production_service->authorise_file( $a_file_id, $job_id )['ok'], 'a traversal path is refused' );
$wpdb->update( $ptable, array( 'file_path' => (string) $real_row['file_path'] ), array( 'id' => $a_file_id ) );

// The store itself must not be browsable.
$storage = $plugin->production->storage_dir();
TD_Test::ok( file_exists( $storage['dir'] . '/.htaccess' ), 'the production directory denies direct web access' );
TD_Test::ok( file_exists( $storage['dir'] . '/index.html' ), 'the production directory is not listable' );

// ===================================================== backward compatibility

TD_Test::group( 'Backward compatibility — back-fill (§55)' );

// An order paid before phase 3: it has a snapshot but no job.
$bc_design = $plugin->designs->save(
	array(
		'model_id' => $tshirt_id,
		'color_id' => $color_id,
		'size_id'  => $size_id,
		'areas'    => array( (string) $areas_shirt['front'] => array( $make_item( array( 'ref_id' => $asset1 ) ) ) ),
	),
	1,
	'',
	null
);
$bc_order = $checkout_design( (int) $bc_design['id'], 'p3buyer@example.org' );
wc_get_order( $bc_order )->payment_complete( 'p3-txn-4' );

// Simulate a pre-phase-3 site: delete the job the hook just made.
$bc_job_id = (int) $plugin->production_jobs->for_order( $bc_order )[0]['id'];
$wpdb->delete( $plugin->db->table( 'production_jobs' ), array( 'id' => $bc_job_id ) );
TD_Test::equals( 0, count( $plugin->production_jobs->for_order( $bc_order ) ), 'the legacy order has no production job' );

// The migration back-fills it without touching the order.
$order_total_before = (float) wc_get_order( $bc_order )->get_total();
delete_option( TShirtDesigner\Migrations::OPTION_APPLIED );
$plugin->migrations->run();

$backfilled = $plugin->production_jobs->for_order( $bc_order );
TD_Test::equals( 1, count( $backfilled ), 'the migration back-fills a job for the legacy order' );
TD_Test::equals( (int) $bc_design['id'], (int) $backfilled[0]['design_id'], 'the back-filled job knows its design' );
TD_Test::equals( $order_total_before, (float) wc_get_order( $bc_order )->get_total(), 'the legacy order total is untouched' );

// Re-running must not duplicate.
delete_option( TShirtDesigner\Migrations::OPTION_APPLIED );
$plugin->migrations->run();
TD_Test::equals( 1, count( $plugin->production_jobs->for_order( $bc_order ) ), 're-running the migration does not duplicate jobs' );

// Existing jobs are not disturbed by the back-fill.
TD_Test::equals( PS::COMPLETED, (string) $plugin->production_jobs->get( $job_id )['status'], 'the back-fill leaves existing jobs alone' );

// ================================================================ cancellation

TD_Test::group( 'Cancellation preserves data (§40)' );

$cancel_job = (int) $plugin->production_jobs->for_order( $bc_order )[0]['id'];
$plugin->production_service->generate( $cancel_job, true, 1 );
$files_before_cancel = count( $plugin->production_service->files( $cancel_job ) );
$hist_before_cancel  = count( $plugin->production_jobs->history( $cancel_job ) );

TD_Test::ok( $plugin->production_jobs->transition( $cancel_job, PS::CANCELLED, 1, 'Customer changed their mind.' )['ok'], 'a live job can be cancelled' );
TD_Test::equals( PS::CANCELLED, (string) $plugin->production_jobs->get( $cancel_job )['status'], 'the job is cancelled' );

TD_Test::ok( null !== $plugin->production_jobs->snapshot( $cancel_job ), 'cancellation preserves the snapshot' );
TD_Test::equals( $files_before_cancel, count( $plugin->production_service->files( $cancel_job ) ), 'cancellation preserves the production files' );
TD_Test::ok( count( $plugin->production_jobs->history( $cancel_job ) ) > $hist_before_cancel, 'cancellation preserves and extends the history' );
TD_Test::ok( null !== wc_get_order( $bc_order ), 'cancellation preserves the order' );

exit( TD_Test::summary() );
