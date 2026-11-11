#!/usr/bin/env python3
"""Inspect the exported APKs themselves, not just the exporter's exit code.

This is package validation in CI. It does not run the game on a device.
Problems are printed as workflow error annotations so they can be read
without downloading the job log.
"""
import hashlib
import json
import pathlib
import re
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
PACKAGES = {
    "LastWall-arm64.apk": ("package-metadata.txt", "AndroidManifest.txt", "com.frontline.lastwall"),
    "LastWall-compatibility.apk": ("compatibility-package-metadata.txt", "compatibility-AndroidManifest.txt", "com.frontline.lastwall.compatibility"),
}
problems = []
report = {}


def expect(condition, message):
    if not condition:
        problems.append(message)


def field(text, name):
    match = re.search(name + r":?'([^']*)'", text)
    return match.group(1) if match else ""


for name, (metadata_file, manifest_file, package_id) in PACKAGES.items():
    package = root / name
    if not package.is_file():
        problems.append("%s is missing" % name)
        continue
    expect(package.stat().st_size > 1_000_000, "%s is suspiciously small (%d bytes)" % (name, package.stat().st_size))
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        expect(any(n.endswith("libgodot_android.so") and "arm64-v8a" in n for n in names), "%s: ARM64 engine library missing" % name)
        expect(not any("armeabi-v7a" in n or "x86_64" in n for n in names), "%s: unexpected architecture" % name)
        expect(any(n.endswith("project.binary") for n in names), "%s: project data missing" % name)
        expect(archive.testzip() is None, "%s: ZIP CRC failure" % name)
        packed = [n for n in names if n.startswith("assets/") and (n.endswith(".gd") or n.endswith(".gdc") or n.endswith(".remap"))]
        expect(not any("/tests/" in n or "/tools/" in n for n in packed), "%s: tests or tools were exported" % name)
    metadata = (root / metadata_file).read_text()
    manifest = (root / manifest_file).read_text()
    found_id = field(metadata, "package: name=")
    min_sdk = field(metadata, "minSdkVersion") or field(metadata, "sdkVersion")
    target_sdk = field(metadata, "targetSdkVersion")
    # 0 landscape, 6 sensorLandscape, 8 reverseLandscape, 11 userLandscape. aapt2 only
    # infers the landscape feature for plain "landscape", so read the attribute itself.
    orientation = re.search(r"screenOrientation\(0x0101001e\)=(?:\(type 0x10\))?(0x[0-9a-fA-F]+|\d+)", manifest)
    orientation_value = int(orientation.group(1), 0) if orientation else -1
    landscape = orientation_value in (0, 6, 8, 11)
    expect(found_id == package_id, "%s: package id is '%s', expected '%s'" % (name, found_id, package_id))
    expect(min_sdk == "24", "%s: minimum Android API is '%s', expected 24" % (name, min_sdk))
    expect(target_sdk == "36", "%s: target Android API is '%s', expected 36" % (name, target_sdk))
    expect("android.permission.INTERNET" not in metadata and "android.permission.INTERNET" not in manifest, "%s: offline game requests INTERNET" % name)
    expect("screenOrientation" in manifest, "%s: activity orientation attribute missing" % name)
    expect(landscape, "%s: the activity is not locked to landscape (screenOrientation=%d)" % (name, orientation_value))
    report[name] = {
        "bytes": package.stat().st_size,
        "sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "package": found_id,
        "arm64": True,
        "min_sdk": min_sdk,
        "target_sdk": target_sdk,
        "landscape": landscape,
        "screen_orientation": orientation_value,
        "no_internet_permission": "android.permission.INTERNET" not in metadata,
    }
report["problems"] = problems
report["scope"] = "CI export, signature and package inspection; no Android device or emulator run"
(root / "package-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
for problem in problems:
    print("::error title=Package check::%s" % problem)
sys.exit(1 if problems else 0)
