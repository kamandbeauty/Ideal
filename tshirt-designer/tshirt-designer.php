<?php
/**
 * Plugin Name:       T-Shirt Designer
 * Plugin URI:        https://github.com/kamandbeauty/Ideal
 * Description:       3D t-shirt designer for WooCommerce — let customers pick a model, color and size, place artwork or uploads on print areas, and get a server-computed price.
 * Version:           1.0.0
 * Requires at least: 6.0
 * Requires PHP:      8.1
 * Author:            Studio Javid
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       tshirt-designer
 * Domain Path:       /languages
 * WC requires at least: 8.0
 * WC tested up to:   9.9
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

defined( 'ABSPATH' ) || exit;

define( 'TD_VERSION', '1.0.0' );
define( 'TD_DB_VERSION', '1.0.0' );
define( 'TD_PLUGIN_FILE', __FILE__ );
define( 'TD_PLUGIN_DIR', plugin_dir_path( __FILE__ ) );
define( 'TD_PLUGIN_URL', plugin_dir_url( __FILE__ ) );
define( 'TD_PLUGIN_BASENAME', plugin_basename( __FILE__ ) );

require_once TD_PLUGIN_DIR . 'includes/class-autoloader.php';

\TShirtDesigner\Autoloader::register();

/**
 * Plugin accessor.
 *
 * @return \TShirtDesigner\Plugin
 */
function td_plugin(): \TShirtDesigner\Plugin {
	return \TShirtDesigner\Plugin::instance();
}

register_activation_hook(
	__FILE__,
	static function (): void {
		td_plugin()->activate();
	}
);

add_action(
	'plugins_loaded',
	static function (): void {
		td_plugin()->boot();
	},
	5
);
