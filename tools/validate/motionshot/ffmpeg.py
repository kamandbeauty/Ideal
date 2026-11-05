"""Thin wrapper around the bundled ffmpeg binary."""
from __future__ import annotations

import functools
import subprocess


@functools.lru_cache(maxsize=1)
def ffmpeg_exe() -> str:
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def run(args, capture: bool = True) -> subprocess.CompletedProcess:
    cmd = [ffmpeg_exe(), "-hide_banner", "-v", "error"] + list(args)
    return subprocess.run(cmd, capture_output=capture, check=True)
