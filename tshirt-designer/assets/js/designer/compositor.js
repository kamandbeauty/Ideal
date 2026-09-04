/**
 * Texture atlas compositor.
 *
 * Paints the garment color (and optional fabric texture) plus every design
 * item into a 2048×2048 canvas that is used as the 3D model's texture map.
 * Each print area owns a UV rectangle; items are drawn in centimeter
 * coordinates mapped onto that rectangle, so artwork follows the fabric
 * when the model rotates — it is part of the texture, never a floating
 * element.
 */
import * as THREE from 'three';
import { loadImage } from './utils.js';

export class Compositor {
  constructor() {
    this.size = 2048;
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.size;
    this.canvas.height = this.size;
    this.ctx = this.canvas.getContext('2d');
    this.texture = new THREE.CanvasTexture(this.canvas);
    this.texture.colorSpace = THREE.SRGBColorSpace;
    this.texture.flipY = false;          // glTF UV convention (origin top-left)
    this.texture.anisotropy = 4;
    this.areas = [];                      // print area shapes
    this.colorHex = '#FFFFFF';
    this.textureUrl = '';
    this.pending = 0;
    this.scheduled = false;
    this.onRepaint = null;
  }

  setPrintAreas(areas) {
    this.areas = areas;
  }

  setColor(hex, textureUrl = '') {
    this.colorHex = hex;
    this.textureUrl = textureUrl;
  }

  /** uv_rect -> pixel rect on the atlas. */
  pixelRect(area) {
    const r = area.uv_rect;
    if (!r) return null;
    return {
      x: r[0] * this.size,
      y: r[1] * this.size,
      w: (r[2] - r[0]) * this.size,
      h: (r[3] - r[1]) * this.size,
    };
  }

  /** Schedule a repaint (coalesced into one animation frame). */
  requestRepaint() {
    if (this.scheduled) return;
    this.scheduled = true;
    requestAnimationFrame(() => {
      this.scheduled = false;
      this.repaint();
    });
  }

  async repaint() {
    const ctx = this.ctx;
    const { size } = this;

    // Base color.
    ctx.save();
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;
    ctx.fillStyle = this.colorHex;
    ctx.fillRect(0, 0, size, size);
    ctx.restore();

    // Optional fabric texture overlay.
    if (this.textureUrl) {
      try {
        const img = await loadImage(this.textureUrl);
        ctx.save();
        ctx.globalAlpha = 0.35;
        ctx.globalCompositeOperation = 'multiply';
        const pattern = ctx.createPattern(img, 'repeat');
        if (pattern) {
          ctx.fillStyle = pattern;
          ctx.fillRect(0, 0, size, size);
        }
        ctx.restore();
      } catch { /* optional */ }
    }

    // Items per print area.
    const jobs = [];
    for (const area of this.areas) {
      const rect = this.pixelRect(area);
      if (!rect || !area._items || !area._items.length) continue;
      const pxPerCm = rect.w / area.max_width_cm;
      const pxPerCmY = rect.h / area.max_height_cm;

      for (const item of area._items) {
        jobs.push(
          loadImage(item.src)
            .then((img) => {
              ctx.save();
              ctx.translate(rect.x + item.x * pxPerCm, rect.y + item.y * pxPerCmY);
              if (item.rotation) ctx.rotate((item.rotation * Math.PI) / 180);
              ctx.drawImage(img, (-item.w * pxPerCm) / 2, (-item.h * pxPerCmY) / 2, item.w * pxPerCm, item.h * pxPerCmY);
              ctx.restore();
            })
            .catch(() => { /* skip missing image */ })
        );
      }
    }

    if (jobs.length) await Promise.all(jobs);
    this.texture.needsUpdate = true;
    if (this.onRepaint) this.onRepaint();
  }
}
