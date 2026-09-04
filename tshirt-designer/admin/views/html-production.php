<?php
/**
 * Production dashboard list.
 *
 * Expects: $result (query result), $counts, $models, $types, $args.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;
use TShirtDesigner\Admin\Admin_Production;
use TShirtDesigner\Production_Status;

defined( 'ABSPATH' ) || exit;

$td_base = Admin::page_url( 'production' );

/** Tab definitions: slug => label. 'queue' is the active work list. */
$td_tabs = array(
	''                        => __( 'All', 'tshirt-designer' ),
	Production_Status::PAID   => Production_Status::label( Production_Status::PAID ),
	Production_Status::READY  => Production_Status::label( Production_Status::READY ),
	Production_Status::IN_PROD => Production_Status::label( Production_Status::IN_PROD ),
	Production_Status::QC     => Production_Status::label( Production_Status::QC ),
	Production_Status::PACKED => Production_Status::label( Production_Status::PACKED ),
	Production_Status::SHIPPED => Production_Status::label( Production_Status::SHIPPED ),
	Production_Status::COMPLETED => Production_Status::label( Production_Status::COMPLETED ),
	Production_Status::CANCELLED => Production_Status::label( Production_Status::CANCELLED ),
	Production_Status::FAILED => Production_Status::label( Production_Status::FAILED ),
);
?>

<ul class="subsubsub td-prod__tabs">
	<?php
	$td_i = 0;
	foreach ( $td_tabs as $td_slug => $td_label ) :
		++$td_i;
		$td_count  = '' === $td_slug ? array_sum( $counts ) : ( $counts[ $td_slug ] ?? 0 );
		$td_active = (string) $args['status'] === (string) $td_slug ? ' class="current"' : '';
		$td_href   = '' === $td_slug ? $td_base : add_query_arg( 'status', $td_slug, $td_base );
		?>
		<li>
			<a href="<?php echo esc_url( $td_href ); ?>"<?php echo $td_active; // phpcs:ignore WordPress.Security.EscapeOutput ?>>
				<?php echo esc_html( $td_label ); ?>
				<span class="count">(<?php echo esc_html( (string) $td_count ); ?>)</span>
			</a>
			<?php echo $td_i < count( $td_tabs ) ? ' | ' : ''; ?>
		</li>
	<?php endforeach; ?>
</ul>

