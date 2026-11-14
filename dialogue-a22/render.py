#!/usr/bin/env python3
# A2.2 (Style 2B Modern Beanie Zeke - Cinematic Story) dialogue — art-rig hybrid:
# generated cartoon head+torso sprites rotated at joints, procedural bold stick limbs (FK arms, IK legs), lip sync
import math, os, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display

ROOT = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1080, 1920, 30

L1, L2, L3 = 3.924, 1.962, 5.968
T1 = 0.6
T2 = T1 + L1 + 0.45
T3 = T2 + L2 + 0.55
END = T3 + L3 + 1.75
TOTAL_FRAMES = int(END * FPS)

A_X, B_X = 315, 790
FLOOR_Y = 1460

# ---------------- audio ----------------
def envelope(path, dur):
    with wave.open(path, 'rb') as w:
        sr, nch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
    dt = {1: np.int8, 2: np.int16, 4: np.int32}[sw]
    x = np.frombuffer(raw, dtype=dt).astype(np.float32)
    if nch > 1: x = x.reshape(-1, nch).mean(axis=1)
    x /= (np.abs(x).max() + 1e-9)
    n = int(dur*FPS)+2
    env = np.zeros(n); win = int(sr/FPS)
    for i in range(n):
        s = int(i*sr/FPS); seg = x[s:s+win]
        if len(seg): env[i] = np.sqrt((seg**2).mean())
    env = np.clip(env/(np.percentile(env,97)+1e-9), 0, 1)
    return np.convolve(env, [0.2,0.6,0.2], mode='same')

AUD = os.path.join(ROOT, 'audio')
ENV1 = envelope(os.path.join(AUD,'line1.wav'), L1)
ENV2 = envelope(os.path.join(AUD,'line2.wav'), L2)
ENV3 = envelope(os.path.join(AUD,'line3.wav'), L3)

def mouth_open(t, who):
    if who == 'A':
        if T1 <= t < T1+L1: return float(ENV1[int((t-T1)*FPS)])
        if T3 <= t < T3+L3: return float(ENV3[int((t-T3)*FPS)])
    else:
        if T2 <= t < T2+L2: return float(ENV2[int((t-T2)*FPS)])
    return 0.0

def ease(x): return 0.5-0.5*math.cos(max(0.0,min(1.0,x))*math.pi)
def track(t, keys):
    if t <= keys[0][0]: return keys[0][1]
    for i in range(len(keys)-1):
        t0,v0 = keys[i]; t1,v1 = keys[i+1]
        if t0 <= t <= t1:
            return v0+(v1-v0)*ease((t-t0)/(t1-t0)) if t1>t0 else v1
    return keys[-1][1]
def shake(t, t0, n, amp, period=0.22):
    if t < t0 or t > t0+n*period: return 0.0
    return amp*math.sin((t-t0)/period*math.pi)*math.exp(-1.5*(t-t0)/(n*period))
def rot_pt(dx, dy, phi):
    r = math.radians(phi)
    return (dx*math.cos(r)-dy*math.sin(r), dx*math.sin(r)+dy*math.cos(r))

# ---------------- character definitions ----------------
# source-space coordinates measured on the cut sprites
CHAR_A = dict(
    src='assets/char-a2-cut.png', scale=0.78,
    head_box=(295, 0, 600, 305), neck=(435, 298),
    eyes=[(405, 180), (475, 180)], eye_rx=12, eye_ry=18, mouth=(433, 240),
    torso_box=(286, 302, 590, 652), pelvis=(438, 630),
    shoulders=[(337, 380), (540, 380)], hips=[(408, 626), (470, 626)],
    uarm=112, farm=98, thigh=136, shin=126, limb_w=20, hand_r=26,
    glasses=False,
)
CHAR_B = dict(
    src='assets/char-b2-cut.png', scale=0.77,
    head_box=(290, 0, 600, 298), neck=(440, 292),
    eyes=[(390, 140), (495, 140)], eye_rx=13, eye_ry=19, mouth=(437, 218),
    torso_box=(283, 295, 602, 662), pelvis=(440, 642),
    shoulders=[(336, 372), (552, 372)], hips=[(410, 638), (475, 638)],
    uarm=114, farm=100, thigh=132, shin=122, limb_w=20, hand_r=26,
    glasses=True,
)
INK = (18, 16, 15)

