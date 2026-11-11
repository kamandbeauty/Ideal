"""Static export intent checks; this does not inspect a built APK."""
from configparser import ConfigParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name: str) -> ConfigParser:
    parser = ConfigParser(interpolation=None)
    text = (ROOT / name).read_text(encoding="utf-8")
    parser.read_string("[header]\n" + text)
    return parser


project = load("project.godot")
preset = load("export_presets.cfg")
assert project["display"]["window/handheld/orientation"] == "1", "Expected portrait orientation"
assert preset["preset.0"]["platform"] == '"Android"'
options = preset["preset.0.options"]
assert options.getboolean("architectures/arm64-v8a")
for abi in ("armeabi-v7a", "x86", "x86_64"):
    assert not options.getboolean("architectures/" + abi)
assert not options.getboolean("permissions/internet")
assert options.getboolean("package/signed")
assert not any(key.startswith("keystore/") for key in options)
print("PASS: portrait, ARM64-only, no requested internet, no stored signing credentials")
print("NOTE: preset intent only; no APK or manifest was inspected")
