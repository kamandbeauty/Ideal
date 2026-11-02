// 2D cutout rig — one skeleton, several costumes.
//
// Every puppet is plain SVG: joint groups nested inside each other, so rotating
// a parent carries the child with it (shoulder → elbow → hand). Nothing is
// animated by CSS — the renderer calls pose() once per frame with the frame
// number, so any frame can be captured on its own.

const INK = '#1e1712';

const PALETTES = {
  woman:    { cloth: '#3f362a', cloth2: '#372f25', apron: '#d8caa8', apron2: '#b9ab8d', skin: '#f2d5b6', skin2: '#e3c09c', hair: '#4a3427', head: '#e9dfc7' },
  man:      { cloth: '#4a3f2f', cloth2: '#3f3527', apron: '#8d6a44', apron2: '#7a5a38', skin: '#eecba6', skin2: '#dcb894', hair: '#31241a', head: '#2f2a22' },
  official: { cloth: '#332a24', cloth2: '#2a221d', apron: '#5b4430', apron2: '#4a3626', skin: '#e8c6a2', skin2: '#d6b28e', hair: '#2a1e16', head: '#211a15' },
  musician: { cloth: '#5b4a33', cloth2: '#4c3d29', apron: '#9b7a4e', apron2: '#87683f', skin: '#f0cfa9', skin2: '#ddb98f', hair: '#3a2a1d', head: '#3a2f24' },
  ghost:    { cloth: '#3a322a', cloth2: '#332c25', apron: '#443b31', apron2: '#3a322a', skin: '#463c31', skin2: '#3d342a', hair: '#2a231c', head: '#2a231c' },
};

