<?php
/**
 * Admin page header. Expects: $title (string), optional $subtitle.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

use TShirtDesigner\Admin\Admin;

defined( 'ABSPATH' ) || exit;
?>
<div class="wrap td-admin">

	<div class="td-admin__top">
		<h1 class="td-admin__title">
			<span class="dashicons dashicons-admin-customizer"></span>
			<?php echo esc_html( $title ); ?>
		</h1>
		<nav class="td-admin__tabs">
			<?php
			$tabs = array(
				'models'      => __( 'Models', 'tshirt-designer' ),
				'colors'      => __( 'Colors', 'tshirt-designer' ),
				'sizes'       => __( 'Sizes', 'tshirt-designer' ),
				'print-areas' => __( 'Print Areas', 'tshirt-designer' ),
				'assets'      => __( 'Design Assets', 'tshirt-designer' ),
				'pricing'     => __( 'Pricing', 'tshirt-designer' ),
				'designs'     => __( 'Designs', 'tshirt-designer' ),
				'settings'    => __( 'Settings', 'tshirt-designer' ),
			);
			// phpcs:ignore WordPress.Security.NonceVerification
			$current_page = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : '';
			foreach ( $tabs as $slug => $label ) :
				$href = Admin::page_url( $slug );
				$active = ( 'tshirt-designer-' . $slug ) === $current_page ? ' is-active' : '';
				?>
				<a class="td-admin__tab<?php echo esc_attr( $active ); ?>"
					href="<?php echo esc_url( $href ); ?>"><?php echo esc_html( $label ); ?></a>
			<?php endforeach; ?>
		</nav>
	</div>

	<?php Admin::notices(); ?>
