"""Audio preparation: trim, loop, fades, volume — spec §9."""
from __future__ import annotations

import math
import os
import subprocess
from dataclasses import dataclass
from typing import Optional

import numpy as np

from .ffmpeg import ffmpeg_exe


@dataclass
class AudioSettings:
    path: Optional[str] = None
    volume: float = 1.0
    fade_in: float = 0.5
    fade_out: float = 1.0
    trim_start: float = 0.0
    trim_end: Optional[float] = None   # None -> end of file
    loop: bool = True

    def to_json(self) -> dict:
        return {
            "path": self.path, "volume": self.volume,
            "fadeIn": self.fade_in, "fadeOut": self.fade_out,
            "trimStart": self.trim_start, "trimEnd": self.trim_end,
            "loop": self.loop,
        }


def decode_to_float(path: str, sample_rate: int = 48000,
                    channels: int = 2) -> np.ndarray:
    """Decode any supported file to float32 PCM via ffmpeg. shape=(n, ch)."""
    cmd = [ffmpeg_exe(), "-v", "error", "-i", path,
           "-f", "f32le", "-acodec", "pcm_f32le",
           "-ar", str(sample_rate), "-ac", str(channels), "-"]
    out = subprocess.run(cmd, capture_output=True, check=True).stdout
    arr = np.frombuffer(out, dtype=np.float32)
    if arr.size == 0:
        raise ValueError("audio decode produced no samples")
    return arr.reshape(-1, channels)


def probe_duration(path: str) -> float:
    # ffprobe is not shipped with imageio-ffmpeg; decode and count instead.
    return decode_to_float(path).shape[0] / 48000.0


def build_audio(settings: Optional[AudioSettings], target_seconds: float,
                sample_rate: int = 48000,
                channels: int = 2) -> Optional[np.ndarray]:
    """Produce exactly `target_seconds` of audio, applying §9 rules."""
    if settings is None or settings.path is None:
        return None
    n_target = int(round(target_seconds * sample_rate))
    if n_target <= 0:
        return None

    pcm = decode_to_float(settings.path, sample_rate, channels)
    total = pcm.shape[0]

    start = int(round(max(0.0, settings.trim_start) * sample_rate))
    end = total if settings.trim_end is None else int(round(settings.trim_end * sample_rate))
    end = min(end, total)
    if end <= start:
        raise ValueError("audio trim range is empty")
    clip = pcm[start:end]
    clip_len = clip.shape[0]

    if settings.loop and clip_len > 0:
        # Overlap-add looping: each repetition starts `fade_n` samples before the
        # previous one ends and the overlap is equal-power crossfaded, so the seam
        # is click-free and the total length is exact (spec §9).
        fade_n = min(int(0.020 * sample_rate), max(1, clip_len // 4))
        step = clip_len - fade_n
        out = np.zeros((n_target, channels), dtype=np.float32)
        pos = 0
        a = np.linspace(0, math.pi / 2, fade_n, dtype=np.float32)[:, None]
        while pos < n_target:
            end = min(pos + clip_len, n_target)
            seg = clip[: end - pos].copy()
            if pos > 0:
                n = min(fade_n, end - pos)
                prev = out[pos:pos + n]
                seg[:n] = prev * np.cos(a[:n]) + seg[:n] * np.sin(a[:n])
            out[pos:end] = seg
            pos += step
        # Any remainder beyond the last full repetition is already written;
        # nothing to mask because the tail was truncated naturally.
    else:
        out = np.zeros((n_target, channels), dtype=np.float32)
        take = min(n_target, clip_len)
        out[:take] = clip[:take]

    out = out.astype(np.float32) * float(settings.volume)

    # Fades, clamped so they can never overlap.
    fi = max(0.0, min(settings.fade_in, target_seconds / 2))
    fo = max(0.0, min(settings.fade_out, target_seconds / 2))
    if fi > 0:
        n = int(fi * sample_rate)
        if n > 1:
            out[:n] *= np.linspace(0, 1, n, dtype=np.float32)[:, None]
    if fo > 0:
        n = int(fo * sample_rate)
        if n > 1:
            out[-n:] *= np.linspace(1, 0, n, dtype=np.float32)[:, None]

    return np.clip(out, -1.0, 1.0)


def write_wav(path: str, data: np.ndarray, sample_rate: int = 48000) -> str:
    import wave
    pcm16 = np.clip(data, -1, 1)
    pcm16 = (pcm16 * 32767.0).astype(np.int16)
    channels = data.shape[1]
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(pcm16.tobytes())
    return path
