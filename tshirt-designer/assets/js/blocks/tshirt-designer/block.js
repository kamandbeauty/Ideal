/**
 * T-Shirt Designer — Gutenberg block (no build step).
 *
 * The block is registered server-side from block.json with a render callback
 * that outputs the [tshirt_designer] shortcode. This script only provides
 * the editor experience: a placeholder in the canvas and a model picker in
 * the sidebar. The live 3D designer runs on the front end only.
 */
(function (wp) {
	'use strict';
	if (!wp || !wp.blocks || !wp.element || !wp.blockEditor) {
		return;
	}

	/* Localized strings (no build step — provided by PHP via TD_BLOCK.i18n). */
	var i18n = (window.TD_BLOCK && TD_BLOCK.i18n) || {};
	var __ = function (key) {
		return i18n[key] || key;
	};

	var el = wp.element.createElement;
	var Fragment = wp.element.Fragment;
	var useEffect = wp.element.useEffect;
	var useState = wp.element.useState;
	var registerBlockType = wp.blocks.registerBlockType;
	var useBlockProps = wp.blockEditor.useBlockProps;
	var InspectorControls = wp.blockEditor.InspectorControls;
	var PanelBody = wp.components.PanelBody;
	var SelectControl = wp.components.SelectControl;
	var Placeholder = wp.components.Placeholder;
	var Spinner = wp.components.Spinner;
	var apiFetch = wp.apiFetch;

	/** Fetch available models once for the sidebar select. */
	function useModels() {
		var state = useState(null);
		var models = state[0];
		var setModels = state[1];

		useEffect(function () {
			if (models !== null || !apiFetch) return;
			apiFetch({ path: 'tshirt-designer/v1/models' })
				.then(function (list) { setModels(list || []); })
				.catch(function () { setModels([]); });
		}, []);

		return models;
	}

	function Edit(props) {
		var attributes = props.attributes;
		var setAttributes = props.setAttributes;
		var blockProps = useBlockProps();
		var models = useModels();

		var options = [{ value: 0, label: __('Default model') }];
		if (models) {
			for (var i = 0; i < models.length; i++) {
				options.push({ value: models[i].id, label: models[i].name });
			}
		}

		return el(
			Fragment,
			{},
			el(
				InspectorControls,
				{},
				el(
					PanelBody,
					{ title: __('Settings'), initialOpen: true },
					models === null
						? el(Spinner)
						: el(SelectControl, {
							label: __('Initial model'),
							value: attributes.modelId || 0,
							options: options,
							onChange: function (value) {
								setAttributes({ modelId: parseInt(value, 10) || 0 });
							}
						})
				)
			),
			el(
				'div',
				blockProps,
				el(
					Placeholder,
					{
						icon: 'admin-customizer',
						label: __('T-Shirt Designer')
					},
					__('The interactive 3D designer runs on the live page. Preview it by viewing the published post.')
				)
			)
		);
	}

	registerBlockType('tshirt-designer/designer', {
		apiVersion: 3,
		title: __('T-Shirt Designer'),
		description: __('Interactive 3D T-Shirt designer for your customers.'),
		category: 'design',
		icon: 'admin-customizer',
		keywords: ['tshirt', 'designer', '3d', 'print'],
		supports: { html: false, align: ['wide', 'full'] },
		attributes: {
			modelId: { type: 'number', default: 0 }
		},
		edit: Edit,
		save: function () {
			// Dynamic block — rendered server-side.
			return null;
		}
	});
})(window.wp);
