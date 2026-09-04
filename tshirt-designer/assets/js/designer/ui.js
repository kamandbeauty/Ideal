/**
 * DOM rendering for all designer panels.
 *
 * Every panel is rendered from state via data-td-el hooks declared in
 * templates/designer.php. All dynamic strings are escaped.
 */
import { esc, formatPrice, formatCm } from './utils.js';

const el = (root, name) => root.querySelector(`[data-td-el="${name}"]`);

export class UI {
  constructor(root, { state, api, i18n, currency, uploadMaxMb, onChange, onEditorAction }) {
    this.root = root;
    this.state = state;
    this.api = api;
    this.i18n = i18n || {};
    this.currency = currency || {};
    this.uploadMaxMb = uploadMaxMb || 5;
    this.onChange = onChange || null;
    this.onEditorAction = onEditorAction || null;

    this.refs = {
      models: el(root, 'models'),
      colors: el(root, 'colors'),
      sizes: el(root, 'sizes'),
      stage: el(root, 'stage'),
      loading: el(root, 'loading'),
      webglError: el(root, 'webglError'),
      loadError: el(root, 'loadError'),
      resetView: el(root, 'resetView'),
      areas: el(root, 'areas'),
      editor: el(root, 'editor'),
      layers: el(root, 'layers'),
      cats: el(root, 'cats'),
      assets: el(root, 'assets'),
      upload: el(root, 'upload'),
      uploadInput: el(root, 'uploadInput'),
      uploadHint: el(root, 'uploadHint'),
      uploadStatus: el(root, 'uploadStatus'),
      priceLines: el(root, 'priceLines'),
      priceTotal: el(root, 'priceTotal'),
      save: el(root, 'save'),
      saveStatus: el(root, 'saveStatus'),
      toolsToggle: el(root, 'toolsToggle'),
    };

    this._bindToolsToggle();
    this._bindTabs();
    this._bindViews();
    this._bindUpload();
    this._bindLayers();
    this._bindSave();

    if (this.refs.uploadHint) {
      this.refs.uploadHint.textContent = `${this.i18n.uploadHint || 'JPG, PNG or WEBP — up to'} ${this.uploadMaxMb}MB`;
    }
  }

  // ------------------------------------------------------------ bindings

