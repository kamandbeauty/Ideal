/**
 * Central state store with a tiny pub/sub.
 */
export class State {
  constructor() {
    this.data = {
      models: [],
      model: null,          // full model detail
      colorId: 0,
      sizeId: 0,
      activeAreaId: 0,
      areas: {},             // areaId -> items[]
      selectedItemId: null,
      assets: [],
      assetCategory: 'all',
      price: null,
      pricePending: false,
    };
    this.subs = new Set();
  }

  get(key) { return this.data[key]; }

  set(patch) {
    this.data = { ...this.data, ...patch };
    this.emit();
  }

  items(areaId = null) {
    const id = areaId ?? this.data.activeAreaId;
    return this.data.areas[id] || [];
  }

  activeArea() {
    if (!this.data.model) return null;
    return this.data.model.print_areas.find((a) => a.id === this.data.activeAreaId) || null;
  }

  addItem(item) {
    const id = this.data.activeAreaId;
    if (!id) return;
    const items = this._reindex([...this.items(id), item]);
    this.set({ areas: { ...this.data.areas, [id]: items }, selectedItemId: item.id });
  }

  updateItem(itemId, patch) {
    const id = this.data.activeAreaId;
    const items = this.items(id).map((it) => (it.id === itemId ? { ...it, ...patch } : it));
    this.set({ areas: { ...this.data.areas, [id]: items } });
  }

  removeItem(itemId) {
    const id = this.data.activeAreaId;
    const items = this._reindex(this.items(id).filter((it) => it.id !== itemId));
    const sel = this.data.selectedItemId === itemId ? null : this.data.selectedItemId;
    this.set({ areas: { ...this.data.areas, [id]: items }, selectedItemId: sel });
  }

  duplicateItem(itemId) {
    const src = this.items().find((it) => it.id === itemId);
    if (!src) return;
    const copy = {
      ...src,
      id: 'i-' + Math.random().toString(36).slice(2, 10),
      x: Math.min(src.x + 2, (this.activeArea() || { max_width_cm: 30 }).max_width_cm - 1),
      y: Math.min(src.y + 2, (this.activeArea() || { max_height_cm: 35 }).max_height_cm - 1),
    };
    this.addItem(copy);
  }

  moveItem(itemId, dir) {
    const id = this.data.activeAreaId;
    const items = [...this.items(id)];
    const idx = items.findIndex((it) => it.id === itemId);
    if (idx < 0) return;
    const to = dir === 'forward' ? idx + 1 : idx - 1;
    if (to < 0 || to >= items.length) return;
    const [item] = items.splice(idx, 1);
    items.splice(to, 0, item);
    this.set({ areas: { ...this.data.areas, [id]: this._reindex(items) } });
  }

  /** Rewrite `layer` so it matches the array order after a reorder. */
  _reindex(items) {
    return items.map((it, index) => (it.layer === index ? it : { ...it, layer: index }));
  }

  /** Serialise the design for the API (server recomputes everything). */
  toDesignPayload() {
    const areas = {};
    for (const [areaId, items] of Object.entries(this.data.areas)) {
      if (!items.length) continue;
      areas[areaId] = items.map((it, index) => {
        const row = {
          id: it.id,
          type: it.type,
          ref_id: it.ref_id,
          x: it.x,
          y: it.y,
          w: it.w,
          h: it.h,
          rotation: it.rotation || 0,
          // Array position IS the z-order; send it explicitly so the server
          // never has to rely on JSON key ordering to reproduce the stack.
          layer: index,
          opacity: typeof it.opacity === 'number' ? it.opacity : 1,
        };
        // Text items carry their typography so the server can re-render them
        // at print resolution instead of storing a flattened bitmap.
        if (it.type === 'text' && it.text) row.text = it.text;
        return row;
      });
    }
    return {
      product_type: this.data.model ? this.data.model.product_type || '' : '',
      model_id: this.data.model ? this.data.model.id : 0,
      color_id: this.data.colorId,
      size_id: this.data.sizeId,
      areas,
    };
  }

  /** Total item count across areas. */
  itemCount() {
    return Object.values(this.data.areas).reduce((n, items) => n + items.length, 0);
  }

  subscribe(fn) {
    this.subs.add(fn);
    return () => this.subs.delete(fn);
  }

  emit() {
    for (const fn of this.subs) {
      try { fn(this.data); } catch (e) { console.error('[td] subscriber error', e); }
    }
  }
}
