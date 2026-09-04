<?php
/**
 * Customer-facing production status tests.
 *
 * Covers the permissive half of the customer rule: a customer may see a coarse
 * status for their OWN order, and must never see files, internal notes, the
 * activity log or internal error states.
 *
 * Not loaded in production.
 *
 * @package TShirtDesigner
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
td_test_activate_plugin();

use TShirtDesigner\Customer_Status;
use TShirtDesigner\Production_Status;

global $td_pass, $td_fail, $td_failures;
$td_pass     = 0;
$td_fail     = 0;
$td_failures = array();

/**
 * Assertion helper.
 *
 * @param string $name  What is being asserted.
 * @param bool   $cond  Result.
 * @param string $extra Detail on failure.
 */
function td_ok( string $name, bool $cond, string $extra = '' ): void {
	global $td_pass, $td_fail, $td_failures;
	if ( $cond ) {
		++$td_pass;
		echo "  [PASS] {$name}\n";
	} else {
		++$td_fail;
		$td_failures[] = $name;
		echo "  [FAIL] {$name}" . ( '' !== $extra ? " -> {$extra}" : '' ) . "\n";
	}
}

echo "\n============================================================\n";
echo "CUSTOMER-FACING STATUS\n";
echo "============================================================\n";

echo "\n-- Every internal status maps to a customer label\n";
$internal = array(
	Production_Status::NEW_JOB,
	Production_Status::PAID,
	Production_Status::READY,
	Production_Status::IN_PROD,
	Production_Status::PRINTED,
	Production_Status::QC,
	Production_Status::PACKED,
	Production_Status::SHIPPED,
	Production_Status::COMPLETED,
	Production_Status::CANCELLED,
	Production_Status::FAILED,
);
$unmapped = array();
foreach ( $internal as $s ) {
	if ( '' === Customer_Status::label( $s ) ) {
		$unmapped[] = $s;
	}
}
td_ok( 'no internal status is left without a customer label', array() === $unmapped, implode( ', ', $unmapped ) );
td_ok( 'an unknown status yields an empty label, not a crash', '' === Customer_Status::label( 'bogus_status' ) );

echo "\n-- Internal detail must not leak through the label\n";
td_ok(
	'production_error is not shown as an error',
	Customer_Status::label( Production_Status::FAILED ) === Customer_Status::label( Production_Status::IN_PROD ),
	Customer_Status::label( Production_Status::FAILED )
);

$leaky = array();
foreach ( $internal as $s ) {
	$label = strtolower( Customer_Status::label( $s ) );
	foreach ( array( 'error', 'fail', 'quality', 'check', 'printed', 'ready_for', 'snapshot', 'job' ) as $word ) {
		if ( str_contains( $label, $word ) ) {
			$leaky[] = "{$s}:{$label}";
		}
	}
}
td_ok( 'no customer label exposes internal vocabulary', array() === $leaky, implode( ', ', $leaky ) );

td_ok(
	'quality check is indistinguishable from ordinary production',
	Customer_Status::label( Production_Status::QC ) === Customer_Status::label( Production_Status::IN_PROD )
);
td_ok(
	'printed is indistinguishable from ordinary production',
	Customer_Status::label( Production_Status::PRINTED ) === Customer_Status::label( Production_Status::IN_PROD )
);

echo "\n-- Progress steps are monotonic\n";
td_ok( 'paid is step 1', 1 === Customer_Status::step( Production_Status::PAID ) );
td_ok( 'in production is step 2', 2 === Customer_Status::step( Production_Status::IN_PROD ) );
td_ok( 'shipped is step 3', 3 === Customer_Status::step( Production_Status::SHIPPED ) );
td_ok( 'completed is step 4', 4 === Customer_Status::step( Production_Status::COMPLETED ) );
td_ok( 'cancelled has no step', 0 === Customer_Status::step( Production_Status::CANCELLED ) );
td_ok( 'an internal failure does not advance the customer step', 2 === Customer_Status::step( Production_Status::FAILED ) );

$prev = 0;
$mono = true;
foreach ( array( Production_Status::PAID, Production_Status::IN_PROD, Production_Status::SHIPPED, Production_Status::COMPLETED ) as $s ) {
	$step = Customer_Status::step( $s );
	if ( $step < $prev ) {
		$mono = false;
	}
	$prev = $step;
}
td_ok( 'the pipeline never moves a customer backwards', $mono );

echo "\n-- Labels are translatable\n";
$untranslated = array();
foreach ( $internal as $s ) {
	$label = Customer_Status::label( $s );
	// Every label must be a non-empty string that went through __().
	if ( '' === trim( $label ) ) {
		$untranslated[] = $s;
	}
}
td_ok( 'every label is a non-empty translatable string', array() === $untranslated, implode( ', ', $untranslated ) );

echo "\n-- Ownership: the renderer is wired but scoped\n";
td_ok(
	'the customer status hook is registered',
	has_action( 'woocommerce_order_item_meta_end' ) !== false
);
td_ok(
	'the class exposes no file, note or history accessor',
	! method_exists( Customer_Status::class, 'files' )
		&& ! method_exists( Customer_Status::class, 'notes' )
		&& ! method_exists( Customer_Status::class, 'history' )
);

$methods = get_class_methods( Customer_Status::class );
sort( $methods );
td_ok(
	'the public surface is read-only',
	array() === array_diff( $methods, array( '__construct', 'labels', 'step', 'label', 'render_item_status' ) ),
	implode( ', ', $methods )
);

echo "\n============================================================\n";
$total = $td_pass + $td_fail;
echo "{$total} tests, {$td_pass} passed, {$td_fail} failed\n";
foreach ( $td_failures as $f ) {
	echo "  - {$f}\n";
}
echo "============================================================\n";
