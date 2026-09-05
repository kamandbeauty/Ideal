/**
 * Customer mockup preview.
 *
 * A presentation layer, NOT a renderer. It deliberately owns no rendering,
 * no transform maths and no text engine of its own: it instantiates the same
 * Viewer and Compositor the designer already uses, feeds them the same design
 * data, and puts a customer-facing shell around them.
 *
 * Consequences of that choice, which are the point of the module:
 *   - design placement can never drift from the designer, because there is
 *     only one implementation of placement;
 *   - text renders exactly as the existing Text Engine renders it;
 *   - the mockup cannot mutate the design, because it never writes to State.
 *
 * The mockup is shown between "add to cart" and the actual cart call. It is a
 * confirmation step only: approving does not price, pay, or create anything.
 */
import { Compositor } from './compositor.js';
import { Viewer } from './viewer.js';
import { formatPrice } from './utils.js';

/** Print-area type -> view button, in display order. */
const VIEW_ORDER = ['front', 'back', 'left_sleeve', 'right_sleeve'];

/** Print-area type -> the Viewer's camera preset name. */
const VIEW_TO_PRESET = {
  front: 'front',
  back: 'back',
  left_sleeve: 'left',
  right_sleeve: 'right',
};

export class Mockup {
  /**
   * @param {object} opts
   * @param {object} opts.i18n     Translated strings.
   * @param {string} opts.currency Currency suffix for prices.
   */
  constructor({ i18n = {}, currency = '', productTypes = {} } = {}) {
    this.i18n = i18n;
    this.currency = currency;
    this.productTypes = productTypes;
    this.root = null;
    this.viewer = null;
    this.compositor = null;
    this.onConfirm = null;
    this.onCancel = null;
    this.activeView = '';
    this.views = [];
    this._keydown = null;
    this._lastFocus = null;
  }

  t(key, fallback) {
    return this.i18n[key] || fallback;
  }

  /**
   * Open the mockup over the page.
   *
   * @param {object} ctx
   * @param {object} ctx.model  Full model detail (print areas, glb url, ...).
   * @param {object} ctx.areas  areaId -> items[] (the live design).
   * @param {object} ctx.color  Selected color row, or null.
   * @param {object} ctx.size   Selected size row, or null.
   * @param {object} ctx.price  Authoritative price breakdown from the server.
   */
  open(ctx) {
    this.close();
    this._lastFocus = document.activeElement;
    this.ctx = ctx;

    this.views = this._availableViews(ctx.model);
    this.root = this._buildShell(ctx);
    document.body.appendChild(this.root);
    document.body.classList.add('td-mockup-open');

    // Escape closes, and focus is trapped inside the dialog.
    this._keydown = (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        this._cancel();
      } else if (e.key === 'Tab') {
        this._trapFocus(e);
      }
    };
    document.addEventListener('keydown', this._keydown);

    const backBtn = this.root.querySelector('[data-td-mk="back"]');
    if (backBtn) backBtn.focus();

