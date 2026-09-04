<?php
/**
 * WooCommerce integration (phase 1: compatibility + product-linked pricing).
 *
 * Cart / checkout / order flows are intentionally deferred to phase 2.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Woocommerce {

	public function __construct( private Plugin $plugin ) {
		add_action( 'before_woocommerce_init', array( $this, 'declare_compatibility' ) );
		add_action( 'admin_notices', array( $this, 'maybe_notice' ) );
	}

	/**
	 * Declare HPOS (custom order tables) compatibility.
	 */
	public function declare_compatibility(): void {
		if ( class_exists( \Automattic\WooCommerce\Utilities\FeaturesUtil::class ) ) {
			\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', TD_PLUGIN_FILE, true );
		}
	}

	/**
	 * Gentle admin notice when WooCommerce is missing.
	 */
	public function maybe_notice(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			return;
		}
		if ( self::is_active() ) {
			return;
		}
		printf(
			'<div class="notice notice-info"><p>%s</p></div>',
			esc_html__( 'T-Shirt Designer: WooCommerce is not active. The 3D designer works standalone; linking models to products and selling require WooCommerce.', 'tshirt-designer' )
		);
	}

	public static function is_active(): bool {
		return class_exists( 'WooCommerce' );
	}
}
