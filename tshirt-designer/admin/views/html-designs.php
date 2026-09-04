<?php
/**
 * Admin view: Design library (search + filters + pagination).
 *
 * @package TShirtDesigner
 *
 * @var array<int, array<string,mixed>> $designs
 * @var array<int, string>              $models
 * @var array<int, array<string,mixed>> $model_rows
 * @var array<int, string>              $users
 * @var array<string, string>           $statuses
 * @var array<string, mixed>            $filters
 * @var int                             $total
 * @var int                             $total_pages
 * @var int                             $paged
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;
use TShirtDesigner\Design_Manager;
use TShirtDesigner\Product_Type_Registry;

defined( 'ABSPATH' ) || exit;

$title = __( 'Designs', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';

$td_settings = td_plugin()->settings;
?>

<h2>
	<?php
	printf(
		/* translators: %d: number of designs. */
		esc_html( _n( '%d saved design', '%d saved designs', $total, 'tshirt-designer' ) ),
		(int) $total
	);
	?>
</h2>

<form method="get" action="<?php echo esc_url( admin_url( 'admin.php' ) ); ?>" class="td-filters">
	<input type="hidden" name="page" value="tshirt-designer-designs">

	<p class="search-box">
		<label class="screen-reader-text" for="td-design-search"><?php esc_html_e( 'Search designs', 'tshirt-designer' ); ?></label>
		<input type="search" id="td-design-search" name="s"
			value="<?php echo esc_attr( (string) $filters['s'] ); ?>"
			placeholder="<?php esc_attr_e( 'Design code or ID…', 'tshirt-designer' ); ?>">
		<button type="submit" class="button"><?php esc_html_e( 'Search', 'tshirt-designer' ); ?></button>
	</p>

	<div class="td-filters__row">
		<label>
			<span><?php esc_html_e( 'Product type', 'tshirt-designer' ); ?></span>
			<select name="product_type">
				<option value=""><?php esc_html_e( 'All', 'tshirt-designer' ); ?></option>
				<?php foreach ( Product_Type_Registry::options() as $td_slug => $td_label ) : ?>
					<option value="<?php echo esc_attr( (string) $td_slug ); ?>" <?php selected( (string) $filters['product_type'], (string) $td_slug ); ?>>
						<?php echo esc_html( (string) $td_label ); ?>
					</option>
				<?php endforeach; ?>
			</select>
		</label>

		<label>
			<span><?php esc_html_e( 'Model', 'tshirt-designer' ); ?></span>
			<select name="model_id">
				<option value="0"><?php esc_html_e( 'All', 'tshirt-designer' ); ?></option>
				<?php foreach ( $models as $td_mid => $td_mname ) : ?>
					<option value="<?php echo esc_attr( (string) $td_mid ); ?>" <?php selected( (int) $filters['model_id'], (int) $td_mid ); ?>>
						<?php echo esc_html( $td_mname ); ?>
					</option>
				<?php endforeach; ?>
			</select>
		</label>

		<label>
			<span><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></span>
			<select name="status">
				<option value=""><?php esc_html_e( 'All', 'tshirt-designer' ); ?></option>
				<?php foreach ( $statuses as $td_skey => $td_slabel ) : ?>
					<option value="<?php echo esc_attr( (string) $td_skey ); ?>" <?php selected( (string) $filters['status'], (string) $td_skey ); ?>>
						<?php echo esc_html( $td_slabel ); ?>
					</option>
				<?php endforeach; ?>
			</select>
		</label>

		<label>
			<span><?php esc_html_e( 'User ID', 'tshirt-designer' ); ?></span>
			<input type="number" name="user_id" min="0" class="small-text"
				value="<?php echo esc_attr( (int) $filters['user_id'] > 0 ? (string) $filters['user_id'] : '' ); ?>">
		</label>

		<label>
			<span><?php esc_html_e( 'Order ID', 'tshirt-designer' ); ?></span>
			<input type="number" name="order_id" min="0" class="small-text"
				value="<?php echo esc_attr( (int) $filters['order_id'] > 0 ? (string) $filters['order_id'] : '' ); ?>">
		</label>

		<label>
			<span><?php esc_html_e( 'From', 'tshirt-designer' ); ?></span>
			<input type="date" name="date_from" value="<?php echo esc_attr( (string) $filters['date_from'] ); ?>">
		</label>

		<label>
			<span><?php esc_html_e( 'To', 'tshirt-designer' ); ?></span>
			<input type="date" name="date_to" value="<?php echo esc_attr( (string) $filters['date_to'] ); ?>">
		</label>

		<span class="td-filters__actions">
			<button type="submit" class="button button-primary"><?php esc_html_e( 'Filter', 'tshirt-designer' ); ?></button>
			<a class="button" href="<?php echo esc_url( Admin::page_url( 'designs' ) ); ?>"><?php esc_html_e( 'Reset', 'tshirt-designer' ); ?></a>
		</span>
	</div>
