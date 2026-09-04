<?php
/**
 * Custom table management (dbDelta install + drop).
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Database {

	/**
	 * Table keys handled by the plugin. Each maps to `{$wpdb->prefix}td_<key>`.
	 *
	 * @return string[]
	 */
	public function tables(): array {
		return array(
			'models',
			'model_colors',
			'model_sizes',
			'print_areas',
			'design_assets',
			'pricing_rules',
			'designs',
			'uploads',
		);
	}

	/**
	 * Fully-qualified table name for a key.
	 */
	public function table( string $key ): string {
		global $wpdb;
		return $wpdb->prefix . 'td_' . $key;
	}

	/**
	 * Create or update all tables using dbDelta().
	 */
	public function install(): void {
		require_once ABSPATH . 'wp-admin/includes/upgrade.php';

		$charset = $this->charset_sql();

		foreach ( $this->schema() as $sql ) {
			dbDelta( $sql );
		}
	}

	/**
	 * Drop every plugin table (used by uninstall when enabled).
	 */
	public function drop(): void {
		global $wpdb;
		foreach ( $this->tables() as $key ) {
			$table = $this->table( $key );
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$wpdb->query( "DROP TABLE IF EXISTS `{$table}`" );
		}
	}

	/**
	 * Character set / collation clause.
	 */
	private function charset_sql(): string {
		global $wpdb;
		$charset = $wpdb->get_charset_collate();
		return $charset;
	}

	/**
	 * Full CREATE TABLE statements (dbDelta-friendly formatting).
	 *
	 * @return string[]
	 */
	public function schema(): array {
		$c   = $this->charset_sql();
		$now = '1970-01-01 00:00:00';

		return array(
			"CREATE TABLE {$this->table('models')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				name varchar(191) NOT NULL,
				slug varchar(191) NOT NULL DEFAULT '',
				description text NULL,
				model_file_id bigint(20) unsigned NOT NULL DEFAULT 0,
				model_file_path varchar(500) NOT NULL DEFAULT '',
				preview_image_id bigint(20) unsigned NOT NULL DEFAULT 0,
				preview_image_path varchar(500) NOT NULL DEFAULT '',
				wc_product_id bigint(20) unsigned NOT NULL DEFAULT 0,
				base_price decimal(14,2) NOT NULL DEFAULT 0,
				is_active tinyint(1) NOT NULL DEFAULT 1,
				sort_order int(11) NOT NULL DEFAULT 0,
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY is_active (is_active),
				KEY slug (slug)
			) {$c};",

			"CREATE TABLE {$this->table('model_colors')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				model_id bigint(20) unsigned NOT NULL DEFAULT 0,
				name varchar(191) NOT NULL,
				hex varchar(7) NOT NULL DEFAULT '#FFFFFF',
				texture_image_id bigint(20) unsigned NOT NULL DEFAULT 0,
				thumbnail_id bigint(20) unsigned NOT NULL DEFAULT 0,
				is_active tinyint(1) NOT NULL DEFAULT 1,
				sort_order int(11) NOT NULL DEFAULT 0,
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY model_id (model_id),
				KEY is_active (is_active)
			) {$c};",

			"CREATE TABLE {$this->table('model_sizes')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				model_id bigint(20) unsigned NOT NULL DEFAULT 0,
				name varchar(191) NOT NULL,
				price_modifier decimal(14,2) NOT NULL DEFAULT 0,
				is_active tinyint(1) NOT NULL DEFAULT 1,
				sort_order int(11) NOT NULL DEFAULT 0,
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY model_id (model_id),
				KEY is_active (is_active)
			) {$c};",

			"CREATE TABLE {$this->table('print_areas')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				model_id bigint(20) unsigned NOT NULL DEFAULT 0,
				name varchar(191) NOT NULL,
				area_type varchar(40) NOT NULL DEFAULT 'other',
				max_width_cm decimal(6,2) NOT NULL DEFAULT 30,
				max_height_cm decimal(6,2) NOT NULL DEFAULT 35,
				position longtext NULL,
				is_active tinyint(1) NOT NULL DEFAULT 1,
				sort_order int(11) NOT NULL DEFAULT 0,
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY model_id (model_id),
				KEY is_active (is_active)
			) {$c};",

			"CREATE TABLE {$this->table('design_assets')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				name varchar(191) NOT NULL,
				category varchar(40) NOT NULL DEFAULT 'other',
				file_id bigint(20) unsigned NOT NULL DEFAULT 0,
				file_path varchar(500) NOT NULL DEFAULT '',
				is_active tinyint(1) NOT NULL DEFAULT 1,
				sort_order int(11) NOT NULL DEFAULT 0,
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY category (category),
				KEY is_active (is_active)
			) {$c};",

			"CREATE TABLE {$this->table('pricing_rules')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				rule_type varchar(20) NOT NULL DEFAULT 'size_tier',
				scope varchar(10) NOT NULL DEFAULT 'global',
				print_area_id bigint(20) unsigned NOT NULL DEFAULT 0,
				size_from_cm decimal(6,2) NOT NULL DEFAULT 0,
				size_to_cm decimal(6,2) NOT NULL DEFAULT 0,
				item_count int(10) unsigned NOT NULL DEFAULT 0,
				price decimal(14,2) NOT NULL DEFAULT 0,
				is_active tinyint(1) NOT NULL DEFAULT 1,
				sort_order int(11) NOT NULL DEFAULT 0,
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY rule_type (rule_type),
				KEY print_area_id (print_area_id),
				KEY is_active (is_active)
			) {$c};",

			"CREATE TABLE {$this->table('designs')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				user_id bigint(20) unsigned NOT NULL DEFAULT 0,
				guest_token varchar(64) NOT NULL DEFAULT '',
				model_id bigint(20) unsigned NOT NULL DEFAULT 0,
				color_id bigint(20) unsigned NOT NULL DEFAULT 0,
				size_id bigint(20) unsigned NOT NULL DEFAULT 0,
				design_data longtext NULL,
				preview_image_id bigint(20) unsigned NOT NULL DEFAULT 0,
				price_total decimal(14,2) NOT NULL DEFAULT 0,
				price_breakdown longtext NULL,
				status varchar(20) NOT NULL DEFAULT 'saved',
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY user_id (user_id),
				KEY guest_token (guest_token),
				KEY model_id (model_id)
			) {$c};",

			"CREATE TABLE {$this->table('uploads')} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				user_id bigint(20) unsigned NOT NULL DEFAULT 0,
				guest_token varchar(64) NOT NULL DEFAULT '',
				attachment_id bigint(20) unsigned NOT NULL DEFAULT 0,
				original_name varchar(191) NOT NULL DEFAULT '',
				mime varchar(100) NOT NULL DEFAULT '',
				width int(10) unsigned NOT NULL DEFAULT 0,
				height int(10) unsigned NOT NULL DEFAULT 0,
				created_at datetime NOT NULL DEFAULT '{$now}',
				updated_at datetime NOT NULL DEFAULT '{$now}',
				PRIMARY KEY  (id),
				KEY user_id (user_id),
				KEY guest_token (guest_token),
				KEY attachment_id (attachment_id)
			) {$c};",
		);
	}
}
