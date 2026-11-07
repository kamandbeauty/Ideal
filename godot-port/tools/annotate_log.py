#!/usr/bin/env python3
"""Turn a build log into GitHub check annotations.

Godot prints its Android export diagnostics to stdout, and a CI run whose logs cannot be downloaded is
a run nobody can debug. Annotations survive where a log file does not, so on failure (and only on
failure) the interesting lines are republished as annotations keyed by the file that is likely wrong.

    python3 godot-port/tools/annotate_log.py /tmp/export.log godot-port/export_presets.cfg
"""

from __future__ import annotations

import sys
from pathlib import Path

MAX_CHUNK = 900
MAX_ANNOTATIONS = 12
INTERESTING = (
    "error",
    "warning",
    "template",
    "sdk",
    "keystore",
    "gradle",
    "android",
    "export",
    "missing",
    "not found",
    "cannot",
    "failed",
)


def encode(message: str) -> str:
    """GitHub workflow commands need their payload escaped."""
    return message.replace("%", "%25").replace("\r", "").replace("\n", "%0A")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: annotate_log.py <log> [path-to-blame]", file=sys.stderr)
        return 2
    log_path = Path(argv[1])
    blame = argv[2] if len(argv) > 2 else "godot-port/export_presets.cfg"
    if not log_path.is_file():
        print(f"::error file={blame}::no build log was produced at {log_path}")
        return 1

    lines = [line.rstrip() for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines()]
    interesting = [line for line in lines if any(word in line.lower() for word in INTERESTING)]
    if not interesting:
        interesting = lines[-20:]

    emitted = 0
    chunk: list[str] = []
    size = 0
    for line in interesting:
        if size + len(line) + 1 > MAX_CHUNK:
            print(f"::error file={blame}::export log: {encode(' | '.join(chunk))}")
            emitted += 1
            chunk, size = [], 0
            if emitted >= MAX_ANNOTATIONS:
                break
        chunk.append(line)
        size += len(line) + 1
    if chunk and emitted < MAX_ANNOTATIONS:
        print(f"::error file={blame}::export log: {encode(' | '.join(chunk))}")
        emitted += 1

    print(f"republished {emitted} annotation(s) from {log_path} ({len(lines)} lines)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
