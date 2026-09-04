<?php
/**
 * Admin view: single design detail.
 *
 * @var array<string,mixed>|null $design
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;

defined( 'ABSPATH' ) || exit;

$title = __( 'Designs', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';

if ( null === $design ) :
	?>
	<p><?php esc_html_e( 'Design not found.', 'tshirt-designer' ); ?></p>
	<?php
	require TD_PLUGIN_DIR . 'admin/views/html-footer.php';
	return;
endif;

$preview = (int) $design['preview_image_id'] > 0 ? wp_get_attachment_url( (int) $design['preview_image_id'] ) : '';
$breakdown = is_array( $design['price_breakdown'] ) ? $design['price_breakdown'] : array();
$design_data = is_array( $design['design_data'] ) ? $design['design_data'] : array();
$item_count = 0;
if ( isset( $design_data['areas'] ) && is_array( $design_data['areas'] ) ) {
	foreach ( $design_data['areas'] as $area_items ) {
		$item_count += is_array( $area_items ) ? count( $area_items ) : 0;
	}
}
?>

<a class="button" href="<?php echo esc_url( Admin::page_url( 'designs' ) ); ?>">← <?php esc_html_e( 'Back to designs', 'tshirt-designer' ); ?></a>

<div class="td-grid td-grid--design-view">
	<div class="td-col-main">
		<h2><?php echo esc_html( sprintf( __( 'Design #%d', 'tshirt-designer' ), (int) $design['id'] ) ); ?></h2>

		<?php if ( is_string( $preview ) && '' !== $preview ) : ?>
			<img class="td-design-preview" src="<?php echo esc_url( $preview ); ?>" alt="" />
		<?php else : ?>
			<p class="td-muted"><?php esc_html_e( 'No preview image was saved with this design.', 'tshirt-designer' ); ?></p>
		<?php endif; ?>

		<h3><?php esc_html_e( 'Design data (JSON)', 'tshirt-designer' ); ?></h3>
		<pre class="td-code-block"><?php echo esc_html( wp_json_encode( $design_data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) ); ?></pre>
	</div>

	<div class="td-col-side">
		<h3><?php esc_html_e( 'Summary', 'tshirt-designer' ); ?></h3>
		<?php
		$td_model = td_plugin()->models->get( (int) $design['model_id'], true );
		$td_color = td_plugin()->colors->get( (int) $design['color_id'] );
		$td_size  = td_plugin()->sizes->get( (int) $design['size_id'] );
		?>
		<table class="widefat striped">
			<tbody>
				<tr><td><?php esc_html_e( 'Design code', 'tshirt-designer' ); ?></td><td><code><?php echo esc_html( (string) $design['uuid'] ); ?></code></td></tr>
				<tr><td><?php esc_html_e( 'Version', 'tshirt-designer' ); ?></td><td><?php echo esc_html( (string) (int) $design['version'] ); ?></td></tr>
				<tr><td><?php esc_html_e( 'Product type', 'tshirt-designer' ); ?></td><td><?php echo esc_html( TShirtDesigner\Product_Type_Registry::label( (string) $design['product_type'] ) ); ?></td></tr>
				<tr><td><?php esc_html_e( 'Model', 'tshirt-designer' ); ?></td><td><?php echo esc_html( null !== $td_model ? (string) $td_model['name'] : '#' . (int) $design['model_id'] ); ?></td></tr>
				<tr><td><?php esc_html_e( 'Color', 'tshirt-designer' ); ?></td><td><?php echo esc_html( null !== $td_color ? (string) $td_color['name'] : '—' ); ?></td></tr>
				<tr><td><?php esc_html_e( 'Size', 'tshirt-designer' ); ?></td><td><?php echo esc_html( null !== $td_size ? (string) $td_size['name'] : '—' ); ?></td></tr>
				<tr><td><?php esc_html_e( 'Owner', 'tshirt-designer' ); ?></td><td>
					<?php
					$td_owner = (int) $design['user_id'];
					if ( $td_owner > 0 ) {
						$td_user = get_userdata( $td_owner );
						echo esc_html( $td_user ? $td_user->user_login : '#' . $td_owner );
					} else {
						esc_html_e( 'Guest', 'tshirt-designer' );
					}
					?>
				</td></tr>
				<tr><td><?php esc_html_e( 'Printed items', 'tshirt-designer' ); ?></td><td><?php echo esc_html( (string) $item_count ); ?></td></tr>
				<tr><td><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></td><td><?php echo esc_html( $design['status'] ); ?></td></tr>
				<tr><td><?php esc_html_e( 'Date', 'tshirt-designer' ); ?></td><td><?php echo esc_html( $design['created_at'] ); ?></td></tr>
			</tbody>
		</table>

		<?php if ( isset( $versions ) && is_array( $versions ) && count( $versions ) > 0 ) : ?>
			<h3><?php esc_html_e( 'Version history', 'tshirt-designer' ); ?></h3>
			<table class="widefat striped">
				<thead>
					<tr>
						<th><?php esc_html_e( 'Version', 'tshirt-designer' ); ?></th>
						<th><?php esc_html_e( 'Price', 'tshirt-designer' ); ?></th>
						<th><?php esc_html_e( 'Saved', 'tshirt-designer' ); ?></th>
					</tr>
				</thead>
				<tbody>
				<?php foreach ( $versions as $td_version ) : ?>
					<tr>
						<td>
							<?php echo esc_html( (string) (int) $td_version['version'] ); ?>
							<?php if ( (int) $td_version['version'] === (int) $design['version'] ) : ?>
								<span class="description"><?php esc_html_e( '(current)', 'tshirt-designer' ); ?></span>
							<?php endif; ?>
						</td>
						<td><?php echo esc_html( td_plugin()->settings->format_price( (float) $td_version['price_total'] ) ); ?></td>
						<td><?php echo esc_html( (string) $td_version['created_at'] ); ?></td>
					</tr>
				<?php endforeach; ?>
				</tbody>
			</table>
			<p class="description">
				<?php esc_html_e( 'Each version keeps its own immutable price snapshot. An order is always bound to the exact version that was purchased.', 'tshirt-designer' ); ?>
			</p>
		<?php endif; ?>

		<?php if ( array() !== $breakdown ) : ?>
			<h3><?php esc_html_e( 'Price breakdown', 'tshirt-designer' ); ?></h3>
			<table class="widefat striped">
				<tbody>
					<tr><td><?php esc_html_e( 'Base product', 'tshirt-designer' ); ?></td><td><?php echo esc_html( td_plugin()->settings->format_price( (float) ( $breakdown['base_price'] ?? 0 ) ) ); ?></td></tr>
					<tr><td><?php esc_html_e( 'Size surcharge', 'tshirt-designer' ); ?></td><td><?php echo esc_html( td_plugin()->settings->format_price( (float) ( $breakdown['size_modifier'] ?? 0 ) ) ); ?></td></tr>
					<?php if ( isset( $breakdown['areas'] ) && is_array( $breakdown['areas'] ) ) : ?>
						<?php foreach ( $breakdown['areas'] as $area ) : ?>
							<tr>
								<td><?php echo esc_html( sprintf( /* translators: %s: area name. */ __( 'Prints — %s', 'tshirt-designer' ), (string) $area['name'] ) ); ?></td>
								<td><?php echo esc_html( td_plugin()->settings->format_price( (float) $area['subtotal'] ) ); ?></td>
							</tr>
						<?php endforeach; ?>
					<?php endif; ?>
					<tr class="td-row-total"><td><strong><?php esc_html_e( 'Total', 'tshirt-designer' ); ?></strong></td>
						<td><strong><?php echo esc_html( td_plugin()->settings->format_price( (float) ( $breakdown['total'] ?? $design['price_total'] ) ) ); ?></strong></td></tr>
				</tbody>
			</table>
		<?php endif; ?>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
