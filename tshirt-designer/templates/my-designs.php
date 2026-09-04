<?php
/**
 * My Account -> My Designs.
 *
 * @var array<int, array<string, mixed>> $designs      Customer designs.
 * @var string                           $notice       Notice key.
 * @var string                           $designer_url Designer page URL.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

defined( 'ABSPATH' ) || exit;

use TShirtDesigner\My_Designs;
use TShirtDesigner\Plugin;

$td_plugin = Plugin::instance();
?>

<?php if ( 'duplicated' === $notice ) : ?>
	<div class="woocommerce-message" role="alert">
		<?php esc_html_e( 'The design was duplicated.', 'tshirt-designer' ); ?>
	</div>
<?php elseif ( 'deleted' === $notice ) : ?>
	<div class="woocommerce-message" role="alert">
		<?php esc_html_e( 'The design was deleted.', 'tshirt-designer' ); ?>
	</div>
<?php elseif ( 'error' === $notice ) : ?>
	<div class="woocommerce-error" role="alert">
		<?php esc_html_e( 'That action could not be completed.', 'tshirt-designer' ); ?>
	</div>
<?php endif; ?>

<?php if ( array() === $designs ) : ?>
	<p><?php esc_html_e( 'You have not saved any designs yet.', 'tshirt-designer' ); ?></p>
	<?php if ( '' !== $designer_url ) : ?>
		<p>
			<a class="woocommerce-Button button" href="<?php echo esc_url( $designer_url ); ?>">
				<?php esc_html_e( 'Start designing', 'tshirt-designer' ); ?>
			</a>
		</p>
	<?php endif; ?>
	<?php return; ?>
<?php endif; ?>

<table class="woocommerce-orders-table shop_table td-my-designs">
	<thead>
		<tr>
			<th><?php esc_html_e( 'Preview', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Design', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Product', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Price', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Updated', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
		</tr>
	</thead>
	<tbody>
	<?php foreach ( $designs as $td_design ) : ?>
		<?php
		$td_id      = (int) $td_design['id'];
		$td_model   = $td_plugin->models->get( (int) $td_design['model_id'], true );
		$td_preview = (int) $td_design['preview_image_id'];
		$td_locked  = in_array(
			(string) $td_design['status'],
			\TShirtDesigner\Design_Manager::PROTECTED_STATUSES,
			true
		);
		$td_edit    = My_Designs::edit_url( $designer_url, $td_id );
		?>
		<tr>
			<td data-title="<?php esc_attr_e( 'Preview', 'tshirt-designer' ); ?>">
				<?php if ( $td_preview > 0 ) : ?>
					<?php echo wp_get_attachment_image( $td_preview, array( 80, 80 ), false, array( 'class' => 'td-my-designs__thumb' ) ); ?>
				<?php else : ?>
					<span class="td-my-designs__thumb td-my-designs__thumb--empty" aria-hidden="true"></span>
				<?php endif; ?>
			</td>
			<td data-title="<?php esc_attr_e( 'Design', 'tshirt-designer' ); ?>">
				<code><?php echo esc_html( (string) $td_design['uuid'] ); ?></code><br>
				<small>
					<?php
					printf(
						/* translators: %d: version number. */
						esc_html__( 'Version %d', 'tshirt-designer' ),
						(int) $td_design['version']
					);
					?>
				</small>
			</td>
			<td data-title="<?php esc_attr_e( 'Product', 'tshirt-designer' ); ?>">
				<?php echo esc_html( null === $td_model ? __( 'Unavailable', 'tshirt-designer' ) : (string) $td_model['name'] ); ?>
			</td>
			<td data-title="<?php esc_attr_e( 'Price', 'tshirt-designer' ); ?>">
				<?php echo esc_html( $td_plugin->settings->format_price( (float) $td_design['price_total'] ) ); ?>
			</td>
			<td data-title="<?php esc_attr_e( 'Updated', 'tshirt-designer' ); ?>">
				<?php echo esc_html( mysql2date( get_option( 'date_format' ), (string) $td_design['updated_at'] ) ); ?>
			</td>
			<td data-title="<?php esc_attr_e( 'Actions', 'tshirt-designer' ); ?>">
				<?php if ( '' !== $td_edit ) : ?>
					<a class="woocommerce-button button" href="<?php echo esc_url( $td_edit ); ?>">
						<?php echo $td_locked ? esc_html__( 'View', 'tshirt-designer' ) : esc_html__( 'Edit', 'tshirt-designer' ); ?>
					</a>
				<?php endif; ?>
				<a class="woocommerce-button button"
					href="<?php echo esc_url( My_Designs::action_url( 'duplicate', $td_id ) ); ?>">
					<?php esc_html_e( 'Duplicate', 'tshirt-designer' ); ?>
				</a>
				<?php if ( ! $td_locked ) : ?>
					<a class="woocommerce-button button"
						href="<?php echo esc_url( My_Designs::action_url( 'delete', $td_id ) ); ?>"
						onclick="return confirm('<?php echo esc_js( __( 'Delete this design?', 'tshirt-designer' ) ); ?>');">
						<?php esc_html_e( 'Delete', 'tshirt-designer' ); ?>
					</a>
				<?php endif; ?>
			</td>
		</tr>
	<?php endforeach; ?>
	</tbody>
</table>