def load_char(c):
    im = Image.open(os.path.join(ROOT, c['src'])).convert('RGBA')
    c['head_im'] = im.crop(c['head_box'])
    c['torso_im'] = im.crop(c['torso_box'])
    return c

def draw_piece(canvas, piece, pivot_local, global_pivot, phi, scale):
    w, h = piece.size
    if scale != 1.0:
        piece = piece.resize((max(1,int(w*scale)), max(1,int(h*scale))), Image.LANCZOS)
        pivot_local = (pivot_local[0]*scale, pivot_local[1]*scale)
        w, h = piece.size
    pad = int(math.hypot(w, h))+4
    sq = Image.new('RGBA', (pad*2, pad*2), (0,0,0,0))
    sq.paste(piece, (int(pad-pivot_local[0]), int(pad-pivot_local[1])), piece)
    if abs(phi) > 0.01:
        sq = sq.rotate(-phi, resample=Image.BICUBIC, center=(pad, pad))
    canvas.alpha_composite(sq, (int(global_pivot[0]-pad), int(global_pivot[1]-pad)))

def leg_ik(P, F, a, b, side):
    dx, dy = F[0]-P[0], F[1]-P[1]
    d = min(math.hypot(dx, dy), a+b-1.5)
    base = math.atan2(dy, dx)
    cosA = (a*a+d*d-b*b)/(2*a*d)
    A = math.acos(max(-1.0, min(1.0, cosA)))
    ang = base - side*A
    return (P[0]+a*math.cos(ang), P[1]+a*math.sin(ang))

# ---------------- poses (same choreography) ----------------
def pose_A(t):
    o = {}
    o['bob'] = 3.5*math.sin(2*math.pi*0.24*t)
    o['dx'] = 2.5*math.sin(2*math.pi*0.09*t+1.0)
    o['lean'] = 1.2*math.sin(2*math.pi*0.1*t)
    o['tilt'] = 2.0*math.sin(2*math.pi*0.13*t)
    o['armL'] = (12+2*math.sin(2*math.pi*0.22*t), 10+2*math.sin(2*math.pi*0.3*t))
    o['armR'] = (12+2*math.sin(2*math.pi*0.22*t+0.8), 10+2*math.sin(2*math.pi*0.3*t+0.5))
    o['stepL'] = o['stepR'] = (0.0, 0.0)
    g1 = track(t, [(T1-0.3,0),(T1+0.35,1),(T1+L1-0.35,1),(T1+L1+0.45,0)])
    if g1 > 0:
        beat = 9*math.sin(2*math.pi*1.6*(t-T1))*mouth_open(t,'A')
        th, el = o['armR']; o['armR'] = (th+g1*(66+beat), el+g1*(24-0.6*beat))
        o['tilt'] += g1*3.5*math.sin(2*math.pi*0.9*(t-T1)); o['lean'] += g1*2.0
    st = t-(T1-0.15)
    if 0 <= st < 0.55:
        ph = math.sin(math.pi*st/0.55); o['stepL'] = (8*ph, 16*ph)
    o['tilt'] += shake(t, T3+0.05, 5, 10)
    g3 = track(t, [(T3+0.9,0),(T3+1.5,1),(T3+L3-0.2,1),(T3+L3+1.2,0)])
    if g3 > 0:
        beat = 7*math.sin(2*math.pi*1.8*(t-T3))*mouth_open(t,'A')
        th, el = o['armR']; o['armR'] = (th+g3*(156+0.5*beat), el+g3*(-16-0.5*beat))
        thL, elL = o['armL']; o['armL'] = (thL+g3*26, elL+g3*10)
        o['lean'] += g3*(-1.5)
        o['tilt'] += g3*(2.0*math.sin(2*math.pi*0.8*(t-T3))-1.5)
    st3 = t-(T3+0.95)
    if 0 <= st3 < 0.6:
        ph = math.sin(math.pi*st3/0.6); o['stepR'] = (10*ph, 15*ph)
    o['dx'] += 10*track(t, [(T3+0.9,0),(T3+1.55,1)]) if t > T3 else 0
    return o

