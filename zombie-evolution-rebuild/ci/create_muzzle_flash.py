#!/usr/bin/env python3
"""Generate a small transparent starburst sprite for the real muzzle effect."""
import math
import struct
import zlib
from pathlib import Path

size = 128
rows = []
for y in range(size):
    row = bytearray([0])
    for x in range(size):
        dx = (x + 0.5 - size / 2) / (size / 2)
        dy = (y + 0.5 - size / 2) / (size / 2)
        r = math.hypot(dx, dy)
        angle = math.atan2(dy, dx)
        core = math.exp(-r * r * 27.0)
        glow = math.exp(-r * r * 8.0) * 0.32
        rays = (abs(math.cos(angle * 4.0)) ** 32.0) * math.exp(-r * 3.8) * (1.0 - min(r, 1.0)) * 1.5
        alpha = max(0.0, min(1.0, core + glow + rays))
        warmth = min(1.0, r * 2.0)
        color = (255, round(255 - 63 * warmth), round(246 - 184 * warmth))
        row.extend((*color, round(alpha * 255)))
    rows.append(bytes(row))

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
target = Path(__file__).resolve().parents[1] / 'assets/effects/muzzle_star.png'
target.write_bytes(png)
print('Wrote', target, len(png), 'bytes')
