<?php
/**
 * Integration test bootstrap: boots a real WordPress (SQLite drop-in),
 * installs it if needed, and activates the plugin.
 *
 * Used by tests/integration-*.php. Not loaded in production.
 *
 * @package TShirtDesigner
 */

// phpcs:disable WordPress.Security.NonceVerification, WordPress.PHP.DevelopmentFunctions

if ( ! defined( 'TD_TEST_WP_DIR' ) ) {
	define( 'TD_TEST_WP_DIR', getenv( 'TD_TEST_WP_DIR' ) ?: '/home/user/.cache/wp-test/wordpress' );
}

$_SERVER['HTTP_HOST']      = 'example.org';
$_SERVER['SERVER_NAME']    = 'example.org';
$_SERVER['REQUEST_METHOD'] = 'GET';
$_SERVER['REQUEST_URI']    = '/';
$_SERVER['SCRIPT_NAME']    = '/index.php';
$_SERVER['HTTPS']          = '';

define( 'WP_USE_THEMES', false );
define( 'WP_INSTALLING', true );   // Skip the "not installed" redirect.
define( 'WP_ADMIN', true );

define( 'TD_TESTING', true );
require TD_TEST_WP_DIR . '/wp-load.php';

require_once ABSPATH . 'wp-admin/includes/upgrade.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';
require_once ABSPATH . 'wp-admin/includes/media.php';

if ( ! is_blog_installed() ) {
	$install = wp_install(
		'CPD Test Site',
		'admin',
		'admin@example.org',
		true,
		'',
		'test-password-123'
	);
	if ( is_wp_error( $install ) ) {
		fwrite( STDERR, 'wp_install failed: ' . $install->get_error_message() . "\n" );
		exit( 1 );
	}
}

// Now that the DB exists, behave like a normal request again.
if ( function_exists( 'wp_cache_flush' ) ) {
	wp_cache_flush();
}

/**
 * Activate the plugin (runs dbDelta + migrations + seeding).
 */
function td_test_activate_plugin(): void {
	$plugin = 'tshirt-designer/tshirt-designer.php';
	if ( ! file_exists( WP_PLUGIN_DIR . '/' . $plugin ) ) {
		fwrite( STDERR, "Plugin not found at " . WP_PLUGIN_DIR . '/' . $plugin . "\n" );
		exit( 1 );
	}
	if ( ! defined( 'TD_PLUGIN_FILE' ) ) {
		require_once WP_PLUGIN_DIR . '/' . $plugin;
	}
	td_plugin()->activate();
	td_plugin()->boot();

	// boot() defers most wiring to `init`; run it now.
	if ( ! did_action( 'init' ) ) {
		do_action( 'init' );
	}
}

// ------------------------------------------------------------------ runner

final class TD_Test {

	public static int $passed = 0;
	public static int $failed = 0;
	/** @var list<string> */
	public static array $failures = array();
	public static string $group = '';

	public static function group( string $name ): void {
		self::$group = $name;
		echo "\n── {$name}\n";
	}

	public static function ok( bool $condition, string $label ): bool {
		if ( $condition ) {
			++self::$passed;
			echo "  \xE2\x9C\x93 {$label}\n";
			return true;
		}
		++self::$failed;
		self::$failures[] = self::$group . ' :: ' . $label;
		echo "  \xE2\x9C\x97 {$label}\n";
		return false;
	}

	public static function equals( mixed $expected, mixed $actual, string $label ): bool {
		$same = $expected === $actual;
		if ( ! $same && is_float( $expected ) && is_numeric( $actual ) ) {
			$same = abs( $expected - (float) $actual ) < 0.001;
		}
		if ( ! $same ) {
			$label .= sprintf(
				' (expected %s, got %s)',
				self::dump( $expected ),
				self::dump( $actual )
			);
		}
		return self::ok( $same, $label );
	}