  /** Mobile: collapse the tools panel into a drawer. */
  _bindToolsToggle() {
    const btn = this.refs.toolsToggle;
    if (!btn) return;
    btn.addEventListener('click', () => {
      const open = this.root.classList.toggle('is-tools-open');
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }

  _bindTabs() {
    const tabs = this.root.querySelectorAll('[data-tab]');
    const panes = this.root.querySelectorAll('[data-tabpane]');
    tabs.forEach((tab) => {
      tab.addEventListener('click', () => {
        const name = tab.getAttribute('data-tab');
        tabs.forEach((t) => t.classList.toggle('is-active', t === tab));
        panes.forEach((p) => p.classList.toggle('is-active', p.getAttribute('data-tabpane') === name));
      });
    });
  }

  _bindViews() {
    this.root.querySelectorAll('[data-view]').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.root.querySelectorAll('[data-view]').forEach((b) => b.classList.toggle('is-active', b === btn));
        if (this.onView) this.onView(btn.getAttribute('data-view'));
      });
    });
    if (this.refs.resetView) {
      this.refs.resetView.addEventListener('click', () => {
        this.root.querySelectorAll('[data-view]').forEach((b) => b.classList.toggle('is-active', b.getAttribute('data-view') === 'front'));
        if (this.onView) this.onView('reset');
      });
    }
  }

  _bindUpload() {
    const input = this.refs.uploadInput;
    const zone = this.refs.upload;
    if (!input || !zone) return;

    input.addEventListener('change', () => {
      if (input.files && input.files[0]) this.uploadFile(input.files[0]);
      input.value = '';
    });

    zone.addEventListener('dragover', (e) => {
      e.preventDefault();
      zone.classList.add('is-dragover');
    });
    zone.addEventListener('dragleave', () => zone.classList.remove('is-dragover'));
    zone.addEventListener('drop', (e) => {
      e.preventDefault();
      zone.classList.remove('is-dragover');
      const file = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
      if (file) this.uploadFile(file);
    });
  }

  _bindLayers() {
    this.root.querySelectorAll('[data-layer]').forEach((btn) => {
      btn.addEventListener('click', () => {
        if (this.onEditorAction) this.onEditorAction(btn.getAttribute('data-layer'));
      });
    });
  }

  _bindSave() {
    if (this.refs.save) {
      this.refs.save.addEventListener('click', () => {
        if (this.onSave) this.onSave();
      });
    }
  }

  // ------------------------------------------------------------ uploads

  async uploadFile(file) {
    const status = this.refs.uploadStatus;
    const show = (msg, ok) => {
      if (!status) return;
      status.textContent = msg;
      status.classList.remove('td-hidden', 'is-error', 'is-ok');
      if (!ok) status.classList.add('is-error');
      else status.classList.add('is-ok');
    };

    const extOk = /\.(jpe?g|png|webp)$/i.test(file.name);
    const typeOk = /^image\/(jpeg|png|webp)$/i.test(file.type);
    if (!extOk || !typeOk) {
      show(this.i18n.uploadBadType || 'Only JPG, PNG and WEBP images are allowed.', false);
      return;
    }
    if (file.size > this.uploadMaxMb * 1024 * 1024) {
      show(this.i18n.uploadTooBig || 'The file is larger than the allowed size.', false);
      return;
    }

    show(this.i18n.uploading || 'Uploading…', true);
    try {
      const res = await this.api.upload(file);
      show(this.i18n.uploadOk || '✓', true);
      if (this.onUploaded) this.onUploaded(res.upload);
    } catch (err) {
      show(err.message, false);
    }
  }

  // ------------------------------------------------------------ renderers

  renderModels() {
    const { models } = this.refs;
    if (!models) return;
    const list = this.state.get('models');
    const current = this.state.get('model');
    models.innerHTML = '';
    for (const m of list) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'td-model' + (current && current.id === m.id ? ' is-active' : '');
      if (m.preview_url) {
        const img = document.createElement('img');
        img.src = m.preview_url;
        img.alt = esc(m.name);
        img.loading = 'lazy';
        btn.appendChild(img);
      }
      const label = document.createElement('span');
      label.className = 'td-model__name';
      label.textContent = m.name;
      btn.appendChild(label);
      btn.addEventListener('click', () => {
        if (this.onSelectModel) this.onSelectModel(m.id);
      });
      models.appendChild(btn);
    }
  }

  renderColors() {
    const { colors } = this.refs;
    if (!colors) return;
    const model = this.state.get('model');
    colors.innerHTML = '';
    if (!model) return;
    for (const c of model.colors || []) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'td-swatch' + (this.state.get('colorId') === c.id ? ' is-active' : '');
      btn.title = c.name;
      const dot = document.createElement('span');
      dot.className = 'td-swatch__dot';
      dot.style.background = c.hex;
      btn.appendChild(dot);
      const name = document.createElement('span');
      name.className = 'td-swatch__name';
      name.textContent = c.name;
      btn.appendChild(name);
      btn.addEventListener('click', () => {
        if (this.onSelectColor) this.onSelectColor(c.id);
      });
      colors.appendChild(btn);
    }
  }

  renderSizes() {
    const { sizes } = this.refs;
    if (!sizes) return;
    const model = this.state.get('model');
    sizes.innerHTML = '';
    if (!model) return;
    for (const s of model.sizes || []) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'td-size' + (this.state.get('sizeId') === s.id ? ' is-active' : '');
      btn.textContent = s.name;
      if (s.price_modifier > 0) btn.dataset.surcharge = '+' + formatPrice(s.price_modifier, this.currency);
      btn.addEventListener('click', () => {
        if (this.onSelectSize) this.onSelectSize(s.id);
      });
      sizes.appendChild(btn);
    }
  }

  renderAreas() {
    const { areas } = this.refs;
    if (!areas) return;
    const model = this.state.get('model');
    areas.innerHTML = '';
    if (!model) return;
    for (const a of model.print_areas || []) {
      const count = (this.state.get('areas')[a.id] || []).length;
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'td-area' + (this.state.get('activeAreaId') === a.id ? ' is-active' : '');
      const label = document.createElement('span');
      label.textContent = a.name;
      btn.appendChild(label);
      if (count > 0) {
        const badge = document.createElement('span');
        badge.className = 'td-area__count';
        badge.textContent = String(count);
        btn.appendChild(badge);
      }
      const dims = document.createElement('small');
      dims.className = 'td-area__dims';
      dims.textContent = `${formatCm(a.max_width_cm, this.i18n)}×${formatCm(a.max_height_cm, this.i18n)}`;
      btn.appendChild(dims);
      btn.addEventListener('click', () => {
        if (this.onSelectArea) this.onSelectArea(a.id);
      });
      areas.appendChild(btn);
    }
  }

  renderCats() {
    const { cats } = this.refs;
    if (!cats) return;
    const catsDef = this.i18n.categories || {};
    const list = ['all', 'logo', 'text', 'sport', 'animal', 'nature', 'kids', 'fantasy', 'other'];
    const active = this.state.get('assetCategory');
    cats.innerHTML = '';
    for (const key of list) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'td-cat' + (active === key ? ' is-active' : '');
      btn.textContent = catsDef[key] || key;
      btn.addEventListener('click', () => {
        if (this.onSelectCategory) this.onSelectCategory(key);
      });
      cats.appendChild(btn);
    }
  }

  renderAssets() {
    const { assets } = this.refs;
    if (!assets) return;
    const list = this.state.get('assets');
    assets.innerHTML = '';
    if (!list.length) {
      const empty = document.createElement('p');
      empty.className = 'td-assets__empty';
      empty.textContent = '—';
      assets.appendChild(empty);
      return;
    }
    for (const a of list) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'td-asset';
      btn.title = a.name;
      const img = document.createElement('img');
      img.src = a.thumb_url || a.url;
      img.alt = esc(a.name);
      img.loading = 'lazy';
      btn.appendChild(img);
      btn.addEventListener('click', () => {
        if (this.onAddAsset) this.onAddAsset(a);
      });
      assets.appendChild(btn);
    }
  }

  renderLayers() {
    const { layers } = this.refs;
    if (!layers) return;
    const items = this.state.items();
    const selected = this.state.get('selectedItemId');
    layers.innerHTML = '';
    if (!items.length) {
      const li = document.createElement('li');
      li.className = 'td-layers__empty';
      li.textContent = this.i18n.noLayers || '';
      layers.appendChild(li);
      return;
    }
    // Top-most layer first in the list.
    const ordered = [...items].reverse();
    for (const it of ordered) {
      const li = document.createElement('li');
      li.className = 'td-layer' + (it.id === selected ? ' is-active' : '');
      const thumb = document.createElement('img');
      thumb.src = it.src;
      thumb.alt = '';
      thumb.loading = 'lazy';
      li.appendChild(thumb);
      const name = document.createElement('span');
      name.className = 'td-layer__name';
      name.textContent = `${formatCm(it.w, this.i18n)}×${formatCm(it.h, this.i18n)}`;
      li.appendChild(name);
      li.addEventListener('click', () => {
        this.state.set({ selectedItemId: it.id });
      });
      layers.appendChild(li);
    }
  }

  renderPrice(pending) {
    const { priceLines, priceTotal } = this.refs;
    const price = this.state.get('price');
    if (!priceLines || !priceTotal) return;

    priceLines.innerHTML = '';
    if (pending && !price) {
      priceTotal.textContent = this.i18n.calculating || '…';
      return;
    }
    if (!price) {
      priceTotal.textContent = '—';
      return;
    }

    const rows = [
      [this.i18n.basePrice || 'Base', price.base_price],
    ];
    if (price.size_modifier) {
      rows.push([this.i18n.sizePrice || 'Size', price.size_modifier]);
    }
    const areaNames = {};
    const model = this.state.get('model');
    if (model) {
      for (const a of model.print_areas || []) areaNames[a.id] = a.name;
    }
    for (const [areaId, info] of Object.entries(price.areas || {})) {
      if (!info || !info.items || !info.items.length) continue;
      const label = `${this.i18n.prints || 'Prints'} — ${info.name || areaNames[areaId] || areaId}`;
      rows.push([label, info.subtotal]);
    }

    for (const [label, value] of rows) {
      const line = document.createElement('div');
      line.className = 'td-price__line';
      const l = document.createElement('span');
      l.textContent = label;
      const v = document.createElement('span');
      v.textContent = formatPrice(value, this.currency);
      line.append(l, v);
      priceLines.appendChild(line);
    }

    priceTotal.textContent = formatPrice(price.total, this.currency);
  }

  setSaveStatus(msg, ok) {
    const s = this.refs.saveStatus;
    if (!s) return;
    if (!msg) {
      s.classList.add('td-hidden');
      s.textContent = '';
      return;
    }
    s.classList.remove('td-hidden');
    s.classList.toggle('is-error', ok === false);
    s.classList.toggle('is-ok', ok === true);
    s.textContent = msg;
  }

  showLoading(show) {
    if (this.refs.loading) this.refs.loading.classList.toggle('td-hidden', !show);
  }

  showLoadError(show) {
    if (this.refs.loadError) this.refs.loadError.classList.toggle('td-hidden', !show);
  }

  showWebglError(show) {
    if (this.refs.webglError) this.refs.webglError.classList.toggle('td-hidden', !show);
  }
}
