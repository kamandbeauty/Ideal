<?php
/**
 * Admin view: Settings.
 *
 * @var array<string, mixed> $settings
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;

defined( 'ABSPATH' ) || exit;

$title = __( 'Settings', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<div class="td-grid">
	<div class="td-col-main td-col-main--narrow">
		<h2><?php esc_html_e( 'General settings', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( Admin::action_url( 'settings' ) ); ?>" class="td-form">
			<?php wp_nonce_field( 'td_admin_settings' ); ?>
			<input type="hidden" name="page_key" value="settings" />
			<input type="hidden" name="do" value="save" />

			<h3><?php esc_html_e( 'Currency', 'tshirt-designer' ); ?></h3>
			<p>
				<label><?php esc_html_e( 'Currency symbol / label', 'tshirt-designer' ); ?></label>
				<input type="text" name="currency_symbol" value="<?php echo esc_attr( (string) $settings['currency']['symbol'] ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Symbol position', 'tshirt-designer' ); ?></label>
				<select name="currency_position" class="widefat">
					<option value="after" <?php selected( (string) $settings['currency']['position'], 'after' ); ?>><?php esc_html_e( 'After the amount (350,000 Toman)', 'tshirt-designer' ); ?></option>
					<option value="before" <?php selected( (string) $settings['currency']['position'], 'before' ); ?>><?php esc_html_e( 'Before the amount (Toman 350,000)', 'tshirt-designer' ); ?></option>
				</select>
			</p>
			<p>
				<label><?php esc_html_e( 'Decimals', 'tshirt-designer' ); ?></label>
				<input type="number" min="0" max="3" name="currency_decimals" value="<?php echo esc_attr( (string) $settings['currency']['decimals'] ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Thousands separator', 'tshirt-designer' ); ?></label>
				<input type="text" name="currency_thousand_sep" value="<?php echo esc_attr( (string) $settings['currency']['thousand_sep'] ); ?>" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Decimal separator', 'tshirt-designer' ); ?></label>
				<input type="text" name="currency_decimal_sep" value="<?php echo esc_attr( (string) $settings['currency']['decimal_sep'] ); ?>" class="widefat" />
			</p>

			<h3><?php esc_html_e( 'Uploads', 'tshirt-designer' ); ?></h3>
			<p>
				<label><?php esc_html_e( 'Maximum upload size (MB)', 'tshirt-designer' ); ?></label>
				<input type="number" step="0.5" min="0.5" max="32" name="upload_max_mb" value="<?php echo esc_attr( (string) $settings['upload_max_mb'] ); ?>" class="widefat" />
				<span class="description"><?php esc_html_e( 'Allowed formats: JPG, JPEG, PNG, WEBP. PNG/WEBP transparency is preserved. SVG is not allowed.', 'tshirt-designer' ); ?></span>
			</p>
			<p>
				<label><?php esc_html_e( 'Uploads per hour (per user/IP)', 'tshirt-designer' ); ?></label>
				<input type="number" min="1" max="500" name="uploads_per_hour" value="<?php echo esc_attr( (string) $settings['uploads_per_hour'] ); ?>" class="widefat" />
			</p>
			<p>
				<label>
					<input type="checkbox" name="allow_guest_uploads" value="1" <?php checked( (int) $settings['allow_guest_uploads'], 1 ); ?> />
					<?php esc_html_e( 'Allow guests to upload images', 'tshirt-designer' ); ?>
				</label>
			</p>
			<p>
				<label>
					<input type="checkbox" name="allow_guest_designs" value="1" <?php checked( (int) $settings['allow_guest_designs'], 1 ); ?> />
					<?php esc_html_e( 'Allow guests to save designs', 'tshirt-designer' ); ?>
				</label>
			</p>

			<h3><?php esc_html_e( 'Data', 'tshirt-designer' ); ?></h3>
			<p>
				<label>
					<input type="checkbox" name="delete_data_on_uninstall" value="1" <?php checked( (int) $settings['delete_data_on_uninstall'], 1 ); ?> />
					<?php esc_html_e( 'Delete all plugin data (tables, settings) when the plugin is uninstalled', 'tshirt-designer' ); ?>
				</label>
			</p>

			<p><button class="button button-primary"><?php esc_html_e( 'Save settings', 'tshirt-designer' ); ?></button></p>
		</form>

		<hr />
		<h2><?php esc_html_e( 'Usage', 'tshirt-designer' ); ?></h2>
		<p><?php esc_html_e( 'Place the shortcode below on any page:', 'tshirt-designer' ); ?></p>
		<pre class="td-code-block">[tshirt_designer]</pre>
		<p class="description"><?php esc_html_e( 'Optional attributes: model="classic-tshirt" or model="3" preselects a model. A “T-Shirt Designer” block is also available in the block editor.', 'tshirt-designer' ); ?></p>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
