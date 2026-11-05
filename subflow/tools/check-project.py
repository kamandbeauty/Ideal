#!/usr/bin/env python3
"""Static consistency checks for the SubFlow source tree.

The Flutter/Dart and Kotlin toolchains are not available in this workspace, so
this script verifies the things that a compiler would otherwise catch first:
unresolved imports, missing assets, channel-name drift between Dart and Kotlin,
JNI symbol mismatches, unbalanced braces (a truncated file), forbidden WebView
usage, and an accidental INTERNET permission.

It is not a compiler and does not pretend to be one. Everything it checks is
mechanical and objective.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
checks = 0
notes: list[str] = []


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


# ---------------------------------------------------------------- inventory
dart_files = sorted(ROOT.glob("lib/**/*.dart")) + sorted(ROOT.glob("test/**/*.dart"))
kt_files = sorted(ROOT.glob("android/app/src/main/kotlin/**/*.kt"))
cpp_files = sorted(ROOT.glob("android/app/src/main/cpp/**/*.cpp")) + sorted(
    ROOT.glob("android/app/src/main/cpp/**/*.h")
)

check(len(dart_files) > 20, f"expected the Dart app sources, found {len(dart_files)} files")
check(len(kt_files) >= 6, f"expected Kotlin bridge/media/core sources, found {len(kt_files)}")
check(len(cpp_files) >= 10, f"expected the C++ core, found {len(cpp_files)}")

# ------------------------------------------------------- balanced delimiters
def strip_comments(text: str) -> str:
    """Removes // and /* */ comments so braces inside prose do not count."""
    without_block = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", without_block)


for path in dart_files + kt_files + cpp_files:
    text = strip_comments(path.read_text(encoding="utf-8"))
    for open_ch, close_ch, label in (("{", "}", "braces"), ("(", ")", "parens"), ("[", "]", "brackets")):
        if text.count(open_ch) != text.count(close_ch):
            failures.append(
                f"{rel(path)}: unbalanced {label} "
                f"({text.count(open_ch)} vs {text.count(close_ch)})"
            )
    checks += 1

# ------------------------------------------------------------ dart imports
pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
declared_packages = set(re.findall(r"^  ([a-z_0-9]+):", pubspec, re.MULTILINE))
own_package = re.search(r"^name: (\w+)", pubspec, re.MULTILINE)
if own_package:
    declared_packages.add(own_package.group(1))
sdk_packages = {"flutter", "flutter_test", "flutter_localizations", "flutter_web_plugins"}

for path in dart_files:
    text = path.read_text(encoding="utf-8")
    for match in re.finditer(r"^import '([^']+)';", text, re.MULTILINE):
        target = match.group(1)
        if target.startswith("dart:"):
            continue
        if target.startswith("package:"):
            package = target.split("/")[0].replace("package:", "")
            if package not in declared_packages and package not in sdk_packages:
                failures.append(f"{rel(path)}: package '{package}' is not declared in pubspec.yaml")
            continue
        resolved = (path.parent / target).resolve()
        if not resolved.exists():
            failures.append(f"{rel(path)}: unresolved import '{target}'")
        checks += 1

# ------------------------------------------- unused relative-import detection
# Mirrors the `unused_import: error` analyzer rule set in analysis_options.yaml:
# for every relative import, at least one top-level symbol of that file must be
# referenced by the importer.
DECL_PATTERNS = (
    re.compile(r"^(?:abstract\s+|sealed\s+|final\s+)?(?:class|enum|mixin|typedef|extension)\s+(\w+)", re.MULTILINE),
    re.compile(r"^(?:const|final|var|late)\s+[\w<>?,\s]+?\s(\w+)\s*=", re.MULTILINE),
    re.compile(r"^(?:Future<[\w<>?]+>|void|int|double|bool|String|[A-Z]\w*)\s+(\w+)(?:<[^>]*>)?\(", re.MULTILINE),
    re.compile(r"^\s+static const \w+ (\w+) =", re.MULTILINE),
)


def declared_symbols(text: str) -> set[str]:
    symbols: set[str] = set()
    for pattern in DECL_PATTERNS:
        symbols |= set(pattern.findall(text))
    return {symbol for symbol in symbols if len(symbol) > 2 and symbol != "main"}


for path in dart_files:
    text = path.read_text(encoding="utf-8")
    body = re.sub(r"^import [^\n]+$", "", text, flags=re.MULTILINE)
    for target in re.findall(r"^import '(\.\.?/[^']+)';", text, re.MULTILINE):
        resolved = (path.parent / target).resolve()
        if not resolved.exists():
            continue
        symbols = declared_symbols(resolved.read_text(encoding="utf-8"))
        if not symbols:
            continue
        if not any(re.search(rf"\b{re.escape(sym)}\b", body) for sym in symbols):
            failures.append(f"{rel(path)}: imports '{target}' but uses none of its symbols")
        checks += 1

