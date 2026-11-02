/**
 * THE ODD FILE — Episode 02: "The Spotlight Effect"
 * Category: Human Psychology · format: landscape 16:9 (YouTube)
 *
 * 8 beats · 76 spoken words · one unique still per scene.
 * The user's long-form treatment is compressed here to the channel cut;
 * the full source text is kept in episodes/ep-002/package.md.
 */

export const EPISODE = {
  code: 'FILE 002',
  category: 'HUMAN PSYCHOLOGY',
  title: 'The Spotlight Effect',
  format: 'landscape',
  fps: 30,
  beats: [
    {
      id: 'b01',
      vo: 'You walk into a room, and every eye is on you.',
      scene: 'statement',
      kicker: 'FILE 002 · HUMAN PSYCHOLOGY',
      plate: 'assets/ep02/web/b01.jpg',
      plateOpacity: 0.9,
      text: ['Every eye', 'is on', '*you.*'],
      dur: 3.6,
    },
    {
      id: 'b02',
      vo: 'It has a name: the spotlight effect.',
      scene: 'code',
      kicker: 'THIS HAS A NAME',
      text: ['The Spotlight', 'Effect.'],
      footnote: 'THE ILLUSION OF BEING SEEN',
      plate: 'assets/ep02/web/b02.jpg',
      plateOpacity: 0.8,
      dur: 3.2,
    },
    {
      id: 'b03',
      vo: "You're sure they see the coffee stain on your shirt.",
      scene: 'plate',
      kicker: 'THE STAIN NOBODY SAW',
      plate: 'assets/ep02/web/b04.jpg',
      text: ["You're sure", 'they see', 'the *stain.*'],
      dur: 4.0,
    },
    {
      id: 'b04',
      vo: 'Your brain assumes people notice you.',
      scene: 'statement',
      plate: 'assets/ep02/web/b03.jpg',
      plateOpacity: 0.85,
      text: ['Your brain', 'assumes they', '*notice.*'],
      dur: 3.4,
    },
    {
      id: 'b05',
      vo: 'In a famous study, students wore an embarrassing T-shirt.',
      scene: 'plate',
      kicker: 'CORNELL · 2000',
      plate: 'assets/ep02/web/b05.jpg',
      text: ['The T-shirt', '*experiment.*'],
      dur: 4.2,
    },
    {
      id: 'b06',
      vo: 'They guessed half the room would notice. Fewer than a quarter did.',
      scene: 'figure',
      kicker: 'WHAT ACTUALLY HAPPENED',
      plate: 'assets/ep02/web/b06.jpg',
      plateOpacity: 0.62,
      from: 50,
      to: 23,
      suffix: '%',
      unit: 'NOTICED THE SHIRT',
      sub: 'Students expected about 50. Fewer than 23 noticed.',
      dur: 4.4,
    },
    {
      id: 'b07',
      vo: 'The spotlight in your head burns brighter than the real one.',
      scene: 'statement',
      plate: 'assets/ep02/web/b07.jpg',
      plateOpacity: 0.85,
      text: ['The spotlight', 'in your head', 'is *brighter.*'],
      dur: 4.0,
    },
    {
      id: 'b08',
      vo: 'Everyone is the main character of their own story.',
      scene: 'tagline',
      plate: 'assets/ep02/web/b08.jpg',
      plateOpacity: 0.85,
      text: ['Everyone is', 'the main character', 'of their own *story.*'],
      brand: 'THE ODD FILE',
      handle: 'NOT EVERYTHING IS WHAT IT SEEMS',
      dur: 3.8,
    },
  ],
};
