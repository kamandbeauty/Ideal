<?php
/**
 * Designer app template.
 *
 * @var \TShirtDesigner\Plugin            $plugin
 * @var int                               $initial_model
 * @var int                               $preload_design
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

defined( 'ABSPATH' ) || exit;

use TShirtDesigner\Assets;

Assets::enqueue_designer();

$boot = Assets::boot_data( $plugin, $initial_model, $preload_design );
$root = 'td-app-' . wp_generate_password( 8, false, false );
?>
<div
	class="td-app"
	id="<?php echo esc_attr( $root ); ?>"
	<?php // Follow the site locale so Persian shops get a real RTL layout. The
	// 2D editor canvas is forced back to LTR in CSS because its coordinates
	// are physical centimetres from the print area's top-left corner. ?>
	dir="<?php echo is_rtl() ? 'rtl' : 'ltr'; ?>"
	data-boot="<?php echo esc_attr( (string) wp_json_encode( $boot, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) ); ?>"
>
	<div class="td-app__inner">

		<!-- Left: product configuration -->
		<aside class="td-panel td-panel--config">
			<h3 class="td-panel__title" data-td="chooseModel"><?php esc_html_e( 'Choose a model', 'tshirt-designer' ); ?></h3>
			<div class="td-models" data-td-el="models"></div>

			<h3 class="td-panel__title" data-td="chooseColor"><?php esc_html_e( 'Color', 'tshirt-designer' ); ?></h3>
			<div class="td-colors" data-td-el="colors"></div>

			<h3 class="td-panel__title" data-td="chooseSize"><?php esc_html_e( 'Size', 'tshirt-designer' ); ?></h3>
			<div class="td-sizes" data-td-el="sizes"></div>
		</aside>

		<!-- Center: 3D viewer -->
		<main class="td-stage">
			<div class="td-stage__toolbar">
				<button type="button" class="td-btn td-btn--view is-active" data-view="front" title="<?php esc_attr_e( 'Front', 'tshirt-designer' ); ?>"><?php esc_html_e( 'Front', 'tshirt-designer' ); ?></button>
				<button type="button" class="td-btn td-btn--view" data-view="back" title="<?php esc_attr_e( 'Back', 'tshirt-designer' ); ?>"><?php esc_html_e( 'Back', 'tshirt-designer' ); ?></button>
				<button type="button" class="td-btn td-btn--view" data-view="left" title="<?php esc_attr_e( 'Left', 'tshirt-designer' ); ?>"><?php esc_html_e( 'Left', 'tshirt-designer' ); ?></button>
				<button type="button" class="td-btn td-btn--view" data-view="right" title="<?php esc_attr_e( 'Right', 'tshirt-designer' ); ?>"><?php esc_html_e( 'Right', 'tshirt-designer' ); ?></button>
				<button type="button" class="td-btn" data-td-el="resetView" title="<?php esc_attr_e( 'Reset view', 'tshirt-designer' ); ?>">⟲ <?php esc_html_e( 'Reset view', 'tshirt-designer' ); ?></button>
			</div>
			<div class="td-stage__canvas" data-td-el="stage">
				<div class="td-stage__loading" data-td-el="loading">
					<span class="td-spinner"></span>
					<span data-td="loading3d"><?php esc_html_e( 'Loading 3D model…', 'tshirt-designer' ); ?></span>
				</div>
				<div class="td-stage__error td-hidden" data-td-el="webglError">
					<p><?php esc_html_e( 'Your browser does not support WebGL, which is required for the 3D preview.', 'tshirt-designer' ); ?></p>
				</div>
				<div class="td-stage__error td-hidden" data-td-el="loadError">
					<p><?php esc_html_e( 'Could not load the 3D model.', 'tshirt-designer' ); ?></p>
				</div>
			</div>
		</main>

		<!-- Right: design tools -->
		<button type="button" class="td-tools-toggle" data-td-el="toolsToggle">
			<span data-td="designTab"><?php esc_html_e( 'Design tools', 'tshirt-designer' ); ?></span>
			<span aria-hidden="true">☰</span>
		</button>
		<aside class="td-panel td-panel--tools">
			<div class="td-tabs" role="tablist">
				<button type="button" class="td-tab is-active" data-tab="design" role="tab"><?php esc_html_e( 'Design', 'tshirt-designer' ); ?></button>
				<button type="button" class="td-tab" data-tab="artwork" role="tab"><?php esc_html_e( 'Artwork', 'tshirt-designer' ); ?></button>
			</div>

			<div class="td-tabpane is-active" data-tabpane="design">
				<div class="td-areas" data-td-el="areas"></div>
				<div class="td-editor" data-td-el="editor">
					<canvas class="td-editor__canvas" data-td-el="editorCanvas"></canvas>
				</div>
				<div class="td-layers">
					<div class="td-layers__head">
						<span data-td="layers"><?php esc_html_e( 'Layers', 'tshirt-designer' ); ?></span>
						<span class="td-layers__actions" data-td-el="layerActions">
							<button type="button" class="td-btn td-btn--sm" data-layer="duplicate" title="<?php esc_attr_e( 'Duplicate', 'tshirt-designer' ); ?>">⧉</button>
							<button type="button" class="td-btn td-btn--sm" data-layer="forward" title="<?php esc_attr_e( 'Bring forward', 'tshirt-designer' ); ?>">↑</button>
							<button type="button" class="td-btn td-btn--sm" data-layer="backward" title="<?php esc_attr_e( 'Send backward', 'tshirt-designer' ); ?>">↓</button>
							<button type="button" class="td-btn td-btn--sm td-btn--danger" data-layer="delete" title="<?php esc_attr_e( 'Delete', 'tshirt-designer' ); ?>">🗑</button>
						</span>
					</div>
					<ul class="td-layers__list" data-td-el="layers"></ul>
				</div>
			</div>

			<div class="td-tabpane" data-tabpane="artwork">
				<div class="td-cats" data-td-el="cats"></div>
				<div class="td-assets" data-td-el="assets"></div>
				<div class="td-upload" data-td-el="upload">
					<label class="td-upload__zone">
						<input type="file" accept="image/jpeg,image/png,image/webp" class="td-upload__input" data-td-el="uploadInput" hidden />
						<span class="td-upload__icon">⬆</span>
						<span data-td="upload"><?php esc_html_e( 'Upload image', 'tshirt-designer' ); ?></span>
						<small class="td-upload__hint" data-td-el="uploadHint"></small>
					</label>
					<div class="td-upload__status td-hidden" data-td-el="uploadStatus"></div>
				</div>
			</div>

			<div class="td-price" data-td-el="price">
				<div class="td-price__lines" data-td-el="priceLines"></div>
				<div class="td-price__total">
					<span data-td="total"><?php esc_html_e( 'Total', 'tshirt-designer' ); ?></span>
					<strong data-td-el="priceTotal">—</strong>
				</div>
				<button type="button" class="td-btn td-btn--primary td-btn--block" data-td-el="save">
					<?php esc_html_e( 'Save design', 'tshirt-designer' ); ?>
				</button>
				<div class="td-price__note td-hidden" data-td-el="saveStatus"></div>
			</div>
		</aside>

	</div>
</div>
