<?php
/**
 * Plugin settings (single option, defaults + sanitization).
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Settings {

	public const OPTION = 'td_settings';

	/**
	 * Cached settings.
	 *
	 * @var array<string, mixed>|null
	 */
	private ?array $cache = null;

	/**
	 * Default settings.
	 *
	 * @return array<string, mixed>
	 */
	public function defaults(): array {
		return array(
			'currency'                 => array(
				'symbol'       => 'تومان',
				'position'     => 'after',
				'decimals'     => 0,
				'thousand_sep' => ',',
				'decimal_sep'  => '.',
			),
			'upload_max_mb'            => 5,
			'allow_guest_uploads'      => 1,
			'allow_guest_designs'      => 1,
			'uploads_per_hour'         => 20,
			'delete_data_on_uninstall' => 0,
		);
	}

	/**
	 * Seed default option on activation (without overwriting existing).
	 */
	public function seed_defaults(): void {
		if ( false === get_option( self::OPTION, false ) ) {
			update_option( self::OPTION, $this->defaults() );
		}
	}

	/**
	 * All settings merged with defaults.
	 *
	 * @return array<string, mixed>
	 */
	public function all(): array {
		if ( null === $this->cache ) {
			$saved          = get_option( self::OPTION, array() );
			$saved          = is_array( $saved ) ? $saved : array();
			$this->cache    = $this->merge_recursive( $this->defaults(), $saved );
		}
		return $this->cache;
	}

	/**
	 * Single setting (dot notation: "currency.symbol").
	 */
	public function get( string $key, mixed $fallback = null ): mixed {
		$value = $this->all();
		foreach ( explode( '.', $key ) as $part ) {
			if ( ! is_array( $value ) || ! array_key_exists( $part, $value ) ) {
				return $fallback;
			}
			$value = $value[ $part ];
		}
		return $value;
	}

	/**
	 * Sanitize and persist settings coming from the admin form.
	 *
	 * @param array<string, mixed> $input Raw input.
	 */
	public function update_from_input( array $input ): void {
		$clean = $this->sanitize( $input );
		update_option( self::OPTION, $clean );
		$this->cache = null;
	}

	/**
	 * Sanitize settings input.
	 *
	 * @param array<string, mixed> $input Raw input.
	 * @return array<string, mixed>
	 */
	public function sanitize( array $input ): array {
		$defaults = $this->defaults();

		$currency = isset( $input['currency'] ) && is_array( $input['currency'] )
			? $input['currency']
			: array();

		$clean = array(
			'currency'                 => array(
				'symbol'       => isset( $currency['symbol'] )
					? sanitize_text_field( (string) $currency['symbol'] )
					: $defaults['currency']['symbol'],
				'position'     => isset( $currency['position'] ) && in_array(
					$currency['position'],
					array( 'before', 'after' ),
					true
				) ? $currency['position'] : 'after',
				'decimals'     => isset( $currency['decimals'] )
					? min( 3, max( 0, (int) $currency['decimals'] ) )
					: 0,
				'thousand_sep' => isset( $currency['thousand_sep'] )
					? (string) $currency['thousand_sep']
					: ',',
				'decimal_sep'  => isset( $currency['decimal_sep'] )
					? (string) $currency['decimal_sep']
					: '.',
			),
			'upload_max_mb'            => isset( $input['upload_max_mb'] )
				? min( 32, max( 0.5, (float) $input['upload_max_mb'] ) )
				: $defaults['upload_max_mb'],
			'allow_guest_uploads'      => empty( $input['allow_guest_uploads'] ) ? 0 : 1,
			'allow_guest_designs'      => empty( $input['allow_guest_designs'] ) ? 0 : 1,
			'uploads_per_hour'         => isset( $input['uploads_per_hour'] )
				? min( 500, max( 1, (int) $input['uploads_per_hour'] ) )
				: $defaults['uploads_per_hour'],
			'delete_data_on_uninstall' => empty( $input['delete_data_on_uninstall'] ) ? 0 : 1,
		);

		// A tiny separator like "" is valid; keep everything else short.
		foreach ( array( 'thousand_sep', 'decimal_sep' ) as $k ) {
			$clean['currency'][ $k ] = mb_substr( (string) $clean['currency'][ $k ], 0, 3 );
		}

		return $clean;
	}

	/**
	 * Format a price amount using the currency settings.
	 */
	public function format_price( float $amount ): string {
		$s = $this->all()['currency'];
		$formatted = number_format(
			$amount,
			(int) $s['decimals'],
			(string) $s['decimal_sep'],
			(string) $s['thousand_sep']
		);
		return 'before' === $s['position']
			? $s['symbol'] . $formatted
			: $formatted . ' ' . $s['symbol'];
	}

	/**
	 * Recursive defaults merge (one level is enough here, but be safe).
	 *
	 * @param array<string, mixed> $defaults Defaults.
	 * @param array<string, mixed> $saved    Saved values.
	 * @return array<string, mixed>
	 */
	private function merge_recursive( array $defaults, array $saved ): array {
		foreach ( $saved as $key => $value ) {
			if ( is_array( $value ) && isset( $defaults[ $key ] ) && is_array( $defaults[ $key ] ) ) {
				$defaults[ $key ] = $this->merge_recursive( $defaults[ $key ], $value );
			} else {
				$defaults[ $key ] = $value;
			}
		}
		return $defaults;
	}
}
