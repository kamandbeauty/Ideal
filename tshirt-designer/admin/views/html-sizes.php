<?php
/**
 * Admin view: Sizes.
 *
 * @var int                       $mid
 * @var array<string,mixed>|null  $model
 * @var array<int, array<string,mixed>> $sizes
 * @var array<int, array<string,mixed>> $models
 * @var array<string,mixed>|null  $edit
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;

defined( 'ABSPATH' ) || exit;

$title = __( 'Sizes', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<?php if ( null === $model ) : ?>
	<p><?php esc_html_e( 'Create a model first.', 'tshirt-designer' ); ?></p>
	<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; return; endif; ?>

<div class="td-model-switcher">
	<strong><?php esc_html_e( 'Model:', 'tshirt-designer' ); ?></strong>
	<?php foreach ( $models as $m ) : ?>
		<a class="td-chip<?php echo (int) $m['id'] === $mid ? ' is-active' : ''; ?>"
			href="<?php echo esc_url( Admin::page_url( 'sizes', array( 'model' => (int) $m['id'] ) ) ); ?>">
			<?php echo esc_html( $m['name'] ); ?>
		</a>
	<?php endforeach; ?>
</div>

<div class="td-grid">
	<div class="td-col-main">
		<h2><?php echo esc_html( sprintf( /* translators: %s: model name. */ __( 'Sizes of “%s”', 'tshirt-designer' ), (string) $model['name'] ) ); ?></h2>
		<table class="widefat striped td-table">
			<thead>
				<tr>
					<th><?php esc_html_e( 'Name', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Price modifier', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
				</tr>
			</thead>
			<tbody>
				<?php if ( array() === $sizes ) : ?>
					<tr><td colspan="4"><?php esc_html_e( 'No sizes yet.', 'tshirt-designer' ); ?></td></tr>
				<?php endif; ?>
				<?php foreach ( $sizes as $size ) : ?>
					<tr>
						<td><strong><a href="<?php echo esc_url( Admin::page_url( 'sizes', array( 'model' => $mid, 'edit' => (int) $size['id'] ) ) ); ?>"><?php echo esc_html( $size['name'] ); ?></a></strong></td>
						<td><?php echo esc_html( $this->plugin->settings->format_price( (float) $size['price_modifier'] ) ); ?></td>
						<td><?php echo $size['is_active'] ? '<span class="td-badge td-badge--on">' . esc_html__( 'Active', 'tshirt-designer' ) . '</span>' : '<span class="td-badge">' . esc_html__( 'Inactive', 'tshirt-designer' ) . '</span>'; ?></td>
						<td>
							<form method="post" action="<?php echo esc_url( Admin::action_url( 'sizes' ) ); ?>" class="td-inline-form">
								<?php wp_nonce_field( 'td_admin_sizes' ); ?>
								<input type="hidden" name="page_key" value="sizes" />
								<input type="hidden" name="do" value="delete" />
								<input type="hidden" name="model_id" value="<?php echo esc_attr( (string) $mid ); ?>" />
								<input type="hidden" name="id" value="<?php echo esc_attr( (string) $size['id'] ); ?>" />
								<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
							</form>
						</td>
					</tr>
				<?php endforeach; ?>
			</tbody>
		</table>
		<p class="description"><?php esc_html_e( 'Size affects order details and adds its price modifier to the base price.', 'tshirt-designer' ); ?></p>
	</div>

	<div class="td-col-side">
		<h2><?php echo null === $edit ? esc_html__( 'Add size', 'tshirt-designer' ) : esc_html__( 'Edit size', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( Admin::action_url( 'sizes' ) ); ?>" class="td-form">
			<?php wp_nonce_field( 'td_admin_sizes' ); ?>
			<input type="hidden" name="page_key" value="sizes" />
			<input type="hidden" name="do" value="save" />
			<input type="hidden" name="id" value="<?php echo esc_attr( (string) ( $edit['id'] ?? 0 ) ); ?>" />
			<input type="hidden" name="model_id" value="<?php echo esc_attr( (string) $mid ); ?>" />

			<p>
				<label><?php esc_html_e( 'Name (e.g. S, M, L, XL)', 'tshirt-designer' ); ?> *</label>
				<input type="text" name="name" required value="<?php echo esc_attr( $edit['name'] ?? '' ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Price modifier', 'tshirt-designer' ); ?></label>
				<input type="number" step="0.01" name="price_modifier" value="<?php echo esc_attr( (string) ( $edit['price_modifier'] ?? 0 ) ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Sort order', 'tshirt-designer' ); ?></label>
				<input type="number" name="sort_order" value="<?php echo esc_attr( (string) ( $edit['sort_order'] ?? count( $sizes ) ) ); ?>" class="widefat" />
			</p>
			<p>
				<label>
					<input type="checkbox" name="is_active" value="1" <?php checked( (int) ( $edit['is_active'] ?? 1 ), 1 ); ?> />
					<?php esc_html_e( 'Active', 'tshirt-designer' ); ?>
				</label>
			</p>
			<p>
				<button class="button button-primary"><?php echo null === $edit ? esc_html__( 'Add size', 'tshirt-designer' ) : esc_html__( 'Save changes', 'tshirt-designer' ); ?></button>
				<?php if ( null !== $edit ) : ?>
					<a class="button" href="<?php echo esc_url( Admin::page_url( 'sizes', array( 'model' => $mid ) ) ); ?>"><?php esc_html_e( 'Cancel', 'tshirt-designer' ); ?></a>
				<?php endif; ?>
			</p>
		</form>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
