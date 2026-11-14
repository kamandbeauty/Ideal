#!/usr/bin/env python3
# A2.2 (Style 2B Modern Beanie Zeke - Cinematic Story) dialogue
# procedural 2D stick figures (FK arms, IK legs, visible joints) in a cinematic dusk scene
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

A_X, B_X = 320, 790
FLOOR_Y = 1430

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
def wob(seed, t, amp=1.0):
    qt = math.floor(t*9)/9
    return (amp*(1.6*math.sin(6.1*qt+seed*1.7)+0.9*math.sin(11.3*qt+seed*3.1)),
            amp*(1.6*math.cos(5.3*qt+seed*2.3)+0.9*math.sin(9.7*qt+seed*1.3)))

HEAD_R, TORSO, UARM, FARM, THIGH, SHIN = 54, 225, 128, 118, 152, 150
FOOT_SPREAD, FOOT_LEN = 55, 42

def leg_ik(P, F, side):
    a, b = THIGH, SHIN
    dx, dy = F[0]-P[0], F[1]-P[1]
    d = min(math.hypot(dx, dy), a+b-2)
    base = math.atan2(dy, dx)
    cosA = (a*a+d*d-b*b)/(2*a*d)
    A = math.acos(max(-1.0, min(1.0, cosA)))
    ang = base - side*A
    return (P[0]+a*math.cos(ang), P[1]+a*math.sin(ang))

def arm_pts(S, theta, elbow, side):
    th = math.radians(theta)
    E = (S[0]+UARM*side*math.sin(th), S[1]+UARM*math.cos(th))
    ph = math.radians(theta+elbow)
    return E, (E[0]+FARM*side*math.sin(ph), E[1]+FARM*math.cos(ph))

# ---------------- poses (same choreography as dialogue-stickman) ----------------
def pose_A(t):
    o = {}
    o['bob'] = 4*math.sin(2*math.pi*0.24*t)
    o['dx'] = 2.5*math.sin(2*math.pi*0.09*t+1.0)
    o['lean'] = 1.2*math.sin(2*math.pi*0.1*t)
    o['tilt'] = 1.5*math.sin(2*math.pi*0.13*t)
    o['armL'] = (10+1.5*math.sin(2*math.pi*0.22*t), 8+2*math.sin(2*math.pi*0.3*t))
    o['armR'] = (10+1.5*math.sin(2*math.pi*0.22*t+0.8), 8+2*math.sin(2*math.pi*0.3*t+0.5))
    o['stepL'] = o['stepR'] = (0.0, 0.0)
    g1 = track(t, [(T1-0.3,0),(T1+0.35,1),(T1+L1-0.35,1),(T1+L1+0.45,0)])
    if g1 > 0:
        beat = 9*math.sin(2*math.pi*1.6*(t-T1))*mouth_open(t,'A')
        th, el = o['armR']; o['armR'] = (th+g1*(68+beat), el+g1*(22-0.6*beat))
        o['tilt'] += g1*3.5*math.sin(2*math.pi*0.9*(t-T1)); o['lean'] += g1*2.0
    st = t-(T1-0.15)
    if 0 <= st < 0.55:
        ph = math.sin(math.pi*st/0.55); o['stepL'] = (12*ph, 26*ph)
    o['tilt'] += shake(t, T3+0.05, 5, 10)
    g3 = track(t, [(T3+0.9,0),(T3+1.5,1),(T3+L3-0.2,1),(T3+L3+1.2,0)])
    if g3 > 0:
        beat = 7*math.sin(2*math.pi*1.8*(t-T3))*mouth_open(t,'A')
        th, el = o['armR']; o['armR'] = (th+g3*(158+0.5*beat), el+g3*(-14-0.5*beat))
        thL, elL = o['armL']; o['armL'] = (thL+g3*26, elL+g3*10)
        o['lean'] += g3*(-1.5)
        o['tilt'] += g3*(2.0*math.sin(2*math.pi*0.8*(t-T3))-1.5)
    st3 = t-(T3+0.95)
    if 0 <= st3 < 0.6:
        ph = math.sin(math.pi*st3/0.6); o['stepR'] = (16*ph, 24*ph)
    o['dx'] += 10*track(t, [(T3+0.9,0),(T3+1.55,1)]) if t > T3 else 0
    return o

