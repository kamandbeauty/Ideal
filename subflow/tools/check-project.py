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
    """Removes // and /* */ comments so braces inside prose do not count.

    Quote-aware on purpose: a `https://...` string literal is not a comment, and
    the earlier regex silently deleted the rest of such a line - which is how a
    perfectly balanced Kotlin file started failing the brace check.
    """
    out: list[str] = []
    index = 0
    length = len(text)
    quote: str | None = None
    while index < length:
        char = text[index]
        nxt = text[index + 1] if index + 1 < length else ""
        if quote is not None:
            out.append(char)
            if char == "\\" and nxt:
                out.append(nxt)
                index += 2
                continue
            if char == quote:
                quote = None
            index += 1
            continue
        if char in ("'", '"'):
            quote = char
            out.append(char)
            index += 1
            continue
        if char == "/" and nxt == "/":
            while index < length and text[index] != "\n":
                index += 1
            continue
        if char == "/" and nxt == "*":
            index += 2
            while index < length - 1 and not (text[index] == "*" and text[index + 1] == "/"):
                index += 1
            index += 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


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
# The product is offline: media, audio and subtitles never leave the device. The
# exceptions are documented in the manifest: the Whisper model downloader (fetches
# weights only) and the opt-in online transcription provider, which uploads the
# audio of one project to an endpoint the user configured. Both have to stay
# documented and must not drag in any other network-related permission.
if "android.permission.INTERNET" in app_manifest:
    check("fetching a Whisper model" in app_manifest,
          "INTERNET is only allowed for the documented model downloader")
    check("opt-in online provider" in app_manifest,
          "the documented cloud provider exception must stay in the manifest")
    check("android.permission.ACCESS_NETWORK_STATE" not in app_manifest,
          "no extra network permissions: the downloader needs INTERNET only")
else:
    check(False, "the model downloader needs INTERNET (see WhisperEngine.downloadModel)")
check("android:supportsRtl=\"true\"" in app_manifest, "AndroidManifest must support RTL")
check("android:minSdkVersion" not in app_manifest, "minSdk belongs in build.gradle.kts")

# The Whisper weights ship inside the APK. They are 57 MB, so they are fetched at
# build time and never committed - which only stays true if all three pieces exist:
# the fetch script, the packaging rule that keeps the asset openable, and the
# .gitignore entry that keeps the file out of the repository.
fetch_script = ROOT / "tools/fetch-bundled-model.sh"
check(fetch_script.is_file(), "tools/fetch-bundled-model.sh must exist")
if fetch_script.is_file():
    fetch_text = fetch_script.read_text(encoding="utf-8")
    check("huggingface.co" in fetch_text, "the bundled model fetch needs the primary host")
    check("hf-mirror.com" in fetch_text, "the bundled model fetch needs the mirror fallback")
    check("ggml" in fetch_text, "the fetch must verify the ggml magic before packaging")
workspace_root = ROOT.parent
gitignore = (workspace_root / ".gitignore").read_text(encoding="utf-8")
check("assets/models/*.bin" in gitignore, "the bundled model must never be committed")
engine = (ROOT / "android/app/src/main/kotlin/app/subflow/asr/WhisperEngine.kt").read_text(encoding="utf-8")
check("BUILTIN_ASSET" in engine, "WhisperEngine must know the bundled model asset")
check("ensureBuiltIn" in engine, "the bundled model must be copied out of the APK on first use")
check("lmgg" in engine, "ggml magic is little-endian on disk: \"lmgg\" must be accepted too")
check('String(magic) != "ggml"' not in engine,
      "no magic check may compare the raw bytes to the string \"ggml\"")
check("openFd(BUILTIN_ASSET)" in engine, "the bundled asset must be opened uncompressed (openFd)")
workflow = (workspace_root / ".github/workflows/subflow-android.yml").read_text(encoding="utf-8")
check("tools/fetch-bundled-model.sh" in workflow, "CI must fetch the bundled model before building")

