#!/usr/bin/env python3
# 2.5D jointed-puppet renderer: ball-joint mannequin dialogue, 1080x1920 @30fps
import math, os, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display

ROOT = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1080, 1920, 30

# ---------------- timeline ----------------
L1, L2, L3 = 3.924, 1.962, 5.968
T1 = 0.6              # line1 start (A)
T2 = T1 + L1 + 0.45   # line2 start (B)
T3 = T2 + L2 + 0.55   # line3 start (A)
END = T3 + L3 + 1.75  # total ~15.2
TOTAL_FRAMES = int(END * FPS)

# ---------------- rig definitions ----------------
# part: (crop box in source cutout, pivot in source coords, parent)
RIG_A = {
    'src': 'assets/cut/char-a.png',
    'parts': {
        'torso':  dict(box=(270,165,470,428), pivot=(368,420), parent=None),
        'head':   dict(box=(275, 10,465,190), pivot=(368,182), parent='torso'),
        'uarmL':  dict(box=(140,180,284,250), pivot=(265,213), parent='torso'),
        'farmL':  dict(box=(  5,180,200,252), pivot=(172,213), parent='uarmL'),
        'uarmR':  dict(box=(452,180,600,250), pivot=(467,213), parent='torso'),
        'farmR':  dict(box=(540,180,735,252), pivot=(567,213), parent='uarmR'),
        'thighL': dict(box=(295,370,365,540), pivot=(331,397), parent=None),
        'shinL':  dict(box=(288,498,368,700), pivot=(326,523), parent='thighL'),
        'thighR': dict(box=(372,370,445,540), pivot=(404,397), parent=None),
        'shinR':  dict(box=(372,498,450,700), pivot=(407,523), parent='thighR'),
    },
    'order': ['thighL','thighR','shinL','shinR','torso','head','uarmL','farmL','uarmR','farmR'],
    'mouth': (368,147), 'eyes': [(330,88),(408,88)], 'eye_r': 13,
    'skin_probe': (368,55), 'mouth_w': 44, 'feet_y': 695,
}
RIG_B = {
    'src': 'assets/cut/char-b.png',
    'parts': {
        'torso':  dict(box=(280,140,455,415), pivot=(368,408), parent=None),
        'head':   dict(box=(268,  5,470,168), pivot=(368,158), parent='torso'),
        'uarmL':  dict(box=(150,163,286,237), pivot=(278,196), parent='torso'),
        'farmL':  dict(box=(  5,163,205,237), pivot=(175,198), parent='uarmL'),
        'uarmR':  dict(box=(450,160,597,234), pivot=(460,192), parent='torso'),
        'farmR':  dict(box=(535,160,728,234), pivot=(562,193), parent='uarmR'),
        'thighL': dict(box=(290,358,362,538), pivot=(326,386), parent=None),
        'shinL':  dict(box=(285,497,365,695), pivot=(322,520), parent='thighL'),
        'thighR': dict(box=(378,358,450,538), pivot=(412,386), parent=None),
        'shinR':  dict(box=(378,497,452,695), pivot=(416,520), parent='thighR'),
    },
    'order': ['thighL','thighR','shinL','shinR','torso','head','uarmL','farmL','uarmR','farmR'],
    'mouth': (368,122), 'eyes': [(327,75),(405,75)], 'eye_r': 12,
    'skin_probe': (368,40), 'mouth_w': 40, 'feet_y': 690,
}

SCALE = 0.88
A_X, B_X = 320, 790          # character anchor (feet center x) on 1080 canvas
FLOOR_Y = 1330

def load_rig(rig):
    im = Image.open(os.path.join(ROOT, rig['src'])).convert('RGBA')
    rig['pieces'] = {}
    for name, p in rig['parts'].items():
        piece = im.crop(p['box'])
        rig['pieces'][name] = piece
    # skin color probe (head local)
    hb = rig['parts']['head']['box']
    head = rig['pieces']['head']
    px, py = rig['skin_probe'][0]-hb[0], rig['skin_probe'][1]-hb[1]
    rig['skin'] = head.getpixel((px, py))[:3]
    return rig

