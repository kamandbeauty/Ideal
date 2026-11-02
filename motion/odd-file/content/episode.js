/**
 * THE ODD FILE — Episode 03: "Why Silence Feels Uncomfortable"
 * Category: Human Psychology · format: landscape (1920×1080) · long-form ≈2:52
 *
 * Narration is the supplied script, word for word, recorded as 10 clips.
 * Each beat declares `clip` plus in-clip `from`/`to` seconds measured from the
 * actual silences of the recording, so type lands on the words.
 * 25 scenes, one unique AI still each.
 */

export const EPISODE = {
  code: 'FILE 003',
  category: 'HUMAN PSYCHOLOGY',
  title: 'Why Silence Feels Uncomfortable',
  format: 'landscape',
  fps: 24,

  // Room tone for the first act, a hole under the opening silence, the bed
  // ducking before the ending, and the brand signature under the logo.
  audio: {
    ambienceTo: 26,
    hole: [5.0, 5.44],
    duckFromEnd: 25,
    signatureFromEnd: 5.5,
    // c10 finishes on "…our minds never stop listening."; the brand line is
    // re-recorded as its own outro clip, so the CTA can sit before it.
    clipCuts: { c10: 24.31 },
  },

  beats: [
    /* ---------------- ACT I — THE HOOK ---------------- */
    {
      id: 'b01',
      clip: 'c01', from: 0, to: 5.07,
      vo: 'Have you ever been talking to someone… and suddenly, everything goes quiet?',
      scene: 'statement',
      kicker: '01 · THE UNCOMFORTABLE PAUSE',
      plate: 'assets/ep03/web/s01.jpg', plateOpacity: 0.9,
      text: ['Everything', 'goes *quiet.*'],
    },
    {
      id: 'b02',
      clip: 'c01', from: 5.07, to: 11.42,
      vo: 'Just a few seconds pass. But somehow, those seconds feel incredibly long.',
      scene: 'sequence',
      plate: 'assets/ep03/web/s02.jpg', plateOpacity: 0.75,
      items: [
        { text: ['A few', '*seconds.*'], first: true, at: 0 },
        { text: ['They feel like', '*minutes.*'], at: 2.3 },
      ],
    },
    {
      id: 'b03',
      clip: 'c02', from: 1.5, to: 10.17,
      vo: 'Did I say something wrong? Are they bored? Should I say something?',
      scene: 'sequence',
      plate: 'assets/ep03/web/s03.jpg', plateOpacity: 0.7,
      items: [
        { text: ['Did I say', 'something *wrong?*'], first: true, at: 0 },
        { text: ['Are they', '*bored?*'], at: 2.3 },
        { text: ['Should I say', '*something?*'], at: 4.6 },
      ],
    },
    {
      id: 'b04',
      clip: 'c02', from: 10.17, to: 12.62,
      vo: 'Why does silence sometimes feel more uncomfortable than an awkward conversation?',
      scene: 'statement',
      kicker: 'THE QUESTION',
      plate: 'assets/ep03/web/s04.jpg', plateOpacity: 0.8,
      text: ['Why is silence', 'so *loud?*'],
    },

    /* ---------------- ACT II — THE PSYCHOLOGY ---------------- */
    {
      id: 'b05',
      clip: 'c03', from: 0, to: 4.73,
      vo: 'The answer is hidden in the way our brains understand social connection.',
      scene: 'statement',
      kicker: 'THE ANSWER',
      plate: 'assets/ep03/web/s05.jpg', plateOpacity: 0.82,
      text: ['SOCIAL', '*CONNECTION.*'],
    },
    {
      id: 'b06',
      clip: 'c03', from: 4.73, to: 13.69,
      vo: "Humans are social creatures. We don't just use conversations to exchange information. We also use them to understand whether we belong.",
      scene: 'sequence',
      plate: 'assets/ep03/web/s06.jpg', plateOpacity: 0.78,
      items: [
        { text: ['Not just', '*information.*'], first: true, at: 0 },
        { text: ['Do I', '*belong?*'], at: 4.2 },
      ],
    },
    {
      id: 'b07',
      clip: 'c04', from: 0, to: 8.44,
      vo: 'A smooth conversation creates a sense of connection. One person speaks. Another responds. The rhythm continues.',
      scene: 'statement',
      kicker: 'THE RHYTHM',
      plate: 'assets/ep03/web/s07.jpg', plateOpacity: 0.7,
      text: ['Speak.', 'Respond.', '*Continue.*'],
    },
    {
      id: 'b08',
      clip: 'c04', from: 8.44, to: 13.6,
      vo: 'But when that rhythm suddenly stops, something changes.',
      scene: 'statement',
      kicker: 'AND THEN',
      plate: 'assets/ep03/web/s08.jpg', plateOpacity: 0.8,
      text: ['The rhythm', '*stops.*'],
    },
    {
      id: 'b09',
      clip: 'c05', from: 0, to: 4.75,
      vo: 'Your brain may begin searching for an explanation.',
      scene: 'statement',
      kicker: 'WHY THE PAUSE HURTS',
      plate: 'assets/ep03/web/s09.jpg', plateOpacity: 0.75,
      text: ['YOUR BRAIN IS', 'SEARCHING FOR', '*ANSWERS.*'],
    },
    {
      id: 'b10',
      clip: 'c05', from: 4.75, to: 10.88,
      vo: 'Did someone disagree? Did I make things awkward? Is something wrong?',
      scene: 'sequence',
      plate: 'assets/ep03/web/s10.jpg', plateOpacity: 0.68,
      items: [
        { text: ['Did someone', '*disagree?*'], first: true, at: 0 },
        { text: ['Did I make things', '*awkward?*'], at: 2.2 },
        { text: ['Is something', '*wrong?*'], at: 4.4 },
      ],
    },
    {
      id: 'b11',
      clip: 'c05', from: 11.23, to: 14.16,
      vo: 'And suddenly, a completely ordinary pause can feel like a sign of rejection.',
      scene: 'statement',
      plate: 'assets/ep03/web/s11.jpg', plateOpacity: 0.85,
      text: ['FEAR OF', '*REJECTION.*'],
      sub: 'An ordinary pause can feel like a sign of it.',
    },

    /* ---------------- ACT III — THE SCIENCE ---------------- */
    {
      id: 'b12',
      clip: 'c06', from: 0, to: 13.82,
      vo: 'Researchers have actually studied this phenomenon. In a 2011 study published in the Journal of Experimental Social Psychology, researchers examined what happens when brief silences interrupt group conversations.',
      scene: 'sequence',
      kicker: '2011 · JOURNAL OF EXPERIMENTAL SOCIAL PSYCHOLOGY',
      plate: 'assets/ep03/web/s12.jpg', plateOpacity: 0.7,
      items: [
        { text: ['Someone', 'studied this.'], first: true, at: 0 },
        { text: ['Brief silences.', 'Group *conversations.*'], at: 3.4 },
      ],
    },
    {
      id: 'b13',
      clip: 'c06', from: 13.82, to: 22.23,
      vo: 'They found that breaking the natural flow of conversation could make people feel less connected, less validated, and even rejected.',
      scene: 'sequence',
      kicker: 'WHAT THEY FOUND',
      plate: 'assets/ep03/web/s13.jpg', plateOpacity: 0.7,
      items: [
        { text: ['Less connected.'], first: true, at: 0 },
        { text: ['Less validated.'], at: 2.7 },
        { text: ['Even *rejected.*'], at: 5.4 },
      ],
    },
    {
      id: 'b14',
      clip: 'c07', from: 0, to: 7.5,
      vo: "Here's the interesting part: The silence itself wasn't necessarily the problem. It was what people thought the silence meant.",
      scene: 'statement',
      plate: 'assets/ep03/web/s14.jpg', plateOpacity: 0.8,
      text: ['The silence', "wasn't the", '*problem.*'],
    },
    {
      id: 'b15',
      clip: 'c07', from: 7.5, to: 16.14,
      vo: "Our minds are constantly interpreting social signals. And when there's no clear signal, we sometimes fill the gap with negative assumptions.",
      scene: 'sequence',
      plate: 'assets/ep03/web/s15.jpg', plateOpacity: 0.75,
      items: [
        { text: ['No clear signal.'], first: true, at: 0 },
        { text: ['So we fill', 'the gap with', '*assumptions.*'], at: 4.3 },
      ],
    },

    /* ---------------- ACT IV — THE TWIST ---------------- */
    {
      id: 'b16',
      clip: 'c08', from: 0, to: 3.79,
      vo: "But here's something important. Not all silence is uncomfortable.",
      scene: 'statement',
      kicker: 'THE TWIST',
      plate: 'assets/ep03/web/s16.jpg', plateOpacity: 0.85,
      text: ['Not all silence', 'is *uncomfortable.*'],
    },
    {
      id: 'b17',
      clip: 'c08', from: 3.79, to: 13.69,
      vo: "Think about sitting with someone you deeply trust. You don't always need to speak. You can share a quiet moment without feeling the need to explain it.",
      scene: 'statement',
      plate: 'assets/ep03/web/s17.jpg', plateOpacity: 0.8,
      text: ['SILENCE IS NOT', 'ALWAYS *EMPTY.*'],
      sub: 'Sitting with someone you trust, saying nothing at all.',
    },
    {
      id: 'b18',
      clip: 'c09', from: 0, to: 5.21,
      vo: "That's because silence can mean different things in different relationships.",
      scene: 'statement',
      plate: 'assets/ep03/web/s18.jpg', plateOpacity: 0.8,
      text: ['Same silence.', 'Different', '*meaning.*'],
    },
    {
      id: 'b19',
      clip: 'c09', from: 5.21, to: 10.9,
      vo: 'With a stranger, it might feel like uncertainty. With someone you love, it might feel like comfort.',
      scene: 'sequence',
      plate: 'assets/ep03/web/s19.jpg', plateOpacity: 0.72,
      items: [
        { text: ['With a stranger:', '*uncertainty.*'], first: true, at: 0 },
        { text: ['With someone you love:', '*comfort.*'], at: 2.7 },
      ],
    },
    {
      id: 'b20',
      clip: 'c09', from: 10.9, to: 16.59,
      vo: "The difference isn't always the silence. It's the connection behind it.",
      scene: 'statement',
      plate: 'assets/ep03/web/s20.jpg', plateOpacity: 0.8,
      text: ["It isn't the silence.", "It's the", '*connection.*'],
    },

    /* ---------------- ACT V — THE ENDING ---------------- */
    {
      id: 'b21',
      clip: 'c10', from: 0, to: 6.17,
      vo: "So the next time a conversation goes quiet… Don't rush to fill every second.",
      scene: 'statement',
      plate: 'assets/ep03/web/s21.jpg', plateOpacity: 0.8,
      text: ["Don't rush", 'to fill every', '*second.*'],
    },
    {
      id: 'b22',
      clip: 'c10', from: 6.17, to: 12.88,
      vo: "A pause doesn't automatically mean something is wrong.",
      scene: 'statement',
      plate: 'assets/ep03/web/s22.jpg', plateOpacity: 0.78,
      text: ['A pause is not', 'automatically', 'a *warning.*'],
    },
    {
      id: 'b23',
      clip: 'c10', from: 12.88, to: 19.48,
      vo: 'Sometimes, silence is just silence.',
      scene: 'statement',
      plate: 'assets/ep03/web/s23.jpg', plateOpacity: 0.85,
      text: ['Sometimes,', 'silence is', 'just *silence.*'],
    },
    {
      id: 'b24',
      clip: 'c10', from: 19.48, to: 24.31,
      vo: 'And maybe the most interesting thing about human communication… Is that even when nobody says a word… Our minds never stop listening.',
      scene: 'statement',
      kicker: 'THE INTERESTING PART',
      plate: 'assets/ep03/web/s24.jpg', plateOpacity: 0.8,
      text: ['Our minds', 'never stop', '*listening.*'],
    },
    /* ---------------- OUTRO — CTA, then the fixed brand card ---------------- */
    {
      id: 'b25',
      clip: 'c11', from: 0, to: 9.04,
      vo:
        "If you enjoyed this video, I'd really appreciate it if you hit the like button " +
        'and subscribed to the channel. Thanks for watching, and see you in the next file.',
      scene: 'cta',
      kicker: 'ONE LAST THING',
      plate: 'assets/ep03/web/s25.jpg', plateOpacity: 0.5,
      items: [
        { icon: 'like', label: 'LIKE THIS VIDEO', at: 0.5 },
        { icon: 'bell', label: 'SUBSCRIBE TO THE ODD FILE', at: 2.6 },
      ],
    },
    {
      id: 'b26',
      clip: 'c12', from: 0, to: 3.84,
      vo: 'THE ODD FILE. Not everything is what it seems.',
      scene: 'tagline',
      text: ['Not everything', 'is what it *seems.*'],
      brand: 'THE ODD FILE',
      handle: 'NOT EVERYTHING IS WHAT IT SEEMS',
    },
  ],
};
