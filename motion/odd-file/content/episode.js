/**
 * THE ODD FILE — Episode 01: "Your Memory Is Not Real"
 * Category: Human Psychology
 *
 * 8 beats · 62 spoken words · 28.8 s · one unique still per scene.
 * `id` maps 1:1 to audio/vo/bXX.mp3 and to the beat entry in timeline.js.
 * `vo` is the recorded line — used for the SRT and the shot list.
 */

export const EPISODE = {
  code: 'FILE 001',
  category: 'HUMAN PSYCHOLOGY',
  title: 'Your Memory Is Not Real',
  fps: 30,
  beats: [
    {
      id: 'b01',
      vo: 'Your memories might be lying to you.',
      scene: 'statement',
      kicker: 'FILE 001 · HUMAN PSYCHOLOGY',
      plate: 'assets/ep01/web/b01.jpg',
      plateOpacity: 0.92,
      text: ['Your memories', 'might be', '*lying* to you.'],
      dur: 3.4,
    },
    {
      id: 'b02',
      vo: 'Every time you remember something, your brain reconstructs it.',
      scene: 'plate',
      kicker: 'MEMORY IS NOT PLAYBACK',
      plate: 'assets/ep01/web/b02.jpg',
      text: ['Every time', 'you remember,', 'your brain', '*rebuilds* it.'],
      dur: 3.4,
    },
    {
      id: 'b03',
      vo: "It doesn't simply replay a recording.",
      scene: 'statement',
      kicker: 'THE RECORDING MYTH',
      plate: 'assets/ep01/web/b03.jpg',
      plateOpacity: 0.8,
      text: ["It doesn't", 'replay a', '*recording.*'],
      dur: 3.0,
    },
    {
      id: 'b04',
      vo: 'Details can change over time.',
      scene: 'serif',
      plate: 'assets/ep01/web/b04.jpg',
      text: ['Details', '*drift.*'],
      sub: 'SMALL EDITS · EVERY RECALL',
      dur: 2.6,
    },
    {
      id: 'b05',
      vo: 'And sometimes, your mind fills in gaps with things that never happened.',
      scene: 'statement',
      plate: 'assets/ep01/web/b05.jpg',
      plateOpacity: 0.8,
      text: ['Your mind fills', 'the gaps with', 'things that', '*never happened.*'],
      dur: 4.0,
    },
    {
      id: 'b06',
      vo: "Your strongest memory isn't necessarily your most accurate one.",
      scene: 'plate',
      kicker: 'CONFIDENCE ≠ ACCURACY',
      plate: 'assets/ep01/web/b06.jpg',
      text: ['Your strongest', "memory isn't", 'your most', '*accurate* one.'],
      dur: 3.4,
    },
    {
      id: 'b07',
      vo: 'Neuroscientists call it reconsolidation.',
      scene: 'statement',
      kicker: 'NEUROSCIENCE HAS A WORD FOR IT',
      plate: 'assets/ep01/web/b07.jpg',
      plateOpacity: 0.72,
      text: ['*Reconsolidation*'],
      sub: 'The window where a memory can be rewritten.',
      dur: 2.6,
    },
    {
      id: 'b08',
      vo: 'So every time you remember, you rewrite the file.',
      scene: 'tagline',
      plate: 'assets/ep01/web/b08.jpg',
      plateOpacity: 0.8,
      text: ['So every time', 'you remember,', 'you rewrite', 'the *file.*'],
      brand: 'THE ODD FILE',
      handle: 'NOT EVERYTHING IS WHAT IT SEEMS',
      dur: 3.6,
    },
  ],
};
