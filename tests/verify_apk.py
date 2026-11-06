#!/usr/bin/env python3
"""Inspect an exported APK, independently of Godot's exporter.

Requires pyaxmlparser; signature verification is performed separately by apksigner.
"""
import sys
import zipfile

from pyaxmlparser import APK

ANDROID = "{http://schemas.android.com/apk/res/android}"
path = sys.argv[1]
abi = sys.argv[2] if len(sys.argv) > 2 else "arm64-v8a"
apk = APK(path)
assert apk.is_valid_APK(), "APK manifest could not be parsed"
assert apk.package == "com.artilleryfrontline.game", apk.package
assert "android.permission.INTERNET" not in apk.get_permissions(), apk.get_permissions()
manifest = apk.get_android_manifest_xml()
activity = manifest.find("./application/activity[@%sname='com.godot.game.GodotApp']" % ANDROID)
assert activity is not None, "Godot game activity missing"
assert activity.get(ANDROID + "screenOrientation") == "11", "Expected sensor landscape"
providers = manifest.findall("./application/provider")
authorities = [p.get(ANDROID + "authorities") for p in providers if p.get(ANDROID + "authorities")]
assert len(authorities) == len(set(authorities)), f"Duplicate provider authorities: {authorities}"
with zipfile.ZipFile(path) as zf:
    assert f"lib/{abi}/libgodot_android.so" in zf.namelist(), f"Missing {abi} runtime"
    corrupt = zf.testzip()
    assert corrupt is None, f"Corrupt ZIP member: {corrupt}"
print(f"APK manifest OK: {apk.package}; landscape; {abi}; no internet permission; unique providers")
