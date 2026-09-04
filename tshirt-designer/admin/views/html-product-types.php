<?php
/**
 * View: Product Types.
 *
 * @package TShirtDesigner
 *
 * @var array<string, array<string, mixed>> $summary     Per-type summary.
 * @var int                                 $default_dpi Global print DPI.
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;
use TShirtDesigner\Product_Type_Registry;

defined( 'ABSPATH' ) || exit;

$title = __( 'Product Types', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<p class="description td-intro">
	<?php
	esc_html_e(
		'Each product type owns its own models, colors, sizes, print areas, pricing rules and production settings. New printable products are registered in code through the "cpd_product_types" filter, so adding one never requires changing the designer core.',
		'tshirt-designer'
	);
	?>
</p>

<table class="widefat striped td-table">
	<thead>
		<tr>
			<th><?php esc_html_e( 'Product type', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Print areas supported', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Has sizes', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Models', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Colors', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Sizes', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Print areas', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Designs', 'tshirt-designer' ); ?></th>
			<th><?php esc_html_e( 'Print DPI', 'tshirt-designer' ); ?></th>
		</tr>
	</thead>
	<tbody>
	<?php foreach ( $summary as $td_slug => $td_row ) : ?>
		<?php $td_def = $td_row['definition']; ?>
		<tr>
			<td>
				<strong><?php echo esc_html( (string) $td_def['label'] ); ?></strong><br>
				<code><?php echo esc_html( (string) $td_slug ); ?></code>
			</td>
			<td>
				<?php
				$td_areas = array();
				foreach ( Product_Type_Registry::area_types( (string) $td_slug ) as $td_area_type ) {
					$td_areas[] = Product_Type_Registry::area_label( (string) $td_slug, $td_area_type );
				}
				echo esc_html( implode( ', ', $td_areas ) );
				?>
			</td>
			<td>
				<?php echo ! empty( $td_def['has_sizes'] ) ? esc_html__( 'Yes', 'tshirt-designer' ) : esc_html__( 'No', 'tshirt-designer' ); ?>
			</td>
			<td>
				<?php echo esc_html( (string) count( (array) $td_row['models'] ) ); ?>
				<?php if ( array() !== (array) $td_row['models'] ) : ?>
					<br>
					<span class="description">
						<?php
						$td_names = array_map(
							static fn( array $m ): string => (string) $m['name'],
							(array) $td_row['models']
						);
						echo esc_html( implode( ', ', $td_names ) );
						?>
					</span>
				<?php endif; ?>
			</td>
			<td><?php echo esc_html( (string) (int) $td_row['colors'] ); ?></td>
			<td><?php echo esc_html( (string) (int) $td_row['sizes'] ); ?></td>
			<td><?php echo esc_html( (string) (int) $td_row['print_areas'] ); ?></td>
			<td><?php echo esc_html( (string) (int) $td_row['designs'] ); ?></td>
			<td><?php echo esc_html( (string) (int) $td_row['dpi'] ); ?></td>
		</tr>
	<?php endforeach; ?>
	</tbody>
</table>

<h2><?php esc_html_e( 'Print resolution', 'tshirt-designer' ); ?></h2>
<p class="description">
	<?php
	esc_html_e(
		'Production files are rendered at physical print size × DPI. Leave a product type empty to use the global default.',
		'tshirt-designer'
	);
	?>
</p>

<form method="post" action="<?php echo esc_url( Admin::action_url( 'product-types' ) ); ?>" class="td-form">
	<?php wp_nonce_field( 'td_admin_product-types' ); ?>
	<input type="hidden" name="page_key" value="product-types">
	<input type="hidden" name="do" value="save_dpi">

	<table class="form-table" role="presentation">
		<tbody>
			<tr>
				<th scope="row">
					<label for="td-print-dpi"><?php esc_html_e( 'Default DPI', 'tshirt-designer' ); ?></label>
				</th>
				<td>
					<input type="number" id="td-print-dpi" name="print_dpi" min="72" max="1200" step="1"
						value="<?php echo esc_attr( (string) $default_dpi ); ?>" class="small-text">
					<p class="description"><?php esc_html_e( '300 DPI is the usual choice for garment printing.', 'tshirt-designer' ); ?></p>
				</td>
			</tr>
			<?php foreach ( $summary as $td_slug => $td_row ) : ?>
				<tr>
					<th scope="row">
						<label for="td-dpi-<?php echo esc_attr( (string) $td_slug ); ?>">
							<?php
							printf(
								/* translators: %s: product type label. */
								esc_html__( '%s DPI', 'tshirt-designer' ),
								esc_html( (string) $td_row['definition']['label'] )
							);
							?>
						</label>
					</th>
					<td>
						<input type="number"
							id="td-dpi-<?php echo esc_attr( (string) $td_slug ); ?>"
							name="dpi[<?php echo esc_attr( (string) $td_slug ); ?>]"
							min="72" max="1200" step="1" class="small-text"
							placeholder="<?php echo esc_attr( (string) $default_dpi ); ?>"
							value="<?php echo esc_attr( $td_row['dpi_custom'] > 0 ? (string) $td_row['dpi_custom'] : '' ); ?>">
						<?php
						$td_example_w = 30.0;
						$td_example_h = 35.0;
						[ $td_px_w, $td_px_h ] = TShirtDesigner\Production_Renderer::pixel_size(
							$td_example_w,
							$td_example_h,
							(int) $td_row['dpi']
						);
						?>
						<p class="description">
							<?php
							echo esc_html(
								sprintf(
									/* translators: 1: width cm, 2: height cm, 3: width px, 4: height px. */
									__( 'A %1$s × %2$s cm print becomes %3$d × %4$d px at this resolution.', 'tshirt-designer' ),
									(string) $td_example_w,
									(string) $td_example_h,
									$td_px_w,
									$td_px_h
								)
							);
							?>
						</p>
					</td>
				</tr>
			<?php endforeach; ?>
		</tbody>
	</table>

	<p class="submit">
		<button type="submit" class="button button-primary"><?php esc_html_e( 'Save changes', 'tshirt-designer' ); ?></button>
	</p>
</form>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