def pose_B(t):
    o = {}
    o['bob'] = 4*math.sin(2*math.pi*0.21*t+2.2)
    o['dx'] = 2.5*math.sin(2*math.pi*0.08*t)
    o['lean'] = 1.2*math.sin(2*math.pi*0.09*t+1.9)
    o['tilt'] = 1.5*math.sin(2*math.pi*0.11*t+0.7)
    o['armL'] = (10+1.5*math.sin(2*math.pi*0.2*t+1.3), 8+2*math.sin(2*math.pi*0.27*t))
    o['armR'] = (10+1.5*math.sin(2*math.pi*0.2*t+2.1), 8+2*math.sin(2*math.pi*0.27*t+0.9))
    o['stepL'] = o['stepR'] = (0.0, 0.0)
    gl = track(t, [(T1+0.3,0),(T1+1.0,1),(T1+L1,1),(T1+L1+0.6,0)])
    o['tilt'] += gl*(-5)
    g2 = track(t, [(T2-0.25,0),(T2+0.3,1),(T2+L2-0.1,1),(T2+L2+0.5,0)])
    if g2 > 0:
        beat = 8*math.sin(2*math.pi*1.7*(t-T2))*mouth_open(t,'B')
        thL, elL = o['armL']; thR, elR = o['armR']
        o['armL'] = (thL+g2*(38+0.5*beat), elL+g2*(92+beat))
        o['armR'] = (thR+g2*(38+0.5*beat), elR+g2*(92+beat))
        o['tilt'] += g2*(7+2*math.sin(2*math.pi*1.1*(t-T2))); o['lean'] += g2*(-1.0)
    st = t-(T2-0.1)
    if 0 <= st < 0.5:
        ph = math.sin(math.pi*st/0.5); o['stepR'] = (-10*ph, 20*ph)
    g3a = track(t, [(T3,0),(T3+0.35,1),(T3+1.2,1),(T3+2.0,0)])
    o['lean'] += g3a*(-2.5); o['tilt'] += g3a*(-4)
    if t > T3+3.2:
        nod = track(t, [(T3+3.2,0),(T3+3.8,1),(END-0.6,1),(END,0.4)])
        o['tilt'] += 6*math.sin(2*math.pi*0.55*(t-T3-3.2))*nod
    return o

BLINKS_A = [1.3, 3.9, 6.6, 9.1, 11.8, 14.2]
BLINKS_B = [0.8, 3.1, 5.4, 7.9, 10.6, 13.4]

INK = (32, 27, 24)
SKIN = (255, 248, 238)
RED, YELLOW = (205, 46, 40), (248, 202, 44)
TEAL = (52, 148, 155)
SHORTS = (45, 40, 38)

