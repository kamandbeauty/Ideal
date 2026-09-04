<?php
/**
 * Main plugin class — wires every module together.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Plugin {

	private static ?Plugin $instance = null;

	public Database $db;
	public Model_Manager $models;
	public Color_Manager $colors;
	public Size_Manager $sizes;
	public Print_Area_Manager $print_areas;
	public Asset_Manager $assets;
	public Design_Manager $designs;
	public Media_Manager $media;
	public Pricing_Engine $pricing;
	public Settings $settings;
	public Logger $logger;
	public Migrations $migrations;
	public Production_Renderer $production;
	public Production_Manager $production_jobs;
	public ?Cart_Manager $cart = null;
	public ?Order_Manager $orders = null;

	private bool $booted = false;

	/**
	 * Singleton.
	 */
	public static function instance(): Plugin {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}
		return self::$instance;
	}

	private function __construct() {
		$this->db         = new Database();
		$this->settings   = new Settings();
		$this->logger     = new Logger( $this->db );
		$this->migrations = new Migrations( $this->db );
		$this->models     = new Model_Manager( $this->db );
		$this->colors     = new Color_Manager( $this->db );
		$this->sizes      = new Size_Manager( $this->db );
		$this->print_areas = new Print_Area_Manager( $this->db );
		$this->assets     = new Asset_Manager( $this->db );
		$this->media      = new Media_Manager( $this->settings );
		$this->pricing    = new Pricing_Engine();
		$this->designs    = new Design_Manager(
			$this->db,
			$this->models,
			$this->print_areas,
			$this->pricing,
			$this->media
		);
		$this->production = new Production_Renderer( $this->db, $this->settings );
		$this->production_jobs = new Production_Manager( $this );
	}

	/**
	 * Activation: create/upgrade tables and seed defaults.
	 */
	public function activate(): void {
		$installed_db = get_option( Migrations::OPTION_DB_VERSION );

		if ( ! $installed_db ) {
			// Fresh install: the CREATE TABLE schema is already current, so the
			// data migrations have nothing to back-fill.
			$this->db->install();
			$this->settings->seed_defaults();
			$this->migrations->mark_all_applied();
			$this->seed_content();
		} else {
			// Upgrade: schema first, then the pending data steps.
			$this->settings->seed_defaults();
			$this->migrations->run();
			// Existing phase-1 sites gain the bundled tote bag product type.
			$this->seed_totebag();
		}

		update_option( 'td_version', TD_VERSION );

		if ( ! wp_next_scheduled( 'td_cleanup_designs' ) ) {
			wp_schedule_event( time() + HOUR_IN_SECONDS, 'daily', 'td_cleanup_designs' );
		}

		// Make sure rewrite rules include our REST namespace.
		flush_rewrite_rules();
	}

	/**
	 * Deactivation: unschedule our cron jobs.
	 */
	public function deactivate(): void {
		$timestamp = wp_next_scheduled( 'td_cleanup_designs' );
		if ( $timestamp ) {
			wp_unschedule_event( $timestamp, 'td_cleanup_designs' );
		}
	}

	/**
	 * Seed only the tote bag (used when upgrading a phase-1 install).
	 */
	private function seed_totebag(): void {
		$seed = new Content_Seeder(
			$this->db,
			$this->models,
			$this->colors,
			$this->sizes,
			$this->print_areas,
			$this->assets,
			$this->pricing
		);
		$seed->seed_totebag();
	}

	/**
	 * Seed the starter content (default model, colors, sizes, print areas,
	 * sample assets and pricing rules). Runs once on first activation.
	 */
	private function seed_content(): void {
		$seed = new Content_Seeder(
			$this->db,
			$this->models,
			$this->colors,
			$this->sizes,
			$this->print_areas,
			$this->assets,
			$this->pricing
		);
		$seed->run();
	}

	/**
	 * Boot all runtime modules.
	 */
	public function boot(): void {
		if ( $this->booted ) {
			return;
		}
		$this->booted = true;

		add_action( 'init', array( $this, 'init' ) );

		// Database upgrades between plugin versions (migration-driven).
		if ( get_option( Migrations::OPTION_DB_VERSION ) !== TD_DB_VERSION ) {
			$this->migrations->run();
		}

		new Rest_Api( $this );
		new Rest_Api_V2( $this );
		new Shortcode( $this );
		new Woocommerce( $this );
		new Assets( $this );
		new Cleanup( $this );

		if ( Woocommerce::is_active() ) {
			$this->cart   = new Cart_Manager( $this );
			$this->orders = new Order_Manager( $this );
			new My_Designs( $this );
		}

		if ( is_admin() ) {
			Admin\Admin::register( $this );
		}
	}

	/**
	 * init callback: load translations, register the block.
	 */
	public function init(): void {
		load_plugin_textdomain( 'tshirt-designer', false, dirname( TD_PLUGIN_BASENAME ) . '/languages' );

		/**
		 * Register the dynamic block (server-rendered, no build step).
		 */
		if ( function_exists( 'register_block_type' ) ) {
			register_block_type(
				TD_PLUGIN_DIR . 'assets/js/blocks/tshirt-designer/block.json',
				array(
					'render_callback' => static function ( array $attributes ): string {
						$attrs = array();
						if ( ! empty( $attributes['modelId'] ) ) {
							$attrs['model'] = (string) (int) $attributes['modelId'];
						}
						return do_shortcode( '[tshirt_designer ' . self::shortcode_attrs( $attrs ) . ']' );
					},
				)
			);
		}
	}

	/**
	 * Build a shortcode attribute string.
	 *
	 * @param array<string, string> $attrs Key => value (already safe strings).
	 */
	private static function shortcode_attrs( array $attrs ): string {
		$parts = array();
		foreach ( $attrs as $key => $value ) {
			$parts[] = $key . '="' . esc_attr( $value ) . '"';
		}
		return implode( ' ', $parts );
	}

	/**
	 * Plugin URL helper.
	 */
	public static function url( string $path ): string {
		return TD_PLUGIN_URL . ltrim( $path, '/' );
	}
}
