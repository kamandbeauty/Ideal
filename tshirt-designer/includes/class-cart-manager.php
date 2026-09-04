<?php
/**
 * WooCommerce cart integration.
 *
 * Adds a designed product to the cart with a *server-computed* price. The
 * client never sends a price: it sends a design id + version, which is
 * re-validated and re-priced here before anything reaches the cart.
 *
 * All hooks are standard WooCommerce extension points — nothing in core is
 * overridden, so the integration stays upgrade-safe.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Cart_Manager {

	/** Cart item key holding our payload. */
	public const CART_KEY = 'td_design';

	public function __construct( private Plugin $plugin ) {
		add_filter( 'woocommerce_add_cart_item_data', array( $this, 'attach_cart_item_data' ), 10, 3 );
		add_filter( 'woocommerce_get_item_data', array( $this, 'display_cart_item_data' ), 10, 2 );
		add_action( 'woocommerce_before_calculate_totals', array( $this, 'apply_prices' ), 20 );
		add_filter( 'woocommerce_cart_item_thumbnail', array( $this, 'cart_item_thumbnail' ), 10, 3 );
		add_filter( 'woocommerce_cart_item_name', array( $this, 'cart_item_name' ), 10, 3 );
		add_filter( 'woocommerce_get_cart_item_from_session', array( $this, 'restore_from_session' ), 10, 3 );
	}

	public static function available(): bool {
		return Woocommerce::is_active() && function_exists( 'WC' ) && null !== WC()->cart;
	}

	/**
	 * Validate a design and add it to the cart.
	 *
	 * Runs the full checklist required before a design may be sold:
	 * design exists, ownership, product, model, colour, size, print areas,
	 * items and pricing are all re-verified server-side.
	 *
	 * @return array{ok:bool, errors:string[], cart_item_key?:string, breakdown?:array<string,mixed>}
	 */
	public function add_to_cart( int $design_id, int $quantity, int $user_id, string $guest_token ): array {
		if ( ! self::available() ) {
			return array(
				'ok'     => false,
				'errors' => array( __( 'WooCommerce is not available.', 'tshirt-designer' ) ),
			);
		}

		$quantity = max( 1, min( 999, $quantity ) );

		// 1-2. Design exists and belongs to the caller.
		$design = $this->plugin->designs->get_design( $design_id, $user_id, $guest_token );
		if ( null === $design ) {
			$this->plugin->logger->warning(
				Logger::CHANNEL_SECURITY,
				'Add to cart refused: design not found or not owned',
				array( 'design_id' => $design_id, 'user_id' => $user_id )
			);
			return array( 'ok' => false, 'errors' => array( __( 'Design not found.', 'tshirt-designer' ) ) );
		}

		$data = is_array( $design['design_data'] ) ? $design['design_data'] : array();

		// 3. Design version exists.
		$version = max( 1, (int) $design['version'] );
		if ( null === $this->plugin->designs->get_version( $design_id, $version ) ) {
			return array( 'ok' => false, 'errors' => array( __( 'This design has no saved version yet.', 'tshirt-designer' ) ) );
		}

		// 4-8. Model, colour, size, print areas and items re-validated, and the
		// price recomputed from the rules that are live right now.
		$quote = $this->plugin->designs->quote(
			array(
				'model_id' => (int) ( $data['model_id'] ?? $design['model_id'] ),
				'color_id' => (int) ( $data['color_id'] ?? $design['color_id'] ),
				'size_id'  => (int) ( $data['size_id'] ?? $design['size_id'] ),
				'areas'    => isset( $data['areas'] ) && is_array( $data['areas'] ) ? $data['areas'] : array(),
			),
			$user_id,
			$guest_token
		);
		if ( ! $quote['ok'] ) {
			return array( 'ok' => false, 'errors' => $quote['errors'] );
		}

		$model = $this->plugin->models->get( (int) ( $data['model_id'] ?? $design['model_id'] ) );
		if ( null === $model ) {
			return array( 'ok' => false, 'errors' => array( __( 'The selected model is not available.', 'tshirt-designer' ) ) );
		}

		// 3b. A real WooCommerce product must back the model.
		$product_id = (int) $model['wc_product_id'];
		if ( $product_id <= 0 || ! function_exists( 'wc_get_product' ) ) {
			return array(
				'ok'     => false,
				'errors' => array( __( 'This model is not linked to a WooCommerce product yet.', 'tshirt-designer' ) ),
			);
		}
		$product = wc_get_product( $product_id );
		if ( ! $product instanceof \WC_Product || ! $product->is_purchasable() ) {
			return array(
				'ok'     => false,
				'errors' => array( __( 'The linked product cannot be purchased right now.', 'tshirt-designer' ) ),
			);
		}

		// 9. Immutable snapshot of exactly what is being bought.
		$snapshot = $this->plugin->designs->build_snapshot( $design_id, $version );
		if ( null === $snapshot ) {
			return array( 'ok' => false, 'errors' => array( __( 'Could not prepare the design for checkout.', 'tshirt-designer' ) ) );
		}
		$snapshot['pricing']     = $quote['breakdown'];
		$snapshot['price_total'] = (float) $quote['breakdown']['total'];

		// 10. Hand it to WooCommerce.
		$cart_item_data = array(
			self::CART_KEY => array(
				'design_id'      => $design_id,
				'design_uuid'    => (string) $design['uuid'],
				'design_version' => $version,
				'product_type'   => (string) $snapshot['product_type'],
				'model_id'       => (int) $model['id'],
				'model_name'     => (string) $model['name'],
				'color_id'       => (int) ( $snapshot['color']['id'] ?? 0 ),
				'color_name'     => (string) ( $snapshot['color']['name'] ?? '' ),
				'size_id'        => (int) ( $snapshot['size']['id'] ?? 0 ),
				'size_name'      => (string) ( $snapshot['size']['name'] ?? '' ),
				'preview_id'     => (int) $snapshot['preview_image_id'],
				'item_count'     => (int) $snapshot['item_count'],
				'pricing'        => $quote['breakdown'],
				'unit_price'     => (float) $quote['breakdown']['total'],
				'snapshot'       => $snapshot,
			),
		);

		$key = WC()->cart->add_to_cart( $product_id, $quantity, 0, array(), $cart_item_data );
		if ( ! is_string( $key ) || '' === $key ) {
			$this->plugin->logger->error(
				Logger::CHANNEL_CART,
				'WooCommerce refused the cart item',
				array( 'design_id' => $design_id, 'product_id' => $product_id )
			);
			return array( 'ok' => false, 'errors' => array( __( 'Could not add the product to your cart.', 'tshirt-designer' ) ) );
		}

		$this->plugin->designs->set_status( $design_id, Design_Manager::STATUS_ORDERED );

		return array(
			'ok'            => true,
			'errors'        => array(),
			'cart_item_key' => $key,
			'breakdown'     => $quote['breakdown'],
		);
	}

	/**
	 * Keep each design a distinct cart line (never merge two designs).
	 *
	 * @param array<string, mixed> $cart_item_data Existing data.
	 * @return array<string, mixed>
	 */
	public function attach_cart_item_data( $cart_item_data, $product_id, $variation_id ) {
		if ( ! is_array( $cart_item_data ) || ! isset( $cart_item_data[ self::CART_KEY ] ) ) {
			return $cart_item_data;
		}
		$payload = $cart_item_data[ self::CART_KEY ];
		$cart_item_data['unique_key'] = md5(
			(string) ( $payload['design_id'] ?? 0 ) . '-' . (string) ( $payload['design_version'] ?? 0 ) . '-' . microtime()
		);
		return $cart_item_data;
	}

	/**
	 * Rehydrate our payload when WooCommerce loads the cart from the session.
	 *
	 * @param array<string, mixed> $cart_item    Cart item.
	 * @param array<string, mixed> $session_data Session values.
	 * @return array<string, mixed>
	 */
	public function restore_from_session( $cart_item, $session_data, $cart_item_key ) {
		if ( is_array( $session_data ) && isset( $session_data[ self::CART_KEY ] ) ) {
			$cart_item[ self::CART_KEY ] = $session_data[ self::CART_KEY ];
		}
		return $cart_item;
	}

	/**
	 * Show the design details on cart & checkout.
	 *
	 * @param array<int, array<string, string>> $item_data Existing rows.
	 * @param array<string, mixed>              $cart_item Cart item.
	 * @return array<int, array<string, string>>
	 */
	public function display_cart_item_data( $item_data, $cart_item ) {
		$payload = $cart_item[ self::CART_KEY ] ?? null;
		if ( ! is_array( $payload ) ) {
			return $item_data;
		}

		$item_data[] = array(
			'key'     => __( 'Design', 'tshirt-designer' ),
			'value'   => (string) $payload['design_uuid'],
			'display' => esc_html(
				sprintf(
					/* translators: 1: design code, 2: version number. */
					__( '%1$s (v%2$d)', 'tshirt-designer' ),
					(string) $payload['design_uuid'],
					(int) $payload['design_version']
				)
			),
		);
		$item_data[] = array(
			'key'   => __( 'Model', 'tshirt-designer' ),
			'value' => (string) $payload['model_name'],
		);
		if ( '' !== (string) $payload['color_name'] ) {
			$item_data[] = array(
				'key'   => __( 'Color', 'tshirt-designer' ),
				'value' => (string) $payload['color_name'],
			);
		}
		if ( '' !== (string) $payload['size_name'] ) {
			$item_data[] = array(
				'key'   => __( 'Size', 'tshirt-designer' ),
				'value' => (string) $payload['size_name'],
			);
		}
		$item_data[] = array(
			'key'   => __( 'Printed items', 'tshirt-designer' ),
			'value' => (string) (int) $payload['item_count'],
		);

		return $item_data;
	}

	/**
	 * Apply the server-computed unit price to every designed cart line.
	 *
	 * @param \WC_Cart $cart Cart instance.
	 */
	public function apply_prices( $cart ): void {
		if ( ! $cart instanceof \WC_Cart ) {
			return;
		}
		if ( did_action( 'woocommerce_before_calculate_totals' ) >= 2 && ! doing_action( 'woocommerce_before_calculate_totals' ) ) {
			return;
		}

		foreach ( $cart->get_cart() as $cart_item ) {
			$payload = $cart_item[ self::CART_KEY ] ?? null;
			if ( ! is_array( $payload ) || ! isset( $cart_item['data'] ) ) {
				continue;
			}
			$product = $cart_item['data'];
			if ( ! $product instanceof \WC_Product ) {
				continue;
			}
			$price = (float) ( $payload['unit_price'] ?? 0 );
			if ( $price > 0 ) {
				$product->set_price( $price );
			}
		}
	}

	/**
	 * Use the saved design preview as the cart thumbnail.
	 *
	 * @param string               $thumbnail Existing markup.
	 * @param array<string, mixed> $cart_item Cart item.
	 */
	public function cart_item_thumbnail( $thumbnail, $cart_item, $cart_item_key ) {
		$payload = $cart_item[ self::CART_KEY ] ?? null;
		if ( ! is_array( $payload ) || (int) $payload['preview_id'] <= 0 ) {
			return $thumbnail;
		}
		$image = wp_get_attachment_image( (int) $payload['preview_id'], 'woocommerce_thumbnail' );
		return is_string( $image ) && '' !== $image ? $image : $thumbnail;
	}

	/**
	 * Append the design code to the product name in the cart.
	 *
	 * @param string               $name      Product name markup.
	 * @param array<string, mixed> $cart_item Cart item.
	 */
	public function cart_item_name( $name, $cart_item, $cart_item_key ) {
		$payload = $cart_item[ self::CART_KEY ] ?? null;
		if ( ! is_array( $payload ) ) {
			return $name;
		}
		return $name . ' <span class="td-cart-design-code">' . esc_html( (string) $payload['design_uuid'] ) . '</span>';
	}
}
