/**
 * T-Shirt Designer — admin scripts.
 *
 * - Media library picker for .td-media-field blocks (images + GLB models).
 * - Pricing rule-type field toggling.
 */
(function () {
	'use strict';

	var i18n = (window.TD_ADMIN && TD_ADMIN.i18n) || {};

	/* ------------------------------------------------------- media picker */

	function renderPreview(field, attachment) {
		var preview = field.querySelector('.td-media-field__preview');
		var clear = field.querySelector('.td-media-clear');
		if (!preview) return;
		preview.innerHTML = '';

		if (attachment) {
			if (isGlb(attachment)) {
				var file = document.createElement('span');
				file.className = 'td-media-file';
				file.textContent = '📦 ' + (attachment.filename || attachment.title || '');
				preview.appendChild(file);
			} else {
				var img = document.createElement('img');
				img.src = (attachment.sizes && attachment.sizes.thumbnail)
					? attachment.sizes.thumbnail.url
					: attachment.url;
				img.alt = '';
				preview.appendChild(img);
				var name = document.createElement('span');
				name.className = 'td-media-file';
				name.textContent = attachment.filename || attachment.title || '';
				preview.appendChild(name);
			}
			if (clear) clear.classList.remove('td-hidden');
		} else if (clear) {
			clear.classList.add('td-hidden');
		}
	}

	function isGlb(attachment) {
		var mime = attachment.mime || '';
		var name = attachment.filename || attachment.url || '';
		return mime === 'model/gltf-binary' || mime === 'model/gltf+json' || /\.glb$/i.test(name);
	}

	function initMediaField(field) {
		var pick = field.querySelector('.td-media-pick');
		var clear = field.querySelector('.td-media-clear');
		var input = field.querySelector('input[type="hidden"]');
		var titleKey = field.getAttribute('data-title-key') || 'chooseImage';
		var buttonKey = field.getAttribute('data-button-key') || 'use';

		if (!pick || !input || !window.wp || !wp.media) return;

		var frame = null;

		var getFrame = function () {
			if (frame) return frame;
			var isModelPicker = titleKey === 'chooseModel';
			frame = wp.media({
				title: i18n[titleKey] || 'Choose a file',
				button: { text: i18n[buttonKey] || 'Use this file' },
				multiple: false,
				library: isModelPicker ? { type: '' } : {}
			});

			if (isModelPicker) {
				// Allow every MIME in the frame, but visibly tag model files.
				frame.on('ready', function () {});
			}

			frame.on('select', function () {
				var attachment = frame.state().get('selection').first().toJSON();
				input.value = attachment.id;
				renderPreview(field, attachment);
			});
			return frame;
		};

		pick.addEventListener('click', function (e) {
			e.preventDefault();
			getFrame().open();
		});

		if (clear) {
			clear.addEventListener('click', function (e) {
				e.preventDefault();
				input.value = '0';
				renderPreview(field, null);
			});
		}

		// Show existing selection on load.
		var id = parseInt(input.value, 10);
		if (id > 0 && wp.media.attachment) {
			var attachment = wp.media.attachment(id);
			attachment.fetch().done(function () {
				if (attachment.get('id')) renderPreview(field, attachment.toJSON());
			});
		}
	}

	/* -------------------------------------------------- pricing rule type */

	function initRuleType() {
		var select = document.getElementById('td-rule-type');
		if (!select) return;

		var toggle = function () {
			var isSize = select.value === 'size';
			document.querySelectorAll('.td-rule-size').forEach(function (el) {
				el.classList.toggle('td-hidden', !isSize);
			});
			document.querySelectorAll('.td-rule-extra').forEach(function (el) {
				el.classList.toggle('td-hidden', isSize);
			});
		};

		select.addEventListener('change', toggle);
		toggle();
	}

	/* ------------------------------------------------------------- boot */

	document.addEventListener('DOMContentLoaded', function () {
		document.querySelectorAll('.td-media-field').forEach(initMediaField);
		initRuleType();
	});
})();