def rot_pt(dx, dy, phi):
    r = math.radians(phi)
    return (dx*math.cos(r) - dy*math.sin(r), dx*math.sin(r) + dy*math.cos(r))

def draw_piece(canvas, piece, pivot_local, global_pivot, phi, scale):
    w, h = piece.size
    if scale != 1.0:
        piece = piece.resize((max(1,int(w*scale)), max(1,int(h*scale))), Image.LANCZOS)
        pivot_local = (pivot_local[0]*scale, pivot_local[1]*scale)
        w, h = piece.size
    pad = int(math.hypot(w, h)) + 4
    sq = Image.new('RGBA', (pad*2, pad*2), (0,0,0,0))
    sq.paste(piece, (int(pad - pivot_local[0]), int(pad - pivot_local[1])), piece)
    if abs(phi) > 0.01:
        sq = sq.rotate(-phi, resample=Image.BICUBIC, center=(pad, pad))
    canvas.alpha_composite(sq, (int(global_pivot[0]-pad), int(global_pivot[1]-pad)))

def ease(t):  # smooth 0..1
    return 0.5 - 0.5*math.cos(max(0.0, min(1.0, t)) * math.pi)

def track(t, keys):
    """keys: list of (time, value); cosine interp"""
    if t <= keys[0][0]: return keys[0][1]
    for i in range(len(keys)-1):
        t0, v0 = keys[i]; t1, v1 = keys[i+1]
        if t0 <= t <= t1:
            if t1 == t0: return v1
            return v0 + (v1-v0)*ease((t-t0)/(t1-t0))
    return keys[-1][1]

def shake(t, t0, n, amp, period=0.22):
    """head shake: n half-cycles starting at t0"""
    if t < t0 or t > t0 + n*period: return 0.0
    return amp * math.sin((t-t0)/period * math.pi) * math.exp(-1.5*(t-t0)/(n*period))

# ---------------- audio envelope ----------------
def envelope(path, dur):
    with wave.open(path, 'rb') as w:
        sr, nch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
    dt = {1: np.int8, 2: np.int16, 4: np.int32}[sw]
    x = np.frombuffer(raw, dtype=dt).astype(np.float32)
    if nch > 1: x = x.reshape(-1, nch).mean(axis=1)
    x /= (np.abs(x).max() + 1e-9)
    n = int(dur*FPS)+2
    env = np.zeros(n)
    win = int(sr/FPS)
    for i in range(n):
        s = int(i*sr/FPS)
        seg = x[s:s+win]
        if len(seg): env[i] = np.sqrt((seg**2).mean())
    env = env / (np.percentile(env, 97) + 1e-9)
    env = np.clip(env, 0, 1)
    # light smoothing but keep attack
    k = np.array([0.2, 0.6, 0.2])
    env = np.convolve(env, k, mode='same')
    return env

ENV1 = envelope(os.path.join(ROOT,'audio/line1.wav'), L1)
ENV2 = envelope(os.path.join(ROOT,'audio/line2.wav'), L2)
ENV3 = envelope(os.path.join(ROOT,'audio/line3.wav'), L3)

def mouth_open(t, who):
    """0..1 openness for character 'A'/'B' at time t"""
    if who == 'A':
        if T1 <= t < T1+L1: return float(ENV1[int((t-T1)*FPS)])
        if T3 <= t < T3+L3: return float(ENV3[int((t-T3)*FPS)])
    else:
        if T2 <= t < T2+L2: return float(ENV2[int((t-T2)*FPS)])
    return 0.0

# ---------------- poses ----------------
REST = 78  # arms hang