gradle = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
check("minSdk = 26" in gradle, "minSdk must be 26 (Android 8)")
check("arm64-v8a" in gradle, "arm64-v8a must be built")
check("src/main/cpp/CMakeLists.txt" in gradle, "CMake must be wired into the Android build")
check('noCompress += "bin"' in gradle, "bundled .bin assets must stay uncompressed (openFd)")

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


# ------------------------------------------------------- brand + launcher art
# tools/make_icons.py is the only source of the launcher art; these checks make
# sure a missing density cannot reach the Gradle resource linker again.
densities = ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
for density in densities:
    folder = ROOT / f"android/app/src/main/res/mipmap-{density}"
    for name in ("ic_launcher.png", "ic_launcher_round.png",
                 "ic_launcher_foreground.png", "ic_launcher_background.png"):
        check((folder / name).exists(), f"missing launcher artwork mipmap-{density}/{name}")

for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
    adaptive = ROOT / "android/app/src/main/res/mipmap-anydpi-v26" / name
    check(adaptive.exists(), f"missing adaptive icon {name}")
    if adaptive.exists():
        body = adaptive.read_text(encoding="utf-8")
        check("<adaptive-icon" in body, f"{name} is not an adaptive-icon")
        check("@mipmap/ic_launcher_foreground" in body, f"{name} must use the keyed foreground")
        check("@mipmap/ic_launcher_background" in body, f"{name} must use the generated backdrop")

check('android:roundIcon="@mipmap/ic_launcher_round"' in app_manifest,
      "manifest must declare roundIcon")
for asset in ("assets/branding/app_icon_1024.png", "assets/branding/app_icon_512.png"):
    check((ROOT / asset).exists(), f"missing {asset}")

# ---------------------------------------------------- caption engine coverage
effect_enums = (ROOT / "lib/features/effects/caption_effect.dart").read_text(encoding="utf-8")
labels_src = (ROOT / "lib/features/effects/caption_labels.dart").read_text(encoding="utf-8")
renderer_src = (ROOT / "lib/features/effects/caption_renderer.dart").read_text(encoding="utf-8")


def enum_cases(source: str, name: str) -> list[str]:
    match = re.search(rf"enum {name} \{{(.*?)\}}", source, re.DOTALL)
    if not match:
        failures.append(f"enum {name} not found in caption_effect.dart")
        return []
    return [line.strip().rstrip(",") for line in match.group(1).splitlines()
            if line.strip() and not line.strip().startswith("//")]


for enum_name in ("CaptionAnimation", "CaptionExit", "CaptionWordEffect"):
    cases = enum_cases(effect_enums, enum_name)
    check(len(cases) >= 5, f"enum {enum_name} looks truncated ({len(cases)} cases)")
    for case in cases:
        check(f"{enum_name}.{case}" in labels_src,
              f"{enum_name}.{case} has no Persian label in caption_labels.dart")
        check(f"{enum_name}.{case}" in renderer_src,
              f"{enum_name}.{case} is never handled by the renderer")

check(len(enum_cases(effect_enums, "CaptionAnimation")) >= 16,
      "at least 16 entrance animations are required")
check(len(enum_cases(effect_enums, "CaptionExit")) >= 8, "at least 8 exit animations are required")
check(len(enum_cases(effect_enums, "CaptionWordEffect")) >= 8, "at least 8 word effects are required")

presets_src = (ROOT / "lib/features/effects/presets_library.dart").read_text(encoding="utf-8")
pairs = len(re.findall(r"^      id: '", presets_src, re.MULTILINE))
check(pairs * 2 >= 30, f"preset catalogue must ship >= 30 looks, found {pairs * 2}")

fonts_src = (ROOT / "lib/features/effects/caption_fonts.dart").read_text(encoding="utf-8")
persian_families = set()
for block in re.findall(r"CaptionFont\((.*?)\n  \);", fonts_src, re.DOTALL):
    family = re.search(r"family: '([^']+)'", block)
    persian = "supportsPersian: true" in block
    if family and persian:
        persian_families.add(family.group(1))
check(len(persian_families) >= 5, "at least five Persian-capable families are required")

for fa_font in re.findall(r"faFont: '([^']+)'", presets_src):
    check(fa_font in persian_families,
          f"Persian preset uses '{fa_font}' which is not a Persian-capable family")