def pose_B(t):
    o = {}
    o['bob'] = 3.5*math.sin(2*math.pi*0.21*t+2.2)
    o['dx'] = 2.5*math.sin(2*math.pi*0.08*t)
    o['lean'] = 1.2*math.sin(2*math.pi*0.09*t+1.9)
    o['tilt'] = 2.0*math.sin(2*math.pi*0.11*t+0.7)
    o['armL'] = (12+2*math.sin(2*math.pi*0.2*t+1.3), 10+2*math.sin(2*math.pi*0.27*t))
    o['armR'] = (12+2*math.sin(2*math.pi*0.2*t+2.1), 10+2*math.sin(2*math.pi*0.27*t+0.9))
    o['stepL'] = o['stepR'] = (0.0, 0.0)
    gl = track(t, [(T1+0.3,0),(T1+1.0,1),(T1+L1,1),(T1+L1+0.6,0)])
    o['tilt'] += gl*(-5)
    g2 = track(t, [(T2-0.25,0),(T2+0.3,1),(T2+L2-0.1,1),(T2+L2+0.5,0)])
    if g2 > 0:
        beat = 8*math.sin(2*math.pi*1.7*(t-T2))*mouth_open(t,'B')
        thL, elL = o['armL']; thR, elR = o['armR']
        o['armL'] = (thL+g2*(40+0.5*beat), elL+g2*(92+beat))
        o['armR'] = (thR+g2*(40+0.5*beat), elR+g2*(92+beat))
        o['tilt'] += g2*(7+2*math.sin(2*math.pi*1.1*(t-T2))); o['lean'] += g2*(-1.0)
    st = t-(T2-0.1)
    if 0 <= st < 0.5:
        ph = math.sin(math.pi*st/0.5); o['stepR'] = (-7*ph, 13*ph)
    g3a = track(t, [(T3,0),(T3+0.35,1),(T3+1.2,1),(T3+2.0,0)])
    o['lean'] += g3a*(-2.5); o['tilt'] += g3a*(-4)
    if t > T3+3.2:
        nod = track(t, [(T3+3.2,0),(T3+3.8,1),(END-0.6,1),(END,0.4)])
        o['tilt'] += 6*math.sin(2*math.pi*0.55*(t-T3-3.2))*nod
    return o

BLINKS_A = [1.3, 3.9, 6.6, 9.1, 11.8, 14.2]
BLINKS_B = [0.8, 3.1, 5.4, 7.9, 10.6, 13.4]

