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
project = pathlib.Path(__file__).resolve().parent.parent
NOT_EXPORTED = ("tests", "tools", "documentation", ".godot", "android")
PACKAGES = {
    "LastWall-arm64.apk": ("package-metadata.txt", "AndroidManifest.txt", "com.studiojavid.zombiesiege"),
    "LastWall-compatibility.apk": ("compatibility-package-metadata.txt", "compatibility-AndroidManifest.txt", "com.studiojavid.zombiesiege.compatibility"),
}
problems = []
report = {}


def expect(condition, message):
    if not condition:
        problems.append(message)


def field(text, name):
    match = re.search(name + r":?'([^']*)'", text)
    return match.group(1) if match else ""


def attribute(manifest, name):
    """Value of an attribute in an `aapt2 dump xmltree` listing, as text ("" when absent)."""
    match = re.search(name + r"\(0x[0-9a-fA-F]+\)=(?:\(type 0x[0-9a-fA-F]+\))?\"?([^\s\"]+)", manifest)
    return match.group(1) if match else ""


def expected_entries():
    """What a package must hold for every project file that ships: scripts as tokens,
    scenes and resources as remaps, imported sources as their importer records."""
    for path in sorted(project.rglob("*")):
        if not path.is_file():
            continue
        parts = path.relative_to(project).parts
        if parts[0] in NOT_EXPORTED or path.suffix == ".md":
            continue
        name = path.relative_to(project).as_posix()
        if path.suffix == ".gd":
            yield name, ("assets/%sc" % name, "assets/%s" % name, "assets/%s.remap" % name)
        elif path.suffix in (".tscn", ".tres"):
            yield name, ("assets/%s.remap" % name, "assets/%s" % name)
        elif path.with_name(path.name + ".import").exists():
            yield name, ("assets/%s.import" % name,)


presets = (project / "export_presets.cfg").read_text()
project_file = (project / "project.godot").read_text()
wanted_name = re.search(r'version/name="([^"]*)"', presets).group(1)
wanted_code = re.search(r"version/code=(\d+)", presets).group(1)
expect('config/version="%s"' % wanted_name in project_file, "the export presets and project.godot disagree about the version")


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
        present = set(names)
        wanted_files = list(expected_entries())
        absent = [source for source, options in wanted_files if not any(option in present for option in options)]
        expect(len(wanted_files) >= 100, "%s: only %d project files were looked for" % (name, len(wanted_files)))
        expect(not absent, "%s: project files missing from the package: %s" % (name, ", ".join(absent[:12])))
        libraries = sorted(n for n in names if n.startswith("lib/"))
    expect(package.stat().st_size < 120_000_000, "%s is unreasonably large (%d bytes)" % (name, package.stat().st_size))
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
    permissions = sorted(set(re.findall(r"uses-permission(?:-sdk-\d+)?: name='([^']+)'", metadata))
                         | set(re.findall(r"E: uses-permission[^\n]*\n\s*A: [^\n]*?=\"([^\"]+)\"", manifest)))
    expect(not permissions, "%s: an offline game needs no permission, yet it asks for %s" % (name, ", ".join(permissions)))
    category = attribute(manifest, "appCategory")
    is_game = attribute(manifest, "isGame")
    expect(category == "0" and is_game == "true", "%s: not declared as a game (appCategory=%s, isGame=%s)" % (name, category, is_game))
    debuggable = attribute(manifest, "debuggable") == "true"
    version_name = field(metadata, "versionName=")
    version_code = field(metadata, "versionCode=")
    expect(version_name == wanted_name and version_code == wanted_code,
           "%s: version is %s (%s), expected %s (%s)" % (name, version_name, version_code, wanted_name, wanted_code))
    expect(attribute(manifest, "allowBackup") in ("false", ""), "%s: Android may back up the save although the preset forbids it" % name)
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
        "permissions": permissions,
        "declared_as_game": category == "0" and is_game == "true",
        "build": "debug template (debuggable)" if debuggable else "release template (not debuggable)",
        "version_name": version_name,
        "version_code": version_code,
        "native_libraries": libraries,
        "project_files_packed": len(wanted_files) - len(absent),
        "project_files_missing": absent,
    }
report["problems"] = problems
report["scope"] = "CI export, signature and package inspection; no Android device or emulator run"
(root / "package-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
for problem in problems:
    print("::error title=Package check::%s" % problem)
sys.exit(1 if problems else 0)