/** SVG markup for one puppet. `uid` must be unique on the page. */
export function puppetMarkup(type = 'woman', uid = 'a') {
  const c = PALETTES[type] || PALETTES.woman;
  const isWoman = type === 'woman';
  const isOfficial = type === 'official';
  const isMusician = type === 'musician';
  const flat = type === 'ghost';
  const face = flat
    ? `<ellipse cx="0" cy="-38" rx="50" ry="58" fill="${c.skin}" stroke="${INK}" stroke-width="6"/>
       <ellipse cx="0" cy="-34" rx="10" ry="6" fill="#0c0a08"/>`
    : `<ellipse cx="0" cy="-38" rx="50" ry="58" fill="${c.skin}" stroke="${INK}" stroke-width="6"/>
       <path d="M-50 -38 Q-52 -100 0 -104 Q52 -100 50 -38 Q30 -66 0 -66 Q-30 -66 -50 -38 Z" fill="${c.hair}" stroke="${INK}" stroke-width="5"/>
       <ellipse cx="-20" cy="-40" rx="12" ry="14" fill="#fff" stroke="${INK}" stroke-width="4"/>
       <ellipse cx="20" cy="-40" rx="12" ry="14" fill="#fff" stroke="${INK}" stroke-width="4"/>
       <circle class="pupil" cx="-20" cy="-38" r="6" fill="#231a13"/>
       <circle class="pupil" cx="20" cy="-38" r="6" fill="#231a13"/>
       <path d="M-33 -60 q13 -8 26 -2" fill="none" stroke="#3b2a1e" stroke-width="5" stroke-linecap="round"/>
       <path d="M8 -62 q13 -6 26 2" fill="none" stroke="#3b2a1e" stroke-width="5" stroke-linecap="round"/>
       <ellipse class="mouth" cx="0" cy="-8" rx="11" ry="8" fill="#5c2b25" stroke="${INK}" stroke-width="4"/>`;

  const headwear = isOfficial
    ? `<path d="M-62 -92 q0 -34 62 -34 q62 0 62 34 q-30 10 -62 10 q-32 0 -62 -10 Z" fill="${c.head}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"/>
       <path d="M-66 -92 h132 q6 12 -4 14 h-124 q-10 -2 -4 -14 Z" fill="${c.head}" stroke="${INK}" stroke-width="5" stroke-linejoin="round"/>
       <path d="M-10 -126 q10 -22 24 -4 q-14 -6 -24 4 Z" fill="#8c3b2f" stroke="${INK}" stroke-width="4"/>`
    : `<path d="M-56 -50 Q-64 -124 0 -130 Q64 -124 56 -50 Q40 -84 0 -84 Q-40 -84 -56 -50 Z"
             fill="${c.head}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"/>
       <path d="M-56 -50 Q-70 -30 -62 -6 Q-46 -26 -40 -46 Z" fill="${c.apron2}" stroke="${INK}" stroke-width="5"/>`;

  const lower = isWoman
    ? `<path d="M-48 -6 L-112 168 Q0 196 112 168 L48 -6 Z" fill="${c.cloth}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"/>
       <path d="M-48 -6 L-112 168 Q-56 182 -20 184 L-14 -6 Z" fill="${c.cloth2}" opacity=".9"/>
       <g class="apron">
         <path d="M-34 6 L-52 160 Q0 176 52 160 L34 6 Z" fill="${c.apron}" stroke="${INK}" stroke-width="5" stroke-linejoin="round"/>
         <path d="M-34 6 L-52 160 Q-26 168 -8 170 L-6 6 Z" fill="${c.apron2}" opacity=".85"/>
       </g>`
    : `<path d="M-42 4 L-46 96 Q0 108 46 96 L42 4 Z" fill="${c.cloth}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"/>
       <path d="M-42 4 L-46 96 Q-20 102 -8 103 L-6 4 Z" fill="${c.cloth2}" opacity=".9"/>`;

  const prop = isMusician
    ? `<g class="prop"><ellipse cx="58" cy="-40" rx="46" ry="40" fill="#b98a52" stroke="${INK}" stroke-width="6"/>
         <ellipse cx="58" cy="-52" rx="42" ry="30" fill="#e3cba0" stroke="${INK}" stroke-width="4"/>
         <path d="M22 -60 q36 -14 72 0" fill="none" stroke="${INK}" stroke-width="4"/></g>`
    : isOfficial
      ? `<g class="prop"><rect x="66" y="-210" width="12" height="330" rx="6" fill="#4c3a26" stroke="${INK}" stroke-width="5"/></g>`
      : '';

  const beard = isOfficial
    ? `<path d="M-26 0 q6 44 26 52 q20 -8 26 -52 q-26 16 -52 0 Z" fill="${c.hair}" stroke="${INK}" stroke-width="5"/>`
    : '';

  return `
  <g class="pup pup-${type}" data-uid="${uid}">
    <g data-j="legL">
      <g fill="${c.cloth2}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"><rect x="-19" y="0" width="38" height="112" rx="19"/></g>
      <g data-j="shinL">
        <g fill="${c.cloth2}" stroke="${INK}" stroke-width="6">
          <rect x="-17" y="0" width="34" height="104" rx="17"/><circle cx="0" cy="4" r="17"/>
          <path d="M-17 96 h34 q26 6 26 22 h-60 q0 -16 0 -22 Z" fill="#241e18"/>
        </g>
      </g>
    </g>
    <g data-j="legR">
      <g fill="${c.cloth}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"><rect x="-19" y="0" width="38" height="112" rx="19"/></g>
      <g data-j="shinR">
        <g fill="${c.cloth}" stroke="${INK}" stroke-width="6">
          <rect x="-17" y="0" width="34" height="104" rx="17"/><circle cx="0" cy="4" r="17"/>
          <path d="M-17 96 h34 q26 6 26 22 h-60 q0 -16 0 -22 Z" fill="#1f1a15"/>
        </g>
      </g>
    </g>
    <g data-j="torso">
      ${lower}
      ${flat ? '' : `<path d="M-46 8 L-52 -118 Q-54 -186 -30 -200 L30 -200 Q54 -186 52 -118 L46 8 Z" fill="${c.cloth}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"/>
      <path d="M-46 8 L-52 -118 Q-54 -186 -30 -200 L-14 -200 L-12 8 Z" fill="${c.cloth2}" opacity=".95"/>
      <path d="M-50 -6 Q0 12 50 -6" fill="none" stroke="#241d17" stroke-width="10" stroke-linecap="round"/>`}
      ${prop}
      <g data-j="armL">
        <g stroke="${INK}" stroke-width="6" stroke-linejoin="round">
          <rect x="-17" y="-8" width="34" height="100" rx="17" fill="${c.cloth}"/><circle cx="0" cy="0" r="20" fill="${c.cloth}"/>
        </g>
        <g data-j="foreL">
          <g stroke="${INK}" stroke-width="6" stroke-linejoin="round">
            <rect x="-15" y="-10" width="30" height="94" rx="15" fill="${c.cloth}"/><circle cx="0" cy="0" r="18" fill="${c.cloth}"/>
            <ellipse cx="0" cy="98" rx="20" ry="23" fill="${c.skin}"/>
          </g>
        </g>
      </g>
      <g data-j="armR">
        <g stroke="${INK}" stroke-width="6" stroke-linejoin="round">
          <rect x="-17" y="-8" width="34" height="100" rx="17" fill="${c.cloth2}"/><circle cx="0" cy="0" r="20" fill="${c.cloth2}"/>
        </g>
        <g data-j="foreR">
          <g stroke="${INK}" stroke-width="6" stroke-linejoin="round">
            <rect x="-15" y="-10" width="30" height="94" rx="15" fill="${c.cloth2}"/><circle cx="0" cy="0" r="18" fill="${c.cloth2}"/>
            <ellipse cx="0" cy="98" rx="20" ry="23" fill="${c.skin2}"/>
          </g>
        </g>
      </g>
      <g data-j="head">
        ${isWoman ? `<path d="M-58 -26 Q-66 -96 -22 -112 Q28 -128 58 -84 Q66 -54 54 -30 Z" fill="${c.hair}" stroke="${INK}" stroke-width="6"/>` : ''}
        ${face}
        ${beard}
        ${headwear}
      </g>
    </g>
  </g>`;
}