	public static function dump( mixed $value ): string {
		if ( is_bool( $value ) ) {
			return $value ? 'true' : 'false';
		}
		if ( is_scalar( $value ) || null === $value ) {
			return var_export( $value, true );
		}
		return substr( (string) wp_json_encode( $value ), 0, 200 );
	}

	public static function summary(): int {
		$total = self::$passed + self::$failed;
		echo "\n" . str_repeat( '=', 60 ) . "\n";
		echo sprintf( "%d tests, %d passed, %d failed\n", $total, self::$passed, self::$failed );
		if ( array() !== self::$failures ) {
			echo "\nFailures:\n";
			foreach ( self::$failures as $failure ) {
				echo "  - {$failure}\n";
			}
		}
		echo str_repeat( '=', 60 ) . "\n";
		return self::$failed > 0 ? 1 : 0;
	}
}

/**
 * Perform a REST request through the real WP REST server (permission
 * callbacks, sanitization and everything else included).
 *
 * @param array<string, mixed> $body   JSON body.
 * @param array<string, mixed> $params Query params.
 */
function td_rest( string $method, string $route, array $body = array(), array $params = array() ): WP_REST_Response {
	$request = new WP_REST_Request( $method, $route );
	foreach ( $params as $key => $value ) {
		$request->set_param( $key, $value );
	}
	if ( array() !== $body ) {
		$request->set_header( 'Content-Type', 'application/json' );
		$request->set_body( (string) wp_json_encode( $body ) );
	}
	if ( is_user_logged_in() ) {
		$_SERVER['HTTP_X_WP_NONCE'] = wp_create_nonce( 'wp_rest' );
	}
	$_SERVER['HTTP_ORIGIN'] = 'http://example.org';

	return rest_get_server()->dispatch( $request );
}

/**
 * Run an admin form handler and capture where it wanted to redirect,
 * instead of letting `exit` kill the test process.
 *
 * @param callable $callback Handler invocation.
 * @return string Redirect URL ('' when the handler did not redirect).
 */
function td_capture_redirect( callable $callback ): string {
	$captured = '';
	$spy      = static function ( string $url ) use ( &$captured ): void {
		$captured = $url;
		throw new \RuntimeException( 'td-redirect' );
	};
	add_action( 'td_admin_before_redirect', $spy );
	try {
		$callback();
	} catch ( \RuntimeException $e ) {
		if ( 'td-redirect' !== $e->getMessage() ) {
			remove_action( 'td_admin_before_redirect', $spy );
			throw $e;
		}
	} finally {
		remove_action( 'td_admin_before_redirect', $spy );
	}
	return $captured;
}

/**
 * Overwrite a few plugin settings through the real sanitizer.
 *
 * @param array<string, mixed> $changes Settings to change.
 */
function td_set_setting( array $changes ): void {
	$settings = td_plugin()->settings;
	$current  = $settings->all();
	$settings->update_from_input( array_merge( $current, $changes ) );
}

/**
 * Create a real PNG on disk (used for upload tests).
 */
function td_test_make_png( string $path, int $w = 64, int $h = 64, bool $alpha = true ): string {
	$img = imagecreatetruecolor( $w, $h );
	imagealphablending( $img, false );
	imagesavealpha( $img, true );
	$transparent = imagecolorallocatealpha( $img, 0, 0, 0, 127 );
	imagefilledrectangle( $img, 0, 0, $w, $h, $transparent );
	$red = imagecolorallocate( $img, 220, 40, 40 );
	imagefilledellipse( $img, (int) ( $w / 2 ), (int) ( $h / 2 ), (int) ( $w * 0.6 ), (int) ( $h * 0.6 ), $red );
	if ( ! $alpha ) {
		imagealphablending( $img, true );
		imagefilledrectangle( $img, 0, 0, 4, 4, $red );
	}
	imagepng( $img, $path );
	imagedestroy( $img );
	return $path;
}
