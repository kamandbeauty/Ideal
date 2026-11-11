#!/usr/bin/env python3
"""Inspect the exported APKs themselves, not just the exporter's exit code.

This is package validation in CI. It does not run the game on a device.
"""
import hashlib
import json
import pathlib
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
PACKAGES = {
    "LastWall-arm64.apk": ("package-metadata.txt", "AndroidManifest.txt", "com.frontline.lastwall"),
    "LastWall-compatibility.apk": ("compatibility-package-metadata.txt", "compatibility-AndroidManifest.txt", "com.frontline.lastwall.compatibility"),
}
report = {}
for name, (metadata_file, manifest_file, package_id) in PACKAGES.items():
    package = root / name
    assert package.is_file() and package.stat().st_size > 1_000_000, name
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        assert any(n.endswith("libgodot_android.so") and "arm64-v8a" in n for n in names), "ARM64 engine library missing"
        assert not any("armeabi-v7a" in n or "x86_64" in n for n in names), "unexpected architecture"
        assert any(n.endswith("project.binary") for n in names), "project data missing"
        assert archive.testzip() is None, "ZIP CRC failure"
    metadata = (root / metadata_file).read_text()
    manifest = (root / manifest_file).read_text()
    assert "package: name='%s'" % package_id in metadata, "unexpected package id"
    assert "minSdkVersion:'24'" in metadata, "unexpected minimum Android API"
    assert "targetSdkVersion:'36'" in metadata, "unexpected target Android API"
    assert "android.permission.INTERNET" not in metadata and "android.permission.INTERNET" not in manifest, "offline game requests INTERNET"
    assert "screenOrientation" in manifest, "activity orientation attribute missing"
    assert "android.hardware.screen.landscape" in metadata, "activity is not landscape"
    report[name] = {
        "bytes": package.stat().st_size,
        "sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "package": package_id,
        "arm64": True,
        "zip_crc": "pass",
        "min_sdk": 24,
        "target_sdk": 36,
        "landscape": True,
        "no_internet_permission": True,
    }
report["scope"] = "CI export, signature and package inspection; no Android device or emulator run"
(root / "package-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
