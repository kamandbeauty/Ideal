/**
 * Designer entry point. Bootstraps one app instance per [tshirt_designer]
 * shortcode occurrence on the page.
 */
import { Api } from './api.js';
import { State } from './state.js';
import { Compositor } from './compositor.js';
import { Viewer } from './viewer.js';
import { Editor2D } from './editor2d.js';
import { UI } from './ui.js';
import { debounce } from './utils.js';
import { setFontStacks, renderTextDataUrl } from './textrender.js';

class DesignerApp {
  constructor(root) {
    this.root = root;
    this.boot = JSON.parse(root.dataset.boot || '{}');
    this.api = new Api({ restUrl: this.boot.restUrl || '/wp-json/tshirt-designer/v1', nonce: this.boot.nonce || '' });
    this.state = new State();
    this.i18n = this.boot.i18n || {};
    this.currency = this.boot.currency || {};
    this.modelLoading = false;

    this.compositor = new Compositor();
    this._priceKey = '';

    // 3D viewer (may be unavailable — WebGL check inside).
    this.viewer = new Viewer(root.querySelector('[data-td-el="stage"]'), {
      i18n: this.i18n,
      onAreaClick: (areaId) => this.selectArea(areaId),
      onReady: () => this.ui.showLoading(false),
    });

    // 2D print-area editor.
    this.editor = new Editor2D(root.querySelector('[data-td-el="editorCanvas"]'), {
      state: this.state,
      i18n: this.i18n,
      onChange: () => this.requestPrice(),
    });

    // UI panels.
    this.ui = new UI(root, {
      state: this.state,
      api: this.api,
      i18n: this.i18n,
      currency: this.currency,
      uploadMaxMb: this.boot.uploadMaxMb || 5,
      fonts: this.boot.fonts || [],
      onChange: () => this.requestPrice(),
    });

    // UI callbacks (wired here to keep UI module dumb).
    this.ui.onSelectModel = (id) => this.loadModel(id);
    this.ui.onSelectColor = (id) => this.applyColor(id);
    this.ui.onSelectSize = (id) => { this.state.set({ sizeId: id }); };
    this.ui.onSelectArea = (id) => this.selectArea(id);
    this.ui.onSelectCategory = (key) => this.loadAssets(key);
    this.ui.onAddAsset = (asset) => this.editor.addAsset(asset);
    this.ui.onUploaded = (upload) => {
      this.editor.addUpload(upload);
      this.requestPrice();
    };
    this.ui.onView = (name) => this.viewer.setView(name);
    this.ui.onEditorAction = (action) => this.editorAction(action);
    this.ui.onAddText = (text) => this.editor.addText(text);
    this.ui.onUpdateText = (id, text) => this.editor.updateText(id, text);
    this.ui.onSave = () => this.save();

    // State changes drive every panel.
    this.state.subscribe((data) => this.render(data));

    // Keyboard: arrows nudge, Delete removes.
    document.addEventListener('keydown', (e) => {
      if (this._isTyping(e)) return;
      const step = e.shiftKey ? 2 : 0.5;
      const map = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] };
      if (map[e.key]) {
        if (this.editor.nudge(map[e.key][0], map[e.key][1])) e.preventDefault();
      } else if (e.key === 'Delete' || e.key === 'Backspace') {
        if (this.editor.removeSelected()) e.preventDefault();
      }
    });

    // Debounced authoritative server price.
    this._debouncedPrice = debounce(() => this.fetchPrice(), 500);

    this.compositor.onRepaint = () => {};

    // Preview font stacks come from the server so the on-screen text and the
    // TTF used for the print file are always the same family.
    setFontStacks(this.boot.fonts || []);

    this.init();
  }

  _isTyping(e) {
    const t = e.target;
    return t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable);
  }

  async init() {
    this.ui.renderCats();
    this.ui.renderPrice(false);

    if (!Viewer.webglAvailable()) {
      this.ui.showWebglError(true);
      this.ui.showLoading(false);
    }

    try {
      const models = await this.api.getModels();
      this.state.set({ models });
      if (!models.length) {
        this.ui.showLoadError(true);
        this.ui.showLoading(false);
        return;
      }
      const wanted = (this.boot.initialModel || 0) || this.preloadModelId;
      const first = models.find((m) => m.id === wanted) || models[0];
      await this.loadModel(first.id);
    } catch (err) {
      this.ui.showLoadError(true);
      this.ui.showLoading(false);
    }

    await this.loadAssets(this.state.get('assetCategory'));
    if (this.boot.preloadDesign) await this.preloadDesign(this.boot.preloadDesign);
  }

  async loadModel(id, keepAreas = false) {
    if (this.modelLoading) return;
    this.modelLoading = true;
    this.ui.showLoading(true);
    this.ui.showLoadError(false);
    try {
      const model = await this.api.getModel(id);
      const areas = keepAreas ? this.state.get('areas') : {};
      const colorId = model.colors.length ? model.colors[0].id : 0;
      const sizeId = model.sizes.length ? model.sizes[0].id : 0;
      const activeAreaId = model.print_areas.length ? model.print_areas[0].id : 0;

      this.state.set({
        model,
        colorId,
        sizeId,
        activeAreaId,
        areas,
        selectedItemId: null,
        price: null,
      });

      // 3D: model + fabric texture + print areas.
      this.compositor.setPrintAreas(model.print_areas);
      this.applyColor(colorId);
      this.editor.setArea(this.state.activeArea());

      if (this.viewer.renderer) {
        await this.viewer.loadModel(model.model_url, this.compositor);
        this.viewer.setPrintAreas(model.print_areas);
        const area = this.state.activeArea();
        if (area && area.camera) this.viewer.setCameraPreset(area.camera);
        this.viewer.setView('front');
      } else {
        this.ui.showLoading(false);
      }
      this.requestPrice();
    } catch (err) {
      this.ui.showLoadError(true);
      this.ui.showLoading(false);
    } finally {
      this.modelLoading = false;
    }
  }

  /** Instant recolor: repaint atlas + tint trims, no model reload. */
  applyColor(colorId) {
    this.state.set({ colorId });
    const model = this.state.get('model');
    const color = model && (model.colors || []).find((c) => c.id === colorId);
    if (!color) return;
    this.compositor.setColor(color.hex, color.texture_url || '');
    if (this.viewer) this.viewer.applyColor(color.hex);
    this.compositor.requestRepaint();
    this.requestPrice();
  }

  selectArea(areaId) {
    const model = this.state.get('model');
    const area = model && model.print_areas.find((a) => a.id === areaId);
    if (!area) return;
    this.state.set({ activeAreaId: areaId, selectedItemId: null });
    this.editor.setArea(area);
    if (area.camera && this.viewer) this.viewer.setCameraPreset(area.camera);
  }

  async loadAssets(category) {
    this.state.set({ assetCategory: category });
    try {
      const assets = await this.api.getAssets(category);
      this.state.set({ assets });
    } catch { /* keep previous list */ }
  }

  editorAction(action) {
    const id = this.state.get('selectedItemId');
    if (!id) return;
    if (action === 'delete') this.state.removeItem(id);
    else if (action === 'duplicate') this.state.duplicateItem(id);
    else if (action === 'forward') this.state.moveItem(id, 'forward');
    else if (action === 'backward') this.state.moveItem(id, 'backward');
  }

  /** Re-render panels + textures after any state change. */
  render() {
    const model = this.state.get('model');
    this.ui.renderModels();
    this.ui.renderColors();
    this.ui.renderSizes();
    this.ui.renderAreas();
    this.ui.renderLayers();
    this.ui.renderAssets();
    this.ui.syncTextPanel();
    this.editor.render();

    if (model) {
      // Compositor needs items attached to each print area.
      const areas = model.print_areas.map((a) => ({
        ...a,
        _items: this.state.get('areas')[a.id] || [],
      }));
      this.compositor.setPrintAreas(areas);
      this.compositor.requestRepaint();
    }

    this.requestPrice();
  }

  requestPrice() {
    this._debouncedPrice();
  }

  async fetchPrice() {
    const model = this.state.get('model');
    if (!model) return;
    const payload = this.state.toDesignPayload();
    if (!payload.size_id) return;

    const key = JSON.stringify(payload);
    if (key === this._priceKey) return;
    this._priceKey = key;

    this.ui.renderPrice(true);
    try {
      const res = await this.api.calculatePrice(payload);
      this.state.set({ price: res.breakdown });
      this.ui.renderPrice(false);
    } catch {
      this.ui.renderPrice(false);
    }
  }

  async save() {
    const model = this.state.get('model');
    if (!model) return;
    if (!this.boot.canSave) {
      this.ui.setSaveStatus(this.i18n.loginToSave || 'Please log in to save designs.', false);
      return;
    }
    if (!this.state.itemCount()) {
      return;
    }

    const btn = this.root.querySelector('[data-td-el="save"]');
    if (btn) btn.disabled = true;
    this.ui.setSaveStatus(this.i18n.saving || 'Saving…', null);

    try {
      const preview = this.viewer.snapshot();
      const res = await this.api.saveDesign(this.state.toDesignPayload(), preview);
      this.ui.setSaveStatus(`${this.i18n.saved || 'Design saved!'} (#${res.id})`, true);
      if (res.breakdown) {
        this.state.set({ price: res.breakdown });
        this.ui.renderPrice(false);
      }
    } catch (err) {
      this.ui.setSaveStatus(err.message || this.i18n.saveError || 'Could not save the design.', false);
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  /** Load a shared design via ?td_design=ID. */
  async preloadDesign(id) {
    try {
      const res = await this.api.getDesign(id);
      const d = res.design || {};
      if (!d || !d.model_id) return;

      if (!this.state.get('model') || this.state.get('model').id !== d.model_id) {
        this.preloadModelId = d.model_id;
        await this.loadModel(d.model_id);
      }

      const areas = {};
      for (const [areaId, items] of Object.entries(d.areas || {})) {
        areas[areaId] = (items || []).map((it) => {
          const item = { ...it };
          // The server stores text as data, not as a bitmap, so a restored
          // text item arrives without a preview raster. Rebuild it here or
          // the item would render as an empty box.
          if (item.type === 'text' && item.text) {
            item.src = renderTextDataUrl(item.text, item.w, item.h);
          }
          return item;
        });
      }
      this.state.set({
        colorId: d.color_id || this.state.get('colorId'),
        sizeId: d.size_id || this.state.get('sizeId'),
        areas,
      });
      this.applyColor(this.state.get('colorId'));
    } catch { /* design not accessible — ignore */ }
  }
}

// Boot every designer instance on the page.
const bootAll = () => {
  document.querySelectorAll('.td-app[data-boot]').forEach((root) => {
    if (!root.dataset.booted) {
      root.dataset.booted = '1';
      try {
        new DesignerApp(root);
      } catch (err) {
        console.error('[tshirt-designer] boot failed', err);
      }
    }
  });
};

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootAll);
} else {
  bootAll();
}
