#!/usr/bin/env python3
"""Teach a headless Godot install where the Android SDK, the JDK and the debug key are.

Godot reads these from its editor settings file, not from environment variables, so a CI export
without this step fails with "Android SDK path is not configured" no matter how correct ANDROID_HOME
looks. Keeping it in a real file (instead of a heredoc glued into the workflow) is also what makes
the step diffable and runnable locally:

    ANDROID_HOME=... JAVA_HOME=... python3 godot-port/tools/write_editor_settings.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

FILE_NAME = "editor_settings-4.tres"


def main() -> int:
    home = Path(os.environ["HOME"])
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT", "")
    java = os.environ.get("JAVA_HOME", "")
    keystore = Path(os.environ.get("DEBUG_KEYSTORE", home / ".android" / "debug.keystore"))

    if not sdk or not Path(sdk).is_dir():
        print(f"error: no Android SDK found (ANDROID_HOME={sdk!r})", file=sys.stderr)
        return 1
    if not java or not Path(java).is_dir():
        print(f"error: no JDK found (JAVA_HOME={java!r})", file=sys.stderr)
        return 1
    if not keystore.is_file():
        print(f"error: debug keystore missing at {keystore}", file=sys.stderr)
        return 1

    settings_dir = home / ".config" / "godot"
    settings_dir.mkdir(parents=True, exist_ok=True)
    path = settings_dir / FILE_NAME
    path.write_text(
        '[gd_resource type="EditorSettings" format=3]\n'
        "\n"
        "[resource]\n"
        f'export/android/android_sdk_path = "{sdk}"\n'
        f'export/android/java_sdk_path = "{java}"\n'
        f'export/android/debug_keystore = "{keystore}"\n'
        'export/android/debug_keystore_user = "androiddebugkey"\n'
        'export/android/debug_keystore_pass = "android"\n',
        encoding="utf-8",
    )
    print(f"wrote {path}")
    print(f"  android_sdk_path = {sdk}")
    print(f"  java_sdk_path    = {java}")
    print(f"  debug_keystore   = {keystore}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