pubspec_fonts = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
for family in re.findall(r"family: '([^']+)'", presets_src) + sorted(persian_families):
    check(f"family: {family}" in pubspec_fonts,
          f"font family '{family}' is used by presets but not declared in pubspec.yaml")

# ------------------------------------------------------ subtitle studio wiring
studio = ROOT / "lib/features/subtitles/subtitle_studio_screen.dart"
check(studio.exists(), "missing the subtitle studio screen")
check("'/project/:id/subtitles'" in router, "router must expose the subtitle studio")
check("SubtitleStudioScreen" in router, "router must instantiate the subtitle studio")

dao_src = (ROOT / "lib/database/dao/subtitle_dao.dart").read_text(encoding="utf-8")
for method in ("ensureOriginalTrack", "loadSegments", "replaceSegments", "saveStyle"):
    check(f"Future" in dao_src and method in dao_src, f"subtitle DAO is missing {method}()")

doc_src = (ROOT / "lib/features/subtitles/subtitle_document.dart").read_text(encoding="utf-8")
for operation in ("withText", "withTiming", "splitAt", "mergeWithNext", "insertAt", "shiftAll"):
    check(operation in doc_src, f"subtitle document is missing {operation}()")
check("minSegmentUs" in doc_src, "subtitle document must enforce a minimum segment length")

model_src = (ROOT / "lib/features/subtitles/subtitle_editor_model.dart").read_text(encoding="utf-8")
for member in ("bool undo()", "bool redo()", "historyLimit"):
    check(member in model_src, f"editor model is missing {member}")

check("SubtitleExportService" in (ROOT / "lib/services/subtitle_export_service.dart").read_text(encoding="utf-8"),
      "missing the subtitle export service")



# ------------------------------------------------ per-caption style (0.11.0)
#
# Three things must stay true for "customise one caption" to be real: the column
# exists and is written, the editor writes to it instead of the project style,
# and the renderer receives it per cue. Each of those is checked here because a
# miss in any one of them is invisible until an export comes out wrong.
migration_manifest = json.loads((ROOT / "assets/db/manifest.json").read_text(encoding="utf-8"))
check(migration_manifest["schemaVersion"] >= 3,
      "per-caption styles need schema version 3")
check(any(m["version"] == 3 for m in migration_manifest["migrations"]),
      "migration 3 (segment preset_json) is missing from the manifest")
segment_sql = (ROOT / "assets/db/003_segment_style.sql").read_text(encoding="utf-8")
check("preset_json" in segment_sql, "migration 3 must add subtitle_segments.preset_json")

segment_model = (ROOT / "lib/models/subtitle.dart").read_text(encoding="utf-8")
check("presetJson" in segment_model and "'preset_json'" in segment_model,
      "SubtitleSegment must carry preset_json to and from the database")
document_src = (ROOT / "lib/features/subtitles/subtitle_document.dart").read_text(encoding="utf-8")
for operation in ("withPreset(", "withPresetFrom("):
    check(operation in document_src, f"subtitle document is missing {operation}")
editor_dirty = (ROOT / "lib/features/subtitles/subtitle_editor_model.dart").read_text(encoding="utf-8")
check("x.presetJson != y.presetJson" in editor_dirty,
      "the editor's change detection must notice a per-caption style edit")
check("presetJson: fixed.presetJson" in doc_src,
      "subtitle normalisation must carry preset_json through")
editor_model = (ROOT / "lib/features/subtitles/subtitle_editor_model.dart").read_text(encoding="utf-8")
for operation in ("setSegmentPreset(", "applySegmentPresetToAll(", "addEmojis("):
    check(operation in editor_model, f"editor model is missing {operation}")

studio_src = (ROOT / "lib/features/subtitles/subtitle_studio_screen.dart").read_text(encoding="utf-8")
check("_styleScopeBar" in studio_src, "the editor needs a scope control for per-caption styling")
check("setSegmentPreset" in studio_src and "applySegmentPresetToAll" in studio_src,
      "the editor must be able to pin a style to one caption and copy it to all")
