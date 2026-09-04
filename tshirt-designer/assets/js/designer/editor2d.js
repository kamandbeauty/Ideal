/**
 * 2D print-area editor.
 *
 * Renders the active print area as a physical-size canvas (cm grid, items
 * drawn in z-order) and handles selection / move / resize / rotate with
 * pointer events. All positions are in centimeters; x,y are item centers
 * relative to the area's top-left corner. Items are clamped inside the
 * area (via utils.clampItem) so the 3D print can never exceed the bounds.
 */
import { clampItem, uid } from './utils.js';

const HANDLE = 7;   // handle radius in px
const GAP = 3;      // distance between resize/rotate handles

export class Editor2D {
  constructor(canvas, { state, i18n, onChange }) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.state = state;
    this.i18n = i18n || {};
    this.onChange = onChange || null;

    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.scale = 4;        // px per cm (canvas backing scale)
    this.area = null;
    this.images = new Map();
    this.drag = null;

    this._bind();
    this._observer();
  }

  /** Load image elements (cached by src) for the current items. */
  async _loadImages() {
    const items = this.state.items();
    const jobs = items
      .filter((it) => !this.images.has(it.src))
      .map(async (it) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.src = it.src;
        try {
          await img.decode();
          this.images.set(it.src, img);
        } catch {
          this.images.set(it.src, null);
        }
      });
    if (!jobs.length) return false;
    await Promise.all(jobs);
    return true;
  }

  /**
   * Items of the active area in paint order (lowest layer first).
   * Hit testing walks the same list backwards so the topmost item wins.
   */
  _sorted() {
    return [...this.state.items()].sort((a, b) => (a.layer ?? 0) - (b.layer ?? 0));
  }

  setArea(area) {
    this.area = area;
    this._resizeCanvas();
  }

  _resizeCanvas() {
    const cssW = this.area ? this.area.max_width_cm * this.scale : 0;
    const cssH = this.area ? this.area.max_height_cm * this.scale : 0;
    const maxW = 360; // CSS pixels budget
    const fit = cssW > maxW ? maxW / cssW : 1;
    this.cssW = cssW * fit;
    this.cssH = cssH * fit;
    this.canvas.style.width = `${Math.max(1, this.cssW)}px`;
    this.canvas.style.height = `${Math.max(1, this.cssH)}px`;
    this.canvas.width = Math.round(this.cssW * this.dpr);
    this.canvas.height = Math.round(this.cssH * this.dpr);
    this.pxPerCm = this.cssW / (this.area ? this.area.max_width_cm : 1);
  }

  cm2px(v) { return v * this.pxPerCm; }
  px2cm(v) { return v / this.pxPerCm; }

  _bind() {
    const c = this.canvas;
    c.addEventListener('pointerdown', (e) => this._down(e));
    c.addEventListener('pointermove', (e) => this._move(e));
    c.addEventListener('pointerup', (e) => this._up(e));
    c.addEventListener('pointercancel', (e) => this._up(e));
    c.style.touchAction = 'none';
  }

  _observer() {
    if (typeof ResizeObserver === 'undefined') return;
    const ro = new ResizeObserver(() => {
      if (this.area) this._resizeCanvas();
    });
    ro.observe(this.canvas.parentElement || this.canvas);
  }

  _pos(e) {
    const r = this.canvas.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  }

  /** Hit-test items (top-most first) and handles of the selected item. */
  hitTest(p) {
    const items = this._sorted();
    const sel = items.find((it) => it.id === this.state.get('selectedItemId'));

    if (sel) {
      const h = this._handles(sel);
      for (const [name, hx, hy] of h.list) {
        if (Math.hypot(p.x - hx, p.y - hy) <= HANDLE + 4) return { type: name, item: sel };
      }
    }

    for (let i = items.length - 1; i >= 0; i--) {
      const it = items[i];
      const halfW = this.cm2px(it.w) / 2;
      const halfH = this.cm2px(it.h) / 2;
      const cx = this.cm2px(it.x);
      const cy = this.cm2px(it.y);
      const rot = ((it.rotation || 0) * Math.PI) / 180;
      const dx = p.x - cx;
      const dy = p.y - cy;
      const lx = dx * Math.cos(-rot) - dy * Math.sin(-rot);
      const ly = dx * Math.sin(-rot) + dy * Math.cos(-rot);
      if (Math.abs(lx) <= halfW && Math.abs(ly) <= halfH) {
        return { type: 'move', item: it };
      }
    }
    return null;
  }

  /** Corner (resize) and top (rotate) handle positions. */
  _handles(item) {
    const cx = this.cm2px(item.x);
    const cy = this.cm2px(item.y);
    const hw = this.cm2px(item.w) / 2;
    const hh = this.cm2px(item.h) / 2;
    const rot = ((item.rotation || 0) * Math.PI) / 180;
    const corner = (sx, sy) => {
      const lx = sx * hw;
      const ly = sy * hh;
      return [
        cx + lx * Math.cos(rot) - ly * Math.sin(rot),
        cy + lx * Math.sin(rot) + ly * Math.cos(rot),
      ];
    };
    const [nx, ny] = corner(0, -1);
    const rotateX = cx + (nx - cx) * 1.25;
    const rotateY = cy + (ny - cy) * 1.25;
    return {
      list: [
        ['resize-tl', ...corner(-1, -1)],
        ['resize-tr', ...corner(1, -1)],
        ['resize-br', ...corner(1, 1)],
        ['resize-bl', ...corner(-1, 1)],
        ['rotate', rotateX, rotateY],
      ],
      cx, cy, hw, hh, rot,
    };
  }

  _down(e) {
    e.preventDefault();
    this.canvas.setPointerCapture(e.pointerId);
    const p = this._pos(e);
    const hit = this.hitTest(p);
    if (!hit) {
      this.state.set({ selectedItemId: null });
      return;
    }
    this.state.set({ selectedItemId: hit.item.id });
    const item = hit.item;
    if (hit.type === 'move') {
      this.drag = { mode: 'move', id: item.id, offX: p.x - this.cm2px(item.x), offY: p.y - this.cm2px(item.y) };
    } else if (hit.type === 'rotate') {
      this.drag = { mode: 'rotate', id: item.id, startAngle: Math.atan2(p.y - this.cm2px(item.y), p.x - this.cm2px(item.x)), startRot: item.rotation || 0 };
    } else {
      this.drag = { mode: 'resize', id: item.id, corner: hit.type, start: { ...item }, p0: p };
    }
  }

  _move(e) {
    const p = this._pos(e);
    if (!this.drag) {
      // cursor feedback
      const hit = this.hitTest(p);
      this.canvas.style.cursor = hit
        ? (hit.type === 'move' ? 'move' : hit.type === 'rotate' ? 'grab' : 'nwse-resize')
        : 'default';
      return;
    }
    const item = this.state.items().find((it) => it.id === this.drag.id);
    if (!item) return;
    const area = this.area;

    if (this.drag.mode === 'move') {
      const x = this.px2cm(p.x - this.drag.offX);
      const y = this.px2cm(p.y - this.drag.offY);
      this._commit(clampItem({ ...item, x, y }, area));
    } else if (this.drag.mode === 'rotate') {
      const a = Math.atan2(p.y - this.cm2px(item.y), p.x - this.cm2px(item.x));
      let rot = this.drag.startRot + ((a - this.drag.startAngle) * 180) / Math.PI;
      this._commit({ ...item, rotation: Math.round(rot) % 360 });
    } else if (this.drag.mode === 'resize') {
      // Resize from the dragged corner, keeping the opposite corner fixed.
      const s = this.drag.start;
      const fixed = { x: this.cm2px(s.x), y: this.cm2px(s.y) };
      // Convert pointer to local (unrotated) coordinates.
      const ang = -((s.rotation || 0) * Math.PI) / 180;
      const dx = p.x - fixed.x;
      const dy = p.y - fixed.y;
      const lx = dx * Math.cos(ang) - dy * Math.sin(ang);
      const ly = dx * Math.sin(ang) + dy * Math.cos(ang);
      const sx = this.drag.corner.includes('l') ? -1 : 1;
      const sy = this.drag.corner.includes('t') ? -1 : 1;
      let w = Math.abs(lx);
      let h = Math.abs(ly);
      // Proportional resize: keep aspect from the drag.
      const ratio = s.h / s.w;
      if (w * ratio > h) h = w * ratio;
      else w = h / ratio;
      // New center keeps the fixed corner opposite the dragged one.
      const ncxLocal = fixed.x + (sx * this.cm2px(w)) / 2;
      const ncyLocal = fixed.y + (sy * this.cm2px(h)) / 2;
      // Rotate center back around the fixed corner.
      const ang2 = (s.rotation || 0) * Math.PI / 180;
      const rx = ncxLocal - fixed.x;
      const ry = ncyLocal - fixed.y;
      const ncx = fixed.x + rx * Math.cos(ang2) - ry * Math.sin(ang2);
      const ncy = fixed.y + rx * Math.sin(ang2) + ry * Math.cos(ang2);
      this._commit(clampItem({
        ...item,
        w: this.px2cm(w),
        h: this.px2cm(h),
        x: this.px2cm(ncx),
        y: this.px2cm(ncy),
      }, area));
    }
  }

  _up(e) {
    if (this.drag && this.canvas.hasPointerCapture && this.canvas.hasPointerCapture(e.pointerId)) {
      this.canvas.releasePointerCapture(e.pointerId);
    }
    if (this.drag) {
      this.drag = null;
      if (this.onChange) this.onChange();
    }
  }

  _commit(next) {
    this.state.updateItem(next.id, next);
  }

  /** Nudge with keyboard arrows. */
  nudge(dx, dy) {
    const id = this.state.get('selectedItemId');
    const item = this.state.items().find((it) => it.id === id);
    if (!item) return false;
    this._commit(clampItem({ ...item, x: item.x + dx, y: item.y + dy }, this.area));
    return true;
  }

  removeSelected() {
    const id = this.state.get('selectedItemId');
    if (!id) return false;
    this.state.removeItem(id);
    return true;
  }

  /** Add an asset at the area centre, scaled to a sane initial size. */
  addAsset(asset) {
    const area = this.area;
    if (!area) return;
    const src = asset.url || asset.file_url;
    const img = this.images.get(src) || null;
    let w = 10;
    let h = 10;
    if (img && img.naturalWidth && img.naturalHeight) {
      const ratio = img.naturalHeight / img.naturalWidth;
      w = Math.min(10, area.max_width_cm * 0.4);
      h = w * ratio;
      if (h > area.max_height_cm * 0.5) {
        h = area.max_height_cm * 0.5;
        w = h / ratio;
      }
    }
    const item = {
      id: uid(),
      type: 'asset',
      ref_id: asset.id,
      src,
      x: area.max_width_cm / 2,
      y: area.max_height_cm / 2,
      w,
      h,
      rotation: 0,
    };
    // Cache the element so the first render is instant.
    const pre = new Image();
    pre.crossOrigin = 'anonymous';
    pre.src = src;
    this.images.set(src, pre);
    this.state.addItem(clampItem(item, area));
    pre.decode().catch(() => {});
  }

  addUpload(upload) {
    this.addAsset({ id: upload.id, url: upload.url });
  }

  render() {
    const { ctx } = this;
    const W = this.canvas.width;
    const H = this.canvas.height;
    ctx.save();
    ctx.scale(this.dpr, this.dpr);
    ctx.clearRect(0, 0, this.cssW, this.cssH);

    // Area backdrop.
    ctx.fillStyle = 'rgba(255,255,255,0.04)';
    ctx.fillRect(0, 0, this.cssW, this.cssH);

    // 5 cm grid.
    ctx.strokeStyle = 'rgba(255,255,255,0.10)';
    ctx.lineWidth = 1;
    for (let x = 5; x < this.area.max_width_cm; x += 5) {
      ctx.beginPath();
      ctx.moveTo(this.cm2px(x), 0);
      ctx.lineTo(this.cm2px(x), this.cssH);
      ctx.stroke();
    }
    for (let y = 5; y < this.area.max_height_cm; y += 5) {
      ctx.beginPath();
      ctx.moveTo(0, this.cm2px(y));
      ctx.lineTo(this.cssW, this.cm2px(y));
      ctx.stroke();
    }

    // Items, painted lowest layer first.
    for (const it of this._sorted()) {
      const img = this.images.get(it.src);
      ctx.save();
      const opacity = typeof it.opacity === 'number' ? it.opacity : 1;
      ctx.globalAlpha = Math.max(0, Math.min(1, opacity));
      ctx.translate(this.cm2px(it.x), this.cm2px(it.y));
      if (it.rotation) ctx.rotate((it.rotation * Math.PI) / 180);
      if (img) {
        ctx.drawImage(img, -this.cm2px(it.w) / 2, -this.cm2px(it.h) / 2, this.cm2px(it.w), this.cm2px(it.h));
      } else {
        ctx.fillStyle = 'rgba(255,255,255,0.15)';
        ctx.fillRect(-this.cm2px(it.w) / 2, -this.cm2px(it.h) / 2, this.cm2px(it.w), this.cm2px(it.h));
        ctx.strokeStyle = 'rgba(255,255,255,0.4)';
        ctx.strokeRect(-this.cm2px(it.w) / 2, -this.cm2px(it.h) / 2, this.cm2px(it.w), this.cm2px(it.h));
      }
      ctx.restore();
    }

    // Selection.
    const sel = this.state.items().find((it) => it.id === this.state.get('selectedItemId'));
    if (sel) {
      const h = this._handles(sel);
      ctx.save();
      ctx.globalAlpha = 1;
      ctx.translate(h.cx, h.cy);
      ctx.rotate(h.rot);
      ctx.strokeStyle = '#38bdf8';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([5, 4]);
      ctx.strokeRect(-h.hw, -h.hh, h.hw * 2, h.hh * 2);
      ctx.setLineDash([]);
      ctx.restore();

      for (const [name, x, y] of h.list) {
        ctx.beginPath();
        ctx.arc(x, y, name === 'rotate' ? 5 : 4, 0, Math.PI * 2);
        ctx.fillStyle = name === 'rotate' ? '#f59e0b' : '#38bdf8';
        ctx.fill();
        ctx.strokeStyle = '#0b1728';
        ctx.stroke();
      }
    }

    ctx.restore();

    // Repaint only when loading actually produced a new image. Repainting
    // unconditionally re-entered render() every frame forever, pinning a CPU
    // core (and a mobile battery) for as long as the designer stayed open.
    this._loadImages().then((loaded) => {
      if (loaded) this.requestPaint();
    });
  }

  requestPaint() {
    if (this._paintScheduled) return;
    this._paintScheduled = true;
    requestAnimationFrame(() => {
      this._paintScheduled = false;
      this.render();
    });
  }
}
