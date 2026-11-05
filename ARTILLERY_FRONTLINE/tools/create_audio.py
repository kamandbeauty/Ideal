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
print('Synthesized six original audio assets at',RATE,'Hz')
