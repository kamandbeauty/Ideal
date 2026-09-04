<?php
/**
 * Frontend asset loading (ES modules, no build step).
 *
 * The designer entry is loaded as <script type="module">; three.js is
 * resolved through an import map so addon modules can `import 'three'`.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Assets {

	private const DESIGNER_HANDLE = 'td-designer';
	private const ADMIN_HANDLE    = 'td-admin';

	public function __construct( private Plugin $plugin ) {
		add_action( 'wp_enqueue_scripts', array( $this, 'register_designer' ) );
		add_action( 'admin_enqueue_scripts', array( $this, 'register_admin' ) );
		add_action( 'init', array( $this, 'register_block_script' ) );
		add_action( 'enqueue_block_editor_assets', array( $this, 'enqueue_block_editor_assets' ) );
		add_filter( 'script_loader_tag', array( $this, 'module_tag' ), 10, 3 );
	}

	/**
	 * Register the Gutenberg block editor script (no build step; uses wp.* globals).
	 */
	public function register_block_script(): void {
		if ( ! function_exists( 'wp_register_script' ) ) {
			return;
		}
		wp_register_script(
			'td-block-designer',
			Plugin::url( 'assets/js/blocks/tshirt-designer/block.js' ),
			array( 'wp-blocks', 'wp-element', 'wp-block-editor', 'wp-components', 'wp-api-fetch' ),
			TD_VERSION,
			true
		);

		wp_localize_script(
			'td-block-designer',
			'TD_BLOCK',
			array(
				'i18n' => array(
					'Default model'   => __( 'Default model', 'tshirt-designer' ),
					'Settings'        => __( 'Settings', 'tshirt-designer' ),
					'Initial model'   => __( 'Initial model', 'tshirt-designer' ),
					'T-Shirt Designer' => __( 'T-Shirt Designer', 'tshirt-designer' ),
					'Interactive 3D T-Shirt designer for your customers.' => __( 'Interactive 3D T-Shirt designer for your customers.', 'tshirt-designer' ),
					'The interactive 3D designer runs on the live page. Preview it by viewing the published post.' => __( 'The interactive 3D designer runs on the live page. Preview it by viewing the published post.', 'tshirt-designer' ),
				),
			)
		);
	}

	/**
	 * Enqueue the block script inside the editor.
	 */
	public function enqueue_block_editor_assets(): void {
		if ( wp_script_is( 'td-block-designer', 'registered' ) ) {
			wp_enqueue_script( 'td-block-designer' );
		}
	}

	/**
	 * Register (not enqueue) designer assets; the shortcode enqueues lazily.
	 */
	public function register_designer(): void {
		wp_register_style(
			'td-designer-style',
			Plugin::url( 'assets/css/designer.css' ),
			array(),
			TD_VERSION
		);

		wp_register_script(
			self::DESIGNER_HANDLE,
			Plugin::url( 'assets/js/designer/main.js' ),
			array(),
			TD_VERSION,
			true
		);
	}

	/**
	 * Enqueue designer assets (called by the template).
	 */
	public function enqueue_designer(): void {
		wp_enqueue_style( 'td-designer-style' );
		wp_enqueue_script( self::DESIGNER_HANDLE );

		// Import map for three.js.
		$map = array(
			'imports' => array(
				'three'          => Plugin::url( 'assets/js/vendor/three/three.module.js' ),
				'three/addons/'  => Plugin::url( 'assets/js/vendor/three/addons/' ),
			),
		);
		wp_print_inline_script_tag(
			json_encode( $map, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ),
			array(
				'type' => 'importmap',
				'id'   => 'td-importmap',
			)
		);
	}

	/**
	 * Admin assets.
	 */
	public function register_admin( string $hook ): void {
		$is_plugin_page = str_contains( $hook, 'tshirt-designer' );

		// The production panel is rendered on the WooCommerce order screen
		// (both the legacy post editor and HPOS), which needs our styles too.
		$is_order_screen = false;
		if ( function_exists( 'get_current_screen' ) ) {
			$screen = get_current_screen();
			if ( null !== $screen ) {
				$order_screens = array( 'shop_order', 'edit-shop_order', 'woocommerce_page_wc-orders' );
				$is_order_screen = in_array( (string) $screen->id, $order_screens, true )
					|| 'shop_order' === (string) $screen->post_type;
			}
		}

		if ( ! $is_plugin_page && ! $is_order_screen ) {
			return;
		}

		wp_enqueue_style(
			self::ADMIN_HANDLE . '-style',
			Plugin::url( 'assets/css/admin.css' ),
			array(),
			TD_VERSION
		);

		if ( ! $is_plugin_page ) {
			// Order screens only need the stylesheet.
			return;
		}

		wp_enqueue_media();
		wp_enqueue_script(
			self::ADMIN_HANDLE,
			Plugin::url( 'assets/js/admin/admin.js' ),
			array(),
			TD_VERSION,
			true
		);
		wp_localize_script( self::ADMIN_HANDLE, 'TD_ADMIN', array(
			'i18n' => array(
				'chooseModel'  => __( 'Choose a 3D model (GLB/GLTF)', 'tshirt-designer' ),
				'chooseImage'  => __( 'Choose an image', 'tshirt-designer' ),
				'use'          => __( 'Use this file', 'tshirt-designer' ),
				'remove'       => __( 'Remove', 'tshirt-designer' ),
			),
		) );
	}

	/**
	 * Load the designer entry as a native ES module.
	 */
	public function module_tag( string $tag, string $handle, string $src ): string {
		if ( self::DESIGNER_HANDLE !== $handle ) {
			return $tag;
		}
		// phpcs:ignore WordPress.WP.EnqueuedResources.NonEnqueuedScript
		return '<script type="module" src="' . esc_url( $src ) . '" id="td-designer-js"></script>';
	}

	/**
	 * Boot data passed to the designer app.
	 *
	 * @return array<string, mixed>
	 */
	public static function boot_data( Plugin $plugin, int $initial_model, int $preload_design ): array {
		$i18n = array(
			'chooseModel'    => __( 'Choose a model', 'tshirt-designer' ),
			'chooseColor'    => __( 'Color', 'tshirt-designer' ),
			'chooseSize'     => __( 'Size', 'tshirt-designer' ),
			'printAreas'     => __( 'Print area', 'tshirt-designer' ),
			'artwork'        => __( 'Artwork', 'tshirt-designer' ),
			'upload'         => __( 'Upload image', 'tshirt-designer' ),
			'uploading'      => __( 'Uploading…', 'tshirt-designer' ),
			'uploadHint'     => __( 'JPG, PNG or WEBP — up to', 'tshirt-designer' ),
			'uploadOk'       => __( 'Image added to the artwork.', 'tshirt-designer' ),
			'uploadBadType'  => __( 'Only JPG, PNG and WEBP images are allowed.', 'tshirt-designer' ),
			'uploadTooBig'   => __( 'The file is larger than the allowed size.', 'tshirt-designer' ),
			'layers'         => __( 'Layers', 'tshirt-designer' ),
			'noLayers'       => __( 'No items on this area yet. Pick artwork or upload an image.', 'tshirt-designer' ),
			'price'          => __( 'Price', 'tshirt-designer' ),
			'basePrice'      => __( 'Base product', 'tshirt-designer' ),
			'sizePrice'      => __( 'Size surcharge', 'tshirt-designer' ),
			'prints'         => __( 'Prints', 'tshirt-designer' ),
			'total'          => __( 'Total', 'tshirt-designer' ),
			'save'           => __( 'Save design', 'tshirt-designer' ),
			'saving'         => __( 'Saving…', 'tshirt-designer' ),
			'saved'          => __( 'Design saved!', 'tshirt-designer' ),
			'calculating'    => __( 'Calculating…', 'tshirt-designer' ),
			'reset'          => __( 'Reset view', 'tshirt-designer' ),
			'front'          => __( 'Front', 'tshirt-designer' ),
			'back'           => __( 'Back', 'tshirt-designer' ),
			'left'           => __( 'Left', 'tshirt-designer' ),
			'right'          => __( 'Right', 'tshirt-designer' ),
			'loading3d'      => __( 'Loading 3D model…', 'tshirt-designer' ),
			'noWebgl'        => __( 'Your browser does not support WebGL, which is required for the 3D preview.', 'tshirt-designer' ),
			'loadError'      => __( 'Could not load the 3D model.', 'tshirt-designer' ),
			'delete'         => __( 'Delete', 'tshirt-designer' ),
			'duplicate'      => __( 'Duplicate', 'tshirt-designer' ),
			'forward'        => __( 'Bring forward', 'tshirt-designer' ),
			'backward'       => __( 'Send backward', 'tshirt-designer' ),
			'removeItem'     => __( 'Remove item', 'tshirt-designer' ),
			'loginToSave'    => __( 'Please log in to save designs.', 'tshirt-designer' ),
			'saveError'      => __( 'Could not save the design.', 'tshirt-designer' ),
			'categories'     => array(
				'all'     => __( 'All', 'tshirt-designer' ),
				'logo'    => __( 'Logo', 'tshirt-designer' ),
				'text'    => __( 'Text', 'tshirt-designer' ),
				'sport'   => __( 'Sport', 'tshirt-designer' ),
				'animal'  => __( 'Animal', 'tshirt-designer' ),
				'nature'  => __( 'Nature', 'tshirt-designer' ),
				'kids'    => __( 'Kids', 'tshirt-designer' ),
				'fantasy' => __( 'Fantasy', 'tshirt-designer' ),
				'other'   => __( 'Other', 'tshirt-designer' ),
			),
			'cm'             => __( 'cm', 'tshirt-designer' ),
		);

		return array(
			'restUrl'       => esc_url_raw( rest_url( Rest_Api::NS ) ),
			'nonce'         => wp_create_nonce( 'wp_rest' ),
			'initialModel'  => $initial_model,
			'preloadDesign' => $preload_design,
			'uploadMaxMb'   => (float) $plugin->settings->get( 'upload_max_mb', 5 ),
			'isLoggedIn'    => is_user_logged_in(),
			'canSave'       => is_user_logged_in() || (int) $plugin->settings->get( 'allow_guest_designs', 1 ),
			'i18n'          => $i18n,
			'currency'      => $plugin->settings->all()['currency'],
		);
	}
}