def draw_stickman(canvas, anchor_x, o, t, who, facing, shirt, beanie=False, glasses=False):
    d = ImageDraw.Draw(canvas)
    s0 = 17 if who == 'A' else 71
    dx, bob = o['dx'], o['bob']
    pelvis = (anchor_x+dx+wob(s0,t)[0], FLOOR_Y-(THIGH+SHIN)*0.972+bob+wob(s0+1,t)[1])
    lean = math.radians(o['lean'])
    neck = (pelvis[0]+TORSO*math.sin(lean), pelvis[1]-TORSO*math.cos(lean))
    neck = (neck[0]+wob(s0+2,t)[0], neck[1]+wob(s0+2,t)[1]*0.6)
    shoulder = (neck[0], neck[1]+16)
    tilt = math.radians(o['tilt'])
    headc = (neck[0]+(HEAD_R+10)*math.sin(lean+tilt*0.6), neck[1]-(HEAD_R+10)*math.cos(lean+tilt*0.6))

    feet, knees = [], []
    for side, step in ((-1, o['stepL']), (1, o['stepR'])):
        F = (anchor_x+side*FOOT_SPREAD+step[0]+wob(s0+3+side,t,0.5)[0], FLOOR_Y-step[1])
        K = leg_ik(pelvis, F, side)
        K = (K[0]+wob(s0+5+side,t,0.7)[0], K[1]+wob(s0+5+side,t,0.7)[1])
        feet.append((F, side)); knees.append(K)

    # soft warm contact shadow
    sh = Image.new('RGBA', (340, 60), (0,0,0,0))
    ImageDraw.Draw(sh).ellipse([8,8,332,52], fill=(35,18,12,85))
    sh = sh.filter(ImageFilter.GaussianBlur(9))
    canvas.alpha_composite(sh, (int(anchor_x+dx-170), int(FLOOR_Y-18)))
    d = ImageDraw.Draw(canvas)

    LW = 11
    def line(p, q, w=LW, col=INK):
        d.line([p, q], fill=col, width=w)
        for pt in (p, q):
            d.ellipse([pt[0]-w/2, pt[1]-w/2, pt[0]+w/2, pt[1]+w/2], fill=col)
    def joint(p, r=8):
        d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=(15,12,10))

    # legs
    for (F, side), K in zip(feet, knees):
        line(pelvis, K); line(K, F)
        fl = FOOT_LEN if side == facing else int(FOOT_LEN*0.8)
        line(F, (F[0]+side*fl, F[1]))
        joint(K)
    # shorts
    for (F, side), K in zip(feet, knees):
        kx, ky = K
        mx_, my_ = pelvis[0]*0.45+kx*0.55, pelvis[1]*0.45+ky*0.55
        line(pelvis, (mx_, my_), 46, SHORTS)
    joint(pelvis, 9)
    # torso + shirt
    line(pelvis, neck, 13)
    shirt_top = (neck[0], neck[1]+26)
    shirt_bot = (pelvis[0]*0.96+neck[0]*0.04, pelvis[1]-26)
    line(shirt_top, shirt_bot, 86, shirt)
    # head
    d.ellipse([headc[0]-HEAD_R, headc[1]-HEAD_R, headc[0]+HEAD_R, headc[1]+HEAD_R],
              fill=SKIN, outline=INK, width=9)
    if beanie:
        bx0, by0 = headc[0]-HEAD_R-5, headc[1]-HEAD_R-10
        bx1, by1 = headc[0]+HEAD_R+5, headc[1]+HEAD_R*0.42
        d.pieslice([bx0, by0, bx1, by1], 180, 360, fill=RED, outline=INK, width=7)
        bandy = (by0+by1)/2
        d.rounded_rectangle([bx0-2, bandy-13, bx1+2, bandy+11], 12, fill=RED, outline=INK, width=6)
    exo = 14*facing
    eyo = 2 if beanie else -8
    eyes = [(headc[0]-20+exo, headc[1]+eyo), (headc[0]+20+exo, headc[1]+eyo)]
    blink = any(b <= t < b+0.14 for b in (BLINKS_A if who=='A' else BLINKS_B))
    for ex, ey in eyes:
        if blink: d.line([ex-8, ey, ex+8, ey], fill=INK, width=5)
        else: d.ellipse([ex-6, ey-6, ex+6, ey+6], fill=INK)
    if glasses:
        for ex, ey in eyes:
            d.ellipse([ex-15, ey-15, ex+15, ey+15], outline=INK, width=5)
        d.line([eyes[0][0]+15, eyes[0][1]-2, eyes[1][0]-15, eyes[1][1]-2], fill=INK, width=5)
    mo = mouth_open(t, who)
    mx, my = headc[0]+10*facing, headc[1]+(32 if beanie else 27)
    if mo > 0.12:
        mw, mh = 16+14*mo, 7+26*mo
        d.ellipse([mx-mw, my-mh/2, mx+mw, my+mh/2], fill=(40,24,20))
    else:
        d.arc([mx-16, my-12, mx+16, my+8], 20, 160, fill=INK, width=5)
    # arms over shirt
    for side, (th, el) in ((-1, o['armL']), (1, o['armR'])):
        E, Hd = arm_pts(shoulder, th, el, side)
        E = (E[0]+wob(s0+8+side,t,0.7)[0], E[1]+wob(s0+8+side,t,0.7)[1])
        Hd = (Hd[0]+wob(s0+10+side,t,0.8)[0], Hd[1]+wob(s0+10+side,t,0.8)[1])
        line(shoulder, E); line(E, Hd)
        joint(E)
        d.ellipse([Hd[0]-9, Hd[1]-9, Hd[0]+9, Hd[1]+9], fill=INK)
    joint(shoulder, 9)

# ---------------- captions ----------------
FONT = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/Vazirmatn-Medium.ttf'), 56)
def rtl(x): return get_display(arabic_reshaper.reshape(x))
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
            x, y = (W-tw)//2, 1600
            d.text((x+2, y+3), s, font=FONT, fill=(20,10,8, int(190*a)))
            d.text((x, y), s, font=FONT, fill=(255,250,242, int(255*a)))
            d.rounded_rectangle([W/2-60, y+92, W/2+60, y+100], 4, fill=(*col, int(235*a)))
            frame.alpha_composite(layer)

# ---------------- cinematic grade ----------------
def make_vignette():
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((xx-W/2)/(W*0.72))**2 + ((yy-H/2)/(H*0.62))**2)
    v = np.clip(1.0 - 0.32*np.clip(r-0.55, 0, None)**1.6, 0.55, 1.0)
    return v[..., None].astype(np.float32)
VIG = make_vignette()
GRAINS = [np.random.default_rng(i).normal(0, 3.2, (H, W, 1)).astype(np.float32) for i in range(6)]

def grade(frame, f):
    a = np.asarray(frame.convert('RGB'), dtype=np.float32)
    a = a*VIG + GRAINS[f % 6]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

# ---------------- main ----------------
def render(frames_dir, times=None):
    os.makedirs(frames_dir, exist_ok=True)
    bg = Image.open(os.path.join(ROOT, 'assets/bg-dusk.png')).convert('RGBA').resize((W, 1932), Image.LANCZOS).crop((0, 0, W, H))
    rng = times if times else [f/FPS for f in range(TOTAL_FRAMES)]
    for i, t in enumerate(rng):
        frame = bg.copy()
        ob = pose_B(t); oa = pose_A(t)
        draw_stickman(frame, B_X, ob, t, 'B', facing=-1, shirt=TEAL, glasses=True)
        draw_stickman(frame, A_X, oa, t, 'A', facing=1, shirt=YELLOW, beanie=True)
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