<form method="get" class="td-prod__filters">
	<input type="hidden" name="page" value="tshirt-designer-production" />
	<?php if ( '' !== (string) $args['status'] ) : ?>
		<input type="hidden" name="status" value="<?php echo esc_attr( (string) $args['status'] ); ?>" />
	<?php endif; ?>

	<p class="search-box">
		<label class="screen-reader-text" for="td-prod-search"><?php esc_html_e( 'Search production', 'tshirt-designer' ); ?></label>
		<input type="search" id="td-prod-search" name="s"
			value="<?php echo esc_attr( (string) $args['search'] ); ?>"
			placeholder="<?php esc_attr_e( 'Order, customer, email, design or job ID', 'tshirt-designer' ); ?>" />

		<select name="product_type">
			<option value=""><?php esc_html_e( 'All product types', 'tshirt-designer' ); ?></option>
			<?php foreach ( $types as $td_slug => $td_type ) : ?>
				<option value="<?php echo esc_attr( (string) $td_slug ); ?>"
					<?php selected( (string) $args['product_type'], (string) $td_slug ); ?>>
					<?php echo esc_html( (string) ( $td_type['label'] ?? $td_slug ) ); ?>
				</option>
			<?php endforeach; ?>
		</select>

		<select name="model_id">
			<option value="0"><?php esc_html_e( 'All models', 'tshirt-designer' ); ?></option>
			<?php foreach ( $models as $td_model ) : ?>
				<option value="<?php echo esc_attr( (string) $td_model['id'] ); ?>"
					<?php selected( (int) $args['model_id'], (int) $td_model['id'] ); ?>>
					<?php echo esc_html( (string) $td_model['name'] ); ?>
				</option>
			<?php endforeach; ?>
		</select>

		<select name="priority">
			<option value=""><?php esc_html_e( 'Any priority', 'tshirt-designer' ); ?></option>
			<?php foreach ( Production_Status::priorities() as $td_p => $td_plabel ) : ?>
				<option value="<?php echo esc_attr( $td_p ); ?>" <?php selected( (string) $args['priority'], $td_p ); ?>>
					<?php echo esc_html( $td_plabel ); ?>
				</option>
			<?php endforeach; ?>
		</select>

		<label for="td-date-from" class="screen-reader-text"><?php esc_html_e( 'From', 'tshirt-designer' ); ?></label>
		<input type="date" id="td-date-from" name="date_from" value="<?php echo esc_attr( (string) $args['date_from'] ); ?>" />
		<label for="td-date-to" class="screen-reader-text"><?php esc_html_e( 'To', 'tshirt-designer' ); ?></label>
		<input type="date" id="td-date-to" name="date_to" value="<?php echo esc_attr( (string) $args['date_to'] ); ?>" />

		<select name="orderby">
			<option value="newest" <?php selected( (string) $args['orderby'], 'newest' ); ?>><?php esc_html_e( 'Newest first', 'tshirt-designer' ); ?></option>
			<option value="oldest" <?php selected( (string) $args['orderby'], 'oldest' ); ?>><?php esc_html_e( 'Oldest first', 'tshirt-designer' ); ?></option>
			<option value="priority" <?php selected( (string) $args['orderby'], 'priority' ); ?>><?php esc_html_e( 'Priority', 'tshirt-designer' ); ?></option>
		</select>

		<button type="submit" class="button"><?php esc_html_e( 'Filter', 'tshirt-designer' ); ?></button>
		<a class="button-link" href="<?php echo esc_url( $td_base ); ?>"><?php esc_html_e( 'Reset', 'tshirt-designer' ); ?></a>
	</p>
</form>

