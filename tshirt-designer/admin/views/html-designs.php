<?php
/**
 * Admin view: Designs list.
 *
 * @var array<int, array<string,mixed>> $designs
 * @var array<int, string>              $models
 * @var array<int, string>              $users
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;

defined( 'ABSPATH' ) || exit;

$title = __( 'Designs', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<h2><?php esc_html_e( 'Saved designs', 'tshirt-designer' ); ?></h2>

<table class="widefat striped td-table">
	<thead>
		<tr>
			<th style="width:64px"><?php esc_html_e( 'Preview', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'ID', 'tshirt-designer' ); ?></th>
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
			<tr><td colspan="8"><?php esc_html_e( 'No saved designs yet.', 'tshirt-designer' ); ?></td></tr>
		<?php endif; ?>
		<?php foreach ( $designs as $design ) : ?>
			<?php
			$preview = (int) $design['preview_image_id'] > 0
				? wp_get_attachment_image_url( (int) $design['preview_image_id'], 'thumbnail' )
				: '';
			?>
			<tr>
				<td>
					<?php if ( is_string( $preview ) && '' !== $preview ) : ?>
						<img class="td-thumb" src="<?php echo esc_url( $preview ); ?>" alt="" />
					<?php else : ?>
						<span class="td-thumb td-thumb--empty"></span>
					<?php endif; ?>
				</td>
				<td><strong>#<?php echo esc_html( (string) $design['id'] ); ?></strong></td>
				<td><?php echo esc_html( $models[ (int) $design['model_id'] ] ?? '—' ); ?></td>
				<td><?php echo (int) $design['user_id'] > 0 ? esc_html( $users[ (int) $design['user_id'] ] ?? '—' ) : esc_html__( 'Guest', 'tshirt-designer' ); ?></td>
				<td><?php echo esc_html( $this->plugin->settings->format_price( (float) $design['price_total'] ) ); ?></td>
				<td><?php echo esc_html( $design['status'] ); ?></td>
				<td><?php echo esc_html( $design['created_at'] ); ?></td>
				<td>
					<a class="button button-small" href="<?php echo esc_url( Admin::page_url( 'designs', array( 'view' => (int) $design['id'] ) ) ); ?>"><?php esc_html_e( 'View', 'tshirt-designer' ); ?></a>
					<form method="post" action="<?php echo esc_url( Admin::action_url( 'designs' ) ); ?>" class="td-inline-form">
						<?php wp_nonce_field( 'td_admin_designs' ); ?>
						<input type="hidden" name="page_key" value="designs" />
						<input type="hidden" name="do" value="delete" />
						<input type="hidden" name="id" value="<?php echo esc_attr( (string) $design['id'] ); ?>" />
						<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
					</form>
				</td>
			</tr>
		<?php endforeach; ?>
	</tbody>
</table>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
