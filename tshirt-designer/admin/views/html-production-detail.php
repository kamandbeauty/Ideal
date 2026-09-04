<?php
/**
 * Production job detail.
 *
 * Expects: $job, $snapshot, $files, $history, $next, $order.
 *
 * Everything shown here is read from the IMMUTABLE snapshot stored on the
 * order line — never from the live catalogue — so this screen always shows
 * what the customer actually bought (§13/§17).
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;
use TShirtDesigner\Admin\Admin_Production;
use TShirtDesigner\Production_Status;

defined( 'ABSPATH' ) || exit;

$td_post_url = admin_url( 'admin-post.php' );
$td_files_by_area = array();
foreach ( $files as $td_f ) {
	$td_files_by_area[ (string) $td_f['area_type'] ] = $td_f;
}
?>

<p>
	<a href="<?php echo esc_url( Admin::page_url( 'production' ) ); ?>">
		&larr; <?php esc_html_e( 'Back to production', 'tshirt-designer' ); ?>
	</a>
</p>

<?php if ( Production_Status::FAILED === (string) $job['status'] && '' !== (string) $job['error_message'] ) : ?>
	<div class="notice notice-error">
		<p>
			<strong><?php esc_html_e( 'Production failed:', 'tshirt-designer' ); ?></strong>
			<?php echo esc_html( (string) $job['error_message'] ); ?>
		</p>
	</div>
<?php endif; ?>

<div class="td-prod__detail">

	<div class="td-card">
		<h2><?php esc_html_e( 'Order', 'tshirt-designer' ); ?></h2>
		<table class="widefat striped">
			<tbody>
			<tr>
				<th><?php esc_html_e( 'Order', 'tshirt-designer' ); ?></th>
				<td>
					<?php if ( $order ) : ?>
						<a href="<?php echo esc_url( $order->get_edit_order_url() ); ?>">#<?php echo esc_html( (string) $job['order_id'] ); ?></a>
					<?php else : ?>
						#<?php echo esc_html( (string) $job['order_id'] ); ?>
						<span class="description"><?php esc_html_e( '(order not found)', 'tshirt-designer' ); ?></span>
					<?php endif; ?>
				</td>
			</tr>
			<tr>
				<th><?php esc_html_e( 'Customer', 'tshirt-designer' ); ?></th>
				<td>
					<?php echo esc_html( (string) $job['customer_name'] ); ?>
					&lt;<?php echo esc_html( (string) $job['customer_email'] ); ?>&gt;
				</td>
			</tr>
			<tr>
				<th><?php esc_html_e( 'Date', 'tshirt-designer' ); ?></th>
				<td><?php echo esc_html( mysql2date( get_option( 'date_format' ) . ' H:i', (string) $job['created_at'] ) ); ?></td>
			</tr>
			<tr>
				<th><?php esc_html_e( 'Payment', 'tshirt-designer' ); ?></th>
				<td><?php echo esc_html( $order ? wc_get_order_status_name( $order->get_status() ) : '—' ); ?></td>
			</tr>
			</tbody>
		</table>
	</div>

	<div class="td-card">
		<h2><?php esc_html_e( 'Product &amp; design', 'tshirt-designer' ); ?></h2>
		<table class="widefat striped">
			<tbody>
			<tr>
				<th><?php esc_html_e( 'Product type', 'tshirt-designer' ); ?></th>
				<td><?php echo esc_html( (string) $job['product_type'] ); ?></td>
			</tr>
			<tr>
				<th><?php esc_html_e( 'Model', 'tshirt-designer' ); ?></th>
				<td><?php echo esc_html( (string) ( $snapshot['model']['name'] ?? '—' ) ); ?></td>
			</tr>
			<tr>
				<th><?php esc_html_e( 'Color', 'tshirt-designer' ); ?></th>
				<td><?php echo esc_html( (string) ( $snapshot['color']['name'] ?? '—' ) ); ?></td>
			</tr>
			<tr>
				<th><?php esc_html_e( 'Size', 'tshirt-designer' ); ?></th>
				<td><?php echo esc_html( (string) ( $snapshot['size']['name'] ?? '—' ) ); ?></td>
			</tr>
			<tr>
				<th><?php esc_html_e( 'Design', 'tshirt-designer' ); ?></th>
				<td>
					#<?php echo esc_html( (string) $job['design_id'] ); ?>
					<?php
					printf(
						/* translators: %d: design version. */
						esc_html__( '(version %d)', 'tshirt-designer' ),
						(int) $job['design_version']
					);
					?>
				</td>
			</tr>
			</tbody>
		</table>

		<?php
		$td_preview = (int) ( $snapshot['preview_image_id'] ?? 0 );
		if ( $td_preview > 0 ) :
			$td_src = wp_get_attachment_image_url( $td_preview, 'medium' );
			if ( $td_src ) :
				?>
				<p class="td-prod__preview">
					<img src="<?php echo esc_url( $td_src ); ?>" alt="<?php esc_attr_e( 'Design preview', 'tshirt-designer' ); ?>" />
				</p>
			<?php endif; ?>
		<?php endif; ?>
	</div>

	<div class="td-card">
		<h2><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></h2>
		<p>
			<span class="td-badge td-badge--<?php echo esc_attr( (string) $job['badge'] ); ?>">
				<?php echo esc_html( (string) $job['status_label'] ); ?>
			</span>
		</p>

		<?php if ( Production_Status::QC === (string) $job['status'] ) : ?>
			<h3><?php esc_html_e( 'Quality check', 'tshirt-designer' ); ?></h3>
			<form method="post" action="<?php echo esc_url( $td_post_url ); ?>">
				<input type="hidden" name="action" value="td_action" />
				<input type="hidden" name="page_key" value="production" />
				<input type="hidden" name="do" value="quality_check" />
				<input type="hidden" name="job_id" value="<?php echo esc_attr( (string) $job['id'] ); ?>" />
				<?php wp_nonce_field( 'td_admin_production' ); ?>
				<p>
					<label for="td-qc-note"><?php esc_html_e( 'Note (required if the check fails)', 'tshirt-designer' ); ?></label><br />
					<textarea id="td-qc-note" name="note" rows="2" class="large-text"></textarea>
				</p>
				<p>
					<button type="submit" name="passed" value="1" class="button button-primary"><?php esc_html_e( 'Pass', 'tshirt-designer' ); ?></button>
					<button type="submit" name="passed" value="0" class="button"><?php esc_html_e( 'Fail — back to production', 'tshirt-designer' ); ?></button>
				</p>
			</form>
		<?php endif; ?>

		<?php if ( array() !== $next ) : ?>
			<h3><?php esc_html_e( 'Move to', 'tshirt-designer' ); ?></h3>
			<form method="post" action="<?php echo esc_url( $td_post_url ); ?>">
				<input type="hidden" name="action" value="td_action" />
				<input type="hidden" name="page_key" value="production" />
				<input type="hidden" name="do" value="status" />
				<input type="hidden" name="job_id" value="<?php echo esc_attr( (string) $job['id'] ); ?>" />
				<?php wp_nonce_field( 'td_admin_production' ); ?>
				<p>
					<select name="status">
						<?php foreach ( $next as $td_to ) : ?>
							<option value="<?php echo esc_attr( $td_to ); ?>"><?php echo esc_html( Production_Status::label( $td_to ) ); ?></option>
						<?php endforeach; ?>
					</select>
				</p>
				<p>
					<label for="td-status-note"><?php esc_html_e( 'Note (optional)', 'tshirt-designer' ); ?></label><br />
					<textarea id="td-status-note" name="note" rows="2" class="large-text"></textarea>
				</p>
				<p><button type="submit" class="button button-primary"><?php esc_html_e( 'Update status', 'tshirt-designer' ); ?></button></p>
			</form>
		<?php else : ?>
			<p class="description"><?php esc_html_e( 'This job has reached a final state and can no longer change.', 'tshirt-designer' ); ?></p>
		<?php endif; ?>

		<h3><?php esc_html_e( 'Priority', 'tshirt-designer' ); ?></h3>
		<form method="post" action="<?php echo esc_url( $td_post_url ); ?>">
			<input type="hidden" name="action" value="td_action" />
			<input type="hidden" name="page_key" value="production" />
			<input type="hidden" name="do" value="priority" />
			<input type="hidden" name="job_id" value="<?php echo esc_attr( (string) $job['id'] ); ?>" />
			<?php wp_nonce_field( 'td_admin_production' ); ?>
			<p>
				<select name="priority">
					<?php foreach ( Production_Status::priorities() as $td_p => $td_plabel ) : ?>
						<option value="<?php echo esc_attr( $td_p ); ?>" <?php selected( (string) $job['priority'], $td_p ); ?>>
							<?php echo esc_html( $td_plabel ); ?>
						</option>
					<?php endforeach; ?>
				</select>
				<button type="submit" class="button"><?php esc_html_e( 'Set', 'tshirt-designer' ); ?></button>
			</p>
		</form>
	</div>

