<?php
/**
 * Product type registry — the product-agnostic core of the designer.
 *
 * A product type is pure configuration: it declares which print-area types a
 * model of that type may expose, the default areas created when seeding, and
 * the production defaults (DPI, whether sizes apply).  Adding a new product
 * (hoodie, cap, mug…) means registering a new type — no core code changes.
 *
 * Extend via the `cpd_product_types` filter.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Product_Type_Registry {

	/** Product type used for rows created before product types existed. */
	public const LEGACY_TYPE = 'tshirt';

	/**
	 * Resolved definitions cache.
	 *
	 * @var array<string, array<string, mixed>>|null
	 */
	private static ?array $cache = null;

	/**
	 * Reset the cache (tests / after filters change).
	 */
	public static function flush(): void {
		self::$cache = null;
	}

	/**
	 * All registered product types, keyed by slug.
	 *
	 * @return array<string, array<string, mixed>>
	 */
	public static function all(): array {
		if ( null !== self::$cache ) {
			return self::$cache;
		}

		$types = self::built_in();

		if ( function_exists( 'apply_filters' ) ) {
			/**
			 * Filter the registered product types.
			 *
			 * Each entry must be an array with at least `label` and `area_types`.
			 *
			 * @param array<string, array<string, mixed>> $types Definitions keyed by slug.
			 */
			$filtered = apply_filters( 'cpd_product_types', $types );
			if ( is_array( $filtered ) ) {
				$types = $filtered;
			}
		}

		$clean = array();
		foreach ( $types as $slug => $definition ) {
			$slug = self::sanitize_slug( (string) $slug );
			if ( '' === $slug || ! is_array( $definition ) ) {
				continue;
			}
			$clean[ $slug ] = self::normalize( $slug, $definition );
		}

		if ( array() === $clean ) {
			$clean = self::built_in();
		}

		self::$cache = $clean;
		return $clean;
	}

	/**
	 * One product type definition (falls back to the legacy type).
	 *
	 * @return array<string, mixed>
	 */
	public static function get( string $slug ): array {
		$all  = self::all();
		$slug = self::sanitize_slug( $slug );
		if ( isset( $all[ $slug ] ) ) {
			return $all[ $slug ];
		}
		if ( isset( $all[ self::LEGACY_TYPE ] ) ) {
			return $all[ self::LEGACY_TYPE ];
		}
		return reset( $all ) ?: self::normalize( self::LEGACY_TYPE, array() );
	}

	public static function exists( string $slug ): bool {
		return isset( self::all()[ self::sanitize_slug( $slug ) ] );
	}

	/**
	 * Human readable label for a product type.
	 *
	 * Unknown slugs fall back to the slug itself so admin screens never show
	 * an empty cell for data created by a plugin that is no longer active.
	 */
	public static function label( string $slug ): string {
		$slug = self::sanitize_slug( $slug );
		if ( '' === $slug ) {
			return '';
		}
		$all = self::all();
		if ( isset( $all[ $slug ] ) ) {
			return (string) $all[ $slug ]['label'];
		}
		return ucwords( str_replace( array( '-', '_' ), ' ', $slug ) );
	}

	/**
	 * Sanitize an incoming product type slug, falling back to the legacy type.
	 */
	public static function sanitize( string $slug ): string {
		$slug = self::sanitize_slug( $slug );
		return self::exists( $slug ) ? $slug : self::LEGACY_TYPE;
	}

	/**
	 * Print-area types allowed for a product type.
	 *
	 * @return list<string>
	 */
	public static function area_types( string $slug ): array {
		$type = self::get( $slug );
		return array_keys( $type['area_types'] );
	}

	/**
	 * Human label for an area type within a product type.
	 */
	public static function area_label( string $product_type, string $area_type ): string {
		$type = self::get( $product_type );
		return (string) ( $type['area_types'][ $area_type ] ?? $area_type );
	}

	/**
	 * Whether an area type is valid for a product type.
	 */
	public static function area_type_allowed( string $product_type, string $area_type ): bool {
		$type = self::get( $product_type );
		return isset( $type['area_types'][ self::sanitize_slug( $area_type ) ] );
	}

	/**
	 * Options list for admin <select> elements.
	 *
	 * @return array<string, string> slug => label
	 */
	public static function options(): array {
		$out = array();
		foreach ( self::all() as $slug => $definition ) {
			$out[ $slug ] = (string) $definition['label'];
		}
		return $out;
	}

	/**
	 * Print DPI for a product type (admin setting wins, then type default).
	 */
	public static function dpi( string $slug, ?Settings $settings = null ): int {
		$type    = self::get( $slug );
		$default = (int) $type['print_dpi'];

		if ( null === $settings && class_exists( Plugin::class ) && function_exists( 'did_action' ) ) {
			$settings = Plugin::instance()->settings;
		}
		if ( $settings instanceof Settings ) {
			$per_type = $settings->get( 'print_dpi_by_type', array() );
			if ( is_array( $per_type ) && isset( $per_type[ $slug ] ) && (int) $per_type[ $slug ] > 0 ) {
				return self::clamp_dpi( (int) $per_type[ $slug ] );
			}
			$global = (int) $settings->get( 'print_dpi', 0 );
			if ( $global > 0 ) {
				return self::clamp_dpi( $global );
			}
		}
		return self::clamp_dpi( $default );
	}

	public static function clamp_dpi( int $dpi ): int {
		return max( 72, min( 1200, $dpi ) );
	}

	/**
	 * Built-in definitions.
	 *
	 * @return array<string, array<string, mixed>>
	 */
	private static function built_in(): array {
		$t = static fn( string $text ): string => function_exists( '__' ) ? __( $text, 'tshirt-designer' ) : $text; // phpcs:ignore WordPress.WP.I18n

		return array(
			'tshirt'  => self::normalize(
				'tshirt',
				array(
					'label'      => $t( 'T-Shirt' ),
					'area_types' => array(
						'front'        => $t( 'Front' ),
						'back'         => $t( 'Back' ),
						'left_sleeve'  => $t( 'Left sleeve' ),
						'right_sleeve' => $t( 'Right sleeve' ),
						'other'        => $t( 'Other' ),
					),
					'has_sizes'  => true,
					'print_dpi'  => 300,
				)
			),
			'totebag' => self::normalize(
				'totebag',
				array(
					'label'      => $t( 'Tote Bag' ),
					'area_types' => array(
						'front' => $t( 'Front' ),
						'back'  => $t( 'Back' ),
						'other' => $t( 'Other' ),
					),
					'has_sizes'  => false,
					'print_dpi'  => 300,
				)
			),
		);
	}

	/**
	 * Fill in defaults for a definition.
	 *
	 * @param array<string, mixed> $definition Raw definition.
	 * @return array<string, mixed>
	 */
	private static function normalize( string $slug, array $definition ): array {
		$area_types = array();
		$raw_areas  = isset( $definition['area_types'] ) && is_array( $definition['area_types'] )
			? $definition['area_types']
			: array( 'front' => 'Front', 'back' => 'Back', 'other' => 'Other' );

		foreach ( $raw_areas as $key => $label ) {
			if ( is_int( $key ) ) {
				$key   = (string) $label;
				$label = ucwords( str_replace( '_', ' ', $key ) );
			}
			$key = self::sanitize_slug( (string) $key );
			if ( '' === $key ) {
				continue;
			}
			$area_types[ $key ] = (string) $label;
		}
		if ( array() === $area_types ) {
			$area_types = array( 'other' => 'Other' );
		}

		return array(
			'slug'       => $slug,
			'label'      => isset( $definition['label'] ) ? (string) $definition['label'] : ucfirst( $slug ),
			'area_types' => $area_types,
			'has_sizes'  => ! isset( $definition['has_sizes'] ) || (bool) $definition['has_sizes'],
			'print_dpi'  => isset( $definition['print_dpi'] ) ? self::clamp_dpi( (int) $definition['print_dpi'] ) : 300,
		);
	}

	private static function sanitize_slug( string $slug ): string {
		if ( function_exists( 'sanitize_key' ) ) {
			return sanitize_key( $slug );
		}
		return strtolower( preg_replace( '/[^a-z0-9_\-]/i', '', $slug ) ?? '' );
	}
}
