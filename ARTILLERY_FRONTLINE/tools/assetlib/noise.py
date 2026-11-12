"""Deterministic lattice value noise for procedural colour and shape detail."""
import numpy as np


def _hash(ix, iy, iz, seed):
    n = (ix.astype(np.uint32) * np.uint32(374761393)) ^ (iy.astype(np.uint32) * np.uint32(668265263)) ^ (
        iz.astype(np.uint32) * np.uint32(2246822519)) ^ np.uint32((seed * 3266489917) & 0xFFFFFFFF)
    n = (n ^ (n >> np.uint32(13))) * np.uint32(1274126177)
    n = n ^ (n >> np.uint32(16))
    return (n & np.uint32(0xFFFFFF)).astype(np.float32) / np.float32(0xFFFFFF)


def value(points, frequency=1.0, seed=0):
    """Trilinear value noise in [0, 1] for an (N, 3) array."""
    p = np.asarray(points, dtype=np.float32) * np.float32(frequency)
    base = np.floor(p)
    f = p - base
    f = f * f * (3.0 - 2.0 * f)
    i = base.astype(np.int64)
    ix, iy, iz = i[:, 0], i[:, 1], i[:, 2]
    out = np.zeros(p.shape[0], dtype=np.float32)
    for dx in (0, 1):
        wx = f[:, 0] if dx else 1.0 - f[:, 0]
        for dy in (0, 1):
            wy = f[:, 1] if dy else 1.0 - f[:, 1]
            for dz in (0, 1):
                wz = f[:, 2] if dz else 1.0 - f[:, 2]
                out += _hash(ix + dx, iy + dy, iz + dz, seed) * wx * wy * wz
    return out


def fbm(points, frequency=1.0, octaves=4, seed=0, gain=0.5, lacunarity=2.03):
    total = np.zeros(np.asarray(points).shape[0], dtype=np.float32)
    amplitude, norm = 1.0, 0.0
    for octave in range(octaves):
        total += value(points, frequency, seed + octave * 17) * amplitude
        norm += amplitude
        amplitude *= gain
        frequency *= lacunarity
    return total / norm


def ridged(points, frequency=1.0, octaves=3, seed=0):
    """Thin dark lines (veins, cracks): 0 on the ridge, 1 away from it."""
    total = np.zeros(np.asarray(points).shape[0], dtype=np.float32)
    amplitude, norm = 1.0, 0.0
    for octave in range(octaves):
        total += np.abs(value(points, frequency, seed + octave * 31) * 2.0 - 1.0) * amplitude
        norm += amplitude
        amplitude *= 0.5
        frequency *= 2.1
    return total / norm
