<?php
/**
 * Admin view: Pricing rules.
 *
 * @var array<int, array<string,mixed>> $areas
 * @var array<string,mixed>|null        $area
 * @var int                             $area_id
 * @var array<int, array<string,mixed>> $tiers
 * @var array<int, array<string,mixed>> $extras
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;
use TShirtDesigner\Pricing_Engine;

defined( 'ABSPATH' ) || exit;

$title = __( 'Pricing', 'tshirt-designer' );
require TD_PLUGIN_DIR . 'admin/views/html-header.php';
?>

<div class="td-tablenav">
	<strong><?php esc_html_e( 'Scope:', 'tshirt-designer' ); ?></strong>
	<a class="td-chip<?php echo 0 === $area_id ? ' is-active' : ''; ?>" href="<?php echo esc_url( Admin::page_url( 'pricing' ) ); ?>"><?php esc_html_e( 'Global (all areas)', 'tshirt-designer' ); ?></a>
	<?php foreach ( $areas as $a ) : ?>
		<a class="td-chip<?php echo (int) $a['id'] === $area_id ? ' is-active' : ''; ?>"
			href="<?php echo esc_url( Admin::page_url( 'pricing', array( 'area' => (int) $a['id'] ) ) ); ?>">
			<?php echo esc_html( sprintf( '%s — %s', $a['name'], $a['area_type'] ) ); ?>
		</a>
	<?php endforeach; ?>
</div>

<?php if ( null !== $area ) : ?>
	<p class="description">
		<?php esc_html_e( 'Area rules override the global rules for this print area only. The global rules are also listed for reference.', 'tshirt-designer' ); ?>
	</p>
<?php endif; ?>

<div class="td-grid">
	<div class="td-col-main td-col-main--wide">
		<h2><?php esc_html_e( 'Size-based print pricing', 'tshirt-designer' ); ?></h2>
		<p class="description"><?php esc_html_e( 'The tier is matched by the longest side of the artwork in centimeters. The first matching rule wins; area rules beat global rules.', 'tshirt-designer' ); ?></p>
		<table class="widefat striped td-table">
			<thead>
				<tr>
					<th><?php esc_html_e( 'From (cm)', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'To (cm)', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Price', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Scope', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
				</tr>
			</thead>
			<tbody>
				<?php if ( array() === $tiers ) : ?>
					<tr><td colspan="5"><?php esc_html_e( 'No size tiers yet.', 'tshirt-designer' ); ?></td></tr>
				<?php endif; ?>
				<?php foreach ( $tiers as $rule ) : ?>
					<tr class="<?php echo 'global' === $rule['scope'] ? 'td-row-muted' : ''; ?>">
						<td><?php echo esc_html( number_format( (float) $rule['size_from_cm'], 1 ) ); ?></td>
						<td><?php echo esc_html( number_format( (float) $rule['size_to_cm'], 1 ) ); ?></td>
						<td><?php echo esc_html( $this->plugin->settings->format_price( (float) $rule['price'] ) ); ?></td>
						<td><?php echo 'area' === $rule['scope'] ? esc_html__( 'This area', 'tshirt-designer' ) : esc_html__( 'Global', 'tshirt-designer' ); ?></td>
						<td>
							<form method="post" action="<?php echo esc_url( Admin::action_url( 'pricing' ) ); ?>" class="td-inline-form">
								<?php wp_nonce_field( 'td_admin_pricing' ); ?>
								<input type="hidden" name="page_key" value="pricing" />
								<input type="hidden" name="do" value="delete_rule" />
								<input type="hidden" name="print_area_id" value="<?php echo esc_attr( (string) $area_id ); ?>" />
								<input type="hidden" name="id" value="<?php echo esc_attr( (string) $rule['id'] ); ?>" />
								<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
							</form>
						</td>
					</tr>
				<?php endforeach; ?>
			</tbody>
		</table>

		<h2 style="margin-top:2em"><?php esc_html_e( 'Additional items in the same print area', 'tshirt-designer' ); ?></h2>
		<p class="description"><?php esc_html_e( 'Extra charge added to the Nth item (N ≥ 2). If there is no rule for N, the highest defined rule applies.', 'tshirt-designer' ); ?></p>
		<table class="widefat striped td-table">
			<thead>
				<tr>
					<th><?php esc_html_e( 'Item number', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Extra charge', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Scope', 'tshirt-designer' ); ?></th>
					<th><?php esc_html_e( 'Actions', 'tshirt-designer' ); ?></th>
				</tr>
			</thead>
			<tbody>
				<?php if ( array() === $extras ) : ?>
					<tr><td colspan="4"><?php esc_html_e( 'No item rules yet.', 'tshirt-designer' ); ?></td></tr>
				<?php endif; ?>
				<?php foreach ( $extras as $rule ) : ?>
					<tr class="<?php echo 'global' === $rule['scope'] ? 'td-row-muted' : ''; ?>">
						<td><?php echo esc_html( sprintf( /* translators: %d: item number. */ __( 'Item #%d', 'tshirt-designer' ), (int) $rule['item_count'] ) ); ?></td>
						<td><?php echo esc_html( $this->plugin->settings->format_price( (float) $rule['price'] ) ); ?></td>
						<td><?php echo 'area' === $rule['scope'] ? esc_html__( 'This area', 'tshirt-designer' ) : esc_html__( 'Global', 'tshirt-designer' ); ?></td>
						<td>
							<form method="post" action="<?php echo esc_url( Admin::action_url( 'pricing' ) ); ?>" class="td-inline-form">
								<?php wp_nonce_field( 'td_admin_pricing' ); ?>
								<input type="hidden" name="page_key" value="pricing" />
								<input type="hidden" name="do" value="delete_rule" />
								<input type="hidden" name="print_area_id" value="<?php echo esc_attr( (string) $area_id ); ?>" />
								<input type="hidden" name="id" value="<?php echo esc_attr( (string) $rule['id'] ); ?>" />
								<button class="button button-small td-btn-danger"><?php esc_html_e( 'Delete', 'tshirt-designer' ); ?></button>
							</form>
						</td>
					</tr>
				<?php endforeach; ?>
			</tbody>
		</table>
	</div>

	<div class="td-col-side">
		<h2><?php esc_html_e( 'Add pricing rule', 'tshirt-designer' ); ?></h2>
		<form method="post" action="<?php echo esc_url( Admin::action_url( 'pricing' ) ); ?>" class="td-form">
			<?php wp_nonce_field( 'td_admin_pricing' ); ?>
			<input type="hidden" name="page_key" value="pricing" />
			<input type="hidden" name="do" value="save_rule" />
			<input type="hidden" name="print_area_id" value="<?php echo esc_attr( (string) $area_id ); ?>" />

			<p>
				<label><?php esc_html_e( 'Rule type', 'tshirt-designer' ); ?></label>
				<select name="rule_type" class="widefat" id="td-rule-type">
					<option value="<?php echo esc_attr( Pricing_Engine::RULE_SIZE_TIER ); ?>"><?php esc_html_e( 'Size tier', 'tshirt-designer' ); ?></option>
					<option value="<?php echo esc_attr( Pricing_Engine::RULE_ITEM_EXTRA ); ?>"><?php esc_html_e( 'Additional item charge', 'tshirt-designer' ); ?></option>
				</select>
			</p>
			<p class="td-rule-size">
				<label><?php esc_html_e( 'From (cm)', 'tshirt-designer' ); ?></label>
				<input type="number" step="0.1" min="0" name="size_from_cm" value="0" class="widefat" />
			</p>
			<p class="td-rule-size">
				<label><?php esc_html_e( 'To (cm)', 'tshirt-designer' ); ?></label>
				<input type="number" step="0.1" min="0.1" name="size_to_cm" value="10" class="widefat" />
			</p>
			<p class="td-rule-extra td-hidden">
				<label><?php esc_html_e( 'Item number (Nth item ≥ 2)', 'tshirt-designer' ); ?></label>
				<input type="number" min="2" name="item_count" value="2" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Price', 'tshirt-designer' ); ?> *</label>
				<input type="number" step="0.01" min="0" name="price" required value="0" class="widefat" />
			</p>
			<p>
				<label><?php esc_html_e( 'Sort order', 'tshirt-designer' ); ?></label>
				<input type="number" name="sort_order" value="0" class="widefat" />
			</p>
			<p>
				<button class="button button-primary"><?php esc_html_e( 'Add rule', 'tshirt-designer' ); ?></button>
			</p>
		</form>

		<hr />
		<h2><?php esc_html_e( 'How pricing works', 'tshirt-designer' ); ?></h2>
		<p class="description">
			<?php esc_html_e( 'Final price = base product price + size modifier + print prices. Each printed item is priced by its size tier; the 2nd, 3rd, … item in the same area adds the configured extra charge. Prices are always recalculated on the server — values shown in the designer are for guidance only.', 'tshirt-designer' ); ?>
		</p>
	</div>
</div>

<?php require TD_PLUGIN_DIR . 'admin/views/html-footer.php'; ?>
