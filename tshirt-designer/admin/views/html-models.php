<?php
/**
 * Admin view: Models list + editor.
 *
 * @var array<int, array<string, mixed>> $models
 * @var array<string, array<int,int>>    $counts
 * @var array<string, mixed>|null        $edit
 * @var int                              $next_sort
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;
use TShirtDesigner\Admin\Admin_Models;

defined( 'ABSPATH' ) || exit;

$title = __( 'Models', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<div class="td-grid">
	<div class="td-col-main">
		<h2><?php esc_html_e( 'T-shirt models', 'tshirt-designer' ); ?></h2>
		<table class="widefat striped td-table">
			<thead>
				<tr>
					<th style="width:70px"><?php esc_html_e( 'Preview', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Name', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Colors', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Sizes', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Print areas', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Base price', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
				</tr>
			</thead>
			<tbody>
				<?php if ( array() === $models ) : ?>
					<tr><td colspan="8"><?php esc_html_e( 'No models yet — create your first one.', 'tshirt-designer' ); ?></td></tr>
				<?php endif; ?>
				<?php foreach ( $models as $model ) : ?>
					<?php
					$mid = (int) $model['id'];
					$preview = $this->plugin->models->preview_url( $model );
					$price = $this->plugin->settings->format_price( (float) $model['base_price'] );
					?>
					<tr>
						<td>
							<?php if ( '' !== $preview ) : ?>
								<img src="<?php echo esc_url( $preview ); ?>" alt="" class="td-thumb" />
							<?php else : ?>
								<span class="td-thumb td-thumb--empty"></span>
							<?php endif; ?>
						</td>
						<td>
							<strong><a href="<?php echo esc_url( Admin::page_url( 'models', array( 'edit' => $mid ) ) ); ?>"><?php echo esc_html( $model['name'] ); ?></a></strong>
							<div class="td-muted"><?php echo esc_html( mb_strimwidth( (string) $model['description'], 0, 70, '…' ) ); ?></div>
						</td>
						<td>
							<a href="<?php echo esc_url( Admin::page_url( 'colors', array( 'model' => $mid ) ) ); ?>"><?php echo esc_html( (string) $counts[ $mid ]['colors'] ); ?></a>
						</td>
						<td>
							<a href="<?php echo esc_url( Admin::page_url( 'sizes', array( 'model' => $mid ) ) ); ?>"><?php echo esc_html( (string) $counts[ $mid ]['sizes'] ); ?></a>
						</td>
						<td>
							<a href="<?php echo esc_url( Admin::page_url( 'print-areas', array( 'model' => $mid ) ) ); ?>"><?php echo esc_html( (string) $counts[ $mid ]['areas'] ); ?></a>
						</td>
						<td><?php echo esc_html( $price ); ?></td>
						<td>
							<form method="post" action="<?php echo esc_url( Admin::action_url( 'models' ) ); ?>" class="td-inline-form">
								<?php wp_nonce_field( 'td_admin_models' ); ?>
								<input type="hidden" name="page_key" value="models" />
								<input type="hidden" name="do" value="toggle" />
								<input type="hidden" name="id" value="<?php echo esc_attr( (string) $mid ); ?>" />
								<button class="button button-small <?php echo $model['is_active'] ? '' : 'td-btn-off'; ?>">
									<?php echo $model['is_active'] ? esc_html__( 'Active', 'tshirt-designer' ) : esc_html__( 'Inactive', 'tshirt-designer' ); ?>
								</button>
							</form>
						</td>
						<td>
							<form method="post" action="<?php echo esc_url( Admin::action_url( 'models' ) ); ?>" class="td-inline-form"
								onsubmit="return confirm('<?php echo esc_js( __( 'Delete this model with its colors, sizes and print areas?', 'tshirt-designer' ) ); ?>');">
								<?php wp_nonce_field( 'td_admin_models' ); ?>
								<input type="hidden" name="page_key" value="models" />
								<input type="hidden" name="do" value="delete" />
								<input type="hidden" name="id" value="<?php echo esc_attr( (string) $mid ); ?>" />
								<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
							</form>
						</td>
					</tr>
				<?php endforeach; ?>
			</tbody>
		</table>
	</div>

	<div class="td-col-side">
		<h2><?php echo null === $edit ? esc_html__( 'Add model', 'tshirt-designer' ) : esc_html__( 'Edit model', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( Admin::action_url( 'models' ) ); ?>" class="td-form">
			<?php wp_nonce_field( 'td_admin_models' ); ?>
			<input type="hidden" name="page_key" value="models" />
			<input type="hidden" name="do" value="save" />
			<input type="hidden" name="id" value="<?php echo esc_attr( (string) ( $edit['id'] ?? 0 ) ); ?>" />

			<p>
				<label><?php esc_html_e( 'Name', 'tshirt-designer' ); ?> *</label>
				<input type="text" name="name" required value="<?php echo esc_attr( $edit['name'] ?? '' ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Description', 'tshirt-designer' ); ?></label>
				<textarea name="description" rows="3" class="widefat"><?php echo esc_textarea( $edit['description'] ?? '' ); ?></textarea>
			</p>

			<?php
			$model_id_field = (int) ( $edit['model_file_id'] ?? 0 );
			$preview_id_field = (int) ( $edit['preview_image_id'] ?? 0 );
			?>
			<div class="td-media-field" data-title-key="chooseModel" data-button-key="use">
				<label><?php esc_html_e( '3D model (GLB / GLTF)', 'tshirt-designer' ); ?> *</label>
				<input type="hidden" name="model_file_id" value="<?php echo esc_attr( (string) $model_id_field ); ?>" />
				<div class="td-media-field__preview"></div>
				<button type="button" class="button td-media-pick"><?php esc_html_e( 'Choose from media library', 'tshirt-designer' ); ?></button>
				<button type="button" class="button-link td-media-clear td-hidden"><?php esc_html_e( 'Remove', 'tshirt-designer' ); ?></button>
				<p class="description"><?php esc_html_e( 'The bundled Classic T-Shirt model works out of the box. Custom models should use a "TD_Fabric" material and the atlas UV layout described in the plugin docs.', 'tshirt-designer' ); ?></p>
			</div>

			<div class="td-media-field" data-title-key="chooseImage" data-button-key="use">
				<label><?php esc_html_e( 'Preview image', 'tshirt-designer' ); ?></label>
				<input type="hidden" name="preview_image_id" value="<?php echo esc_attr( (string) $preview_id_field ); ?>" />
				<div class="td-media-field__preview"></div>
				<button type="button" class="button td-media-pick"><?php esc_html_e( 'Choose from media library', 'tshirt-designer' ); ?></button>
				<button type="button" class="button-link td-media-clear td-hidden"><?php esc_html_e( 'Remove', 'tshirt-designer' ); ?></button>
			</div>

			<p>
				<label><?php esc_html_e( 'Linked WooCommerce product (optional)', 'tshirt-designer' ); ?></label>
				<input type="number" min="0" name="wc_product_id" value="<?php echo esc_attr( (string) ( $edit['wc_product_id'] ?? 0 ) ); ?>" class="widefat" />
				<span class="description"><?php esc_html_e( 'When set, the product price is used as the base price.', 'tshirt-designer' ); ?></span>
			</p>
			<p>
				<label><?php esc_html_e( 'Base price', 'tshirt-designer' ); ?></label>
				<input type="number" step="0.01" min="0" name="base_price" value="<?php echo esc_attr( (string) ( $edit['base_price'] ?? '' ) ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Sort order', 'tshirt-designer' ); ?></label>
				<input type="number" name="sort_order" value="<?php echo esc_attr( (string) ( $edit['sort_order'] ?? $next_sort ) ); ?>" class="widefat" />
			</p>
			<p>
				<label>
					<input type="checkbox" name="is_active" value="1" <?php checked( (int) ( $edit['is_active'] ?? 1 ), 1 ); ?> />
					<?php esc_html_e( 'Active', 'tshirt-designer' ); ?>
				</label>
			</p>
			<p>
				<button class="button button-primary"><?php echo null === $edit ? esc_html__( 'Create model', 'tshirt-designer' ) : esc_html__( 'Save changes', 'tshirt-designer' ); ?></button>
				<?php if ( null !== $edit ) : ?>
					<a class="button" href="<?php echo esc_url( Admin::page_url( 'models' ) ); ?>"><?php esc_html_e( 'Cancel', 'tshirt-designer' ); ?></a>
				<?php endif; ?>
			</p>
		</form>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