<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
	<input type="hidden" name="action" value="td_action" />
	<input type="hidden" name="page_key" value="production" />
	<input type="hidden" name="do" value="bulk" />
	<?php wp_nonce_field( 'td_admin_production' ); ?>

	<div class="tablenav top">
		<div class="alignleft actions bulkactions">
			<label class="screen-reader-text" for="td-bulk"><?php esc_html_e( 'Bulk action', 'tshirt-designer' ); ?></label>
			<select name="bulk_status" id="td-bulk">
				<option value=""><?php esc_html_e( 'Bulk actions', 'tshirt-designer' ); ?></option>
				<?php
				// Only forward moves that are safe to apply in bulk.
				foreach ( array( Production_Status::READY, Production_Status::IN_PROD, Production_Status::PRINTED, Production_Status::PACKED, Production_Status::SHIPPED ) as $td_bulk ) :
					?>
					<option value="<?php echo esc_attr( $td_bulk ); ?>">
						<?php
						/* translators: %s: status label. */
						printf( esc_html__( 'Mark as %s', 'tshirt-designer' ), esc_html( Production_Status::label( $td_bulk ) ) );
						?>
					</option>
				<?php endforeach; ?>
			</select>
			<button type="submit" class="button"><?php esc_html_e( 'Apply', 'tshirt-designer' ); ?></button>
		</div>
		<div class="tablenav-pages">
			<span class="displaying-num">
				<?php
				printf(
					/* translators: %d: number of jobs. */
					esc_html( _n( '%d job', '%d jobs', (int) $result['total'], 'tshirt-designer' ) ),
					(int) $result['total']
				);
				?>
			</span>
		</div>
	</div>

	<table class="wp-list-table widefat fixed striped td-prod__table">
		<thead>
			<tr>
				<td class="check-column"><input type="checkbox" onclick="document.querySelectorAll('.td-prod__cb').forEach(c=>c.checked=this.checked)" /></td>
				<th><?php esc_html_e( 'Job', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Order', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Customer', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Product', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Design', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Priority', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Date', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
			</tr>
		</thead>
		<tbody>
		<?php if ( array() === $result['items'] ) : ?>
			<tr><td colspan="10"><?php esc_html_e( 'No production jobs match these filters.', 'tshirt-designer' ); ?></td></tr>
		<?php endif; ?>

		<?php foreach ( $result['items'] as $td_job ) : ?>
			<?php $td_detail = Admin::page_url( 'production', array( 'job' => (int) $td_job['id'] ) ); ?>
			<tr>
				<th class="check-column">
					<input type="checkbox" class="td-prod__cb" name="jobs[]" value="<?php echo esc_attr( (string) $td_job['id'] ); ?>" />
				</th>
				<td><a href="<?php echo esc_url( $td_detail ); ?>"><strong>#<?php echo esc_html( (string) $td_job['id'] ); ?></strong></a></td>
				<td>
					<?php if ( function_exists( 'wc_get_order' ) && wc_get_order( (int) $td_job['order_id'] ) ) : ?>
						<a href="<?php echo esc_url( get_edit_post_link( (int) $td_job['order_id'] ) ?: admin_url( 'post.php?post=' . (int) $td_job['order_id'] . '&action=edit' ) ); ?>">
							#<?php echo esc_html( (string) $td_job['order_id'] ); ?>
						</a>
					<?php else : ?>
						#<?php echo esc_html( (string) $td_job['order_id'] ); ?>
					<?php endif; ?>
				</td>
				<td>
					<?php echo esc_html( (string) $td_job['customer_name'] ); ?><br />
					<span class="description"><?php echo esc_html( (string) $td_job['customer_email'] ); ?></span>
				</td>
				<td><?php echo esc_html( (string) $td_job['product_type'] ); ?></td>
				<td>
					#<?php echo esc_html( (string) $td_job['design_id'] ); ?>
					<span class="description">v<?php echo esc_html( (string) $td_job['design_version'] ); ?></span>
				</td>
				<td>
					<span class="td-badge td-badge--<?php echo esc_attr( (string) $td_job['badge'] ); ?>">
						<?php echo esc_html( (string) $td_job['status_label'] ); ?>
					</span>
				</td>
				<td>
					<?php $td_pr = (string) $td_job['priority']; ?>
					<span class="td-prio td-prio--<?php echo esc_attr( $td_pr ); ?>">
						<?php echo esc_html( Production_Status::priorities()[ $td_pr ] ?? $td_pr ); ?>
					</span>
				</td>
				<td><?php echo esc_html( mysql2date( get_option( 'date_format' ) . ' H:i', (string) $td_job['created_at'] ) ); ?></td>
				<td>
					<a class="button button-small" href="<?php echo esc_url( $td_detail ); ?>"><?php esc_html_e( 'View', 'tshirt-designer' ); ?></a>
				</td>
			</tr>
		<?php endforeach; ?>
		</tbody>
	</table>
</form>

<?php
// Pagination.
if ( (int) $result['pages'] > 1 ) :
	$td_page_links = paginate_links(
		array(
			'base'      => add_query_arg( 'paged', '%#%' ),
			'format'    => '',
			'prev_text' => __( '&laquo;', 'tshirt-designer' ),
			'next_text' => __( '&raquo;', 'tshirt-designer' ),
			'total'     => (int) $result['pages'],
			'current'   => (int) $result['page'],
			'type'      => 'array',
		)
	);
	?>
	<div class="tablenav bottom">
		<div class="tablenav-pages">
			<span class="pagination-links">
				<?php
				foreach ( (array) $td_page_links as $td_link ) {
					echo wp_kses_post( $td_link ) . ' ';
				}
				?>
			</span>
		</div>
	</div>
<?php endif; ?>
