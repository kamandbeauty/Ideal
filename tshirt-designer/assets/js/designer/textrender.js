/**
 * Client-side text rasterizer.
 *
 * Text items are stored as structured data (content, font, color, weight,
 * alignment, direction) and are re-rendered server-side at print resolution
 * by TShirtDesigner\Text_Engine. This module only produces the *preview*
 * bitmap the 2D editor and the 3D texture compositor draw, so a text item can
 * flow through exactly the same painting path as artwork and uploads: both
 * read `item.src`.
 *
 * The raster is deliberately never sent to the server — it would be a
 * flattened, uneditable copy of data the server already has and can render
 * more accurately with the real TTF.
 */

/** Pixels per centimetre used for the preview raster. */
const PREVIEW_DPCM = 40;

/** Hard ceiling so a huge print area cannot allocate a giant canvas. */
const MAX_PX = 2048;

const cache = new Map();
const MAX_CACHE = 120;

/** Font stacks keyed by slug, filled from boot data. */
let fontStacks = {};

export function setFontStacks(fonts) {
  fontStacks = {};
  for (const f of fonts || []) {
    if (f && f.slug) fontStacks[f.slug] = f.stack || 'sans-serif';
  }
}

function stackFor(slug) {
  return fontStacks[slug] || 'sans-serif';
}

/** Arabic/Hebrew ranges — mirrors Text_Engine::detect_direction(). */
export function detectDirection(content) {
  return /[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/.test(content)
    ? 'rtl'
    : 'ltr';
}

/** Normalise a text payload the same way the server does. */
export function normalizeText(text) {
  const content = String(text?.content ?? '').slice(0, 200);
  return {
    content,
    font: text?.font || 'sans',
    color: text?.color || '#111111',
    bold: !!text?.bold,
    italic: !!text?.italic,
    align: ['left', 'center', 'right'].includes(text?.align) ? text.align : 'center',
    direction: ['rtl', 'ltr'].includes(text?.direction)
      ? text.direction
      : detectDirection(content),
  };
}

function cacheKey(text, widthCm, heightCm) {
  const t = normalizeText(text);
  return [
    t.content, t.font, t.color, t.bold, t.italic, t.align, t.direction,
    Math.round(widthCm * 10), Math.round(heightCm * 10),
  ].join('|');
}

/**
 * Measure the natural aspect ratio of a text block so a newly added item can
 * be sized sensibly instead of being stretched into an arbitrary box.
 *
 * @returns {{ratio: number, lines: string[]}} height / width.
 */
export function measure(text) {
  const t = normalizeText(text);
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  const size = 100;
  ctx.font = fontSpec(t, size);

  const lines = t.content.split('\n');
  let widest = 1;
  for (const line of lines) {
    widest = Math.max(widest, ctx.measureText(line || ' ').width);
  }
  const lineHeight = size * 1.25;
  const height = lineHeight * lines.length;
  return { ratio: height / widest, lines };
}

function fontSpec(t, pxSize) {
  const style = t.italic ? 'italic ' : '';
  const weight = t.bold ? '700 ' : '400 ';
  return `${style}${weight}${pxSize}px ${stackFor(t.font)}`;
}

/**
 * Render a text item to a transparent data URL sized to the item's box.
 *
 * The glyphs are scaled to fill the box the user dragged out, which is what
 * makes resizing a text item behave like resizing artwork.
 *
 * @param {object} text     Text payload.
 * @param {number} widthCm  Item width in cm.
 * @param {number} heightCm Item height in cm.
 * @returns {string} data: URL (PNG with alpha).
 */
export function renderTextDataUrl(text, widthCm, heightCm) {
  const key = cacheKey(text, widthCm, heightCm);
  if (cache.has(key)) return cache.get(key);

  const t = normalizeText(text);
  const w = Math.max(1, Math.min(MAX_PX, Math.round(widthCm * PREVIEW_DPCM)));
  const h = Math.max(1, Math.min(MAX_PX, Math.round(heightCm * PREVIEW_DPCM)));

  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');

  const lines = t.content.split('\n');
  const count = Math.max(1, lines.length);

  // Find the largest font size that fits the box on both axes.
  let size = h / (count * 1.25);
  ctx.font = fontSpec(t, size);
  let widest = 1;
  for (const line of lines) {
    widest = Math.max(widest, ctx.measureText(line || ' ').width);
  }
  if (widest > w) {
    size *= w / widest;
    ctx.font = fontSpec(t, size);
  }

  ctx.fillStyle = t.color;
  ctx.textBaseline = 'middle';
  ctx.direction = t.direction;

  // Horizontal anchor. In RTL the visual meaning of left/right is preserved
  // by anchoring to the physical edge, because the print file is physical.
  let anchorX = w / 2;
  if (t.align === 'left') {
    ctx.textAlign = 'left';
    anchorX = 0;
  } else if (t.align === 'right') {
    ctx.textAlign = 'right';
    anchorX = w;
  } else {
    ctx.textAlign = 'center';
  }

  const lineHeight = size * 1.25;
  const blockHeight = lineHeight * count;
  const startY = (h - blockHeight) / 2 + lineHeight / 2;

  for (let i = 0; i < count; i += 1) {
    ctx.fillText(lines[i], anchorX, startY + i * lineHeight);
  }

  const url = canvas.toDataURL('image/png');

  // Bounded LRU: text is re-rasterised on every keystroke while typing.
  if (cache.size >= MAX_CACHE) {
    cache.delete(cache.keys().next().value);
  }
  cache.set(key, url);
  return url;
}
