<?php
/**
 * Uninstall routine.
 *
 * Runs when the plugin is deleted from wp-admin. All data is removed only
 * when "Delete all data on uninstall" is enabled in the plugin settings;
 * otherwise database tables and uploads are left untouched.
 *
 * @package TShirtDesigner
 */

defined( 'WP_UNINSTALL_PLUGIN' ) || exit;

$td_uninstall_options = array(
	'td_settings',
	'td_db_version',
	'td_version',
);

/**
 * Full cleanup is opt-in via the td_settings option.
 */
$td_settings = get_option( 'td_settings', array() );
$td_delete   = is_array( $td_settings )
	&& isset( $td_settings['delete_data_on_uninstall'] )
	&& (int) $td_settings['delete_data_on_uninstall'] === 1;

if ( ! $td_delete ) {
	// Remove plugin bookkeeping options only.
	foreach ( $td_uninstall_options as $td_uninstall_option ) {
		delete_option( $td_uninstall_option );
	}
	if ( is_multisite() ) {
		delete_site_option( 'td_db_version' );
	}
	return;
}

global $wpdb;

/*
 * Drop plugin tables.
 *
 * The table list deliberately comes from Database::tables() rather than being
 * repeated here: a duplicated list silently fell out of sync as later phases
 * added tables, leaving orphaned data behind on uninstall. Database is a plain
 * class with no bootstrap dependencies (it only needs $wpdb), so it is safe to
 * require directly in the uninstall context.
 */
$td_uninstall_db_file = __DIR__ . '/includes/class-database.php';

if ( is_readable( $td_uninstall_db_file ) ) {
	require_once $td_uninstall_db_file;
	( new TShirtDesigner\Database() )->drop();
} else {
	// Defensive fallback: never leave tables behind if the file is missing.
	$td_uninstall_like = $wpdb->esc_like( $wpdb->prefix . 'td_' ) . '%';
	// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
	$td_uninstall_found = $wpdb->get_col( $wpdb->prepare( 'SHOW TABLES LIKE %s', $td_uninstall_like ) );
	foreach ( (array) $td_uninstall_found as $td_uninstall_table ) {
		$wpdb->query( "DROP TABLE IF EXISTS `{$td_uninstall_table}`" ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
	}
}

// Delete options.
foreach ( $td_uninstall_options as $td_uninstall_option ) {
	delete_option( $td_uninstall_option );
}
if ( is_multisite() ) {
	delete_site_option( 'td_db_version' );
}

/*
 * Remove uploaded artwork / previews and print-ready production files.
 *
 * td-production holds every rendered print file. Leaving it behind meant a
 * reinstall resurrected old customer artwork, so it is cleared here too.
 */
$td_uninstall_upload_dir = wp_upload_dir();
$td_uninstall_basedir    = trailingslashit( $td_uninstall_upload_dir['basedir'] );
$td_uninstall_targets    = array(
	$td_uninstall_basedir . 'td-uploads',
	$td_uninstall_basedir . 'td-production',
);

foreach ( $td_uninstall_targets as $td_uninstall_target ) {
	if ( ! is_dir( $td_uninstall_target ) ) {
		continue;
	}

	$td_uninstall_iterator = new RecursiveIteratorIterator(
		new RecursiveDirectoryIterator( $td_uninstall_target, FilesystemIterator::SKIP_DOTS ),
		RecursiveIteratorIterator::CHILD_FIRST
	);

	foreach ( $td_uninstall_iterator as $td_uninstall_file ) {
		if ( $td_uninstall_file->isDir() ) {
			@rmdir( $td_uninstall_file->getPathname() ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		} else {
			@unlink( $td_uninstall_file->getPathname() ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		}
	}

	@rmdir( $td_uninstall_target ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
}

/*
 * Clear scheduled events. Deactivation removes td_cleanup_designs, but a site
 * can be deleted without deactivating first, and per-order file generation
 * events are scheduled with arguments, so clear both hooks wholesale.
 */
foreach ( array( 'td_cleanup_designs', 'td_generate_production_files' ) as $td_uninstall_hook ) {
	if ( function_exists( 'wp_unschedule_hook' ) ) {
		wp_unschedule_hook( $td_uninstall_hook );
	}
}

// Clear any cached REST/option fragments.
wp_cache_flush();