# ---------------- character drawing ----------------
def draw_char(canvas, c, anchor_x, o, t, who, facing):
    s = c['scale']
    dx, bob = o['dx'], o['bob']
    leg_len = (c['thigh']+c['shin'])*s
    pelvis_g = (anchor_x+dx, FLOOR_Y-leg_len*0.96+bob)
    lean, tilt = o['lean'], o['tilt']

    # contact shadow
    sh = Image.new('RGBA', (360, 60), (0,0,0,0))
    ImageDraw.Draw(sh).ellipse([8,8,352,52], fill=(90,95,110,60))
    sh = sh.filter(ImageFilter.GaussianBlur(9))
    canvas.alpha_composite(sh, (int(anchor_x+dx-180), int(FLOOR_Y-16)))
    d = ImageDraw.Draw(canvas)

    LW = max(10, int(c['limb_w']*s))
    def line(p, q, w=LW, col=INK):
        d.line([p, q], fill=col, width=w)
        for pt in (p, q):
            d.ellipse([pt[0]-w/2, pt[1]-w/2, pt[0]+w/2, pt[1]+w/2], fill=col)

    def t_attach(src_pt):
        """torso-space source point -> global, honoring torso rotation (lean) about pelvis"""
        ddx = (src_pt[0]-c['pelvis'][0])*s
        ddy = (src_pt[1]-c['pelvis'][1])*s
        rx, ry = rot_pt(ddx, ddy, lean)
        return (pelvis_g[0]+rx, pelvis_g[1]+ry)

    # ---- legs (behind torso) ----
    for (hip_src, side, step) in ((c['hips'][0], -1, o['stepL']), (c['hips'][1], 1, o['stepR'])):
        hipg = t_attach(hip_src)
        fx = anchor_x + (hip_src[0]-c['pelvis'][0])*s*1.15 + side*6 + step[0]
        F = (fx, FLOOR_Y-step[1])
        K = leg_ik(hipg, F, c['thigh']*s, c['shin']*s, side)
        line(hipg, K); line(K, F)
        # simple line foot
        fl = 50*s if side == facing else 40*s
        line(F, (F[0]+facing*fl, F[1]))

    # ---- torso sprite ----
    tp_local = (c['pelvis'][0]-c['torso_box'][0], c['pelvis'][1]-c['torso_box'][1])
    draw_piece(canvas, c['torso_im'], tp_local, pelvis_g, lean, s)
    d = ImageDraw.Draw(canvas)

    # ---- head sprite with face dynamics ----
    head = c['head_im'].copy()
    hd = ImageDraw.Draw(head)
    bx, by = c['head_box'][0], c['head_box'][1]
    mo = mouth_open(t, who)
    mx, my = c['mouth'][0]-bx, c['mouth'][1]-by
    if mo > 0.12:
        hd.rounded_rectangle([mx-38, my-16, mx+38, my+26], 14, fill=(255,255,255))
        mw, mh = 20+16*mo, 10+30*mo
        hd.ellipse([mx-mw, my-mh/2+6, mx+mw, my+mh/2+6], fill=(30,20,18), outline=INK, width=4)
        if mo > 0.45:
            hd.ellipse([mx-mw*0.45, my+mh/2-8, mx+mw*0.45, my+mh/2+2], fill=(200,90,90))
    blink = any(b <= t < b+0.14 for b in (BLINKS_A if who=='A' else BLINKS_B))
    if blink:
        for ex, ey in c['eyes']:
            exl, eyl = ex-bx, ey-by
            hd.ellipse([exl-c['eye_rx']-5, eyl-c['eye_ry']-5, exl+c['eye_rx']+5, eyl+c['eye_ry']+5], fill=(255,255,255))
            hd.line([exl-12, eyl+4, exl+12, eyl+4], fill=INK, width=5)
    neck_g = t_attach(c['neck'])
    np_local = (c['neck'][0]-c['head_box'][0], c['neck'][1]-c['head_box'][1])
    draw_piece(canvas, head, np_local, neck_g, lean+tilt, s)
    d = ImageDraw.Draw(canvas)

    # ---- arms (front) ----
    for (sh_src, side, (th, el)) in ((c['shoulders'][0], -1, o['armL']), (c['shoulders'][1], 1, o['armR'])):
        S = t_attach(sh_src)
        thr = math.radians(th)
        E = (S[0]+c['uarm']*s*side*math.sin(thr), S[1]+c['uarm']*s*math.cos(thr))
        ph = math.radians(th+el)
        Hd = (E[0]+c['farm']*s*side*math.sin(ph), E[1]+c['farm']*s*math.cos(ph))
        line(S, E); line(E, Hd)
        r = c['hand_r']*s
        d.ellipse([Hd[0]-r, Hd[1]-r*0.85, Hd[0]+r, Hd[1]+r*0.85], fill=(255,255,255), outline=INK, width=5)

