<?php
/**
 * Customer-facing production status.
 *
 * Shows a customer where their own designed items are in fulfilment, on the
 * order details screen and in My Account. Deliberately read-only and
 * deliberately vague: customers see a coarse progress label, never internal
 * notes, activity history, print files or error messages.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Customer_Status {

	public function __construct( private Plugin $plugin ) {
		add_action( 'woocommerce_order_item_meta_end', array( $this, 'render_item_status' ), 10, 3 );
	}

	/**
	 * Internal status -> customer-facing label.
	 *
	 * Several internal states collapse into one customer label on purpose. A
	 * customer has no use for the difference between "printed" and
	 * "quality_check", and production_error must never surface as an error:
	 * it is an internal condition the shop recovers from, so it reads as
	 * "in progress" until it genuinely resolves.
	 *
	 * @return array<string, string>
	 */
	public static function labels(): array {
		return array(
			Production_Status::NEW_JOB   => __( 'Awaiting payment', 'tshirt-designer' ),
			Production_Status::PAID      => __( 'Preparing', 'tshirt-designer' ),
			Production_Status::READY     => __( 'Preparing', 'tshirt-designer' ),
			Production_Status::IN_PROD   => __( 'In production', 'tshirt-designer' ),
			Production_Status::PRINTED   => __( 'In production', 'tshirt-designer' ),
			Production_Status::QC        => __( 'In production', 'tshirt-designer' ),
			Production_Status::PACKED    => __( 'Packed', 'tshirt-designer' ),
			Production_Status::SHIPPED   => __( 'Shipped', 'tshirt-designer' ),
			Production_Status::COMPLETED => __( 'Completed', 'tshirt-designer' ),
			Production_Status::CANCELLED => __( 'Cancelled', 'tshirt-designer' ),
			// Intentionally indistinguishable from normal progress.
			Production_Status::FAILED    => __( 'In production', 'tshirt-designer' ),
		);
	}

	/**
	 * Coarse progress step (1-4) for the customer, or 0 when not applicable.
	 */
	public static function step( string $status ): int {
		return match ( $status ) {
			Production_Status::PAID,
			Production_Status::READY => 1,
			Production_Status::IN_PROD,
			Production_Status::PRINTED,
			Production_Status::QC,
			Production_Status::FAILED => 2,
			Production_Status::PACKED,
			Production_Status::SHIPPED => 3,
			Production_Status::COMPLETED => 4,
			default => 0,
		};
	}

	/**
	 * Customer-facing label for an internal status.
	 */
	public static function label( string $status ): string {
		return self::labels()[ $status ] ?? '';
	}

	/**
	 * Print the status under a designed line item on the order screen.
	 *
	 * @param int                    $item_id Order item ID.
	 * @param \WC_Order_Item|object  $item    Order item.
	 * @param \WC_Order|object       $order   Order.
	 */
	public function render_item_status( $item_id, $item, $order ): void {
		// Only the order screens, never emails: an email is a snapshot in time
		// and would go stale the moment the job advances.
		if ( ! function_exists( 'is_wc_endpoint_url' ) || is_admin() ) {
			return;
		}
		if ( ! $order instanceof \WC_Order ) {
			return;
		}
		if ( ! $this->viewer_owns_order( $order ) ) {
			return;
		}

		$job = $this->plugin->production_jobs->find_by_item( (int) $order->get_id(), (int) $item_id );
		if ( null === $job ) {
			return;
		}

		$label = self::label( (string) $job['status'] );
		if ( '' === $label ) {
			return;
		}

		printf(
			'<p class="td-customer-status"><span class="td-customer-status__label">%1$s</span> <strong>%2$s</strong></p>',
			esc_html__( 'Production:', 'tshirt-designer' ),
			esc_html( $label )
		);
	}

	/**
	 * Is the current viewer entitled to see this order's fulfilment state?
	 *
	 * Guests reaching an order via the order-received / order-pay key are
	 * legitimate viewers, so the WooCommerce key check counts as ownership.
	 */
	private function viewer_owns_order( \WC_Order $order ): bool {
		$customer_id = (int) $order->get_customer_id();
		$user_id     = get_current_user_id();

		if ( $user_id > 0 && $customer_id > 0 && $user_id === $customer_id ) {
			return true;
		}

		// Order-received / view-order pages pass the order key.
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$key = isset( $_GET['key'] ) ? sanitize_text_field( wp_unslash( $_GET['key'] ) ) : '';
		if ( '' !== $key && hash_equals( (string) $order->get_order_key(), $key ) ) {
			return true;
		}

		return current_user_can( 'manage_woocommerce' );
	}
}
