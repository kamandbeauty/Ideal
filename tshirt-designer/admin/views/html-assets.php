<?php
/**
 * Admin view: Design Assets.
 *
 * @var array<int, array<string,mixed>> $assets
 * @var array<string,mixed>|null        $edit
 * @var string                          $cat
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;
use TShirtDesigner\Asset_Manager;

defined( 'ABSPATH' ) || exit;

$title = __( 'Design Assets', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<div class="td-grid">
	<div class="td-col-main td-col-main--wide">
		<h2><?php esc_html_e( 'Artwork library', 'tshirt-designer' ); ?></h2>

		<div class="td-tablenav">
			<a class="td-chip<?php echo '' === $cat ? ' is-active' : ''; ?>" href="<?php echo esc_url( Admin::page_url( 'assets' ) ); ?>"><?php esc_html_e( 'All', 'tshirt-designer' ); ?></a>
			<?php foreach ( Asset_Manager::CATEGORIES as $key => $label ) : ?>
				<a class="td-chip<?php echo $key === $cat ? ' is-active' : ''; ?>" href="<?php echo esc_url( Admin::page_url( 'assets', array( 'category' => $key ) ) ); ?>"><?php echo esc_html( $label ); ?></a>
			<?php endforeach; ?>
		</div>

		<div class="td-asset-grid">
			<?php if ( array() === $assets ) : ?>
				<p><?php esc_html_e( 'No assets in this category.', 'tshirt-designer' ); ?></p>
			<?php endif; ?>
			<?php foreach ( $assets as $asset ) : ?>
				<div class="td-asset-card">
					<div class="td-asset-card__thumb" style="background-image:url('<?php echo esc_url( $this->plugin->assets->file_url( $asset ) ); ?>')"></div>
					<div class="td-asset-card__meta">
						<strong><?php echo esc_html( $asset['name'] ); ?></strong>
						<span class="td-muted"><?php echo esc_html( $asset['category'] ); ?></span>
					</div>
					<div class="td-asset-card__actions">
						<a class="button button-small" href="<?php echo esc_url( Admin::page_url( 'assets', array( 'edit' => (int) $asset['id'], 'category' => $cat ) ) ); ?>"><?php esc_html_e( 'Edit', 'tshirt-designer' ); ?></a>
						<form method="post" action="<?php echo esc_url( Admin::action_url( 'assets' ) ); ?>" class="td-inline-form">
							<?php wp_nonce_field( 'td_admin_assets' ); ?>
							<input type="hidden" name="page_key" value="assets" />
							<input type="hidden" name="do" value="toggle" />
							<input type="hidden" name="id" value="<?php echo esc_attr( (string) $asset['id'] ); ?>" />
							<button class="button button-small <?php echo $asset['is_active'] ? '' : 'td-btn-off'; ?>"><?php echo $asset['is_active'] ? esc_html__( 'On', 'tshirt-designer' ) : esc_html__( 'Off', 'tshirt-designer' ); ?></button>
						</form>
						<form method="post" action="<?php echo esc_url( Admin::action_url( 'assets' ) ); ?>" class="td-inline-form">
							<?php wp_nonce_field( 'td_admin_assets' ); ?>
							<input type="hidden" name="page_key" value="assets" />
							<input type="hidden" name="do" value="delete" />
							<input type="hidden" name="id" value="<?php echo esc_attr( (string) $asset['id'] ); ?>" />
							<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
						</form>
					</div>
				</div>
			<?php endforeach; ?>
		</div>
	</div>

	<div class="td-col-side">
		<h2><?php echo null === $edit ? esc_html__( 'Add asset', 'tshirt-designer' ) : esc_html__( 'Edit asset', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( Admin::action_url( 'assets' ) ); ?>" class="td-form">
			<?php wp_nonce_field( 'td_admin_assets' ); ?>
			<input type="hidden" name="page_key" value="assets" />
			<input type="hidden" name="do" value="save" />
			<input type="hidden" name="id" value="<?php echo esc_attr( (string) ( $edit['id'] ?? 0 ) ); ?>" />

			<?php $file_field = (int) ( $edit['file_id'] ?? 0 ); ?>
			<div class="td-media-field td-media-field--image" data-title-key="chooseImage" data-button-key="use">
				<label><?php esc_html_e( 'Image file (PNG recommended)', 'tshirt-designer' ); ?> *</label>
				<input type="hidden" name="file_id" value="<?php echo esc_attr( (string) $file_field ); ?>" />
				<div class="td-media-field__preview"></div>
				<button type="button" class="button td-media-pick"><?php esc_html_e( 'Choose from media library', 'tshirt-designer' ); ?></button>
				<button type="button" class="button-link td-media-clear td-hidden"><?php esc_html_e( 'Remove', 'tshirt-designer' ); ?></button>
			</div>

			<p>
				<label><?php esc_html_e( 'Name', 'tshirt-designer' ); ?> *</label>
				<input type="text" name="name" required value="<?php echo esc_attr( $edit['name'] ?? '' ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Category', 'tshirt-designer' ); ?></label>
				<select name="category" class="widefat">
					<?php
					$current_cat = (string) ( $edit['category'] ?? ( '' !== $cat ? $cat : 'other' ) );
					foreach ( Asset_Manager::CATEGORIES as $key => $label ) :
						?>
						<option value="<?php echo esc_attr( $key ); ?>" <?php selected( $current_cat, $key ); ?>><?php echo esc_html( $label ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
			<p>
				<label><?php esc_html_e( 'Sort order', 'tshirt-designer' ); ?></label>
				<input type="number" name="sort_order" value="<?php echo esc_attr( (string) ( $edit['sort_order'] ?? 0 ) ); ?>" class="widefat" />
			</p>
			<p>
				<button class="button button-primary"><?php echo null === $edit ? esc_html__( 'Add asset', 'tshirt-designer' ) : esc_html__( 'Save changes', 'tshirt-designer' ); ?></button>
				<?php if ( null !== $edit ) : ?>
					<a class="button" href="<?php echo esc_url( Admin::page_url( 'assets', array( 'category' => $cat ) ) ); ?>"><?php esc_html_e( 'Cancel', 'tshirt-designer' ); ?></a>
				<?php endif; ?>
			</p>
		</form>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