check("_presetFor(" in studio_src, "the stage must render a caption's own style")

# ------------------------------------------------------- long-task progress
# Import, export and transcription are the three places a user stares at the
# screen, so they must share one progress surface instead of three spinners.
progress_src = (ROOT / "lib/shared/widgets/sf_progress.dart").read_text(encoding="utf-8")
for widget in ("class SfProgressBar", "class SfProgressRing", "class SfProgressDialog",
               "class SfTaskOverlay", "class SfProgressController"):
    check(widget in progress_src, f"progress widget missing: {widget}")
check("sfFormatRemaining" in progress_src, "progress surface must format remaining time")
check("disableAnimations" in progress_src, "progress animations must respect reduced motion")
check("milliseconds: 90" in progress_src, "progress callbacks must be coalesced")
check((ROOT / "test/sf_progress_test.dart").exists(), "the progress surface needs tests")

export_sheet_src = (ROOT / "lib/features/subtitles/video_export_sheet.dart").read_text(
    encoding="utf-8")
check("SfProgressDialog" in export_sheet_src and "SfProgressController" in export_sheet_src,
      "the render dialog must use the shared progress surface")
import_screen_src = (ROOT / "lib/features/video_import/video_import_screen.dart").read_text(
    encoding="utf-8")
check("SfTaskOverlay" in import_screen_src,
      "importing a clip must show the task overlay, not a button spinner")
asr_src = (ROOT / "lib/features/asr/asr_screen.dart").read_text(encoding="utf-8")
check(asr_src.count("SfProgressBar(") >= 3,
      "transcription, model download and the cloud check each need the shared bar")

stray = []
for path in (ROOT / "lib").rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    if "LinearProgressIndicator" in text:
        stray.append(str(path.relative_to(ROOT)))
check(not stray, f"bare LinearProgressIndicator left in: {stray}")

render_service_src = (ROOT / "lib/services/video_export_service.dart").read_text(encoding="utf-8")
check("decodePreset" in render_service_src, "the renderer must decode per-caption styles")
check("'style': decodePreset" in render_service_src,
      "each render cue must carry its own style when it has one")
exporter_model = (ROOT / "android/app/src/main/kotlin/app/subflow/export/ExportRequest.kt").read_text(encoding="utf-8")
check("val style: CaptionLook?" in exporter_model,
      "the Kotlin cue model must accept a per-caption style")
painter_src_2 = (ROOT / "android/app/src/main/kotlin/app/subflow/export/CaptionFramePainter.kt").read_text(encoding="utf-8")
check("cueStyles" in painter_src_2, "the native painter must resolve a style per cue")

# ------------------------------------------------------------- font catalogue
fonts_dir = ROOT / "assets/fonts"
catalog_src = (ROOT / "lib/features/effects/caption_fonts.dart").read_text(encoding="utf-8")
pubspec_src = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
catalogue_families = re.findall(r"family: '([^']+)'", catalog_src)
check(len(catalogue_families) >= 24,
      f"expected at least 24 caption families, found {len(catalogue_families)}")
for family in catalogue_families:
    check(f"family: {family}" in pubspec_src,
          f"font family '{family}' is in the catalogue but not declared in pubspec.yaml")
    stem = family.replace(" ", "")
    regular = fonts_dir / f"{stem}-Regular.ttf"
    check(regular.exists(), f"missing font file for family '{family}'")
    licences = list((fonts_dir / "licenses").glob(f"*{stem}*"))
    check(bool(licences), f"missing licence file for font family '{family}'")
    for weight_file in (fonts_dir).glob(f"{stem}-*.ttf"):
        check(weight_file.stat().st_size > 8 * 1024,
              f"{weight_file.name} looks truncated")

# Persian coverage record: the fonts were verified with fontTools at review time,
# and the emoji table must stay non-trivial for the auto-emoji pass to be honest.
persian_doc = (ROOT / "docs/PHASE-3-REPORT.md").read_text(encoding="utf-8")
check("fontTools" in persian_doc or "fontTools" in (ROOT / "assets/fonts/README.md").read_text(encoding="utf-8")
      if (ROOT / "assets/fonts/README.md").exists() else True,
      "font coverage verification must be documented")
