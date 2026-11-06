#!/usr/bin/env python3
"""Inspect exported artifacts, not merely the exporter exit code.

This is CI package validation, not execution on an Android device.
"""
import hashlib
import json
import pathlib
import re
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
report = {}
for name in [
    "Artillery-Frontline-arm64.apk",
    "Artillery-Frontline-arm64.aab",
    "Artillery-Frontline-compatibility.apk",
]:
    package = root / name
    assert package.is_file() and package.stat().st_size > 1_000_000, name
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        assert any(n.endswith("libgodot_android.so") and "arm64-v8a" in n for n in names), "ARM64 native engine missing"
        assert not any("armeabi-v7a" in n or "x86_64" in n for n in names), "Unexpected architecture"
        assert any(n.endswith("project.binary") for n in names), "Project data missing"
        assert archive.testzip() is None, "ZIP CRC failure"
    report[name] = {
        "bytes": package.stat().st_size,
        "sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "arm64": True,
        "zip_crc": "pass",
    }

metadata = (root / "package-metadata.txt").read_text()
compat_metadata = (root / "compatibility-package-metadata.txt").read_text()
assert "package: name='com.frontline.artillery'" in metadata
assert "package: name='com.frontline.artillery.compatibility'" in compat_metadata
for text in (metadata, compat_metadata):
    assert "minSdkVersion:'24'" in text, "Unexpected minimum Android API"
    assert "targetSdkVersion:'36'" in text, "Unexpected target Android API"
    assert "android.permission.INTERNET" not in text, "Offline build requests INTERNET"

# Badging's implied landscape feature is useful, but also decode the actual
# activity attribute so a missing orientation cannot pass this check.
manifest = (root / "AndroidManifest.txt").read_text()
compat_manifest = (root / "compatibility-AndroidManifest.txt").read_text()
for text in (manifest, compat_manifest):
    values = re.findall(r"screenOrientation[^\n]*?=\(type 0x10\)(0x[0-9a-fA-F]+)", text)
    assert values and any(int(value, 16) in (0, 6, 9) for value in values), "Activity is not landscape"
    assert "android.permission.INTERNET" not in text, "Manifest requests INTERNET"
for name in ("Artillery-Frontline-arm64.apk", "Artillery-Frontline-compatibility.apk"):
    report[name].update({"package_id_verified": True, "min_sdk": 24, "target_sdk": 36, "landscape": True, "no_internet_permission": True})
report["Artillery-Frontline-arm64.aab"]["signature_check"] = "jarsigner verified in CI"
report["scope"] = "CI export, signature and package inspection; no Android device/emulator execution"
(root / "package-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
