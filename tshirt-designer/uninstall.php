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

$td_uninstall_tables = array(
	$wpdb->prefix . 'td_designs',
	$wpdb->prefix . 'td_uploads',
	$wpdb->prefix . 'td_pricing_rules',
	$wpdb->prefix . 'td_design_assets',
	$wpdb->prefix . 'td_print_areas',
	$wpdb->prefix . 'td_model_sizes',
	$wpdb->prefix . 'td_model_colors',
	$wpdb->prefix . 'td_models',
);

// Drop plugin tables.
foreach ( $td_uninstall_tables as $td_uninstall_table ) {
	$wpdb->query( "DROP TABLE IF EXISTS `{$td_uninstall_table}`" ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
}

// Delete options.
foreach ( $td_uninstall_options as $td_uninstall_option ) {
	delete_option( $td_uninstall_option );
}
if ( is_multisite() ) {
	delete_site_option( 'td_db_version' );
}

// Remove uploaded artwork / previews.
$td_uninstall_upload_dir = wp_upload_dir();
$td_uninstall_target     = trailingslashit( $td_uninstall_upload_dir['basedir'] ) . 'td-uploads';

if ( is_dir( $td_uninstall_target ) ) {
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

// Clear any cached REST/option fragments.
wp_cache_flush();
