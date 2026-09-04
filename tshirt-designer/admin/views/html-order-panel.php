<?php
/**
 * View: "Custom Product Design" panel on the WooCommerce order screen.
 *
 * @package TShirtDesigner
 *
 * @var array<int, array<string, mixed>> $designed          Designed line items.
 * @var \WC_Order                        $order             The order.
 * @var int                              $order_id          Order id.
 * @var string                           $production_status Current status.
 * @var array<string, string>            $statuses          Available statuses.
 */

defined( 'ABSPATH' ) || exit;

use TShirtDesigner\Admin\Admin_Order_Panel;

// phpcs:disable WordPress.Security.NonceVerification -- read-only notices.
$td_notice = isset( $_GET['td_notice'] ) ? sanitize_text_field( wp_unslash( $_GET['td_notice'] ) ) : '';
$td_error  = isset( $_GET['td_error'] ) ? sanitize_text_field( wp_unslash( $_GET['td_error'] ) ) : '';
// phpcs:enable

$td_settings = td_plugin()->settings;
?>
<div class="td-order-panel">

	<?php if ( '' !== $td_notice ) : ?>
		<div class="notice notice-success inline"><p><?php echo esc_html( $td_notice ); ?></p></div>
	<?php endif; ?>
	<?php if ( '' !== $td_error ) : ?>
		<div class="notice notice-error inline"><p><?php echo esc_html( $td_error ); ?></p></div>
	<?php endif; ?>

	<div class="td-order-panel__toolbar">
		<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="td-inline-form">
			<?php wp_nonce_field( Admin_Order_Panel::NONCE ); ?>
			<input type="hidden" name="action" value="<?php echo esc_attr( Admin_Order_Panel::ACTION ); ?>">
			<input type="hidden" name="do" value="set_status">
			<input type="hidden" name="order_id" value="<?php echo esc_attr( (string) $order_id ); ?>">

			<label for="td-production-status"><strong><?php esc_html_e( 'Production status', 'tshirt-designer' ); ?></strong></label>
			<select name="production_status" id="td-production-status">
				<?php foreach ( $statuses as $td_key => $td_label ) : ?>
					<option value="<?php echo esc_attr( $td_key ); ?>" <?php selected( $production_status, $td_key ); ?>>
						<?php echo esc_html( $td_label ); ?>
					</option>
				<?php endforeach; ?>
			</select>
			<button type="submit" class="button"><?php esc_html_e( 'Update', 'tshirt-designer' ); ?></button>
		</form>

		<div class="td-order-panel__bulk">
			<a class="button button-primary"
				href="<?php echo esc_url( Admin_Order_Panel::action_url( 'download_all', $order_id ) ); ?>">
				<?php esc_html_e( 'Download all print files (ZIP)', 'tshirt-designer' ); ?>
			</a>
			<a class="button"
				href="<?php echo esc_url( Admin_Order_Panel::action_url( 'regenerate', $order_id ) ); ?>"
				onclick="return confirm('<?php echo esc_js( __( 'Regenerate all production files from the order snapshot?', 'tshirt-designer' ) ); ?>');">
				<?php esc_html_e( 'Regenerate from snapshot', 'tshirt-designer' ); ?>
			</a>
		</div>
	</div>

	<?php foreach ( $designed as $td_line ) : ?>
		<?php
		$td_snap    = $td_line['snapshot'];
		$td_pricing = is_array( $td_line['pricing'] ) ? $td_line['pricing'] : array();
		$td_files   = $td_line['files'];
		$td_item_id = (int) $td_line['item_id'];

		$td_files_by_area = array();
		foreach ( $td_files as $td_file ) {
			$td_files_by_area[ (int) $td_file['print_area_id'] ] = $td_file;
		}

		$td_preview_id  = (int) ( $td_snap['preview_image_id'] ?? 0 );
		$td_preview_url = $td_preview_id > 0 ? wp_get_attachment_image_url( $td_preview_id, 'medium' ) : '';
		?>
		<div class="td-design-card">

			<div class="td-design-card__media">
				<?php if ( is_string( $td_preview_url ) && '' !== $td_preview_url ) : ?>
					<img src="<?php echo esc_url( $td_preview_url ); ?>"
						alt="<?php esc_attr_e( 'Design preview', 'tshirt-designer' ); ?>">
				<?php else : ?>
					<div class="td-design-card__noimage"><?php esc_html_e( 'No preview saved', 'tshirt-designer' ); ?></div>
				<?php endif; ?>
			</div>

			<div class="td-design-card__body">
				<table class="widefat striped td-design-meta">
					<tbody>
						<tr>
							<th scope="row"><?php esc_html_e( 'Design', 'tshirt-designer' ); ?></th>
							<td>
								<code><?php echo esc_html( (string) ( $td_snap['design_uuid'] ?? '' ) ); ?></code>
								<?php
								printf(
									' <span class="description">%s</span>',
									esc_html(
										sprintf(
											/* translators: %d: version number. */
											__( 'version %d', 'tshirt-designer' ),
											(int) ( $td_snap['design_version'] ?? 1 )
										)
									)
								);
								?>
							</td>
						</tr>
						<tr>
							<th scope="row"><?php esc_html_e( 'Product type', 'tshirt-designer' ); ?></th>
							<td><?php echo esc_html( \TShirtDesigner\Product_Type_Registry::label( (string) ( $td_snap['product_type'] ?? '' ) ) ); ?></td>
						</tr>
						<tr>
							<th scope="row"><?php esc_html_e( 'Model', 'tshirt-designer' ); ?></th>
							<td><?php echo esc_html( (string) ( $td_snap['model']['name'] ?? '—' ) ); ?></td>
						</tr>
						<?php if ( ! empty( $td_snap['color'] ) ) : ?>
							<tr>
								<th scope="row"><?php esc_html_e( 'Color', 'tshirt-designer' ); ?></th>
								<td>
									<span class="td-swatch" style="background:<?php echo esc_attr( (string) ( $td_snap['color']['hex'] ?? '#fff' ) ); ?>"></span>
									<?php echo esc_html( (string) ( $td_snap['color']['name'] ?? '' ) ); ?>
								</td>
							</tr>
						<?php endif; ?>
						<?php if ( ! empty( $td_snap['size'] ) ) : ?>
							<tr>
								<th scope="row"><?php esc_html_e( 'Size', 'tshirt-designer' ); ?></th>
								<td><?php echo esc_html( (string) ( $td_snap['size']['name'] ?? '' ) ); ?></td>
							</tr>
						<?php endif; ?>
						<tr>
							<th scope="row"><?php esc_html_e( 'Printed items', 'tshirt-designer' ); ?></th>
							<td><?php echo esc_html( (string) (int) ( $td_snap['item_count'] ?? 0 ) ); ?></td>
						</tr>
						<tr>
							<th scope="row"><?php esc_html_e( 'Print resolution', 'tshirt-designer' ); ?></th>
							<td><?php echo esc_html( sprintf( '%d DPI', (int) ( $td_snap['dpi'] ?? 300 ) ) ); ?></td>
						</tr>
					</tbody>
				</table>

				<h4><?php esc_html_e( 'Print areas', 'tshirt-designer' ); ?></h4>
				<table class="widefat striped td-area-table">
					<thead>
						<tr>
							<th><?php esc_html_e( 'Area', 'tshirt-designer' ); ?></th>
							<th><?php esc_html_e( 'Print size', 'tshirt-designer' ); ?></th>
							<th><?php esc_html_e( 'Items', 'tshirt-designer' ); ?></th>
							<th><?php esc_html_e( 'Production file', 'tshirt-designer' ); ?></th>
							<th><?php esc_html_e( 'Download', 'tshirt-designer' ); ?></th>
						</tr>
					</thead>
					<tbody>
					<?php foreach ( (array) ( $td_snap['areas'] ?? array() ) as $td_area ) : ?>
						<?php
						$td_area_id = (int) ( $td_area['id'] ?? 0 );
						$td_file    = $td_files_by_area[ $td_area_id ] ?? null;
						?>
						<tr>
							<td>
								<strong><?php echo esc_html( (string) ( $td_area['name'] ?? '' ) ); ?></strong><br>
								<span class="description"><?php echo esc_html( strtoupper( (string) ( $td_area['type'] ?? '' ) ) ); ?></span>
							</td>
							<td>
								<?php
								echo esc_html(
									sprintf(
										'%s × %s cm',
										(string) round( (float) ( $td_area['max_width_cm'] ?? 0 ), 1 ),
										(string) round( (float) ( $td_area['max_height_cm'] ?? 0 ), 1 )
									)
								);
								?>
							</td>
							<td><?php echo esc_html( (string) count( (array) ( $td_area['items'] ?? array() ) ) ); ?></td>
							<td>
								<?php if ( is_array( $td_file ) ) : ?>
									<code><?php echo esc_html( (string) $td_file['file_name'] ); ?></code><br>
									<span class="description">
										<?php
										echo esc_html(
											sprintf(
												'%d × %d px',
												(int) $td_file['width_px'],
												(int) $td_file['height_px']
											)
										);
										?>
									</span>
								<?php else : ?>
									<span class="description"><?php esc_html_e( 'Not generated yet', 'tshirt-designer' ); ?></span>
								<?php endif; ?>
							</td>
							<td>
								<?php if ( is_array( $td_file ) && file_exists( (string) $td_file['file_path'] ) ) : ?>
									<a class="button button-small"
										href="<?php echo esc_url( Admin_Order_Panel::action_url( 'download', $order_id, array( 'file_id' => (int) $td_file['id'] ) ) ); ?>">
										<?php
										printf(
											/* translators: %s: print area name, e.g. Front. */
											esc_html__( 'Download %s', 'tshirt-designer' ),
											esc_html( (string) ( $td_area['name'] ?? '' ) )
										);
										?>
									</a>
								<?php else : ?>
									&mdash;
								<?php endif; ?>
							</td>
						</tr>
					<?php endforeach; ?>
					</tbody>
				</table>

				<?php if ( array() !== $td_pricing ) : ?>
					<h4><?php esc_html_e( 'Price breakdown (as charged)', 'tshirt-designer' ); ?></h4>
					<table class="widefat striped td-price-table">
						<tbody>
							<tr>
								<th scope="row"><?php esc_html_e( 'Base product', 'tshirt-designer' ); ?></th>
								<td><?php echo esc_html( $td_settings->format_price( (float) ( $td_pricing['base_price'] ?? 0 ) ) ); ?></td>
							</tr>
							<?php if ( (float) ( $td_pricing['size_modifier'] ?? 0 ) > 0 ) : ?>
								<tr>
									<th scope="row"><?php esc_html_e( 'Size surcharge', 'tshirt-designer' ); ?></th>
									<td><?php echo esc_html( $td_settings->format_price( (float) $td_pricing['size_modifier'] ) ); ?></td>
								</tr>
							<?php endif; ?>
							<?php foreach ( (array) ( $td_pricing['areas'] ?? array() ) as $td_pa ) : ?>
								<tr>
									<th scope="row">
										<?php
										printf(
											/* translators: %s: print area name. */
											esc_html__( '%s printing', 'tshirt-designer' ),
											esc_html( (string) ( $td_pa['name'] ?? '' ) )
										);
										?>
									</th>
									<td><?php echo esc_html( $td_settings->format_price( (float) ( $td_pa['subtotal'] ?? 0 ) ) ); ?></td>
								</tr>
							<?php endforeach; ?>
							<tr>
								<th scope="row"><strong><?php esc_html_e( 'Unit total', 'tshirt-designer' ); ?></strong></th>
								<td><strong><?php echo esc_html( $td_settings->format_price( (float) ( $td_pricing['total'] ?? 0 ) ) ); ?></strong></td>
							</tr>
						</tbody>
					</table>
				<?php endif; ?>

				<p class="td-design-card__actions">
					<a class="button"
						href="<?php echo esc_url( Admin_Order_Panel::action_url( 'download_all', $order_id, array( 'item_id' => $td_item_id ) ) ); ?>">
						<?php esc_html_e( 'Download this item (ZIP)', 'tshirt-designer' ); ?>
					</a>
				</p>
			</div>
		</div>
	<?php endforeach; ?>
</div>