# -------------------------------------------------------------- dart assets
for path in dart_files:
    text = path.read_text(encoding="utf-8")
    for match in re.finditer(r"'(assets/[^']+)'", text):
        asset = match.group(1)
        if asset.endswith("/"):
            continue
        if not (ROOT / asset).exists():
            failures.append(f"{rel(path)}: references missing asset '{asset}'")
        checks += 1

# pubspec asset directories + fonts must exist
for directory in re.findall(r"^    - (assets/[^/\n]+/)$", pubspec, re.MULTILINE):
    check((ROOT / directory).is_dir(), f"pubspec asset directory missing: {directory}")
for font in re.findall(r"asset: (assets/[^\n]+)", pubspec):
    check((ROOT / font).exists(), f"pubspec font missing: {font}")

# ------------------------------------------- dart <-> kotlin channel parity
constants_dart = (ROOT / "lib/core/constants.dart").read_text(encoding="utf-8")
contract_kt = (ROOT / "android/app/src/main/kotlin/app/subflow/bridge/BridgeContract.kt").read_text(
    encoding="utf-8"
)
bridge_kt = (ROOT / "android/app/src/main/kotlin/app/subflow/bridge/SubFlowBridge.kt").read_text(
    encoding="utf-8"
)


def dart_strings(text: str, block: str) -> set[str]:
    section = re.search(rf"class {block} \{{(.*?)\n\}}", text, re.DOTALL)
    if not section:
        return set()
    return set(re.findall(r"= '([^']+)'", section.group(1)))


def kotlin_strings(text: str) -> set[str]:
    return set(re.findall(r'const val [A-Z_0-9]+ = "([^"]+)"', text))


dart_methods = dart_strings(constants_dart, "NativeMethods")
dart_channel_names = dart_strings(constants_dart, "Channels")
kt_strings = kotlin_strings(contract_kt)

for method in sorted(dart_methods):
    check(method in kt_strings, f"Dart calls '{method}' but BridgeContract.kt does not define it")

# Every Kotlin inbound handler must be reachable from Dart (no dead bridge code).
handled = set(re.findall(r"BridgeContract\.(METHOD_[A-Z_]+) ->", bridge_kt))
named = dict(re.findall(r'const val (METHOD_[A-Z_]+) = "([^"]+)"', contract_kt))
for constant in sorted(handled):
    value = named.get(constant)
    check(value in dart_methods, f"Kotlin handles {constant} = '{value}' but Dart never calls it")

check("app.subflow/native" in dart_channel_names, "Dart channel name mismatch for the native channel")
check("app.subflow/native" in kt_strings, "Kotlin channel name mismatch for the native channel")
check("app.subflow/player_view" in dart_channel_names and "app.subflow/player_view" in kt_strings,
      "platform view type differs between Dart and Kotlin")
check("app.subflow/player" in dart_channel_names and "app.subflow/player" in kt_strings,
      "player channel prefix differs between Dart and Kotlin")

# ---------------------------------------------------------- JNI symbol names
jni_source = (ROOT / "android/app/src/main/cpp/jni/sf_jni.cpp").read_text(encoding="utf-8")
jni_exports = set(re.findall(r"Java_app_subflow_core_NativeCore_(native\w+)", jni_source))
native_core_kt = (ROOT / "android/app/src/main/kotlin/app/subflow/core/NativeCore.kt").read_text(
    encoding="utf-8"
)
kotlin_externals = set(re.findall(r"external fun (\w+)\(", native_core_kt))
for fun in sorted(kotlin_externals):
    check(fun in jni_exports, f"Kotlin declares external '{fun}' with no matching JNI export")
for export in sorted(jni_exports):
    check(export in kotlin_externals,
          f"JNI export '{export}' has no Kotlin external declaration (dead symbol)")

# ------------------------------------------------------------- CMake sources
cmake = (ROOT / "android/app/src/main/cpp/CMakeLists.txt").read_text(encoding="utf-8")
cmake_block = cmake.split("add_library(subflow_core SHARED", 1)[-1].split(")", 1)[0]
for source in re.findall(r"((?:core|jni)/[\w.]+)", cmake_block):
    check((ROOT / "android/app/src/main/cpp" / source).exists(), f"CMakeLists references missing {source}")