# ---------------- captions ----------------
FONT = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/Vazirmatn-Medium.ttf'), 56)
def rtl(x): return get_display(arabic_reshaper.reshape(x))
RED, TEAL = (205, 46, 40), (38, 150, 155)
CUES = [
    (T1, T1+L1, 'به نظرت بزرگ‌ترین ترسِ انسان چیه؟', RED),
    (T2, T2+L2, 'اینکه یک روز بمیره؟', TEAL),
    (T3, T3+1.15, 'نه…', RED),
    (T3+1.15, T3+L3+0.3, 'اینکه تمامِ عمرش زندگی نکرده باشه!', RED),
]
def draw_caption(frame, t):
    for t0, t1, txt, col in CUES:
        if t0 <= t <= t1:
            a = max(0.0, min(1.0, (t-t0)/0.18, (t1-t)/0.18))
            layer = Image.new('RGBA', frame.size, (0,0,0,0))
            d = ImageDraw.Draw(layer)
            s = rtl(txt)
            bb = d.textbbox((0,0), s, font=FONT)
            tw = bb[2]-bb[0]
            x, y = (W-tw)//2, 1640
            d.text((x+2, y+3), s, font=FONT, fill=(180,182,190, int(120*a)))
            d.text((x, y), s, font=FONT, fill=(42,40,45, int(255*a)))
            d.rounded_rectangle([W/2-60, y+92, W/2+60, y+100], 4, fill=(*col, int(235*a)))
            frame.alpha_composite(layer)

# ---------------- cinematic grade ----------------
def make_vignette():
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((xx-W/2)/(W*0.72))**2 + ((yy-H/2)/(H*0.62))**2)
    v = np.clip(1.0 - 0.32*np.clip(r-0.55, 0, None)**1.6, 0.55, 1.0)
    return v[..., None].astype(np.float32)
VIG = make_vignette()
GRAINS = [np.random.default_rng(i).normal(0, 3.0, (H, W, 1)).astype(np.float32) for i in range(6)]
def grade(frame, f):
    return frame.convert('RGB')

# ---------------- main ----------------
def render(frames_dir, times=None):
    os.makedirs(frames_dir, exist_ok=True)
    bg = Image.open(os.path.join(ROOT, 'assets/bg-studio2a.png')).convert('RGBA').resize((W, 1932), Image.LANCZOS).crop((0, 0, W, H))
    A = load_char(dict(CHAR_A)); B = load_char(dict(CHAR_B))
    rng = times if times else [f/FPS for f in range(TOTAL_FRAMES)]
    for i, t in enumerate(rng):
        frame = bg.copy()
        ob = pose_B(t); oa = pose_A(t)
        draw_char(frame, B, B_X, ob, t, 'B', facing=-1)
        draw_char(frame, A, A_X, oa, t, 'A', facing=1)
        z = 1.0 + 0.05*(t/END) + 0.06*track(t, [(T3+0.6,0),(T3+2.0,1),(T3+L3,1),(END,0.7)])
        cx = W/2 - 60*track(t, [(T3+0.6,0),(T3+2.0,1),(END,1)])
        cy = H/2 + 40
        cw, ch = W/z, H/z
        x0 = max(0, min(W-cw, cx-cw/2)); y0 = max(0, min(H-ch, cy-ch/2))
        frame = frame.crop((int(x0), int(y0), int(x0+cw), int(y0+ch))).resize((W, H), Image.LANCZOS)
        draw_caption(frame, t)
        f = i if times else int(round(t*FPS))
        grade(frame, f).save(os.path.join(frames_dir, f'f{f:05d}.jpg'), quality=90)
        if not times and f % 90 == 0: print('frame', f, '/', TOTAL_FRAMES, flush=True)
    print('done', flush=True)

if __name__ == '__main__':
    render('/tmp/frames-a22')
