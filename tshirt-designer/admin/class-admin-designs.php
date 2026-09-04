<?php
/**
 * Admin page: Design library (saved customer designs).
 *
 * Provides search, filtering by product type / model / status / owner / order
 * / date, pagination, preview, download of the stored preview and deletion.
 * Designs attached to a paid or in-production order can never be deleted from
 * here — that rule is enforced in Design_Manager and re-checked below.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner\Admin;

use TShirtDesigner\Design_Manager;
use TShirtDesigner\Product_Type_Registry;

defined( 'ABSPATH' ) || exit;

final class Admin_Designs {

	private const PER_PAGE = 25;

	public function __construct( private \TShirtDesigner\Plugin $plugin ) {}

	public function render(): void {
		global $wpdb;

		// phpcs:disable WordPress.Security.NonceVerification -- read-only listing filters.
		$view      = isset( $_GET['view'] ) && ctype_digit( (string) $_GET['view'] ) ? (int) $_GET['view'] : 0;
		$search    = isset( $_GET['s'] ) ? sanitize_text_field( wp_unslash( $_GET['s'] ) ) : '';
		$f_type    = isset( $_GET['product_type'] ) ? sanitize_key( (string) wp_unslash( $_GET['product_type'] ) ) : '';
		$f_model   = isset( $_GET['model_id'] ) ? absint( wp_unslash( $_GET['model_id'] ) ) : 0;
		$f_color   = isset( $_GET['color_id'] ) ? absint( wp_unslash( $_GET['color_id'] ) ) : 0;
		$f_size    = isset( $_GET['size_id'] ) ? absint( wp_unslash( $_GET['size_id'] ) ) : 0;
		$f_status  = isset( $_GET['status'] ) ? sanitize_key( (string) wp_unslash( $_GET['status'] ) ) : '';
		$f_user    = isset( $_GET['user_id'] ) ? absint( wp_unslash( $_GET['user_id'] ) ) : 0;
		$f_order   = isset( $_GET['order_id'] ) ? absint( wp_unslash( $_GET['order_id'] ) ) : 0;
		$f_from    = isset( $_GET['date_from'] ) ? sanitize_text_field( wp_unslash( $_GET['date_from'] ) ) : '';
		$f_to      = isset( $_GET['date_to'] ) ? sanitize_text_field( wp_unslash( $_GET['date_to'] ) ) : '';
		$paged     = isset( $_GET['paged'] ) ? max( 1, absint( wp_unslash( $_GET['paged'] ) ) ) : 1;
		// phpcs:enable

		$table = $this->plugin->db->table( 'designs' );

		if ( $view > 0 ) {
			// phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery
			$row = $wpdb->get_row(
				$wpdb->prepare( "SELECT * FROM {$table} WHERE id = %d", $view ),
				ARRAY_A
			);
			$design = is_array( $row ) ? $this->plugin->designs->cast( $row ) : null;

			$versions = null !== $design ? $this->plugin->designs->versions( $view ) : array();

			require TD_PLUGIN_DIR . 'admin/views/html-designs-view.php';
			return;
		}

		// ---- Build the filtered query. Every value goes through prepare(). ---

		$where  = array( '1=1' );
		$params = array();

		if ( '' !== $search ) {
			// Search by design code or numeric id.
			$like     = '%' . $wpdb->esc_like( $search ) . '%';
			$where[]  = '( uuid LIKE %s OR id = %d )';
			$params[] = $like;
			$params[] = ctype_digit( $search ) ? (int) $search : 0;
		}
		if ( '' !== $f_type && Product_Type_Registry::exists( $f_type ) ) {
			$where[]  = 'product_type = %s';
			$params[] = $f_type;
		}
		if ( $f_model > 0 ) {
			$where[]  = 'model_id = %d';
			$params[] = $f_model;
		}
		if ( $f_color > 0 ) {
			$where[]  = 'color_id = %d';
			$params[] = $f_color;
		}
		if ( $f_size > 0 ) {
			$where[]  = 'size_id = %d';
			$params[] = $f_size;
		}
		if ( '' !== $f_status ) {
			$where[]  = 'status = %s';
			$params[] = $f_status;
		}
		if ( $f_user > 0 ) {
			$where[]  = 'user_id = %d';
			$params[] = $f_user;
		}
		if ( $f_order > 0 ) {
			// The designs table has no order column: an order references its
			// design through line-item meta, so resolve the ids that way.
			$design_ids = $this->design_ids_for_order( $f_order );
			if ( array() === $design_ids ) {
				$where[] = '1=0';
			} else {
				$where[] = 'id IN (' . implode( ',', array_fill( 0, count( $design_ids ), '%d' ) ) . ')';
				foreach ( $design_ids as $design_id ) {
					$params[] = $design_id;
				}
			}
		}
		if ( '' !== $f_from && (bool) strtotime( $f_from ) ) {
			$where[]  = 'created_at >= %s';
			$params[] = gmdate( 'Y-m-d 00:00:00', (int) strtotime( $f_from ) );
		}
		if ( '' !== $f_to && (bool) strtotime( $f_to ) ) {
			$where[]  = 'created_at <= %s';
			$params[] = gmdate( 'Y-m-d 23:59:59', (int) strtotime( $f_to ) );
		}

		$where_sql = implode( ' AND ', $where );

		// phpcs:disable WordPress.DB.PreparedSQL.InterpolatedNotPrepared, WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQLPlaceholders
		$count_sql = "SELECT COUNT(*) FROM {$table} WHERE {$where_sql}";
		$total     = (int) ( array() === $params
			? $wpdb->get_var( $count_sql )
			: $wpdb->get_var( $wpdb->prepare( $count_sql, ...$params ) ) );

		$offset    = ( $paged - 1 ) * self::PER_PAGE;
		$list_sql  = "SELECT * FROM {$table} WHERE {$where_sql} ORDER BY id DESC LIMIT %d OFFSET %d";
		$list_args = array_merge( $params, array( self::PER_PAGE, $offset ) );
		$rows      = $wpdb->get_results( $wpdb->prepare( $list_sql, ...$list_args ), ARRAY_A );
		// phpcs:enable

		$designs = array_map( array( $this->plugin->designs, 'cast' ), is_array( $rows ) ? $rows : array() );

		// ---- Reference data for the filter UI + table rendering. -------------

		$models     = array();
		$model_rows = array();
		foreach ( $this->plugin->models->all( false ) as $model ) {
			$models[ (int) $model['id'] ]     = (string) $model['name'];
			$model_rows[ (int) $model['id'] ] = $model;
		}

		$users = array();
		foreach ( $designs as $design ) {
			$uid = (int) $design['user_id'];
			if ( $uid > 0 && ! isset( $users[ $uid ] ) ) {
				$user          = get_userdata( $uid );
				$users[ $uid ] = $user ? $user->user_login : ( '#' . $uid );
			}
		}

		$statuses = array(
			Design_Manager::STATUS_DRAFT      => __( 'Draft', 'tshirt-designer' ),
			Design_Manager::STATUS_SAVED      => __( 'Saved', 'tshirt-designer' ),
			Design_Manager::STATUS_ORDERED    => __( 'Ordered', 'tshirt-designer' ),
			Design_Manager::STATUS_PAID       => __( 'Paid', 'tshirt-designer' ),
			Design_Manager::STATUS_PRODUCTION => __( 'In production', 'tshirt-designer' ),
		);

		$total_pages = (int) ceil( $total / self::PER_PAGE );
		$filters     = array(
			's'            => $search,
			'product_type' => $f_type,
			'model_id'     => $f_model,
			'status'       => $f_status,
			'user_id'      => $f_user,
			'order_id'     => $f_order,
			'date_from'    => $f_from,
			'date_to'      => $f_to,
		);

		require TD_PLUGIN_DIR . 'admin/views/html-designs.php';
	}

	/**
	 * Design ids referenced by the line items of an order.
	 *
	 * @return list<int>
	 */
	private function design_ids_for_order( int $order_id ): array {
		if ( ! function_exists( 'wc_get_order' ) ) {
			return array();
		}
		$order = wc_get_order( $order_id );
		if ( ! $order instanceof \WC_Order ) {
			return array();
		}
		$ids = array();
		foreach ( $order->get_items() as $item ) {
			$design_id = (int) $item->get_meta( \TShirtDesigner\Order_Manager::META_DESIGN_ID );
			if ( $design_id > 0 ) {
				$ids[] = $design_id;
			}
		}
		return array_values( array_unique( $ids ) );
	}

	public function handle_action( string $do ): void {
		if ( 'delete' !== $do ) {
			Admin_Models::redirect( 'designs', array() );
			return;
		}

		// phpcs:ignore WordPress.Security.NonceVerification -- verified in Admin::route_action().
		$id = isset( $_POST['id'] ) ? absint( wp_unslash( $_POST['id'] ) ) : 0;

		if ( $id <= 0 ) {
			Admin_Models::redirect(
				'designs',
				array( 'error' => rawurlencode( __( 'No design selected.', 'tshirt-designer' ) ) )
			);
			return;
		}

		// Admins are powerful, but sold work is still protected: an order must
		// keep the design it was placed against.
		$design = $this->plugin->designs->get_design( $id, get_current_user_id(), '' );
		if ( null === $design ) {
			Admin_Models::redirect(
				'designs',
				array( 'error' => rawurlencode( __( 'Design not found.', 'tshirt-designer' ) ) )
			);
			return;
		}

		if ( in_array( (string) $design['status'], Design_Manager::PROTECTED_STATUSES, true ) ) {
			Admin_Models::redirect(
				'designs',
				array(
					'error' => rawurlencode(
						__( 'This design belongs to an order and cannot be deleted.', 'tshirt-designer' )
					),
				)
			);
			return;
		}

		$result = $this->plugin->designs->delete( $id, get_current_user_id(), '' );

		Admin_Models::redirect(
			'designs',
			$result['ok']
				? array( 'updated' => rawurlencode( __( 'Design deleted.', 'tshirt-designer' ) ) )
				: array( 'error' => rawurlencode( implode( ' ', $result['errors'] ) ) )
		);
	}
}