</form>

<table class="widefat striped td-table">
	<thead>
		<tr>
			<th style="width:64px"><?php esc_html_e( 'Preview', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Design', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Product type', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Model', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Owner', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Total price', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Date', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
		</tr>
	</thead>
	<tbody>
		<?php if ( array() === $designs ) : ?>
			<tr><td colspan="9"><?php esc_html_e( 'No designs match these filters.', 'tshirt-designer' ); ?></td></tr>
		<?php endif; ?>

		<?php foreach ( $designs as $td_design ) : ?>
			<?php
			$td_preview = (int) $td_design['preview_image_id'] > 0
				? wp_get_attachment_image_url( (int) $td_design['preview_image_id'], 'thumbnail' )
				: '';
			$td_locked = in_array( (string) $td_design['status'], Design_Manager::PROTECTED_STATUSES, true );
			?>
			<tr>
				<td>
					<?php if ( is_string( $td_preview ) && '' !== $td_preview ) : ?>
						<img class="td-thumb" src="<?php echo esc_url( $td_preview ); ?>" alt="" />
					<?php else : ?>
						<span class="td-thumb td-thumb--empty"></span>
					<?php endif; ?>
				</td>
				<td>
					<strong><code><?php echo esc_html( (string) $td_design['uuid'] ); ?></code></strong><br>
					<span class="description">
						<?php
						echo esc_html(
							sprintf(
								/* translators: 1: numeric id, 2: version. */
								__( '#%1$d · version %2$d', 'tshirt-designer' ),
								(int) $td_design['id'],
								(int) $td_design['version']
							)
						);
						?>
					</span>
				</td>
				<td><?php echo esc_html( Product_Type_Registry::label( (string) $td_design['product_type'] ) ); ?></td>
				<td><?php echo esc_html( $models[ (int) $td_design['model_id'] ] ?? '—' ); ?></td>
				<td>
					<?php
					echo (int) $td_design['user_id'] > 0
						? esc_html( $users[ (int) $td_design['user_id'] ] ?? '—' )
						: esc_html__( 'Guest', 'tshirt-designer' );
					?>
				</td>
				<td><?php echo esc_html( $td_settings->format_price( (float) $td_design['price_total'] ) ); ?></td>
				<td>
					<span class="td-status td-status--<?php echo esc_attr( (string) $td_design['status'] ); ?>">
						<?php echo esc_html( $statuses[ (string) $td_design['status'] ] ?? (string) $td_design['status'] ); ?>
					</span>
				</td>
				<td><?php echo esc_html( (string) $td_design['created_at'] ); ?></td>
				<td>
					<a class="button button-small"
						href="<?php echo esc_url( Admin::page_url( 'designs', array( 'view' => (int) $td_design['id'] ) ) ); ?>">
						<?php esc_html_e( 'View', 'tshirt-designer' ); ?>
					</a>
					<?php if ( is_string( $td_preview ) && '' !== $td_preview ) : ?>
						<a class="button button-small" href="<?php echo esc_url( $td_preview ); ?>" download>
							<?php esc_html_e( 'Preview', 'tshirt-designer' ); ?>
						</a>
					<?php endif; ?>
					<?php if ( $td_locked ) : ?>
						<span class="description" title="<?php esc_attr_e( 'This design belongs to an order.', 'tshirt-designer' ); ?>">
							<?php esc_html_e( 'Locked', 'tshirt-designer' ); ?>
						</span>
					<?php else : ?>
						<form method="post" action="<?php echo esc_url( Admin::action_url( 'designs' ) ); ?>" class="td-inline-form">
							<?php wp_nonce_field( 'td_admin_designs' ); ?>
							<input type="hidden" name="page_key" value="designs" />
							<input type="hidden" name="do" value="delete" />
							<input type="hidden" name="id" value="<?php echo esc_attr( (string) $td_design['id'] ); ?>" />
							<button class="button button-small td-btn-danger"
								onclick="return confirm('<?php echo esc_js( __( 'Delete this design permanently?', 'tshirt-designer' ) ); ?>');">
								<?php esc_html_e( 'Delete', 'tshirt-designer' ); ?>
							</button>
						</form>
					<?php endif; ?>
				</td>
			</tr>
		<?php endforeach; ?>
	</tbody>
</table>

<?php if ( $total_pages > 1 ) : ?>
	<div class="tablenav"><div class="tablenav-pages">
		<?php
		echo wp_kses_post(
			paginate_links(
				array(
					'base'      => add_query_arg( 'paged', '%#%' ),
					'format'    => '',
					'current'   => $paged,
					'total'     => $total_pages,
					'prev_text' => '&laquo;',
					'next_text' => '&raquo;',
				)
			) ?? ''
		);
		?>
	</div></div>
<?php endif; ?>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
