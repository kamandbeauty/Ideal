"""Encoding: pipes reference frames to ffmpeg (H.264 / HEVC + AAC)."""
from __future__ import annotations

import json
import os
import subprocess
from typing import Callable, Optional

import numpy as np

from .audio import AudioSettings, build_audio, write_wav
from .ffmpeg import ffmpeg_exe
from .renderer import RenderProject, SourceCache, iter_frames

QUALITY_BPP = {"standard": 0.10, "high": 0.16, "maximum": 0.24}


def derive_bitrate(out_w: int, out_h: int, fps: int, quality: str,
                   codec: str, custom: int = 0) -> int:
    """spec §8.2"""
    if quality == "custom" and custom > 0:
        return int(min(max(custom, 1_500_000), 100_000_000))
    bpp = QUALITY_BPP.get(quality, 0.16)
    hevc = 0.70 if codec == "hevc" else 1.0
    b = out_w * out_h * fps * bpp * hevc
    return int(min(max(b, 1_500_000), 100_000_000))


def round_even(v: int) -> int:
    """4:2:0 chroma requires an even width/height (spec §8.1)."""
    return max(2, (int(v) // 2) * 2)


# kept for callers that intentionally want macroblock alignment
def round16(v: int) -> int:
    return max(16, (int(v) // 16) * 16)


class ExportResult:
    def __init__(self, path: str, width: int, height: int, fps: int,
                 duration: float, frames: int, bitrate: int, codec: str,
                 has_audio: bool):
        self.path = path
        self.width = width
        self.height = height
        self.fps = fps
        self.duration = duration
        self.frames = frames
        self.bitrate = bitrate
        self.codec = codec
        self.has_audio = has_audio

    def __repr__(self) -> str:
        return (f"ExportResult({os.path.basename(self.path)} "
                f"{self.width}x{self.height}@{self.fps} "
                f"{self.frames}f {self.duration:.3f}s {self.codec} "
                f"{self.bitrate//1000}kbps audio={self.has_audio})")


def export_video(project: RenderProject, out_path: str, *, codec: str = "h264",
                 quality: str = "high", custom_bitrate: int = 0,
                 audio: Optional[AudioSettings] = None,
                 work_dir: str = "/tmp",
                 progress: Optional[Callable[[float, str], None]] = None,
                 should_cancel: Optional[Callable[[], bool]] = None) -> ExportResult:
    w = round16(project.out_w)
    h = round16(project.out_h)
    fps = project.fps
    duration = project.total_duration
    bitrate = derive_bitrate(w, h, fps, quality, codec, custom_bitrate)

    has_audio = audio is not None and audio.path is not None
    wav_path = None
    if has_audio:
        pcm = build_audio(audio, duration)
        if pcm is not None:
            wav_path = write_wav(os.path.join(work_dir, "motionshot_audio.wav"), pcm)
        else:
            has_audio = False

    vcodec = "libx265" if codec == "hevc" else "libx264"
    args = [
        "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{w}x{h}", "-r", str(fps), "-i", "-",
    ]
    if wav_path:
        args += ["-i", wav_path]
    # Quality-first settings: CRF is only a safety net under the target bitrate.
    crf = {"standard": "23", "high": "18", "maximum": "14"}.get(quality, "18")
    args += [
        "-c:v", vcodec,
        "-b:v", str(bitrate),
        "-maxrate", str(int(bitrate * 1.5)),
        "-bufsize", str(int(bitrate * 2)),
        "-preset", "medium",
        "-pix_fmt", "yuv420p",
        "-profile:v", "high" if codec == "h264" else "main",
        "-x264-params" if codec == "h264" else "-x265-params",
        f"crf={crf}:keyint={fps * 2}:min-keyint={fps}:scenecut=0",
    ]
    if codec == "hevc":
        args += ["-tag:v", "hvc1"]
    if wav_path:
        args += ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
                 "-shortest"]
    args += ["-movflags", "+faststart", "-f", "mp4", out_path]

    proc = subprocess.Popen([ffmpeg_exe(), "-hide_banner", "-v", "error"] + args,
                            stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    cache = SourceCache()
    frames = 0
    try:
        for i, t, frame in iter_frames(project, cache):
            if should_cancel and should_cancel():
                proc.kill()
                proc.wait()
                raise RuntimeError("cancelled")
            proc.stdin.write(np.ascontiguousarray(frame).tobytes())
            frames += 1
            if progress:
                progress((i + 1) / project.total_frames, "encoding")
        proc.stdin.close()
        err = proc.stderr.read().decode("utf-8", "replace")
        code = proc.wait()
        if code != 0:
            raise RuntimeError(f"ffmpeg failed ({code}): {err[-2000:]}")
        if not os.path.exists(out_path) or os.path.getsize(out_path) < 1024:
            raise RuntimeError("encoder produced no usable output file")
    finally:
        cache.clear()
        if proc.poll() is None:
            proc.kill()
        if wav_path and os.path.exists(wav_path):
            os.remove(wav_path)

    return ExportResult(out_path, w, h, fps, duration, frames, bitrate, codec,
                        has_audio)


def probe(path: str) -> dict:
    """Verify the produced file: streams, duration, frame count, dimensions."""
    out = subprocess.run(
        [ffmpeg_exe(), "-hide_banner", "-v", "error", "-i", path,
         "-f", "null", "-"],
        capture_output=True, text=True)
    info = subprocess.run(
        [ffmpeg_exe(), "-hide_banner", "-i", path],
        capture_output=True, text=True)
    text = (info.stderr or "") + (out.stderr or "")
    res = {"path": path, "size": os.path.getsize(path), "stderr": text}
    import re
    m = re.search(r"Duration: (\d+):(\d+):(\d+\.\d+)", text)
    if m:
        res["duration"] = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    m = re.search(r"Video: (\w+).*?, (\d+)x(\d+)", text)
    if m:
        res["codec"] = m.group(1)
        res["width"] = int(m.group(2))
        res["height"] = int(m.group(3))
    m = re.search(r"(\d+(?:\.\d+)?) fps", text)
    if m:
        res["fps"] = float(m.group(1))
    m = re.search(r"Audio: (\w+)", text)
    if m:
        res["audio_codec"] = m.group(1)
    return res
