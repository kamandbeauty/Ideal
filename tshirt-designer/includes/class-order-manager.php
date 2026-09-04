<?php
/**
 * WooCommerce order integration + order immutability.
 *
 * When a cart line becomes an order line we copy the *whole* production
 * snapshot into order item meta. From that moment the order is self
 * contained: editing models, colours, print areas, assets or pricing rules
 * can never change what was bought or what gets printed.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Order_Manager {

	// Visible meta (shown to the customer on the order screen).
	public const META_DESIGN_CODE = 'Design';
	public const META_MODEL       = 'Model';
	public const META_COLOR       = 'Color';
	public const META_SIZE        = 'Size';

	// Hidden meta (underscore prefix keeps it out of the customer view).
	public const META_DESIGN_ID   = '_td_design_id';
	public const META_DESIGN_UUID = '_td_design_uuid';
	public const META_VERSION     = '_td_design_version';
	public const META_PRODUCT_TYPE = '_td_product_type';
	public const META_PREVIEW     = '_td_preview_id';
	public const META_PRICING     = '_td_price_snapshot';
	public const META_SNAPSHOT    = '_td_production_snapshot';
	public const META_ITEM_COUNT  = '_td_item_count';

	/** Production status stored on the order. */
	public const META_PRODUCTION_STATUS = '_td_production_status';

	public const STATUS_NEW        = 'new';
	public const STATUS_PAID       = 'paid';
	public const STATUS_READY      = 'ready_for_production';
	public const STATUS_IN_PROD    = 'in_production';
	public const STATUS_PRINTED    = 'printed';
	public const STATUS_QC         = 'quality_check';
	public const STATUS_SHIPPED    = 'shipped';
	public const STATUS_COMPLETED  = 'completed';
	public const STATUS_CANCELLED  = 'cancelled';

	public function __construct( private Plugin $plugin ) {
		add_action( 'woocommerce_checkout_create_order_line_item', array( $this, 'add_order_item_meta' ), 10, 4 );
		add_action( 'woocommerce_payment_complete', array( $this, 'on_payment_complete' ) );
		add_action( 'woocommerce_order_status_processing', array( $this, 'on_payment_complete' ) );
		add_action( 'woocommerce_order_status_completed', array( $this, 'on_payment_complete' ) );
		add_action( 'td_generate_production_files', array( $this, 'generate_for_order' ) );
	}

	/**
	 * All production statuses with their labels.
	 *
	 * @return array<string, string>
	 */
	public static function statuses(): array {
		return array(
			self::STATUS_NEW       => __( 'New', 'tshirt-designer' ),
			self::STATUS_PAID      => __( 'Paid', 'tshirt-designer' ),
			self::STATUS_READY     => __( 'Ready for production', 'tshirt-designer' ),
			self::STATUS_IN_PROD   => __( 'In production', 'tshirt-designer' ),
			self::STATUS_PRINTED   => __( 'Printed', 'tshirt-designer' ),
			self::STATUS_QC        => __( 'Quality check', 'tshirt-designer' ),
			self::STATUS_SHIPPED   => __( 'Shipped', 'tshirt-designer' ),
			self::STATUS_COMPLETED => __( 'Completed', 'tshirt-designer' ),
			self::STATUS_CANCELLED => __( 'Cancelled', 'tshirt-designer' ),
		);
	}

	/**
	 * Copy the design snapshot into the order line item.
	 *
	 * @param \WC_Order_Item_Product $item          Order line item.
	 * @param string                 $cart_item_key Cart key.
	 * @param array<string, mixed>   $values        Cart item values.
	 * @param \WC_Order              $order         The order.
	 */
	public function add_order_item_meta( $item, $cart_item_key, $values, $order ): void {
		$payload = is_array( $values ) ? ( $values[ Cart_Manager::CART_KEY ] ?? null ) : null;
		if ( ! is_array( $payload ) || ! $item instanceof \WC_Order_Item_Product ) {
			return;
		}

		$snapshot = isset( $payload['snapshot'] ) && is_array( $payload['snapshot'] )
			? $payload['snapshot']
			: array();

		// Human-readable meta.
		$item->add_meta_data(
			self::META_DESIGN_CODE,
			sprintf(
				/* translators: 1: design code, 2: version. */
				__( '%1$s (v%2$d)', 'tshirt-designer' ),
				(string) $payload['design_uuid'],
				(int) $payload['design_version']
			),
			true
		);
		$item->add_meta_data( self::META_MODEL, (string) $payload['model_name'], true );
		if ( '' !== (string) $payload['color_name'] ) {
			$item->add_meta_data( self::META_COLOR, (string) $payload['color_name'], true );
		}
		if ( '' !== (string) $payload['size_name'] ) {
			$item->add_meta_data( self::META_SIZE, (string) $payload['size_name'], true );
		}

		// Machine-readable, immutable meta.
		$item->add_meta_data( self::META_DESIGN_ID, (int) $payload['design_id'], true );
		$item->add_meta_data( self::META_DESIGN_UUID, (string) $payload['design_uuid'], true );
		$item->add_meta_data( self::META_VERSION, (int) $payload['design_version'], true );
		$item->add_meta_data( self::META_PRODUCT_TYPE, (string) $payload['product_type'], true );
		$item->add_meta_data( self::META_PREVIEW, (int) $payload['preview_id'], true );
		$item->add_meta_data( self::META_ITEM_COUNT, (int) $payload['item_count'], true );
		$item->add_meta_data( self::META_PRICING, wp_json_encode( $payload['pricing'] ), true );
		$item->add_meta_data( self::META_SNAPSHOT, wp_json_encode( $snapshot ), true );

		$this->plugin->designs->set_status( (int) $payload['design_id'], Design_Manager::STATUS_ORDERED );

		if ( $order instanceof \WC_Order && '' === (string) $order->get_meta( self::META_PRODUCTION_STATUS ) ) {
			$order->update_meta_data( self::META_PRODUCTION_STATUS, self::STATUS_NEW );
		}
	}

	/**
	 * Payment succeeded: lock the designs and queue production files.
	 */
	public function on_payment_complete( $order_id ): void {
		$order_id = (int) $order_id;
		$order    = $order_id > 0 && function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		if ( ! $order instanceof \WC_Order ) {
			return;
		}
		if ( '' !== (string) $order->get_meta( '_td_paid_handled' ) ) {
			return; // Already processed (several status hooks can fire).
		}

		$has_designs = false;
		foreach ( $order->get_items() as $item ) {
			$design_id = (int) $item->get_meta( self::META_DESIGN_ID );
			if ( $design_id > 0 ) {
				$has_designs = true;
				$this->plugin->designs->set_status( $design_id, Design_Manager::STATUS_PAID );
			}
		}
		if ( ! $has_designs ) {
			return;
		}

		$order->update_meta_data( '_td_paid_handled', current_time( 'mysql' ) );
		$order->update_meta_data( self::META_PRODUCTION_STATUS, self::STATUS_PAID );
		$order->save();

		// Production rendering can be slow — push it to the background when
		// cron is available, otherwise run it inline so nothing is lost.
		if ( function_exists( 'wp_schedule_single_event' ) && ! wp_next_scheduled( 'td_generate_production_files', array( $order_id ) ) ) {
			wp_schedule_single_event( time() + 5, 'td_generate_production_files', array( $order_id ) );
		} else {
			$this->generate_for_order( $order_id );
		}
	}

	/**
	 * Generate production files for every designed line of an order.
	 *
	 * Always renders from the stored snapshot, never from live data.
	 *
	 * @return array{ok:bool, files:list<array<string,mixed>>, errors:string[]}
	 */
	public function generate_for_order( $order_id, bool $force = false ): array {
		$order_id = (int) $order_id;
		$order    = $order_id > 0 && function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		if ( ! $order instanceof \WC_Order ) {
			return array( 'ok' => false, 'files' => array(), 'errors' => array( __( 'Order not found.', 'tshirt-designer' ) ) );
		}

		$all_files = array();
		$errors    = array();

		foreach ( $order->get_items() as $item_id => $item ) {
			$snapshot = self::snapshot_from_item( $item );
			if ( null === $snapshot ) {
				continue;
			}
			$result = $this->plugin->production->generate( $snapshot, $order_id, (int) $item_id, $force );
			$all_files = array_merge( $all_files, $result['files'] );
			$errors    = array_merge( $errors, $result['errors'] );

			$design_id = (int) ( $snapshot['design_id'] ?? 0 );
			if ( $design_id > 0 && $result['ok'] ) {
				$this->plugin->designs->set_status( $design_id, Design_Manager::STATUS_PRODUCTION );
			}
		}

		if ( array() !== $errors ) {
			$this->plugin->logger->error(
				Logger::CHANNEL_PRODUCTION,
				'Production file generation reported errors',
				array( 'order_id' => $order_id, 'errors' => $errors )
			);
		} elseif ( array() !== $all_files ) {
			$current = (string) $order->get_meta( self::META_PRODUCTION_STATUS );
			if ( in_array( $current, array( '', self::STATUS_NEW, self::STATUS_PAID ), true ) ) {
				$order->update_meta_data( self::META_PRODUCTION_STATUS, self::STATUS_READY );
				$order->save();
			}
		}

		return array( 'ok' => array() === $errors, 'files' => $all_files, 'errors' => $errors );
	}

	/**
	 * Decode the immutable snapshot stored on an order item.
	 *
	 * @param \WC_Order_Item $item Order item.
	 * @return array<string, mixed>|null
	 */
	public static function snapshot_from_item( $item ): ?array {
		if ( ! is_object( $item ) || ! method_exists( $item, 'get_meta' ) ) {
			return null;
		}
		$raw = $item->get_meta( self::META_SNAPSHOT );
		if ( ! is_string( $raw ) || '' === $raw ) {
			return null;
		}
		$decoded = json_decode( $raw, true );
		return is_array( $decoded ) && isset( $decoded['areas'] ) ? $decoded : null;
	}

	/**
	 * Decode the price snapshot stored on an order item.
	 *
	 * @param \WC_Order_Item $item Order item.
	 * @return array<string, mixed>|null
	 */
	public static function pricing_from_item( $item ): ?array {
		if ( ! is_object( $item ) || ! method_exists( $item, 'get_meta' ) ) {
			return null;
		}
		$raw = $item->get_meta( self::META_PRICING );
		if ( ! is_string( $raw ) || '' === $raw ) {
			return null;
		}
		$decoded = json_decode( $raw, true );
		return is_array( $decoded ) ? $decoded : null;
	}

	/**
	 * Set the production status of an order.
	 */
	public function set_production_status( int $order_id, string $status ): bool {
		if ( ! array_key_exists( $status, self::statuses() ) ) {
			return false;
		}
		$order = function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		if ( ! $order instanceof \WC_Order ) {
			return false;
		}
		$order->update_meta_data( self::META_PRODUCTION_STATUS, $status );
		$order->save();
		return true;
	}

	/**
	 * Re-order: build a fresh design (new record) from an order's snapshot and
	 * price it with today's rules. The original order is never touched.
	 *
	 * @return array{ok:bool, errors:string[], design_id?:int, uuid?:string}
	 */
	public function order_again( int $order_id, int $item_id, int $user_id, string $guest_token ): array {
		$order = function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		if ( ! $order instanceof \WC_Order ) {
			return array( 'ok' => false, 'errors' => array( __( 'Order not found.', 'tshirt-designer' ) ) );
		}
		if ( $user_id <= 0 || (int) $order->get_customer_id() !== $user_id ) {
			return array( 'ok' => false, 'errors' => array( __( 'You are not allowed to reorder this item.', 'tshirt-designer' ) ) );
		}

		$item = $order->get_item( $item_id );
		if ( ! $item ) {
			return array( 'ok' => false, 'errors' => array( __( 'Order item not found.', 'tshirt-designer' ) ) );
		}

		$snapshot = self::snapshot_from_item( $item );
		if ( null === $snapshot ) {
			return array( 'ok' => false, 'errors' => array( __( 'This item has no stored design.', 'tshirt-designer' ) ) );
		}

		// Availability checks against the *current* catalogue.
		$model = $this->plugin->models->get( (int) ( $snapshot['model']['id'] ?? 0 ) );
		if ( null === $model ) {
			return array( 'ok' => false, 'errors' => array( __( 'The product of this design is no longer available.', 'tshirt-designer' ) ) );
		}

		$areas = array();
		foreach ( ( $snapshot['areas'] ?? array() ) as $area ) {
			if ( ! is_array( $area ) ) {
				continue;
			}
			$items = array();
			foreach ( ( $area['items'] ?? array() ) as $snap_item ) {
				if ( ! is_array( $snap_item ) ) {
					continue;
				}
				$copy = array(
					'id'       => (string) ( $snap_item['id'] ?? '' ),
					'type'     => (string) ( $snap_item['type'] ?? '' ),
					'ref_id'   => (int) ( $snap_item['ref_id'] ?? 0 ),
					'x'        => (float) ( $snap_item['x'] ?? 0 ),
					'y'        => (float) ( $snap_item['y'] ?? 0 ),
					'w'        => (float) ( $snap_item['w'] ?? 0 ),
					'h'        => (float) ( $snap_item['h'] ?? 0 ),
					'rotation' => (float) ( $snap_item['rotation'] ?? 0 ),
					'layer'    => (int) ( $snap_item['layer'] ?? 0 ),
					'opacity'  => (float) ( $snap_item['opacity'] ?? 1 ),
				);
				if ( isset( $snap_item['text'] ) && is_array( $snap_item['text'] ) ) {
					$copy['text'] = $snap_item['text'];
				}
				$items[] = $copy;
			}
			if ( array() !== $items ) {
				$areas[ (string) (int) $area['id'] ] = $items;
			}
		}

		// A brand new design is created, priced with today's rules.
		$result = $this->plugin->designs->save(
			array(
				'model_id' => (int) $model['id'],
				'color_id' => (int) ( $snapshot['color']['id'] ?? 0 ),
				'size_id'  => (int) ( $snapshot['size']['id'] ?? 0 ),
				'areas'    => $areas,
			),
			$user_id,
			$guest_token,
			null
		);

		if ( ! $result['ok'] ) {
			return $result;
		}

		return array(
			'ok'        => true,
			'errors'    => array(),
			'design_id' => (int) $result['id'],
			'uuid'      => (string) $result['uuid'],
		);
	}

	/**
	 * Orders that contain at least one design, filtered by production status.
	 *
	 * @return list<int> Order ids.
	 */
	public function order_ids( string $production_status = '', int $limit = 50, int $page = 1 ): array {
		if ( ! function_exists( 'wc_get_orders' ) ) {
			return array();
		}
		$args = array(
			'limit'    => max( 1, min( 200, $limit ) ),
			'paged'    => max( 1, $page ),
			'orderby'  => 'date',
			'order'    => 'DESC',
			'return'   => 'ids',
			'meta_key' => self::META_PRODUCTION_STATUS, // phpcs:ignore WordPress.DB.SlowDBQuery
		);
		if ( '' !== $production_status && array_key_exists( $production_status, self::statuses() ) ) {
			$args['meta_value'] = $production_status; // phpcs:ignore WordPress.DB.SlowDBQuery
		}
		$ids = wc_get_orders( $args );
		return is_array( $ids ) ? array_map( 'intval', $ids ) : array();
	}
}
