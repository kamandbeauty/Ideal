<?php
/**
 * Admin view: Colors.
 *
 * @var int                       $mid
 * @var array<string,mixed>|null  $model
 * @var array<int, array<string,mixed>> $colors
 * @var array<int, array<string,mixed>> $models
 * @var array<string,mixed>|null  $edit
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;

defined( 'ABSPATH' ) || exit;

$title = __( 'Colors', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<?php if ( null === $model ) : ?>
	<p><?php esc_html_e( 'Create a model first.', 'tshirt-designer' ); ?></p>
	<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; return; endif; ?>

<div class="td-model-switcher">
	<strong><?php esc_html_e( 'Model:', 'tshirt-designer' ); ?></strong>
	<?php foreach ( $models as $m ) : ?>
		<a class="td-chip<?php echo (int) $m['id'] === $mid ? ' is-active' : ''; ?>"
			href="<?php echo esc_url( Admin::page_url( 'colors', array( 'model' => (int) $m['id'] ) ) ); ?>">
			<?php echo esc_html( $m['name'] ); ?>
		</a>
	<?php endforeach; ?>
</div>

<div class="td-grid">
	<div class="td-col-main">
		<h2><?php echo esc_html( sprintf( /* translators: %s: model name. */ __( 'Colors of “%s”', 'tshirt-designer' ), (string) $model['name'] ) ); ?></h2>
		<table class="widefat striped td-table">
			<thead>
				<tr>
					<th style="width:60px"></th>
					<th><?php esc_html_e( 'Name', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'HEX', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Fabric texture', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
				</tr>
			</thead>
			<tbody>
				<?php if ( array() === $colors ) : ?>
					<tr><td colspan="6"><?php esc_html_e( 'No colors yet.', 'tshirt-designer' ); ?></td></tr>
				<?php endif; ?>
				<?php foreach ( $colors as $color ) : ?>
					<tr>
						<td><span class="td-swatch" style="background:<?php echo esc_attr( $color['hex'] ); ?>"></span></td>
						<td><strong><a href="<?php echo esc_url( Admin::page_url( 'colors', array( 'model' => $mid, 'edit' => (int) $color['id'] ) ) ); ?>"><?php echo esc_html( $color['name'] ); ?></a></strong></td>
						<td><code><?php echo esc_html( $color['hex'] ); ?></code></td>
						<td><?php echo (int) $color['texture_image_id'] > 0 ? esc_html__( 'Custom texture', 'tshirt-designer' ) : esc_html__( '—', 'tshirt-designer' ); ?></td>
						<td><?php echo $color['is_active'] ? '<span class="td-badge td-badge--on">' . esc_html__( 'Active', 'tshirt-designer' ) . '</span>' : '<span class="td-badge">' . esc_html__( 'Inactive', 'tshirt-designer' ) . '</span>'; ?></td>
						<td>
							<form method="post" action="<?php echo esc_url( Admin::action_url( 'colors' ) ); ?>" class="td-inline-form">
								<?php wp_nonce_field( 'td_admin_colors' ); ?>
								<input type="hidden" name="page_key" value="colors" />
								<input type="hidden" name="do" value="delete" />
								<input type="hidden" name="model_id" value="<?php echo esc_attr( (string) $mid ); ?>" />
								<input type="hidden" name="id" value="<?php echo esc_attr( (string) $color['id'] ); ?>" />
								<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
							</form>
						</td>
					</tr>
				<?php endforeach; ?>
			</tbody>
		</table>
	</div>

	<div class="td-col-side">
		<h2><?php echo null === $edit ? esc_html__( 'Add color', 'tshirt-designer' ) : esc_html__( 'Edit color', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( Admin::action_url( 'colors' ) ); ?>" class="td-form">
			<?php wp_nonce_field( 'td_admin_colors' ); ?>
			<input type="hidden" name="page_key" value="colors" />
			<input type="hidden" name="do" value="save" />
			<input type="hidden" name="id" value="<?php echo esc_attr( (string) ( $edit['id'] ?? 0 ) ); ?>" />
			<input type="hidden" name="model_id" value="<?php echo esc_attr( (string) $mid ); ?>" />

			<p>
				<label><?php esc_html_e( 'Name', 'tshirt-designer' ); ?> *</label>
				<input type="text" name="name" required value="<?php echo esc_attr( $edit['name'] ?? '' ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'HEX color', 'tshirt-designer' ); ?> *</label>
				<input type="color" name="hex" value="<?php echo esc_attr( $edit['hex'] ?? '#FFFFFF' ); ?>" class="td-color-input" />
				<span class="description"><?php esc_html_e( 'Applied to the 3D model instantly, without reloading the page.', 'tshirt-designer' ); ?></span>
			</p>

			<?php $texture_field = (int) ( $edit['texture_image_id'] ?? 0 ); ?>
			<div class="td-media-field" data-title-key="chooseImage" data-button-key="use">
				<label><?php esc_html_e( 'Fabric texture (optional)', 'tshirt-designer' ); ?></label>
				<input type="hidden" name="texture_image_id" value="<?php echo esc_attr( (string) $texture_field ); ?>" />
				<div class="td-media-field__preview"></div>
				<button type="button" class="button td-media-pick"><?php esc_html_e( 'Choose from media library', 'tshirt-designer' ); ?></button>
				<button type="button" class="button-link td-media-clear td-hidden"><?php esc_html_e( 'Remove', 'tshirt-designer' ); ?></button>
			</div>

			<p>
				<label><?php esc_html_e( 'Sort order', 'tshirt-designer' ); ?></label>
				<input type="number" name="sort_order" value="<?php echo esc_attr( (string) ( $edit['sort_order'] ?? count( $colors ) ) ); ?>" class="widefat" />
			</p>
			<p>
				<label>
					<input type="checkbox" name="is_active" value="1" <?php checked( (int) ( $edit['is_active'] ?? 1 ), 1 ); ?> />
					<?php esc_html_e( 'Active', 'tshirt-designer' ); ?>
				</label>
			</p>
			<p>
				<button class="button button-primary"><?php echo null === $edit ? esc_html__( 'Add color', 'tshirt-designer' ) : esc_html__( 'Save changes', 'tshirt-designer' ); ?></button>
				<?php if ( null !== $edit ) : ?>
					<a class="button" href="<?php echo esc_url( Admin::page_url( 'colors', array( 'model' => $mid ) ) ); ?>"><?php esc_html_e( 'Cancel', 'tshirt-designer' ); ?></a>
				<?php endif; ?>
			</p>
		</form>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
