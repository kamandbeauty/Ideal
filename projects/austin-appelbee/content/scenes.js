// Camera plan — hand-tuned for the new project.
// plate = assets/plates/hd/<plate>.jpg. Moves are deliberately gentle: the
// smoother camera is the house setting now (engine/stage.html: smootherstep).
// p17 is the REAL-PHOTO card and stays almost still so its caption is readable.
export const SCENES = [
  { id: 1,  plate: 'p01', move: 'hook',  amt: 0.70, a0: [0.50, 0.46], a1: [0.50, 0.52], fog: 0.28, warm: 0.22 },
  { id: 2,  plate: 'p02', move: 'in',    amt: 0.65, a0: [0.48, 0.52], a1: [0.52, 0.48], fog: 0.12, warm: 0.40 },
  { id: 3,  plate: 'p03', move: 'panR',  amt: 0.62, a0: [0.42, 0.50], a1: [0.58, 0.50], fog: 0.10, warm: 0.46 },
  { id: 4,  plate: 'p04', move: 'push',  amt: 0.75, a0: [0.50, 0.46], a1: [0.50, 0.54], fog: 0.34, warm: 0.14 },
  { id: 5,  plate: 'p05', move: 'inL',   amt: 0.70, a0: [0.44, 0.44], a1: [0.54, 0.50], fog: 0.26, warm: 0.26 },
  { id: 6,  plate: 'p06', move: 'tiltD', amt: 0.66, a0: [0.50, 0.42], a1: [0.50, 0.56], fog: 0.30, warm: 0.18 },
  { id: 7,  plate: 'p07', move: 'panL',  amt: 0.64, a0: [0.58, 0.50], a1: [0.44, 0.50], fog: 0.28, warm: 0.20 },
  { id: 8,  plate: 'p08', move: 'out',   amt: 0.68, a0: [0.50, 0.52], a1: [0.50, 0.46], fog: 0.36, warm: 0.16 },
  { id: 9,  plate: 'p09', move: 'hold',  amt: 0.40, a0: [0.50, 0.56], a1: [0.50, 0.56], fog: 0.16, warm: 0.48 },
  { id: 10, plate: 'p10', move: 'in',    amt: 0.72, a0: [0.50, 0.52], a1: [0.50, 0.44], fog: 0.18, warm: 0.44 },
  { id: 11, plate: 'p11', move: 'panR',  amt: 0.66, a0: [0.40, 0.52], a1: [0.60, 0.50], fog: 0.20, warm: 0.38 },
  { id: 12, plate: 'p12', move: 'out',   amt: 0.60, a0: [0.50, 0.48], a1: [0.50, 0.54], fog: 0.32, warm: 0.18 },
  { id: 13, plate: 'p13', move: 'in',    amt: 0.68, a0: [0.46, 0.46], a1: [0.54, 0.52], fog: 0.22, warm: 0.42 },
  { id: 14, plate: 'p14', move: 'hold',  amt: 0.38, a0: [0.50, 0.50], a1: [0.50, 0.50], fog: 0.10, warm: 0.34 },
  { id: 15, plate: 'p15', move: 'tiltU', amt: 0.62, a0: [0.50, 0.56], a1: [0.50, 0.44], fog: 0.12, warm: 0.30 },
  { id: 16, plate: 'p16', move: 'inL',   amt: 0.70, a0: [0.44, 0.48], a1: [0.54, 0.52], fog: 0.14, warm: 0.50 },
  { id: 17, plate: 'p17', move: 'hold',  amt: 0.20, a0: [0.50, 0.44], a1: [0.50, 0.44], fog: 0.08, warm: 0.30 },
];