emoji_src = (ROOT / "lib/features/subtitles/emoji_suggester.dart").read_text(encoding="utf-8")
check(emoji_src.count("': '") >= 60, "the emoji keyword table lost entries")
check("_endsWithEmoji" in emoji_src, "auto-emoji must not stack emojis on repeat runs")

# ------------------------------------------------------ video render (phase 5)
#
# The renderer is the only place where the app re-implements the caption look,
# so these assertions guard the two things that would silently break "preview ==
# export": a bridge method that exists on one side only, and an animation the
# native painter never learned about.
render_service = ROOT / "lib/services/video_export_service.dart"
check(render_service.exists(), "missing the video export service")
render_src = render_service.read_text(encoding="utf-8")
check("preset.toMap()" in render_src,
      "video export must send the same CaptionPreset map the preview renders with")
check("class VideoExportService" in render_src, "missing VideoExportService")
kf = ROOT / "android/app/src/main/kotlin/app/subflow/export/CaptionFramePainter.kt"
check(kf.exists(), "missing the native caption frame painter")
painter_src = kf.read_text(encoding="utf-8")
effects_src = (ROOT / "lib/features/effects/caption_effect.dart").read_text(encoding="utf-8")


def enum_values(source: str, name: str) -> list:
    body = re.search(r"enum " + name + r"\s*\{(.*?)\n\}", source, re.S)
    if body is None:
        return []
    return [value.strip() for value in re.findall(r"^\s{2}(\w+),", body.group(1), re.MULTILINE)]


for animation in enum_values(effects_src, "CaptionAnimation"):
    check(f'"{animation.lower()}"' in painter_src,
          f"caption animation '{animation}' is never handled by the native painter")
for effect in enum_values(effects_src, "CaptionWordEffect"):
    check(f'"{effect.lower()}"' in painter_src,
          f"word effect '{effect}' is never handled by the native painter")

exporter_src = (ROOT / "android/app/src/main/kotlin/app/subflow/export/VideoExporter.kt").read_text(encoding="utf-8")
check("Transformer.Builder" in exporter_src, "the renderer must use Media3 Transformer")
check("OverlayEffect" in exporter_src, "the renderer must draw the caption as an overlay effect")
check("Presentation.createForHeight" in exporter_src, "the renderer must cap the output resolution")
check("setClipStartPositionMs" in exporter_src and "setClipEndPositionMs" in exporter_src,
      "the renderer must support a trimmed range")
check("progress" in exporter_src and "getProgress" in exporter_src,
      "the renderer must report real encoder progress")

manifest_src = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
check("androidx.core.content.FileProvider" in manifest_src,
      "the share sheet needs a FileProvider declared in the manifest")
check("${applicationId}.fileprovider" in manifest_src,
      "the FileProvider authority must match the one the bridge builds")
check((ROOT / "android/app/src/main/res/xml/file_paths.xml").exists(),
      "missing res/xml/file_paths.xml for the FileProvider")
paths_src = (ROOT / "android/app/src/main/res/xml/file_paths.xml").read_text(encoding="utf-8")
check("Movies/exports/" in paths_src, "the FileProvider must expose the render output directory")
bridge_src = (ROOT / "android/app/src/main/kotlin/app/subflow/bridge/SubFlowBridge.kt").read_text(encoding="utf-8")
bridge_contract_src = (ROOT / "android/app/src/main/kotlin/app/subflow/bridge/BridgeContract.kt").read_text(encoding="utf-8")
check("handleExportVideo" in bridge_src and "handleShareFile" in bridge_src,
      "the bridge is missing the render or share handler")
check("METHOD_EXPORT_CANCEL" in bridge_src, "the bridge cannot cancel a running render")
constants_src = (ROOT / "lib/core/constants.dart").read_text(encoding="utf-8")
check("app.subflow/export" in constants_src, "Dart must know the export event channel")
for method in ("export.video", "export.cancel", "export.share"):
    check(f"'{method}'" in constants_src and f'"{method}"' in bridge_contract_src,
          f"bridge method {method} is not declared on both sides")

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
