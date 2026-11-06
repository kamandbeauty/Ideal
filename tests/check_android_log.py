#!/usr/bin/env python3
"""Fail an Android smoke run on engine errors, except a confirmed Vulkan fallback.

A missing Vulkan device is intentional when testing the Compatibility fallback.
Only Godot's two specific startup errors, before its fallback warning, are
exempted; shader, script, and later initialization errors remain failures.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

FALLBACK_WARNING = "Your device does not seem to support Vulkan, switching to OpenGL 3"
VULKAN_MISSING = "ERROR: vkEnumeratePhysicalDevices reported zero accessible devices."
VULKAN_CONDITION = 'ERROR: Condition "err != OK" is true. Returning: err'
VULKAN_CALLSITE = "at: initialize (drivers/vulkan/rendering_context_driver_vulkan.cpp:"
# Accept both logcat's time format and its common threadtime format.
GODOT_ERROR = re.compile(r"(?:E/godot\s*\(\s*\d+\)|\bE\s+godot)\s*:\s*ERROR:")


def unexpected_errors(text: str) -> list[str]:
    lines = text.splitlines()
    fallback = next((i for i, line in enumerate(lines) if FALLBACK_WARNING in line), -1)
    failures: list[str] = []
    for i, line in enumerate(lines):
        if "FATAL EXCEPTION" in line or "SCRIPT ERROR" in line:
            failures.append(line)
            continue
        if not GODOT_ERROR.search(line):
            continue
        before_fallback = 0 <= i < fallback
        next_line = lines[i + 1] if i + 1 < len(lines) else ""
        expected = before_fallback and (
            VULKAN_MISSING in line
            or (VULKAN_CONDITION in line and VULKAN_CALLSITE in next_line)
        )
        if not expected:
            failures.append(line)
    return failures


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: check_android_log.py path/to/logcat.txt", file=sys.stderr)
        return 2
    failures = unexpected_errors(Path(sys.argv[1]).read_text(errors="replace"))
    if failures:
        print("Unexpected Android runtime errors:", file=sys.stderr)
        print("\n".join(failures[:30]), file=sys.stderr)
        return 1
    print("Android log: no unexpected Godot/script/fatal errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