cmake_all = "\n".join(
    str(p.relative_to(ROOT / "android/app/src/main/cpp"))
    for p in (ROOT / "android/app/src/main/cpp/core").glob("*.cpp")
)
for cpp in sorted(p.name for p in (ROOT / "android/app/src/main/cpp/core").glob("*.cpp")):
    check(f"core/{cpp}" in cmake_all and f"core/{cpp}" in cmake,
          f"{cpp} is not compiled by CMakeLists.txt")

# ------------------------------------------------------------ kotlin package
for path in kt_files:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^package ([\w.]+)", text, re.MULTILINE)
    check(match is not None, f"{rel(path)}: missing package declaration")
    if match is None:
        continue
    expected_dir = ROOT / "android/app/src/main/kotlin" / match.group(1).replace(".", "/")
    check(path.parent == expected_dir,
          f"{rel(path)}: package {match.group(1)} does not match its directory")
    for import_line in re.findall(r"^import (app\.subflow\.[\w.]+)", text, re.MULTILINE):
        target = ROOT / "android/app/src/main/kotlin" / import_line.replace(".", "/")
        candidates = list(target.parent.glob(target.name + ".kt")) if target.parent.exists() else []
        check(bool(candidates), f"{rel(path)}: unresolved Kotlin import {import_line}")

# ------------------------------------------------------- sql manifest parity
manifest = json.loads((ROOT / "assets/db/manifest.json").read_text(encoding="utf-8"))
check(manifest["schemaVersion"] == len(manifest["migrations"]),
      "manifest schemaVersion must equal the number of migrations")
for migration in manifest["migrations"]:
    sql_path = ROOT / migration["file"]
    check(sql_path.exists(), f"missing migration file {migration['file']}")
    if not sql_path.exists():
        continue
    sql = sql_path.read_text(encoding="utf-8")
    check(f"PRAGMA user_version = {migration['version']}" in sql,
          f"{sql_path.name} does not set user_version = {migration['version']}")

# ------------------------------------------------------------- app manifest
app_manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
check("android.permission.INTERNET" not in app_manifest,
      "AndroidManifest must not request INTERNET (offline product)")
check("android:supportsRtl=\"true\"" in app_manifest, "AndroidManifest must support RTL")
check("android:minSdkVersion" not in app_manifest, "minSdk belongs in build.gradle.kts")

gradle = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
check("minSdk = 26" in gradle, "minSdk must be 26 (Android 8)")
check("arm64-v8a" in gradle, "arm64-v8a must be built")
check("src/main/cpp/CMakeLists.txt" in gradle, "CMake must be wired into the Android build")

# --------------------------------------------------- forbidden constructions
# A WebView would violate non-negotiable #1: the UI must be real Flutter. The
# check looks for actual API usage, not the word appearing in documentation.
webview_api = re.compile(r"(WebViewWidget|InAppWebView|webview_flutter|addJavascriptChannel|"
                         r"loadDataWithBaseURL|WebViewController\()")
for path in dart_files + kt_files:
    text = path.read_text(encoding="utf-8")
    if webview_api.search(text):
        failures.append(f"{rel(path)}: WebView API usage is forbidden")
    checks += 1

# The UI must not open raw HTTP sockets for media processing.
for path in dart_files:
    text = path.read_text(encoding="utf-8")
    if re.search(r"http://(?!\s)", text) or re.search(r"https://", text):
        notes.append(f"{rel(path)}: contains a URL literal (verify it is not a media upload)")

# ------------------------------------------------------- router class checks
router = (ROOT / "lib/app/router.dart").read_text(encoding="utf-8")
for target in re.findall(r"^import '([^']+)';", router, re.MULTILINE):
    if target.startswith("package:"):
        continue
    resolved = (ROOT / "lib/app" / target).resolve()
    check(resolved.exists(), f"router import '{target}' does not exist")

# Every screen the router instantiates must exist in some Dart file.
defined_classes: set[str] = set()
for path in dart_files:
    defined_classes |= set(re.findall(r"class (\w+)", path.read_text(encoding="utf-8")))
referenced_screens = set(re.findall(r"const (\w+Screen)\(\)", router)) | set(
    re.findall(r"(\w+Screen)\(projectId", router)
)
for name in sorted(referenced_screens):
    check(name in defined_classes, f"router references {name} which is not defined anywhere")
check(len(referenced_screens) >= 6, "router should wire every Phase 1 screen")

# --------------------------------------------------------- JSON sanity pass
for json_path in ROOT.glob("assets/**/*.json"):
    try:
        json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        failures.append(f"{rel(json_path)}: invalid JSON ({exc})")

print(f"SubFlow project check: {checks} assertions, {len(failures)} failure(s)")
for failure in failures:
    print(f"  FAIL {failure}")
for note in notes:
    print(f"  NOTE {note}")
sys.exit(0 if not failures else 1)