def pose_A(t):
    p = {k: 0.0 for k in RIG_A['parts']}
    bob = 4*math.sin(2*math.pi*0.24*t)
    sway = 2.5*math.sin(2*math.pi*0.09*t + 1.0)
    p['uarmL'] = -REST + 2.0*math.sin(2*math.pi*0.22*t)
    p['uarmR'] = REST - 2.0*math.sin(2*math.pi*0.22*t + 0.8)
    p['farmL'] = -4 + 1.5*math.sin(2*math.pi*0.3*t)
    p['farmR'] = 4 - 1.5*math.sin(2*math.pi*0.3*t+0.5)
    p['head'] = 1.5*math.sin(2*math.pi*0.13*t)
    p['torso'] = 0.8*math.sin(2*math.pi*0.1*t)
    # legs breathe: tiny knee flex + counter thigh so feet stay planted
    kf = 1.6 + 1.6*math.sin(2*math.pi*0.24*t)
    p['thighL'] += kf*0.5; p['shinL'] -= kf; p['thighR'] -= kf*0.4; p['shinR'] += kf*0.9

    # --- line1 gesture: raise right arm toward B, beat on syllables
    g1 = track(t, [(T1-0.3,0),(T1+0.35,1),(T1+L1-0.35,1),(T1+L1+0.45,0)])
    if g1 > 0:
        beat = 7*math.sin(2*math.pi*1.6*(t-T1)) * mouth_open(t,'A')
        p['uarmR'] += g1*(-REST + 38 + beat)         # raise toward horizontal-ish
        p['farmR'] += g1*(-35 - 0.6*beat)            # elbow bend upward
        p['head'] += g1*(3.5*math.sin(2*math.pi*0.9*(t-T1)))
        p['torso'] += g1*1.5
    # small step-in at line1 start (left leg)
    st = t - (T1-0.15)
    if 0 <= st < 0.55:
        ph = math.sin(math.pi*st/0.55)
        p['thighL'] += 20*ph; p['shinL'] -= 26*ph
    # --- line3: head shake on "نه", then emphatic point-up
    p['head'] += shake(t, T3+0.05, 5, 9)
    g3 = track(t, [(T3+0.9,0),(T3+1.5,1),(T3+L3-0.2,1),(T3+L3+1.2,0)])
    if g3 > 0:
        beat = 6*math.sin(2*math.pi*1.8*(t-T3)) * mouth_open(t,'A')
        p['uarmR'] += g3*(-REST - 8 + beat*0.4)      # arm up high
        p['farmR'] += g3*(-55 - beat*0.5)            # forearm points up
        p['uarmL'] += g3*(16 + 0.3*beat)             # left arm opens slightly
        p['farmL'] += g3*(-12)
        p['torso'] += g3*(-1.8)
        p['head'] += g3*(2.0*math.sin(2*math.pi*0.8*(t-T3)) - 1.5)
    # step forward at line3 emphasis
    st3 = t - (T3+0.95)
    if 0 <= st3 < 0.6:
        ph = math.sin(math.pi*st3/0.6)
        p['thighR'] += 17*ph; p['shinR'] -= 24*ph
    dx = sway + (10*track(t,[(T3+0.9,0),(T3+1.55,1)]) if t > T3 else 0)
    return p, dx, bob

def pose_B(t):
    p = {k: 0.0 for k in RIG_B['parts']}
    bob = 4*math.sin(2*math.pi*0.21*t + 2.2)
    sway = 2.5*math.sin(2*math.pi*0.08*t)
    p['uarmL'] = -REST + 2.0*math.sin(2*math.pi*0.2*t+1.3)
    p['uarmR'] = REST - 2.0*math.sin(2*math.pi*0.2*t+2.1)
    p['farmL'] = -4 + 1.5*math.sin(2*math.pi*0.27*t)
    p['farmR'] = 4 - 1.5*math.sin(2*math.pi*0.27*t+0.9)
    p['head'] = 1.5*math.sin(2*math.pi*0.11*t+0.7)
    p['torso'] = 0.8*math.sin(2*math.pi*0.09*t+1.9)
    kf = 1.6 + 1.6*math.sin(2*math.pi*0.21*t + 2.2)
    p['thighL'] += kf*0.5; p['shinL'] -= kf; p['thighR'] -= kf*0.4; p['shinR'] += kf*0.9

    # listens to line1: tilts head toward A
    gl = track(t, [(T1+0.3,0),(T1+1.0,1),(T1+L1,1),(T1+L1+0.6,0)])
    p['head'] += gl*(-5)
    # --- line2: questioning shrug, palms out
    g2 = track(t, [(T2-0.25,0),(T2+0.3,1),(T2+L2-0.1,1),(T2+L2+0.5,0)])
    if g2 > 0:
        beat = 6*math.sin(2*math.pi*1.7*(t-T2)) * mouth_open(t,'B')
        p['uarmL'] += g2*(26 - 0.4*beat)
        p['farmL'] += g2*(-52 - beat)
        p['uarmR'] += g2*(-26 + 0.4*beat)
        p['farmR'] += g2*(52 + beat)
        p['head'] += g2*(7 + 2*math.sin(2*math.pi*1.1*(t-T2)))
        p['torso'] += g2*(-1.2)
    # weight shift during own line
    st = t - (T2-0.1)
    if 0 <= st < 0.5:
        ph = math.sin(math.pi*st/0.5)
        p['thighR'] += 14*ph; p['shinR'] -= 20*ph
    # reaction to "نه": small startle lean back
    g3a = track(t, [(T3,0),(T3+0.35,1),(T3+1.2,1),(T3+2.0,0)])
    p['torso'] += g3a*(-2.2); p['head'] += g3a*(-4)
    # slow understanding nods at the end
    if t > T3 + 3.2:
        p['head'] += 6*math.sin(2*math.pi*0.55*(t-T3-3.2)) * track(t,[(T3+3.2,0),(T3+3.8,1),(END-0.6,1),(END,0.4)])
    return p, sway, bob

