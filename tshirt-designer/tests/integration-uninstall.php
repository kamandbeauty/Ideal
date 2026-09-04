<?php
/**
 * Uninstall integration test.
 *
 * Verifies that deleting the plugin removes EVERY table, option, upload
 * directory and scheduled event it created — and, just as importantly, that it
 * removes nothing when the opt-in setting is off.
 *
 * This test is destructive by design: it drops the plugin schema. It must be
 * run in its own process, never alongside the other suites.
 *
 * Not loaded in production.
 *
 * @package TShirtDesigner
 */

/*
 * Test-only entry point. These files live inside the plugin folder and are
 * therefore reachable over HTTP on a normal install. Refuse anything that is
 * not a local CLI invocation.
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

global $wpdb, $td_pass, $td_fail, $td_failures;
$td_pass     = 0;
$td_fail     = 0;
$td_failures = array();

/**
 * Assertion helper.
 *
 * @param string $name  What is being asserted.
 * @param bool   $cond  Result.
 * @param string $extra Optional detail shown on failure.
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

/**
 * Does a table physically exist?
 *
 * @param string $table Fully-qualified table name.
 */
function td_table_exists( string $table ): bool {
	global $wpdb;
	// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
	$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $table ) );
	return (string) $found === $table;
}

/**
 * Run uninstall.php in an isolated scope, exactly as WordPress does.
 */
function td_run_uninstall(): void {
	// WordPress defines this before including the file; uninstall.php exits without it.
	if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
		define( 'WP_UNINSTALL_PLUGIN', 'tshirt-designer/tshirt-designer.php' );
	}
	require WP_PLUGIN_DIR . '/tshirt-designer/uninstall.php';
}

echo "\n============================================================\n";
echo "UNINSTALL INTEGRATION TEST\n";
echo "============================================================\n";

$db     = new TShirtDesigner\Database();
$tables = $db->tables();

// ---------------------------------------------------------------- setup ----
$db->install();

$uploads     = wp_upload_dir();
$dir_uploads = trailingslashit( $uploads['basedir'] ) . 'td-uploads';
$dir_prod    = trailingslashit( $uploads['basedir'] ) . 'td-production';

wp_mkdir_p( $dir_uploads . '/2026/09' );
wp_mkdir_p( $dir_prod . '/ORDER-1' );
file_put_contents( $dir_uploads . '/2026/09/art.png', 'x' );
file_put_contents( $dir_prod . '/ORDER-1/FRONT.png', 'x' );
file_put_contents( $dir_prod . '/.htaccess', "Deny from all\n" );

update_option( 'td_settings', array( 'delete_data_on_uninstall' => 0 ) );
update_option( 'td_db_version', '1.2.0' );
update_option( 'td_version', '1.2.0' );
wp_schedule_event( time() + 3600, 'daily', 'td_cleanup_designs' );
wp_schedule_single_event( time() + 5, 'td_generate_production_files', array( 123 ) );

echo "\n-- Setup\n";
$created = 0;
foreach ( $tables as $key ) {
	if ( td_table_exists( $db->table( $key ) ) ) {
		++$created;
	}
}
td_ok( 'all ' . count( $tables ) . ' plugin tables exist before uninstall', $created === count( $tables ), "created={$created}" );
td_ok( 'the upload directories exist', is_dir( $dir_uploads ) && is_dir( $dir_prod ) );

// ------------------------------------------- opt-out must preserve data ----
echo "\n-- Uninstall with the opt-in setting OFF must preserve user data\n";
td_run_uninstall();

$survived = 0;
foreach ( $tables as $key ) {
	if ( td_table_exists( $db->table( $key ) ) ) {
		++$survived;
	}
}
td_ok( 'no tables were dropped', $survived === count( $tables ), "survived={$survived}" );
td_ok( 'artwork was kept', file_exists( $dir_uploads . '/2026/09/art.png' ) );
td_ok( 'production files were kept', file_exists( $dir_prod . '/ORDER-1/FRONT.png' ) );
td_ok( 'bookkeeping options were still cleared', false === get_option( 'td_db_version', false ) );

// --------------------------------------------- opt-in must remove all -----
echo "\n-- Uninstall with the opt-in setting ON must remove everything\n";

/*
 * Re-run the real file. td_run_uninstall() uses `require`, not `require_once`,
 * so the second pass genuinely re-executes it — the early `return` in the
 * opt-out branch above only returned from that include.
 *
 * This deliberately does NOT eval() a copy of the source: inside eval(),
 * __DIR__ resolves to this test's directory rather than the plugin root, so
 * uninstall.php would miss includes/class-database.php and silently fall
 * through to its defensive branch. That made the test pass even when the real
 * drop path was removed entirely.
 */
update_option( 'td_settings', array( 'delete_data_on_uninstall' => 1 ) );
update_option( 'td_db_version', '1.2.0' );
update_option( 'td_version', '1.2.0' );

td_run_uninstall();

echo "\n-- Results\n";
$left = array();
foreach ( $tables as $key ) {
	if ( td_table_exists( $db->table( $key ) ) ) {
		$left[] = $key;
	}
}
td_ok( 'every plugin table was dropped', array() === $left, 'left behind: ' . implode( ', ', $left ) );

// Named checks for the tables that were previously orphaned, so a regression
// names the exact culprit instead of just "some table survived".
foreach ( array( 'design_versions', 'production_files', 'production_jobs', 'production_events', 'logs' ) as $key ) {
	td_ok( "table td_{$key} was dropped", ! td_table_exists( $db->table( $key ) ) );
}

td_ok( 'the td-uploads directory was removed', ! is_dir( $dir_uploads ), $dir_uploads );
td_ok( 'the td-production directory was removed', ! is_dir( $dir_prod ), $dir_prod );

td_ok( 'option td_settings was deleted', false === get_option( 'td_settings', false ) );
td_ok( 'option td_db_version was deleted', false === get_option( 'td_db_version', false ) );
td_ok( 'option td_version was deleted', false === get_option( 'td_version', false ) );

td_ok( 'the cleanup cron was unscheduled', false === wp_next_scheduled( 'td_cleanup_designs' ) );
td_ok(
	'the production-file cron was unscheduled',
	false === wp_next_scheduled( 'td_generate_production_files', array( 123 ) )
);

echo "\n============================================================\n";
$total = $td_pass + $td_fail;
echo "{$total} tests, {$td_pass} passed, {$td_fail} failed\n";
if ( $td_failures ) {
	foreach ( $td_failures as $f ) {
		echo "  - {$f}\n";
	}
}
echo "============================================================\n";
