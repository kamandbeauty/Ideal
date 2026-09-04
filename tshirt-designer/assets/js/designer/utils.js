/**
 * Shared helpers: bounds math (mirrors TShirtDesigner\Print_Area_Bounds in
 * PHP), currency formatting and image caching.
 */

export const EPS = 1e-9;

/** Axis-aligned bounding box of a rotated rectangle (cm). */
export function rotatedAabb(w, h, rotationDeg) {
  const a = (Math.abs(rotationDeg) % 180) * Math.PI / 180;
  const c = Math.abs(Math.cos(a));
  const s = Math.abs(Math.sin(a));
  return { w: w * c + h * s, h: w * s + h * c };
}

/**
 * Clamp an item so its rotated AABB fits and stays inside the print area.
 * Same algorithm as Print_Area_Bounds::clamp_item() on the server.
 *
 * @param {object} item  Design item (x, y = center in cm from area top-left).
 * @param {object} area  Print area ({max_width_cm, max_height_cm}).
 */
export function clampItem(item, area) {
  const maxW = area.max_width_cm;
  const maxH = area.max_height_cm;
  let { w, h } = item;
  const r = item.rotation || 0;

  let aabb = rotatedAabb(w, h, r);
  if (aabb.w > maxW + EPS || aabb.h > maxH + EPS) {
    const scale = Math.min(maxW / aabb.w, maxH / aabb.h);
    w *= scale;
    h *= scale;
    aabb = rotatedAabb(w, h, r);
  }

  const halfW = aabb.w / 2;
  const halfH = aabb.h / 2;
  const x = Math.min(Math.max(item.x, halfW), Math.max(0, maxW - halfW));
  const y = Math.min(Math.max(item.y, halfH), Math.max(0, maxH - halfH));

  return {
    ...item,
    x: Math.round(x * 100) / 100,
    y: Math.round(y * 100) / 100,
    w: Math.round(w * 100) / 100,
    h: Math.round(h * 100) / 100,
    rotation: Math.round(r * 10) / 10,
  };
}

/** Format a number with the currency settings from boot data. */
export function formatPrice(amount, currency) {
  const c = currency || { symbol: '', position: 'after', decimals: 0, thousand_sep: ',', decimal_sep: '.' };
  const fixed = Number(amount).toFixed(c.decimals || 0);
  const [int, dec] = fixed.split('.');
  const grouped = int.replace(/\B(?=(\d{3})+(?!\d))/g, c.thousand_sep || ',');
  const value = dec ? `${grouped}${c.decimal_sep || '.'}${dec}` : grouped;
  return c.position === 'before' ? `${c.symbol}${value}` : `${value} ${c.symbol}`;
}

/** Format centimeters for labels. */
export function formatCm(v, i18n) {
  return `${Math.round(v * 10) / 10} ${i18n.cm || 'cm'}`;
}

/** Random item id. */
export function uid() {
  return 'i-' + Math.random().toString(36).slice(2, 10);
}

const imageCache = new Map();

/**
 * Load (and cache) an HTMLImageElement for a URL.
 * @returns {Promise<HTMLImageElement>}
 */
export function loadImage(src) {
  if (imageCache.has(src)) {
    const entry = imageCache.get(src);
    if (entry instanceof HTMLImageElement) return Promise.resolve(entry);
    return entry;
  }
  const promise = new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      imageCache.set(src, img);
      resolve(img);
    };
    img.onerror = () => {
      imageCache.delete(src);
      reject(new Error(`Failed to load image: ${src}`));
    };
    img.src = src;
  });
  imageCache.set(src, promise);
  return promise;
}

/** Debounce helper. */
export function debounce(fn, ms) {
  let t;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

/** Escape HTML. */
export function esc(s) {
  return String(s).replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[ch]));
}