</div>

<div class="td-card">
	<h2><?php esc_html_e( 'Print areas &amp; production files', 'tshirt-designer' ); ?></h2>

	<p>
		<a class="button button-primary" href="<?php echo esc_url( Admin_Production::zip_url( (int) $job['id'] ) ); ?>">
			<?php esc_html_e( 'Download all (ZIP)', 'tshirt-designer' ); ?>
		</a>

		<?php // Regeneration always uses the purchased snapshot, never the live catalogue. ?>
		<form method="post" action="<?php echo esc_url( $td_post_url ); ?>" style="display:inline">
			<input type="hidden" name="action" value="td_action" />
			<input type="hidden" name="page_key" value="production" />
			<input type="hidden" name="do" value="regenerate" />
			<input type="hidden" name="job_id" value="<?php echo esc_attr( (string) $job['id'] ); ?>" />
			<?php wp_nonce_field( 'td_admin_production' ); ?>
			<input type="text" name="note" placeholder="<?php esc_attr_e( 'Reason (optional)', 'tshirt-designer' ); ?>" />
			<button type="submit" class="button"><?php esc_html_e( 'Regenerate from snapshot', 'tshirt-designer' ); ?></button>
		</form>

		<?php if ( Production_Status::FAILED === (string) $job['status'] ) : ?>
			<form method="post" action="<?php echo esc_url( $td_post_url ); ?>" style="display:inline">
				<input type="hidden" name="action" value="td_action" />
				<input type="hidden" name="page_key" value="production" />
				<input type="hidden" name="do" value="retry" />
				<input type="hidden" name="job_id" value="<?php echo esc_attr( (string) $job['id'] ); ?>" />
				<?php wp_nonce_field( 'td_admin_production' ); ?>
				<button type="submit" class="button"><?php esc_html_e( 'Retry production', 'tshirt-designer' ); ?></button>
			</form>
		<?php endif; ?>
	</p>

	<table class="wp-list-table widefat fixed striped">
		<thead>
			<tr>
				<th><?php esc_html_e( 'Print area', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Layers', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Dimensions', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Pixels', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'DPI', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'File', 'tshirt-designer' ); ?></th>
				<th><?php esc_html_e( 'Download', 'tshirt-designer' ); ?></th>
			</tr>
		</thead>
		<tbody>
		<?php
		$td_areas = isset( $snapshot['areas'] ) && is_array( $snapshot['areas'] ) ? $snapshot['areas'] : array();
		if ( array() === $td_areas ) :
			?>
			<tr><td colspan="7"><?php esc_html_e( 'This job has no stored design areas.', 'tshirt-designer' ); ?></td></tr>
		<?php endif; ?>

		<?php foreach ( $td_areas as $td_area ) : ?>
			<?php
			$td_type  = (string) ( $td_area['type'] ?? '' );
			$td_items = isset( $td_area['items'] ) && is_array( $td_area['items'] ) ? $td_area['items'] : array();
			$td_file  = $td_files_by_area[ $td_type ] ?? null;
			?>
			<tr>
				<td><strong><?php echo esc_html( (string) ( $td_area['name'] ?? $td_type ) ); ?></strong></td>
				<td><?php echo esc_html( (string) count( $td_items ) ); ?></td>
				<td>
					<?php
					echo esc_html(
						sprintf(
							'%s × %s cm',
							(string) ( $td_area['max_width_cm'] ?? '?' ),
							(string) ( $td_area['max_height_cm'] ?? '?' )
						)
					);
					?>
				</td>
				<td><?php echo $td_file ? esc_html( $td_file['width_px'] . ' × ' . $td_file['height_px'] ) : '—'; ?></td>
				<td><?php echo $td_file ? esc_html( (string) $td_file['dpi'] ) : '—'; ?></td>
				<td>
					<?php if ( array() === $td_items ) : ?>
						<span class="description"><?php esc_html_e( 'Not designed', 'tshirt-designer' ); ?></span>
					<?php elseif ( null === $td_file ) : ?>
						<span class="td-badge td-badge--warn"><?php esc_html_e( 'Not generated', 'tshirt-designer' ); ?></span>
					<?php elseif ( ! $td_file['exists'] ) : ?>
						<span class="td-badge td-badge--error"><?php esc_html_e( 'Missing on disk', 'tshirt-designer' ); ?></span>
					<?php else : ?>
						<span class="td-badge td-badge--ok"><?php esc_html_e( 'Ready', 'tshirt-designer' ); ?></span>
						<br /><span class="description"><?php echo esc_html( size_format( (int) $td_file['file_size'] ) ); ?></span>
					<?php endif; ?>
				</td>
				<td>
					<?php if ( $td_file && $td_file['exists'] ) : ?>
						<a class="button button-small"
							href="<?php echo esc_url( Admin_Production::download_url( (int) $td_file['id'], (int) $job['id'] ) ); ?>">
							<?php esc_html_e( 'PNG', 'tshirt-designer' ); ?>
						</a>
					<?php else : ?>
						—
					<?php endif; ?>
				</td>
			</tr>
		<?php endforeach; ?>
		</tbody>
	</table>
</div>

<div class="td-prod__detail">
	<div class="td-card">
		<h2><?php esc_html_e( 'Notes', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( $td_post_url ); ?>">
			<input type="hidden" name="action" value="td_action" />
			<input type="hidden" name="page_key" value="production" />
			<input type="hidden" name="do" value="note" />
			<input type="hidden" name="job_id" value="<?php echo esc_attr( (string) $job['id'] ); ?>" />
			<?php wp_nonce_field( 'td_admin_production' ); ?>
			<p>
				<label for="td-note" class="screen-reader-text"><?php esc_html_e( 'Note', 'tshirt-designer' ); ?></label>
				<textarea id="td-note" name="note" rows="3" class="large-text"
					placeholder="<?php esc_attr_e( 'e.g. Needs a colour check before printing', 'tshirt-designer' ); ?>"></textarea>
			</p>
			<p><button type="submit" class="button"><?php esc_html_e( 'Add note', 'tshirt-designer' ); ?></button></p>
		</form>
	</div>

	<div class="td-card">
		<h2><?php esc_html_e( 'Activity log', 'tshirt-designer' ); ?></h2>
		<ul class="td-timeline">
			<?php foreach ( array_reverse( $history ) as $td_ev ) : ?>
				<li>
					<span class="td-timeline__time">
						<?php echo esc_html( mysql2date( get_option( 'date_format' ) . ' H:i', (string) $td_ev['created_at'] ) ); ?>
					</span>
					<span class="td-timeline__what">
						<?php
						if ( '' !== (string) $td_ev['to_status'] ) {
							echo esc_html(
								sprintf(
									/* translators: 1: from status, 2: to status. */
									__( '%1$s → %2$s', 'tshirt-designer' ),
									'' !== (string) $td_ev['from_status'] ? Production_Status::label( (string) $td_ev['from_status'] ) : '—',
									Production_Status::label( (string) $td_ev['to_status'] )
								)
							);
						} else {
							echo esc_html( (string) $td_ev['event_type'] );
						}
						?>
					</span>
					<?php if ( '' !== (string) $td_ev['user_name'] ) : ?>
						<span class="td-timeline__who"><?php echo esc_html( (string) $td_ev['user_name'] ); ?></span>
					<?php endif; ?>
					<?php if ( '' !== (string) $td_ev['note'] ) : ?>
						<span class="td-timeline__note"><?php echo esc_html( (string) $td_ev['note'] ); ?></span>
					<?php endif; ?>
				</li>
			<?php endforeach; ?>
		</ul>
	</div>
</div>
