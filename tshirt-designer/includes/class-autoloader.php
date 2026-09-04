<?php
/**
 * PSR-ish autoloader for the plugin's namespaced classes.
 *
 * TShirtDesigner\Foo_Bar        -> includes/class-foo-bar.php
 * TShirtDesigner\Admin\Foo_Bar  -> admin/class-foo-bar.php
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Autoloader {

	/**
	 * Register the autoloader with SPL.
	 */
	public static function register(): void {
		spl_autoload_register( array( self::class, 'autoload' ) );
	}

	/**
	 * Autoload a plugin class.
	 *
	 * @param string $class Fully-qualified class name.
	 */
	public static function autoload( string $class ): void {
		if ( ! str_starts_with( $class, 'TShirtDesigner\\' ) ) {
			return;
		}

		$relative = substr( $class, strlen( 'TShirtDesigner\\' ) );

		if ( str_starts_with( $relative, 'Admin\\' ) ) {
			$dir     = 'admin';
			$relative = substr( $relative, strlen( 'Admin\\' ) );
		} else {
			$dir = 'includes';
		}

		$file = strtolower( str_replace( '_', '-', $relative ) ) . '.php';
		$path = TD_PLUGIN_DIR . $dir . '/' . $file;

		if ( is_readable( $path ) ) {
			require_once $path;
		}
	}
}
