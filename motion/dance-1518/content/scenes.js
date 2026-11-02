// صحنه‌به‌صحنه — یک صحنه برای هر جملهٔ نریشن.
// plate  : فایل پس‌زمینه در assets/plates (بدون شخصیت، بدون متن)
// actors : عروسک‌های متحرک روی صحنه (rig دوبعدی، مفاصل واقعی)
// crowd  : تعداد عروسک ساده در عمق صحنه
// cam    : حرکت دوربین روی پلیت (push/pull/drift/tilt)

export const SCENES = [
  {
    id: 1, plate: 's01',
    cam: { from: 1.10, to: 1.00, driftX: -18, driftY: -8 },
    actors: [{ type: 'woman', x: 0.5, y: 0.782, scale: 1.0, mood: 'still', seed: 0.1 }],
    crowd: 0, fog: 0.35,
  },
  {
    id: 2, plate: 's02',
    cam: { from: 1.04, to: 1.12, driftX: 14, driftY: 0 },
    actors: [{ type: 'woman', x: 0.46, y: 0.786, scale: 1.05, mood: 'dance', seed: 0.3 }],
    crowd: 0, fog: 0.2,
  },
  {
    id: 3, plate: 's03',
    cam: { from: 1.14, to: 1.04, driftX: -10, driftY: 4 },
    actors: [{ type: 'woman', x: 0.5, y: 0.786, scale: 1.12, mood: 'dance', seed: 0.55 }],
    crowd: 0, fog: 0.15,
  },
  {
    id: 4, plate: 's04',
    cam: { from: 1.02, to: 1.13, driftX: 8, driftY: -6 },
    actors: [{ type: 'woman', x: 0.5, y: 0.786, scale: 1.0, mood: 'dance', seed: 0.8 }],
    crowd: 0, fog: 0.3,
  },
  {
    id: 5, plate: 's05',
    cam: { from: 1.12, to: 1.0, driftX: 0, driftY: 6 },
    actors: [{ type: 'woman', x: 0.42, y: 0.81, scale: 0.95, mood: 'dance', seed: 0.2 }],
    crowd: 14, fog: 0.25,
  },
  {
    id: 6, plate: 's06',
    cam: { from: 1.06, to: 1.14, driftX: -12, driftY: 0 },
    actors: [
      { type: 'woman', x: 0.38, y: 0.81, scale: 0.9, mood: 'collapse', seed: 0.4 },
      { type: 'man', x: 0.66, y: 0.81, scale: 0.95, mood: 'collapse', seed: 0.7 },
    ],
    crowd: 5, fog: 0.3,
  },
  {
    id: 7, plate: 's07',
    cam: { from: 1.0, to: 1.1, driftX: 10, driftY: 0 },
    actors: [
      { type: 'official', x: 0.34, y: 0.81, scale: 1.02, mood: 'still', seed: 0.15 },
      { type: 'official', x: 0.62, y: 0.81, scale: 0.98, mood: 'still', seed: 0.6, flip: true },
    ],
    crowd: 6, fog: 0.2,
  },
  {
    id: 8, plate: 's08',
    cam: { from: 1.1, to: 1.02, driftX: -8, driftY: 0 },
    actors: [
      { type: 'musician', x: 0.3, y: 0.81, scale: 0.95, mood: 'play', seed: 0.25 },
      { type: 'musician', x: 0.7, y: 0.81, scale: 0.92, mood: 'play', seed: 0.75, flip: true },
    ],
    crowd: 10, fog: 0.15,
  },
  {
    id: 9, plate: 's09',
    cam: { from: 1.14, to: 1.0, driftX: 0, driftY: 0 },
    actors: [],
    crowd: 26, fog: 0.35,
  },
  {
    id: 10, plate: 's10',
    cam: { from: 1.02, to: 1.12, driftX: -14, driftY: -4 },
    actors: [{ type: 'official', x: 0.3, y: 0.81, scale: 1.0, mood: 'still', seed: 0.35 }],
    crowd: 12, fog: 0.25,
  },
  {
    id: 11, plate: 's11',
    cam: { from: 1.12, to: 1.02, driftX: 0, driftY: 0 },
    actors: [],
    crowd: 3, fog: 0.45,
  },
  {
    id: 12, plate: 's12',
    cam: { from: 1.0, to: 1.06, driftX: 0, driftY: 0 },
    actors: [{ type: 'woman', x: 0.5, y: 0.782, scale: 0.9, mood: 'still', seed: 0.5 }],
    crowd: 0, fog: 0.4,
  },
  {
    id: 13, plate: 's13',
    cam: { from: 1.06, to: 1.14, driftX: 6, driftY: 0 },
    actors: [
      { type: 'woman', x: 0.3, y: 0.792, scale: 0.88, mood: 'collapse', seed: 0.2 },
      { type: 'man', x: 0.55, y: 0.793, scale: 0.86, mood: 'collapse', seed: 0.9 },
      { type: 'woman', x: 0.76, y: 0.792, scale: 0.84, mood: 'collapse', seed: 0.45 },
    ],
    crowd: 3, fog: 0.3,
  },
  {
    id: 14, plate: 's14',
    cam: { from: 1.14, to: 1.03, driftX: -6, driftY: 4 },
    actors: [], crowd: 0, fog: 0.1,
  },
  {
    id: 15, plate: 's15',
    cam: { from: 1.0, to: 1.1, driftX: 0, driftY: 0 },
    actors: [{ type: 'woman', x: 0.5, y: 0.81, scale: 1.15, mood: 'still', seed: 0.65 }],
    crowd: 0, fog: 0.35,
  },
  {
    id: 16, plate: 's16',
    cam: { from: 1.12, to: 1.0, driftX: 0, driftY: -10 },
    actors: [], crowd: 30, fog: 0.3,
  },
  {
    id: 17, plate: 's17',
    cam: { from: 1.0, to: 1.08, driftX: 0, driftY: 0 },
    actors: [], crowd: 0, fog: 0.15,
  },
  {
    id: 18, plate: 's18',
    cam: { from: 1.08, to: 1.0, driftX: 0, driftY: 0 },
    actors: [], crowd: 0, fog: 0.4,
  },
  {
    id: 19, plate: 's19',
    cam: { from: 1.0, to: 1.1, driftX: 0, driftY: 0 },
    actors: [], crowd: 0, fog: 0.25,
  },
  {
    id: 20, plate: 's20',
    cam: { from: 1.1, to: 1.0, driftX: 0, driftY: 0 },
    actors: [{ type: 'woman', x: 0.5, y: 0.786, scale: 1.05, mood: 'wave', seed: 0.85 }],
    crowd: 0, fog: 0.2,
  },
];
