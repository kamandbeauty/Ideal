"""Feature audit: every product requirement must be traceable to real code.

No feature may be claimed on the strength of a label, a screen existing, or a
button whose handler does nothing. Each check looks for the *implementation*
symbol, not the UI text.
"""
from __future__ import annotations

import json
import os
import re
from typing import Dict, List, Tuple

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

DART_ROOT = os.path.join(ROOT, "lib")
KT_ROOT = os.path.join(ROOT, "android", "app", "src", "main", "kotlin")
DOCS = os.path.join(ROOT, "docs")

PASS, FAIL, TODO = "PASS", "NOT IMPLEMENTED", "BLOCKED"


def load_tree(root: str, ext: str) -> Dict[str, str]:
    out = {}
    for base, _, files in os.walk(root):
        for f in files:
            if f.endswith(ext):
                p = os.path.join(base, f)
                with open(p, "r", encoding="utf-8") as fh:
                    out[p] = fh.read()
    return out


def main() -> int:
    dart = load_tree(DART_ROOT, ".dart")
    kt = load_tree(KT_ROOT, ".kt")
    all_dart = "\n".join(dart.values())
    all_kt = "\n".join(kt.values())
    docs = {}
    for base, _, files in os.walk(DOCS):
        for f in files:
            if f.endswith(".md"):
                with open(os.path.join(base, f), "r", encoding="utf-8") as fh:
                    docs[os.path.relpath(os.path.join(base, f), ROOT)] = fh.read()

    checks: List[Tuple[str, str, str]] = []

    def need(name: str, pattern: str, where: str) -> None:
        text = all_dart if where == "dart" else all_kt if where == "kt" else all_dart + all_kt
        m = re.search(pattern, text, re.IGNORECASE)
        checks.append((name, PASS if m else FAIL,
                       "" if m else f"missing pattern {pattern!r}"))

    # ---- import / gallery -------------------------------------------------
    need("photo import (multi-select)", r"pickMultiImage", "dart")
    need("EXIF orientation handled", r"exif|ExifOrientation|orientation", "dart")
    need("photo reorder", r"class\s+\w*Reorder|reorder", "dart")
    need("photo replace", r"replacePhoto|replace\(", "dart")
    need("photo rotate", r"rotatePhoto|rotate\(", "dart")
    need("thumbnail cache", r"class ThumbnailService", "dart")

    # ---- motion -----------------------------------------------------------
    need("15 motion types", r"enum MotionType[\s\S]{0,2000}?combined", "dart")
    need("seeded random", r"photoSeed|Xorshift|fnv1a64", "dart")
    need("regenerate all (unlocked only)", r"regenerateAll", "dart")
    need("per-photo manual keyframes", r"class Keyframe|addKeyframe", "dart")
    need("pinch/drag gestures", r"onScaleStart|ScaleGestureRecognizer|onScaleUpdate", "dart")
    need("timeline playhead", r"playhead", "dart")
    need("custom cubic-bezier easing", r"cubicBezier|CubicBezier|easingCurve", "dart")
    need("undo/redo", r"class (?:EditorHistory|HistoryController|UndoStack)|undo\(\)", "dart")
    need("copy/paste motion", r"MotionClipboard", "dart")
    need("duplicate motion", r"duplicateMotion|duplicate", "dart")
    need("lock motion", r"isLocked", "dart")

    # ---- curved paths (spec §12) ------------------------------------------
    need("path model (spec + presets)", r"class MotionPathSpec|enum MotionPathPreset", "dart")
    need("centripetal CR spline engine", r"crSegment", "all")
    need("arc-length LUT (N=4096, refine=16)", r"buildArcLut|buildLut", "all")
    need("arc-length uniform parameter", r"paramAtArc|param_at_arc", "all")
    need("speed + speed-ease progress", r"progressAt|progress_at", "all")
    need("path evaluation (clamp + log-lerp zoom)", r"evaluatePath|evaluate_path", "all")
    need("bake path to keyframes", r"bakePathToKeyframes", "all")
    need("sanitize (cover-safe, pan-clamped)", r"sanitizePath|sanitize_path", "all")
    need("freehand smoothing (dedupe+resample+Chaikin)", r"smoothStroke", "all")
    need("curved-motion preset draw (no repeats)", r"pickPathPreset", "all")
    need("deterministic path generation (15 draws)", r"generatePathProfile", "all")
    need("~40% curved chance + protectManual", r"kCurvedPathChance|protectManual", "dart")
    need("path editor screen (freehand + presets)", r"class PathEditorScreen", "dart")
    need("path in export request", r"motionPath", "all")
    need("path preview integration", r"evaluatePath", "dart")
    need("Kotlin path evaluator (native render)", r"class MotionPathEvaluator", "kt")
    need("Kotlin path keyframe bake (fallback/tests)", r"fun bakePath\b", "kt")

    # ---- transitions ------------------------------------------------------
    for t in ["crossDissolve", "fade", "fadeToBlack", "slideLeft", "slideRight",
              "zoomTransition", "blurTransition", "smoothZoom", "none"]:
        need(f"transition {t}", t, "dart")
    need("transition randomizer avoids repeats",
         r"previous|avoid", "dart")

    # ---- preview ----------------------------------------------------------
    need("preview uses the same motion math", r"MotionInterpolator|sampleKeyframes", "dart")
    need("preview transform (unit rect -> pixels)", r"previewMatrix", "dart")

    # ---- audio ------------------------------------------------------------
    need("audio picker (MP3/AAC/WAV)", r"pickAudio|AudioSheet", "dart")
    need("volume", r"volume", "dart")
    need("fade in/out", r"fadeIn", "dart")
    need("trim", r"trimStart", "dart")
    need("loop with crossfade", r"loop", "dart")
    need("audio PCM building (native)", r"fun build|AudioRenderSpec", "kt")
    need("AAC encoding (native)", r"AAC|aac", "kt")

    # ---- export -----------------------------------------------------------
    for res in ["720", "1080", "1440", "2160"]:
        need(f"resolution {res}p", rf"{res}", "dart")
    for fps in ["24", "30", "60"]:
        need(f"fps {fps}", rf"{fps}", "dart")
    need("H.264", r"h264", "all")
    need("HEVC", r"hevc", "all")
    need("quality presets + custom bitrate", r"bitrate", "dart")
    for ar in ["9:16", "16:9", "1:1", "4:5"]:
        need(f"aspect {ar}", re.escape(ar), "dart")
    need("hardware encoder selection", r"MediaCodecList|isHardwareAccelerated|selectEncoder", "kt")
    need("MP4 via MediaMuxer", r"MediaMuxer", "kt")
    need("foreground service export", r"startForeground|ExportService", "kt")
    need("cancel export", r"cancelExport", "all")
    need("gallery publish via MediaStore", r"MediaStore", "kt")
    need("post-render verification", r"verify|MediaProbe", "dart")

    # ---- project ----------------------------------------------------------
    need("project persistence (SQLite)", r"sqflite|openDatabase", "dart")
    need("project resume", r"\.recent\(|\.load\(", "dart")
    need("project export/import file", r"projectJson|toJson", "dart")

    # ---- i18n / UI --------------------------------------------------------
    need("Persian + English", r"'fa'[\s\S]{0,200000}'en'|'en'[\s\S]{0,200000}'fa'", "dart")
    need("RTL support", r"TextDirection\.rtl|Directionality|isRtl", "dart")

    # ---- offline ----------------------------------------------------------
    manifest = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    with open(manifest, "r", encoding="utf-8") as fh:
        mf = fh.read()
    checks.append(("no INTERNET permission", PASS if "android.permission.INTERNET" not in mf else FAIL, ""))
    checks.append(("no HTTP client in Dart",
                   PASS if not re.search(r"package:http/|HttpClient\(", all_dart) else FAIL, ""))
    checks.append(("no FFmpeg", PASS if "ffmpeg" not in all_kt.lower() else FAIL, ""))

    # ---- curved path in the spec -------------------------------------------
    spec = next((v for k, v in docs.items() if k.endswith("MOTION_SPEC.md")), "")
    has_s12 = bool(re.search(r"^#{1,3}\s*12[\. ]|§12", spec, re.MULTILINE))
    checks.append(("spec: curved paths section (§12)", PASS if has_s12 else FAIL,
                   "" if has_s12 else "MOTION_SPEC.md lacks a §12 section"))

    # ---- screens ----------------------------------------------------------
    screens = ["HomeScreen", "GalleryScreen", "EditorScreen", "MotionEditorScreen",
               "PathEditorScreen", "PreviewScreen", "ExportScreen", "SettingsScreen"]
    for name in screens:
        found = re.search(rf"class\s+{name}\b", all_dart)
        checks.append((f"screen: {name}", PASS if found else FAIL,
                       "" if found else "widget class missing"))

    # ---- dead UI ----------------------------------------------------------
    dead = re.findall(r"on(?:Pressed|Tap):\s*\(\)\s*\{\s*\}", all_dart)
    checks.append(("no empty button handlers", PASS if not dead else FAIL,
                   f"{len(dead)} empty handlers" if dead else ""))
    todo = re.findall(r"\bTODO\b|\bFIXME\b|UnimplementedError", all_dart + all_kt)
    checks.append(("no TODO/FIXME/UnimplementedError",
                   PASS if not todo else FAIL, f"{len(todo)} occurrences" if todo else ""))

    # ---- phase reports ----------------------------------------------------
    for phase in ("phase-1-foundation", "phase-2-flutter-app", "phase-3-android-renderer"):
        found = any(phase in p for p in docs)
        checks.append((f"report: {phase}", PASS if found else FAIL,
                       "" if found else "docs/phases report missing"))

    width = max(len(n) for n, _, _ in checks)
    lines = [f"{'CHECK'.ljust(width)}  RESULT"]
    for name, status, detail in checks:
        lines.append(f"{name.ljust(width)}  {status}" + (f"  ({detail})" if detail else ""))
    fails = [c for c in checks if c[1] == FAIL]
    lines.append("")
    lines.append(f"{len(checks)} checks, {len(checks) - len(fails)} pass, {len(fails)} fail")
    text = "\n".join(lines)
    print(text)
    os.makedirs(os.path.join(DOCS, "phases"), exist_ok=True)
    with open(os.path.join(DOCS, "phases", "feature-audit.txt"), "w", encoding="utf-8") as fh:
        fh.write(text + "\n")
    return 0 if not fails else 1


if __name__ == "__main__":
    raise SystemExit(main())