BLINKS_A = [1.3, 3.9, 6.6, 9.1, 11.8, 14.2]
BLINKS_B = [0.8, 3.1, 5.4, 7.9, 10.6, 13.4]

def draw_char(canvas, rig, pose, anchor_x, dx, bob, t, who, flip=False):
    p, blinks = pose, (BLINKS_A if who=='A' else BLINKS_B)
    s = SCALE
    feet_global_y = FLOOR_Y
    # source anchor: feet center x=368, y=feet_y
    ox = anchor_x + dx - 368*s
    oy = feet_global_y - rig['feet_y']*s + bob
    def g(ptx, pty): return (ox + ptx*s, oy + pty*s)

    # soft shadow
    sh = Image.new('RGBA', (360, 70), (0,0,0,0))
    ImageDraw.Draw(sh).ellipse([10,10,350,60], fill=(40,30,25, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(10))
    shw = int(330 + bob*3)
    sh = sh.resize((shw, 60))
    canvas.alpha_composite(sh, (int(anchor_x+dx-shw/2), int(FLOOR_Y-28)))

    parts, pieces = rig['parts'], rig['pieces']
    # resolve global pivots + accumulated angles (2-level FK)
    world = {}
    for name in rig['order']:
        pd = parts[name]
        par = pd['parent']
        local_angle = p.get(name, 0.0)
        if par is None or name == 'torso' or par is None:
            base_angle = 0.0
            pivot = g(*pd['pivot'])
        if par is None:
            world[name] = (pivot, local_angle)
        else:
            ppd = parts[par]
            ppivot, pangle = world[par]
            ddx, ddy = (pd['pivot'][0]-ppd['pivot'][0])*s, (pd['pivot'][1]-ppd['pivot'][1])*s
            rx, ry = rot_pt(ddx, ddy, pangle)
            pivot = (ppivot[0]+rx, ppivot[1]+ry)
            world[name] = (pivot, pangle + local_angle)

    for name in rig['order']:
        pd = parts[name]
        piece = pieces[name]
        # face dynamics on head
        if name == 'head':
            piece = piece.copy()
            d = ImageDraw.Draw(piece)
            bx, by = pd['box'][0], pd['box'][1]
            mo = mouth_open(t, who)
            if mo > 0.12:
                mw = rig['mouth_w']*(0.75+0.3*mo); mh = 7 + 30*mo
                mx, my = rig['mouth'][0]-bx, rig['mouth'][1]-by
                d.ellipse([mx-mw/2, my-mh/2, mx+mw/2, my+mh/2], fill=(58,36,32,255))
                d.ellipse([mx-mw/4, my+mh/2-6-mh*0.25, mx+mw/4, my+mh/2-4], fill=(190,95,95,255))
            for b0 in blinks:
                if b0 <= t < b0+0.14:
                    sk = rig['skin']
                    for ex, ey in rig['eyes']:
                        exl, eyl, r = ex-bx, ey-by, rig['eye_r']+4
                        d.ellipse([exl-r, eyl-r, exl+r, eyl+r], fill=(*sk,255))
                        d.arc([exl-r+4, eyl-4, exl+r-4, eyl+10], 20, 160, fill=(45,35,35,255), width=3)
        pivot_local = (pd['pivot'][0]-pd['box'][0], pd['pivot'][1]-pd['box'][1])
        gp, ang = world[name]
        draw_piece(canvas, piece, pivot_local, gp, ang, s)

# ---------------- captions ----------------
FONT = ImageFont.truetype(os.path.join(ROOT,'assets/fonts/Vazirmatn-Medium.ttf'), 56)
def rtl(s): return get_display(arabic_reshaper.reshape(s))
CUES = [
    (T1, T1+L1, 'به نظرت بزرگ‌ترین ترسِ انسان چیه؟', (72,170,170)),
    (T2, T2+L2, 'اینکه یک روز بمیره؟', (230,140,70)),
    (T3, T3+1.15, 'نه…', (72,170,170)),
    (T3+1.15, T3+L3+0.3, 'اینکه تمامِ عمرش زندگی نکرده باشه!', (72,170,170)),
]
def draw_caption(frame, t):
    for t0, t1, txt, col in CUES:
        if t0 <= t <= t1:
            a = min(1.0, (t-t0)/0.18, 1.0 if t1-t<0 else max(0.0,(t1-t)/0.18+0.0001))
            a = max(0.0, min(1.0, a))
            layer = Image.new('RGBA', frame.size, (0,0,0,0))
            d = ImageDraw.Draw(layer)
            s = rtl(txt)
            bb = d.textbbox((0,0), s, font=FONT)
            tw = bb[2]-bb[0]
            x, y = (W-tw)//2, 1555
            # soft shadow
            d.text((x+2, y+3), s, font=FONT, fill=(30,22,18, int(160*a)))
            d.text((x, y), s, font=FONT, fill=(255,252,246, int(255*a)))
            d.rounded_rectangle([W/2-60, y+92, W/2+60, y+100], 4, fill=(*col, int(230*a)))
            frame.alpha_composite(layer)

# ---------------- main ----------------
def render(frames_dir, start=0, end=None, step=1):
    os.makedirs(frames_dir, exist_ok=True)
    bg = Image.open(os.path.join(ROOT,'assets/raw/bg-studio.png')).convert('RGBA').resize((W, 1932), Image.LANCZOS).crop((0,0,W,H))
    load_rig(RIG_A); load_rig(RIG_B)
    end = end or TOTAL_FRAMES
    for f in range(start, end, step):
        t = f / FPS
        frame = bg.copy()
        pa, dxa, boba = pose_A(t)
        pb, dxb, bobb = pose_B(t)
        draw_char(frame, RIG_B, pb, B_X, dxb, bobb, t, 'B')
        draw_char(frame, RIG_A, pa, A_X, dxa, boba, t, 'A')
        # camera: slow push-in; extra push toward A during line3
        z = 1.0 + 0.05*(t/END) + 0.06*track(t,[(T3+0.6,0),(T3+2.0,1),(T3+L3,1),(END,0.7)])
        cx, cy = W/2 - 60*track(t,[(T3+0.6,0),(T3+2.0,1),(END,1)]), H/2 + 40
        cw, ch = W/z, H/z
        x0 = max(0, min(W-cw, cx-cw/2)); y0 = max(0, min(H-ch, cy-ch/2))
        frame = frame.crop((int(x0), int(y0), int(x0+cw), int(y0+ch))).resize((W,H), Image.LANCZOS)
        draw_caption(frame, t)
        frame.convert('RGB').save(os.path.join(frames_dir, f'f{f:05d}.jpg'), quality=90)
        if f % 60 == 0: print('frame', f, '/', end, flush=True)
    print('done', flush=True)

if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if mode == 'test':
        render('/tmp/frames-test', start=int(sys.argv[2]), end=int(sys.argv[2])+1)
    else:
        render('/tmp/frames')