/** Idle / dance / collapse / play / wave — all closed-form in time. */
export function moodPose(mood, t, seed = 0, energy = 1) {
  const p = (2 * Math.PI);
  const beat = 0.92 + seed * 0.28;                 // each dancer a slightly different tempo
  const w = p * beat;
  const ph = seed * p;                              // phase offset so a crowd is not in lock-step
  const s = Math.sin(w * t + ph);
  const s2 = Math.sin(2 * (w * t + ph));
  const out = {
    bob: 0, sway: 0, lean: 0, rootRot: 0, rootShiftY: 0,
    armL: 34, armR: -34, foreL: -16, foreR: 16,
    thighL: 3, thighR: -3, shinL: -4, shinR: -4,
    head: 0, skirt: 0, mouth: 0,
  };

  if (mood === 'dance') {
    out.bob = -16 * energy * Math.abs(s2);
    out.sway = 20 * energy * s;
    out.lean = 5.5 * energy * Math.sin(w * t + ph + 0.5);
    out.armL = 34 + 52 * energy * s;
    out.armR = -(34 - 52 * energy * s);
    out.foreL = -(16 + 34 * energy * Math.sin(w * t + ph + 1.1));
    out.foreR = 16 + 34 * energy * Math.sin(w * t + ph + Math.PI + 1.1);
    out.thighL = 12 * energy * s + 3;
    out.thighR = -12 * energy * s - 3;
    out.shinL = -Math.max(0, 26 * s2) - 4;
    out.shinR = -Math.max(0, -26 * s2) - 4;
    out.head = -6 * s + 2 * Math.cos(2 * (w * t + ph));
    out.skirt = 2.4 * Math.sin(w * t + ph + 0.8);
    out.mouth = 2 + 2 * Math.abs(s2);
  } else if (mood === 'still') {
    out.bob = -3 * Math.abs(s2);
    out.sway = 4 * s;
    out.lean = 1.6 * Math.sin(0.5 * w * t + ph);
    out.armL = 30 + 5 * s;
    out.armR = -(30 - 5 * s);
    out.foreL = -22 - 4 * Math.sin(w * t + ph);
    out.foreR = 22 + 4 * Math.sin(w * t + ph);
    out.head = -2.5 * s;
    out.skirt = 0.8 * Math.sin(0.5 * w * t);
    out.mouth = 0;
  } else if (mood === 'collapse') {
    out.rootRot = -78;
    out.rootShiftY = 128;
    out.bob = 0;
    out.armL = 58 + 6 * s;
    out.armR = -(60 - 6 * s);
    out.foreL = -30;
    out.foreR = 34;
    out.thighL = 34;
    out.thighR = 12;
    out.shinL = -54;
    out.shinR = -30;
    out.head = 12 + 1.5 * s;
    out.mouth = 1;
  } else if (mood === 'play') {
    out.bob = -7 * Math.abs(s2);
    out.sway = 9 * s;
    out.lean = 3 * Math.sin(w * t + 0.4);
    out.armL = 74 + 18 * s2;
    out.armR = -(62 + 16 * s);
    out.foreL = -84 - 16 * s2;
    out.foreR = 70 + 18 * s;
    out.head = 3 * s;
    out.mouth = 1.5 + 1.5 * Math.abs(s2);
  } else if (mood === 'wave') {
    out.bob = -6 * Math.abs(s2);
    out.sway = 10 * s;
    out.lean = 3 * s;
    out.armL = 44 + 6 * s;
    out.armR = -150 - 14 * Math.sin(1.6 * w * t);
    out.foreL = -18;
    out.foreR = 26 + 18 * Math.sin(1.6 * w * t + 0.6);
    out.head = -4 * s;
    out.skirt = 1.6 * Math.sin(0.7 * w * t);
    out.mouth = 2;
  }
  return out;
}