    this._startRender(ctx);
    return this.root;
  }

  /**
   * Only the print areas this product type actually has, in a stable order.
   *
   * Driven by the model's own print areas, so a Tote can never show sleeve
   * buttons and a T-Shirt can never show a Tote-only area.
   */
  _availableViews(model) {
    const areas = (model && model.print_areas) || [];
    const present = new Set(areas.map((a) => a.type));
    return VIEW_ORDER.filter((v) => present.has(v));
  }

  _viewLabel(type) {
    const map = {
      front: this.t('front', 'Front'),
      back: this.t('back', 'Back'),
      left_sleeve: this.t('leftSleeve', 'Left sleeve'),
      right_sleeve: this.t('rightSleeve', 'Right sleeve'),
    };
    return map[type] || type;
  }

  _buildShell(ctx) {
    const wrap = document.createElement('div');
    wrap.className = 'td-mockup';
    // The dialog mounts on <body>, outside .td-app, so it does not inherit the
    // designer's dir attribute. Take it from the document instead.
    wrap.setAttribute('dir', document.documentElement.dir === 'rtl' ? 'rtl' : 'ltr');
    wrap.setAttribute('role', 'dialog');
    wrap.setAttribute('aria-modal', 'true');
    wrap.setAttribute('aria-label', this.t('mockupTitle', 'Product preview'));

    const viewButtons = this.views
      .map(
        (v, i) =>
          `<button type="button" class="td-mockup__view${i === 0 ? ' is-active' : ''}"` +
          ` data-td-mk="view" data-view="${esc(v)}" aria-pressed="${i === 0}">${esc(
            this._viewLabel(v)
          )}</button>`
      )
      .join('');

    wrap.innerHTML = `
      <div class="td-mockup__dialog">
        <header class="td-mockup__head">
          <h2 class="td-mockup__title">${esc(this.t('mockupTitle', 'Product preview'))}</h2>
          <button type="button" class="td-mockup__close" data-td-mk="back"
                  aria-label="${esc(this.t('backToDesigner', 'Back to the designer'))}">&times;</button>
        </header>

        <div class="td-mockup__body">
          <div class="td-mockup__stagewrap">
            <div class="td-mockup__stage" data-td-mk="stage"></div>

            <div class="td-mockup__loading" data-td-mk="loading" role="status">
              <span class="td-mockup__spinner" aria-hidden="true"></span>
              <span>${esc(this.t('mockupLoading', 'Preparing your preview…'))}</span>
            </div>

            <div class="td-mockup__error td-hidden" data-td-mk="error" role="alert">
              <p>${esc(this.t('mockupError', 'The preview could not be displayed.'))}</p>
              <p class="td-mockup__errorhint">${esc(this.t('mockupErrorHint', 'Please try again.'))}</p>
              <div class="td-mockup__errorActions">
                <button type="button" class="td-btn td-btn--primary" data-td-mk="retry">
                  ${esc(this.t('retry', 'Try again'))}
                </button>
                <button type="button" class="td-btn" data-td-mk="back2">
                  ${esc(this.t('backToDesigner', 'Back to the designer'))}
                </button>
              </div>
            </div>

            <div class="td-mockup__zoom" data-td-mk="zoomBar">
              <button type="button" class="td-mockup__zoombtn" data-td-mk="zoomIn"
                      aria-label="${esc(this.t('zoomIn', 'Zoom in'))}">+</button>
              <button type="button" class="td-mockup__zoombtn" data-td-mk="zoomOut"
                      aria-label="${esc(this.t('zoomOut', 'Zoom out'))}">&minus;</button>
              <button type="button" class="td-mockup__zoombtn" data-td-mk="zoomReset"
                      aria-label="${esc(this.t('resetZoom', 'Reset zoom'))}">⟲</button>
            </div>
          </div>

          <div class="td-mockup__views" role="group"
               aria-label="${esc(this.t('chooseView', 'Choose a view'))}">${viewButtons}</div>

          <dl class="td-mockup__summary">${this._summaryRows(ctx)}</dl>

          <div class="td-mockup__actions">
            <button type="button" class="td-btn td-btn--primary td-btn--block" data-td-mk="confirm">
              ${esc(this.t('approveContinue', 'Approve and continue'))}
            </button>
            <button type="button" class="td-btn td-btn--block" data-td-mk="back3">
              ${esc(this.t('backToDesigner', 'Back to the designer'))}
            </button>
            <p class="td-mockup__note">${esc(
              this.t('mockupNote', 'This is a preview for approval. You will pay at checkout.')
            )}</p>
          </div>
        </div>
      </div>
    `;

    wrap.addEventListener('click', (e) => this._onClick(e));
    return wrap;
  }

  _summaryRows(ctx) {
    const rows = [];
    const push = (label, value) => {
      if (value === null || value === undefined || value === '') return;
      rows.push(
        `<div class="td-mockup__row"><dt>${esc(label)}</dt><dd>${esc(String(value))}</dd></div>`
      );
    };

    const model = ctx.model || {};
    push(this.t('product', 'Product'), this.productTypes[model.product_type] || model.product_type || '');
    push(this.t('modelLabel', 'Model'), model.name || '');
    push(this.t('chooseColor', 'Color'), ctx.color ? ctx.color.name : '');
    push(this.t('chooseSize', 'Size'), ctx.size ? ctx.size.name : '');

    const areaNames = this._designedAreaNames(ctx);
    if (areaNames.length) push(this.t('printAreas', 'Print area'), areaNames.join('، '));

    // The price is whatever the server last told us. The mockup never computes
    // or adjusts it; it only displays it.
    if (ctx.price && typeof ctx.price.total !== 'undefined') {
      push(this.t('price', 'Price'), formatPrice(ctx.price.total, this.currency));
    }

    return rows.join('');
  }

  _designedAreaNames(ctx) {
    const areas = (ctx.model && ctx.model.print_areas) || [];
    const out = [];
    for (const area of areas) {
      const items = (ctx.areas && ctx.areas[area.id]) || [];
      if (items.length) out.push(area.name || this._viewLabel(area.type));
    }
    return out;
  }

  _onClick(e) {
    const btn = e.target.closest('[data-td-mk]');
    if (!btn) return;
    const role = btn.dataset.tdMk;

    if (role === 'back' || role === 'back2' || role === 'back3') this._cancel();
    else if (role === 'confirm') this._confirm();
    else if (role === 'view') this._switchView(btn.dataset.view, btn);
    else if (role === 'zoomIn') this._zoom(0.82);
    else if (role === 'zoomOut') this._zoom(1.22);
    else if (role === 'zoomReset') this._resetZoom();
    else if (role === 'retry') this._retry();
  }

  /**
   * Build the scene. The compositor is fed a deep copy of the design so that
   * nothing downstream can reach back into the designer's own item objects.
   */
  async _startRender(ctx) {
    const stage = this.root.querySelector('[data-td-mk="stage"]');
    const model = ctx.model || {};

    if (!Viewer.webglAvailable()) {
      this._showError();
      return;
    }

    try {
      this.compositor = new Compositor();

      const areas = (model.print_areas || []).map((a) => ({
        ...a,
        _items: deepCopyItems((ctx.areas && ctx.areas[a.id]) || []),
      }));
      this.compositor.setPrintAreas(areas);
      this.compositor.setColor(
        (ctx.color && ctx.color.hex) || '#FFFFFF',
        (ctx.color && ctx.color.texture_url) || ''
      );
      await this.compositor.repaint();

      this.viewer = new Viewer(stage, {
        // No area-click handler: the mockup is not an editor.
        onAreaClick: null,
        onReady: () => this._hideLoading(),
        i18n: this.i18n,
      });
      this.viewer.setPrintAreas(model.print_areas || []);

      if (!model.model_url) {
        this._showError();
        return;
      }

      await this.viewer.loadModel(model.model_url, this.compositor);
      this.viewer.applyColor((ctx.color && ctx.color.hex) || '#FFFFFF');

      if (this.views.length) this._switchView(this.views[0], null);
      this._hideLoading();
    } catch (err) {
      this._showError();
      if (window.console && console.warn) {
        console.warn('[tshirt-designer] mockup render failed', err && err.message);
      }
    }
  }

  _switchView(view, btn) {
    if (!view) return;
    this.activeView = view;
    if (this.viewer) this.viewer.setView(VIEW_TO_PRESET[view] || 'reset');

    const buttons = this.root.querySelectorAll('[data-td-mk="view"]');
    buttons.forEach((b) => {
      const on = b.dataset.view === view;
      b.classList.toggle('is-active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    if (btn) btn.focus();
  }

  /**
   * Zoom by moving the CAMERA only. Design coordinates are never touched —
   * this is the whole reason zoom lives here and not in the editor.
   */
  _zoom(factor) {
    const v = this.viewer;
    if (!v || !v.camera || !v.controls) return;
    const target = v.controls.target;
    const dir = v.camera.position.clone().sub(target);
    const len = dir.length() * factor;
    const min = v.controls.minDistance || 0.55;
    const max = v.controls.maxDistance || 2.8;
    dir.setLength(Math.max(min, Math.min(max, len)));
    v.camera.position.copy(target.clone().add(dir));
    v.controls.update();
  }

  _resetZoom() {
    if (this.viewer) this.viewer.setView(VIEW_TO_PRESET[this.activeView] || 'reset');
  }

  _retry() {
    const err = this.root.querySelector('[data-td-mk="error"]');
    if (err) err.classList.add('td-hidden');
    const loading = this.root.querySelector('[data-td-mk="loading"]');
    if (loading) loading.classList.remove('td-hidden');
    this._disposeScene();
    this._startRender(this.ctx);
  }

  _hideLoading() {
    const el = this.root && this.root.querySelector('[data-td-mk="loading"]');
    if (el) el.classList.add('td-hidden');
  }

  _showError() {
    this._hideLoading();
    const el = this.root && this.root.querySelector('[data-td-mk="error"]');
    if (el) el.classList.remove('td-hidden');
    const zoom = this.root && this.root.querySelector('[data-td-mk="zoomBar"]');
    if (zoom) zoom.classList.add('td-hidden');
  }

  _trapFocus(e) {
    const focusables = this.root.querySelectorAll(
      'button:not([disabled]), [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    if (!focusables.length) return;
    const first = focusables[0];
    const last = focusables[focusables.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  }

  _confirm() {
    const fn = this.onConfirm;
    this.close();
    if (fn) fn();
  }

  _cancel() {
    const fn = this.onCancel;
    this.close();
    if (fn) fn();
  }

  /**
   * Release every GPU resource this instance created.
   *
   * Viewer.dispose() drops the renderer and controls but not the geometries,
   * materials and textures inside the loaded model, so opening the mockup
   * repeatedly would leak. Walk the scene and dispose them explicitly.
   */
  _disposeScene() {
    if (this.viewer) {
      const scene = this.viewer.scene;
      const renderer = this.viewer.renderer;

      if (scene) {
        scene.traverse((obj) => {
          if (!obj.isMesh) return;
          if (obj.geometry && obj.geometry.dispose) obj.geometry.dispose();
          const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
          for (const mat of mats) {
            if (!mat) continue;
            for (const key of Object.keys(mat)) {
              const val = mat[key];
              if (val && val.isTexture && val.dispose) val.dispose();
            }
            if (mat.dispose) mat.dispose();
          }
        });

        // The PMREM environment map is a render target owned by the scene,
        // not by any mesh, so the traversal above never reaches it. Left
        // alone it is the single largest per-cycle GPU leak.
        if (scene.environment && scene.environment.dispose) scene.environment.dispose();
        scene.environment = null;
        scene.clear();
      }

      /*
       * Drop Three's cached programs and render lists before disposing the
       * renderer. forceContextLoss() then releases the GL context itself
       * rather than leaving it for the browser to reclaim lazily, which
       * matters because browsers cap simultaneous WebGL contexts.
       */
      if (renderer) {
        if (renderer.renderLists && renderer.renderLists.dispose) renderer.renderLists.dispose();
        if (renderer.info && renderer.info.programs) {
          for (const p of [...renderer.info.programs]) {
            if (p && p.destroy) p.destroy();
          }
        }
      }

      this.viewer.dispose();

      if (renderer && renderer.forceContextLoss) {
        try { renderer.forceContextLoss(); } catch { /* context already gone */ }
      }
      this.viewer = null;
    }

    if (this.compositor) {
      if (this.compositor.texture && this.compositor.texture.dispose) {
        this.compositor.texture.dispose();
      }
      // Drop the 2048² backing store rather than waiting for GC.
      this.compositor.canvas.width = 1;
      this.compositor.canvas.height = 1;
      this.compositor = null;
    }
  }

  close() {
    if (this._keydown) {
      document.removeEventListener('keydown', this._keydown);
      this._keydown = null;
    }
    this._disposeScene();
    if (this.root && this.root.parentNode) this.root.parentNode.removeChild(this.root);
    this.root = null;
    document.body.classList.remove('td-mockup-open');
    if (this._lastFocus && this._lastFocus.focus) {
      try { this._lastFocus.focus(); } catch { /* element gone */ }
    }
    this._lastFocus = null;
  }
}

/** Structured clone of design items so the mockup cannot alias designer state. */
function deepCopyItems(items) {
  return (items || []).map((it) => ({ ...it }));
}

/** Escape a value for safe innerHTML interpolation. */
function esc(value) {
  return String(value === null || value === undefined ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
