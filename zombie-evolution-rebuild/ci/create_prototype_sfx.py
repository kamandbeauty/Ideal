"""Generate original, deterministic placeholder effects without external assets."""
from math import sin, pi, exp
from pathlib import Path
from random import Random
from struct import pack
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)


def write(name, duration, synth):
    rng = Random(4242)
    state = [0.0]
    samples = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0)
        state[0] += (noise - state[0]) * 0.24
        value = synth(t, noise, state[0])
        samples.append(pack('<h', int(max(-1.0, min(1.0, value)) * 24000)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b''.join(samples))


write('rifle', 0.22, lambda t, n, l: (0.65*n*exp(-t*30) + 0.52*l*exp(-t*18) + 0.25*sin(2*pi*(155-130*t)*t)*exp(-t*22)))
write('impact', 0.16, lambda t, n, l: (0.55*l + 0.30*sin(2*pi*180*t))*exp(-t*25))
write('gate', 0.38, lambda t, n, l: (sin(2*pi*510*t) + 0.45*sin(2*pi*765*t))*0.36*exp(-t*8))
write('reload', 0.58, lambda t, n, l: 0.42*n*sum(exp(-abs(t-x)*100) for x in (0.04,0.24,0.49)))
write('hurt', 0.24, lambda t, n, l: (0.40*l + 0.3*sin(2*pi*105*t))*exp(-t*13))
write('victory', 0.68, lambda t, n, l: 0.25*(sin(2*pi*(420 if t < 0.2 else 530 if t < 0.4 else 630)*t)+0.35*sin(2*pi*840*t))*exp(-t*2.5))
write('defeat', 0.58, lambda t, n, l: 0.38*sin(2*pi*(230-120*t)*t)*exp(-t*5))
print('Generated prototype SFX in', OUT)
