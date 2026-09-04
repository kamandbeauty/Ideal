<?php
/**
 * Admin view: Print Areas.
 *
 * @var int                       $mid
 * @var array<string,mixed>|null  $model
 * @var array<int, array<string,mixed>> $areas
 * @var array<int, array<string,mixed>> $models
 * @var array<string,mixed>|null  $edit
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Print_Area_Manager;

defined( 'ABSPATH' ) || exit;

$title = __( 'Print Areas', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<?php if ( null === $model ) : ?>
	<p><?php esc_html_e( 'Create a model first.', 'tshirt-designer' ); ?></p>
	<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; return; endif; ?>

<div class="td-model-switcher">
	<strong><?php esc_html_e( 'Model:', 'tshirt-designer' ); ?></strong>
	<?php foreach ( $models as $m ) : ?>
		<a class="td-chip<?php echo (int) $m['id'] === $mid ? ' is-active' : ''; ?>"
			href="<?php echo esc_url( \TShirtDesigner\Admin\Admin::page_url( 'print-areas', array( 'model' => (int) $m['id'] ) ) ); ?>">
			<?php echo esc_html( $m['name'] ); ?>
		</a>
	<?php endforeach; ?>
</div>

<div class="td-grid">
	<div class="td-col-main">
		<h2><?php echo esc_html( sprintf( /* translators: %s: model name. */ __( 'Print areas of “%s”', 'tshirt-designer' ), (string) $model['name'] ) ); ?></h2>
		<table class="widefat striped td-table">
			<thead>
				<tr>
					<th><?php esc_html_e( 'Name', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Type', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Max size', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'UV mapping', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Status', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
				</tr>
			</thead>
			<tbody>
				<?php if ( array() === $areas ) : ?>
					<tr><td colspan="6"><?php esc_html_e( 'No print areas yet.', 'tshirt-designer' ); ?></td></tr>
				<?php endif; ?>
				<?php foreach ( $areas as $area ) : ?>
					<?php $pos = $this->plugin->print_areas->position( $area ); ?>
					<tr>
						<td><strong><a href="<?php echo esc_url( \TShirtDesigner\Admin\Admin::page_url( 'print-areas', array( 'model' => $mid, 'edit' => (int) $area['id'] ) ) ); ?>"><?php echo esc_html( $area['name'] ); ?></a></strong></td>
						<td><?php echo esc_html( $area['area_type'] ); ?></td>
						<td><?php echo esc_html( number_format( (float) $area['max_width_cm'], 0 ) . ' × ' . number_format( (float) $area['max_height_cm'], 0 ) . ' cm' ); ?></td>
						<td><?php echo is_array( $pos['uv_rect'] ) ? '<span class="td-badge td-badge--on">' . esc_html__( 'Mapped', 'tshirt-designer' ) . '</span>' : '<span class="td-badge">' . esc_html__( 'None', 'tshirt-designer' ) . '</span>'; ?></td>
						<td><?php echo $area['is_active'] ? '<span class="td-badge td-badge--on">' . esc_html__( 'Active', 'tshirt-designer' ) . '</span>' : '<span class="td-badge">' . esc_html__( 'Inactive', 'tshirt-designer' ) . '</span>'; ?></td>
						<td>
							<form method="post" action="<?php echo esc_url( \TShirtDesigner\Admin\Admin::action_url( 'print-areas' ) ); ?>" class="td-inline-form">
								<?php wp_nonce_field( 'td_admin_print-areas' ); ?>
								<input type="hidden" name="page_key" value="print-areas" />
								<input type="hidden" name="do" value="delete" />
								<input type="hidden" name="model_id" value="<?php echo esc_attr( (string) $mid ); ?>" />
								<input type="hidden" name="id" value="<?php echo esc_attr( (string) $area['id'] ); ?>" />
								<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
							</form>
						</td>
					</tr>
				<?php endforeach; ?>
			</tbody>
		</table>
		<p class="description">
			<?php esc_html_e( 'Each print area maps a rectangular UV region of the 3D model. Artwork is painted into that region and follows the fabric when the model rotates.', 'tshirt-designer' ); ?>
		</p>
	</div>

	<div class="td-col-side">
		<h2><?php echo null === $edit ? esc_html__( 'Add print area', 'tshirt-designer' ) : esc_html__( 'Edit print area', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( \TShirtDesigner\Admin\Admin::action_url( 'print-areas' ) ); ?>" class="td-form">
			<?php wp_nonce_field( 'td_admin_print-areas' ); ?>
			<input type="hidden" name="page_key" value="print-areas" />
			<input type="hidden" name="do" value="save" />
			<input type="hidden" name="id" value="<?php echo esc_attr( (string) ( $edit['id'] ?? 0 ) ); ?>" />
			<input type="hidden" name="model_id" value="<?php echo esc_attr( (string) $mid ); ?>" />

			<?php
			$edit_position = '';
			if ( null !== $edit ) {
				$decoded = json_decode( (string) $edit['position'], true );
				if ( is_array( $decoded ) ) {
					$edit_position = wp_json_encode( $decoded, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT );
				}
			}
			?>

			<p>
				<label><?php esc_html_e( 'Name', 'tshirt-designer' ); ?> *</label>
				<input type="text" name="name" required value="<?php echo esc_attr( $edit['name'] ?? '' ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Type', 'tshirt-designer' ); ?></label>
				<select name="area_type" class="widefat">
					<?php
					$current_type = (string) ( $edit['area_type'] ?? 'front' );
					foreach ( Print_Area_Manager::AREA_TYPES as $type ) :
						?>
						<option value="<?php echo esc_attr( $type ); ?>" <?php selected( $current_type, $type ); ?>><?php echo esc_html( $type ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
			<p>
				<label><?php esc_html_e( 'Maximum width (cm)', 'tshirt-designer' ); ?> *</label>
				<input type="number" step="0.1" min="1" name="max_width_cm" required value="<?php echo esc_attr( (string) ( $edit['max_width_cm'] ?? 30 ) ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Maximum height (cm)', 'tshirt-designer' ); ?> *</label>
				<input type="number" step="0.1" min="1" name="max_height_cm" required value="<?php echo esc_attr( (string) ( $edit['max_height_cm'] ?? 35 ) ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Position / UV mapping (JSON)', 'tshirt-designer' ); ?></label>
				<textarea name="position" rows="8" class="widefat td-code"><?php echo esc_textarea( $edit_position ); ?></textarea>
				<span class="description">
					<?php echo esc_html( __( 'Format: {"uv_rect":[u0,v0,u1,v1], "camera":{"azimuth":0,"polar":78,"distance":1.55}} — uv_rect is the atlas region for this area (0-1 range), camera is the preset used when the area is selected.', 'tshirt-designer' ) ); ?>
				</span>
			</p>
			<p>
				<label><?php esc_html_e( 'Sort order', 'tshirt-designer' ); ?></label>
				<input type="number" name="sort_order" value="<?php echo esc_attr( (string) ( $edit['sort_order'] ?? count( $areas ) ) ); ?>" class="widefat" />
			</p>
			<p>
				<label>
					<input type="checkbox" name="is_active" value="1" <?php checked( (int) ( $edit['is_active'] ?? 1 ), 1 ); ?> />
					<?php esc_html_e( 'Active', 'tshirt-designer' ); ?>
				</label>
			</p>
			<p>
				<button class="button button-primary"><?php echo null === $edit ? esc_html__( 'Create area', 'tshirt-designer' ) : esc_html__( 'Save changes', 'tshirt-designer' ); ?></button>
				<?php if ( null !== $edit ) : ?>
					<a class="button" href="<?php echo esc_url( \TShirtDesigner\Admin\Admin::page_url( 'print-areas', array( 'model' => $mid ) ) ); ?>"><?php esc_html_e( 'Cancel', 'tshirt-designer' ); ?></a>
				<?php endif; ?>
			</p>
		</form>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
