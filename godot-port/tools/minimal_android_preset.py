#!/usr/bin/env python3
"""Write the smallest Android export preset that can produce an APK.

Used by CI as a diagnostic: if the shipped preset fails and this one exports, the problem is a key
in `export_presets.cfg`, not the toolchain. Every option here is one the game actually needs.
"""

from pathlib import Path

PRESET = """[preset.0]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/minimal.apk"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
version/code=1
version/name="1.0.0"
package/unique_name="com.shazdeh.palace"
package/name="Prince's Palace"
package/signed=true
package/app_category=2
launcher_icons/main_192x192="res://assets/branding/icon_192.png"
launcher_icons/adaptive_foreground_432x432="res://assets/branding/icon_432.png"
launcher_icons/adaptive_background_432x432="res://assets/branding/icon_432.png"
permissions/internet=true
"""


def main() -> int:
    project = Path(__file__).resolve().parents[1]
    target = project / "export_presets.cfg"
    if not target.is_file():
        print(f"error: {target} does not exist", flush=True)
        return 1
    target.write_text(PRESET, encoding="utf-8")
    print(f"wrote the minimal Android preset to {target}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