/** Applies a pose to a puppet root. Returns the root transform. */
export function applyPose(root, pose, scale = 1) {
  const q = (j) => root.querySelector(`[data-j="${j}"]`);
  const legs = ['legL', 'legR', 'shinL', 'shinR'];
  const set = (el, tr) => el && el.setAttribute('transform', tr);

  set(q('torso'), '');
  set(q('head'), `translate(0 -212) rotate(${pose.head}) scale(1.04)`);
  set(q('armL'), `translate(-44 -172) rotate(${pose.armL})`);
  set(q('armR'), `translate(44 -172) rotate(${pose.armR})`);
  set(q('foreL'), `translate(0 90) rotate(${pose.foreL})`);
  set(q('foreR'), `translate(0 90) rotate(${pose.foreR})`);
  set(q('legL'), `translate(-24 6) rotate(${pose.thighL})`);
  set(q('legR'), `translate(24 6) rotate(${pose.thighR})`);
  set(q('shinL'), `translate(0 112) rotate(${pose.shinL})`);
  set(q('shinR'), `translate(0 112) rotate(${pose.shinR})`);
  const apron = root.querySelector('.apron');
  if (apron) apron.setAttribute('transform', `rotate(${pose.skirt})`);
  const mouth = root.querySelector('.mouth');
  if (mouth) mouth.setAttribute('ry', `${8 + pose.mouth}`);
  const pupils = root.querySelectorAll('.pupil');
  pupils.forEach((el, i) => el.setAttribute('cx', `${i === 0 ? -20 : 20}`));

  return `translate(${pose.sway} ${pose.bob + pose.rootShiftY}) rotate(${pose.rootRot}) scale(${scale})`;
}
