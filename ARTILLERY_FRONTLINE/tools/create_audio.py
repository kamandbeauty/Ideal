#!/usr/bin/env python3
"""Deterministic original PCM synthesis; no samples or external audio."""
import math, random, wave, struct, os
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','audio');os.makedirs(OUT,exist_ok=True)
RATE=24000
def write(name,duration,fn):
    rng=random.Random(421)
    values=[];low=0.;low2=0.
    for i in range(int(RATE*duration)):
        t=i/RATE;n=rng.uniform(-1,1)
        low=.94*low+.06*n;low2=.995*low2+.005*n
        values.append(fn(t,n,low,low2))
    peak=max(.01,max(abs(v) for v in values))
    gain=.78/peak
    with wave.open(os.path.join(OUT,name+'.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v*gain))*32767)) for v in values))
write('cannon',1.8,lambda t,n,l,l2: (n*.75+l2*3)*math.exp(-t*17)+math.sin(2*math.pi*(54*t-8*t*t))*.65*math.exp(-t*3)+l*.4*math.exp(-t*2))
write('explosion',2.8,lambda t,n,l,l2: (l2*5+l*.8)*math.exp(-t*1.8)+math.sin(2*math.pi*38*t)*.4*math.exp(-t*3)+n*.22*math.exp(-t*12))
write('reload',.8,lambda t,n,l,l2: sum(math.exp(-max(0,t-a)*35)*(math.sin(2*math.pi*f*t)*.3+n*.2) for a,f in [(0,430),(.24,720),(.53,240)] if t>=a))
write('click',.09,lambda t,n,l,l2: math.sin(2*math.pi*880*t)*math.exp(-t*55)*.4)
write('impact',.65,lambda t,n,l,l2: n*.4*math.exp(-t*18)+math.sin(2*math.pi*110*t)*math.exp(-t*9)*.35)
write('wind',8.,lambda t,n,l,l2: (l*.7+l2*1.5)*(.6+.15*math.sin(2*math.pi*t/8)))
# Loops use integer frequencies only, so each one repeats exactly at its length.
CHORDS=[(55,110,165,220),(44,88,132,176),(49,98,147,196),(41,82,123,164)]
def theme(t,n,l,l2):
    chord=CHORDS[int(t//12)%4]
    pad=sum(math.sin(2*math.pi*f*t) for f in chord)*.05*(.75+.25*math.sin(2*math.pi*t/6))
    root=chord[0]
    bass=math.sin(2*math.pi*root*t)*.22*math.exp(-(t%.75)*6)
    kick=math.sin(2*math.pi*48*(t%1.5))*.5*math.exp(-(t%1.5)*9)
    hat=n*.07*math.exp(-(t%.375)*60)
    return pad+bass+kick+hat
write('music_theme',48.,theme)
def engine(t,n,l,l2):
    # Diesel throb: harmonics of 28 Hz amplitude-modulated at 4 Hz; period 1 s.
    body=sum(math.sin(2*math.pi*28*h*t+h*1.7)/(h**1.3) for h in range(1,40))
    return body*(.7+.3*math.sin(2*math.pi*4*t))*.25
write('boat_engine',1.,engine)
write('ramp_clank',1.2,lambda t,n,l,l2: (sum(a*math.sin(2*math.pi*f*t)*math.exp(-t*d) for f,a,d in [(310,.5,5),(720,.35,7),(1180,.25,9),(1690,.15,12)]))+n*.3*math.exp(-t*60))
write('splash',1.2,lambda t,n,l,l2: l2*2.4*(min(1,t/.05))*math.exp(-t*3.5)+math.sin(2*math.pi*(300+900*t)*t)*.08*math.exp(-t*6))
print('Synthesized ten original audio assets at',RATE,'Hz')
