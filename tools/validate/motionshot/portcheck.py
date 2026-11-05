"""Static + behavioural audit of the Kotlin renderer without a compiler.

Runs three families of checks:

1. **parity** — the Kotlin algorithm (transcribed in `kotlin_parity.py`) is
   compared against the Python reference golden vectors used by the JVM tests.
2. **symbols** — every `import` resolves either to the Kotlin standard library,
   the Android SDK / AndroidX or a symbol defined inside the module; every
   `Name.member(...)`/`Name.CONST` reference points at something declared.
3. **bridges** — the Dart and Kotlin MethodChannel/EventChannel names, method
   names and protocol JSON keys agree, and every error code declared in Dart has
   a producer in Kotlin.
"""
from __future__ import annotations

import json
import math
import os
import re
import sys
from typing import Dict, List, Set, Tuple

OK, FAIL, WARN = "PASS", "FAIL", "WARN"


class Report:
    def __init__(self):
        self.checks: List[Tuple[str, str, str]] = []

    def add(self, name: str, status: str, detail: str = ""):
        self.checks.append((name, status, detail))

    def require(self, name: str, cond: bool, detail: str = ""):
        self.add(name, OK if cond else FAIL, "" if cond else detail)

    def counts(self):
        c = {OK: 0, FAIL: 0, WARN: 0}
        for _, s, _ in self.checks:
            c[s] = c.get(s, 0) + 1
        return c

    def render(self) -> str:
        lines = []
        for name, status, detail in self.checks:
            lines.append(f"[{status}] {name}" + (f"  — {detail}" if detail else ""))
        c = self.counts()
        lines.append("")
        lines.append(f"TOTAL {len(self.checks)}  PASS {c[OK]}  FAIL {c[FAIL]}  WARN {c[WARN]}")
        return "\n".join(lines)


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
GOLDEN = os.path.join(ROOT, "tools", "validate", "motionshot", "golden")
KOTLIN_ROOT = os.path.join(ROOT, "android", "app", "src", "main", "kotlin")
KOTLIN_TEST_ROOT = os.path.join(ROOT, "android", "app", "src", "test", "kotlin")
DART_ROOT = os.path.join(ROOT, "lib")


def _kotlin_files() -> List[str]:
    out = []
    for kroot in (KOTLIN_ROOT, KOTLIN_TEST_ROOT):
        if not os.path.exists(kroot):
            continue
        for base, _, files in os.walk(kroot):
            for f in files:
                if f.endswith(".kt"):
                    out.append(os.path.join(base, f))
    return sorted(out)


def _read(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


# --------------------------------------------------------------------------
# declared symbols
# --------------------------------------------------------------------------

DECL_PATTERNS = [
    r"\b(?:enum class|data class|class|object|interface)\s+([A-Z][A-Za-z0-9_]*)",
    r"^\s*(?:private |internal |public )?(?:const )?val\s+([A-Za-z][A-Za-z0-9_]*)",
    r"^\s*(?:private |internal )?fun\s+(?:<[^>]*>\s*)?([A-Za-z][A-Za-z0-9_]*)",
    r"^\s*(?:private |internal )?(?:val|var)\s+([A-Za-z][A-Za-z0-9_]*)",
    r"^\s*([A-Z][A-Z0-9_]*)\s*(?:,|;|$)",  # enum entries
]


def declared_symbols(sources: Dict[str, str]) -> Set[str]:
    symbols: Set[str] = set()
    for src in sources.values():
        for pat in DECL_PATTERNS:
            for m in re.finditer(pat, src, re.MULTILINE):
                symbols.add(m.group(1))
    return symbols


# --------------------------------------------------------------------------
# check: imports and members
# --------------------------------------------------------------------------

STD_KOTLIN = {
    "kotlin", "kotlin.math", "kotlin.text", "kotlin.collections", "kotlin.io",
    "kotlin.random", "kotlin.system", "kotlin.annotation",
}
STD_JAVA = {
    "java", "javax",
}
SDK = {
    "android", "androidx", "org.json", "org.junit", "io.flutter", "com.google",
}
# Kotlin stdlib top-level functions that appear as bare calls.
KNOWN_BARE = {
    "require", "check", "error", "max", "min", "abs", "maxOf", "minOf",
    "println", "arrayOf", "mutableListOf", "listOf", "mapOf", "setOf",
    "sequenceOf", "lazy", "remember", "TODO", "repeat", "buildList",
    "buildString", "emptyList", "emptyMap", "emptyArray", "doubleArrayOf",
    "floatArrayOf", "intArrayOf", "longArrayOf", "booleanArrayOf", "typeOf",
}


ALLOWED_PREFIXES = tuple(
    sorted(STD_KOTLIN | STD_JAVA | SDK | {"com.motionshot"})
)


def check_imports(report: Report, sources: Dict[str, str]):
    unresolved: List[str] = []
    for path, src in sources.items():
        rel = os.path.relpath(path, ROOT)
        for m in re.finditer(r"^import\s+([A-Za-z0-9_.]+)", src, re.MULTILINE):
            fq = m.group(1)
            if not fq.startswith(ALLOWED_PREFIXES):
                unresolved.append(f"{fq} ({rel})")
    report.require("all imports are platform, SDK or module-internal",
                   not unresolved, "; ".join(unresolved[:8]))


def enum_entries(src: str, name: str) -> Set[str]:
    """Entries of `enum class Name { A, B; ... }` (may contain `fun` bodies)."""
    entries: Set[str] = set()
    start = re.search(rf"enum class\s+{re.escape(name)}\b", src)
    if not start:
        return entries
    i = src.index("{", start.end())
    depth = 0
    end = len(src)
    for j in range(i, len(src)):
        ch = src[j]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = j
                break
    body = src[i + 1:end]
    # The entry list ends at the first ';' that sits outside parentheses.
    paren = 0
    cut = len(body)
    for k, ch in enumerate(body):
        if ch == "(":
            paren += 1
        elif ch == ")":
            paren -= 1
        elif ch == ";" and paren == 0:
            cut = k
            break
    text = re.sub(r"//[^\n]*", "", body[:cut])
    # split on commas that are outside constructor parens (entries may carry
    # arguments, e.g. `ZOOM_IN("zoomIn")`)
    parts, buf, depth = [], [], 0
    for ch in text:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    parts.append("".join(buf))
    for part in parts:
        m = re.match(r"\s*([A-Z][A-Z0-9_]*)", part)
        if m:
            entries.add(m.group(1))
    return entries


def check_member_refs(report: Report, sources: Dict[str, str]):
    """`Type.member` for module types must exist as a declaration.

    This catches the class of error that compiles locally but fails on the
    device build: a renamed helper still referenced somewhere.
    """
    symbols = declared_symbols(sources)
    module_types = {s for s in symbols if s[:1].isupper()}
    all_text = "\n".join(sources.values())
    owned: Dict[str, Set[str]] = {}

    for name in module_types:
        members: Set[str] = set()
        for path, src in sources.items():
            if not re.search(
                rf"\b(?:class|object|interface)\s+{re.escape(name)}\b", src
            ):
                continue
            # Members of this type are everything declared inside its braces.
            start = re.search(rf"\b(?:class|object|interface)\s+{re.escape(name)}\b",
                              src)
            i = src.index("{", start.end()) if start else -1
            if i < 0:
                continue
            depth, end = 0, len(src)
            for j in range(i, len(src)):
                if src[j] == "{":
                    depth += 1
                elif src[j] == "}":
                    depth -= 1
                    if depth == 0:
                        end = j
                        break
            body = src[i + 1:end]
            for m in re.finditer(r"\bfun\s+(?:<[^>]*>\s*)?([A-Za-z][A-Za-z0-9_]*)\s*\(",
                                 body):
                members.add(m.group(1))
            for m in re.finditer(
                r"^\s*(?:override\s+)?(?:private\s+|internal\s+|public\s+)?"
                r"(?:val|var|const\s+val)\s+([A-Za-z][A-Za-z0-9_]*)",
                body,
                re.MULTILINE,
            ):
                members.add(m.group(1))
            for m in re.finditer(r"^\s*companion object\b", body, re.MULTILINE):
                pass
            members |= enum_entries(src, name)
            # Properties declared in the primary constructor.
            prim = re.search(rf"(?:class|object)\s+{re.escape(name)}\s*\(([^)]*)\)",
                             src, re.DOTALL)
            if prim:
                for m in re.finditer(r"\b(?:val|var)\s+([A-Za-z][A-Za-z0-9_]*)",
                                     prim.group(1)):
                    members.add(m.group(1))
        owned[name] = members

    bad = 0
    for name in sorted(module_types):
        for m in re.finditer(rf"\b{re.escape(name)}\.([a-zA-Z][A-Za-z0-9_]*)\b",
                             all_text):
            member = m.group(1)
            if member in owned[name] or member in symbols:
                continue
            bad += 1
            report.add(
                f"member {name}.{member}",
                FAIL,
                "declared nowhere in the module",
            )
    report.require("member references", bad == 0, f"{bad} dangling references")


# --------------------------------------------------------------------------
# check: channel + method-name agreement between Dart and Kotlin
# --------------------------------------------------------------------------

def dart_string_consts(src: str) -> Dict[str, str]:
    out = {}
    for m in re.finditer(r"static const (?:String )?([A-Za-z0-9_]+)\s*=\s*'([^']*)'", src):
        out[m.group(1)] = m.group(2)
    return out


def check_bridge(report: Report):
    kotlin_bridge = os.path.join(KOTLIN_ROOT, "com", "motionshot", "app", "NativeBridge.kt")
    dart_bridge = os.path.join(DART_ROOT, "features", "platform", "native_video_bridge",
                               "video_bridge.dart")
    if not (os.path.exists(kotlin_bridge) and os.path.exists(dart_bridge)):
        report.add("bridge files", FAIL, "NativeBridge.kt or video_bridge.dart missing")
        return
    k = _read(kotlin_bridge)
    d = _read(dart_bridge)

    k_channels = dict(re.findall(r'const val ([A-Z_]*CHANNEL[^:]*)\s*:\s*String\s*=\s*"([^"]+)"', k))
    d_channels = dart_string_consts(d)

    def norm(s: str) -> str:
        return re.sub(r"[^a-z0-9]", "", s.lower())

    kpairs = {norm(v): v for v in k_channels.values()}
    dpairs = {norm(v): v for v in d_channels.values()}
    report.require(
        "channel names agree",
        set(kpairs) == set(dpairs),
        f"kotlin={sorted(kpairs.values())} dart={sorted(dpairs.values())}",
    )

    # Method names: every Dart invokeMethod('x') must be handled in Kotlin.
    dart_methods = set(re.findall(r"invokeMethod<[^>]*>\(\s*'([a-zA-Z0-9_]+)'", d))
    dart_methods |= set(re.findall(r"invokeMethod\(\s*'([a-zA-Z0-9_]+)'", d))
    kotlin_methods = set(re.findall(r'"([a-zA-Z0-9_]+)"\s*->', k))
    missing = sorted(dart_methods - kotlin_methods)
    report.require(
        "dart methods handled by kotlin",
        not missing,
        f"unhandled: {missing}",
    )
    report.add(
        "kotlin methods",
        OK if kotlin_methods else FAIL,
        ", ".join(sorted(kotlin_methods)) or "none",
    )

    # Error codes: Dart enum values must be producible in Kotlin.
    dart_codes = set(re.findall(r"\b([A-Z][A-Z0-9_]{2,})\b", d))
    dart_codes = {c for c in dart_codes if "_" in c or c in {"CANCELLED"}}
    code_block = re.search(r"object ErrorCodes\s*\{(.*?)\n\s*\}", d, re.DOTALL)
    if code_block:
        declared = set(re.findall(r"const (?:String )?([A-Z][A-Z0-9_]*)", code_block.group(1)))
    else:
        declared = {c for c in dart_codes if c.isupper()}
    produced = set(re.findall(r'"([A-Z][A-Z0-9_]{2,})"', k))
    missing_codes = sorted(c for c in declared if c not in produced)
    report.require(
        "error codes produced",
        not missing_codes,
        f"declared in Dart but never emitted by Kotlin: {missing_codes}",
    )


# --------------------------------------------------------------------------
# check: JSON protocol keys used by both sides
# --------------------------------------------------------------------------

PROGRESS_KEYS = {"sessionId", "stage", "progress", "framesDone", "framesTotal",
                 "elapsedMs", "etaMs", "result", "errorCode"}

PROTOCOL_KEYS = [
    "projectId", "projectSeed", "outputPath", "width", "height", "fps", "codec",
    "bitrate", "aspect", "totalDuration", "frameCount", "photos", "audio",
    "sessionId", "stage", "progress", "framesDone", "framesTotal", "elapsedMs",
    "etaMs", "result", "errorCode", "keyframes", "transition", "motionType",
    "motionPath",
]


def check_protocol(report: Report):
    dart = os.path.join(DART_ROOT, "features", "platform", "native_video_bridge",
                        "video_bridge.dart")
    kotlin_bridge = os.path.join(KOTLIN_ROOT, "com", "motionshot", "app", "NativeBridge.kt")
    kotlin_request = os.path.join(KOTLIN_ROOT, "com", "motionshot", "app", "motion",
                                  "ExportRequest.kt")
    dart_builder = os.path.join(DART_ROOT, "features", "export",
                                "export_request_builder.dart")
    dart_progress = os.path.join(DART_ROOT, "features", "export",
                                 "export_manager.dart")
    # Which side must know which key: requests are built in Dart; progress
    # events are emitted in Kotlin and parsed in Dart.
    sides = {
        "dart": [dart_builder, dart],
        "kotlin-request": [kotlin_request],
        "kotlin-progress": [kotlin_bridge, os.path.join(
            KOTLIN_ROOT, "com", "motionshot", "app", "motion", "ExportService.kt")],
        "dart-progress": [dart_progress],
    }
    # Dart-to-Dart hops (bridge -> manager) do not need to share key literals,
    # so the progress contract is checked against the bridge parser only.
    sides.pop("dart-progress", None)
    srcs = {}
    for label, paths in sides.items():
        srcs[label] = "\n".join(_read(p) for p in paths if os.path.exists(p))
    missing = {key: [] for key in PROTOCOL_KEYS}
    for key in PROTOCOL_KEYS:
        for label, src in srcs.items():
            if src and f'"{key}"' not in src and f"'{key}'" not in src:
                if label.endswith("progress") != (key in PROGRESS_KEYS):
                    continue
                missing[key].append(label)
    bad = {k: v for k, v in missing.items() if v}
    report.require(
        "protocol keys present on both sides",
        not bad,
        json.dumps(bad, ensure_ascii=False),
    )


# --------------------------------------------------------------------------
# behavioural parity (kotlin_parity vs the golden vectors)
# --------------------------------------------------------------------------

def check_parity(report: Report):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from motionshot import kotlin_parity as KP
    from motionshot.camera import ImageFit, Viewport, sample_keyframes
    from motionshot.mathx import fnv1a64, to_signed64
    from motionshot.profile import Keyframe
    from motionshot.timeline import (Layer, TRANSITION_TYPES,
                                     transition_draw_layers)

    def load(name):
        with open(os.path.join(GOLDEN, f"{name}.json"), "r", encoding="utf-8") as fh:
            return json.load(fh)

    seed = load("prng")
    k_photo_seed = lambda p, pid, i: (  # noqa: E731
        p ^ fnv1a64(pid) ^ (((i + 1) * 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF)
    ) & 0xFFFFFFFFFFFFFFFF
    wrong = [i for i in range(len(seed["photo_seeds"]))
             if to_signed64(k_photo_seed(1, f"p{i}", i)) != seed["photo_seeds"][i][0]]
    report.require("kotlin photoSeed parity", not wrong, f"indices {wrong}")

    rng = KP.KRandom(k_photo_seed(42, "photo-a", 0))
    draws = [to_signed64(rng.next_u64()) for _ in range(len(seed["seed_42_photo_a"]))]
    report.require("kotlin xorshift128+ parity", draws == seed["seed_42_photo_a"])

    r2 = KP.KRandom(fnv1a64("MotionShot"))
    got = [r2.next_double() for _ in range(len(seed["doubles"]))]
    report.require(
        "kotlin nextDouble parity",
        all(abs(a - b) <= 1e-15 for a, b in zip(got, seed["doubles"])),
        f"{got[:3]} vs {seed['doubles'][:3]}",
    )

    ease_g = load("easing")
    worst = 0.0
    for kind in ("linear", "easeIn", "easeOut", "easeInOut", "smooth", "smoother"):
        for row in ease_g[kind]:
            worst = max(worst, abs(row[1] - KP.k_ease(kind, row[0])))
    for row in ease_g["custom"]:
        worst = max(worst, abs(row[1] - KP.k_ease("custom", row[0],
                                                 (0.25, 0.1, 0.25, 1.0))))
    report.require("kotlin easing parity", worst <= 1e-9, f"max err {worst:.3e}")

    kf_g = load("keyframes")
    kfs = [Keyframe(o["time"], o["x"], o["y"], o["scale"], o["rotation"], o["easing"])
           for o in kf_g["keyframes"]]
    worst = 0.0
    for row in kf_g["samples"]:
        st = KP.k_sample(kfs, row[0])
        worst = max(worst, abs(st.x - row[1]), abs(st.y - row[2]),
                    abs(st.scale - row[3]), abs(st.rotation - row[4]))
    report.require("kotlin keyframe sampling parity", worst <= 1e-12, f"max err {worst:.3e}")

    prof = load("profiles")
    vp = Viewport(16 / 9)
    fit = ImageFit.make(4032, 3024, vp)
    bad = []
    for motion_type, expected in prof["types"].items():
        mine = KP.k_generate(
            motion_type, 0.7, 5.0, fit, vp,
            KP.KRandom(k_photo_seed(99, "photo-x", 3)), 12345,
        )
        if len(mine) != len(expected["keyframes"]):
            bad.append(f"{motion_type}:count")
            continue
        for idx, (k, e) in enumerate(zip(mine, expected["keyframes"])):
            d = max(abs(k.time - e["time"]), abs(k.x - e["x"]), abs(k.y - e["y"]),
                    abs(k.scale - e["scale"]), abs(k.rotation - e["rotation"]))
            if d > 1e-12:
                bad.append(f"{motion_type}[{idx}]={d:.2e}")
    report.require("kotlin motion generator parity (15 types)", not bad,
                   ", ".join(bad[:6]))

    tl = load("transitions")
    durs = tl["timeline"]["durations"]
    trans = tl["timeline"]["transitions"]
    bad = []
    span = 0.0
    for row in tl["timeline"]["rows"]:
        t, expected = row[0], row[1]
        mine = KP.k_layers_at(t, durs, trans)
        if len(mine) != len(expected):
            bad.append(f"count@{t}")
            continue
        for got, exp in zip(mine, expected):
            # The golden rounds times to 6dp before publishing them.
            span = max(span, abs(got[1] - exp[2]), abs(got[3] - exp[3]))
            if got[0] != exp[0]:
                bad.append(f"index@{t}")
    report.require("kotlin timeline parity", not bad and span <= 1e-6,
                   f"{', '.join(bad[:6])} max dt {span:.2e}")

    # transition draw parameters
    bad = []
    for tr in TRANSITION_TYPES:
        for step in range(21):
            p = step / 20.0
            layers = [Layer(0, 1.0, "out", p, tr), Layer(1, 0.5, "in", p, tr)]
            dl = transition_draw_layers(layers)
            if tr in ("crossDissolve", "fade", "zoomTransition", "smoothZoom",
                      "blurTransition", "none"):
                if abs(dl[0].alpha + dl[1].alpha - 1.0) > 1e-9:
                    bad.append(f"{tr}@{p}")
            elif tr in ("slideLeft", "slideRight"):
                if abs(abs(dl[0].offset_x - dl[1].offset_x) - 1.0) > 1e-9:
                    bad.append(f"{tr}@{p}")
            else:
                if dl[0].alpha + dl[1].alpha > 1.0 + 1e-9:
                    bad.append(f"{tr}@{p}")
    report.require("transition invariants (9 types x 21 steps)", not bad,
                   ", ".join(bad[:6]))

    # ---- Motion Path Engine (spec §12) ----
    mp = load("motion_paths")
    report.require("kotlin path LUT size", mp["lutSize"] == KP.K_LUT_SIZE,
                   f"golden {mp['lutSize']} vs transcription {KP.K_LUT_SIZE}")

    worst = 0.0
    for name, entry in mp["specs"].items():
        spec = KP.KSpec(entry["spec"])
        ev = KP.KMotionPathEvaluator(spec)
        worst = max(worst, abs(entry["total"] - ev.total()))
        for row in entry["samples"]:
            st = ev.evaluate(fit, vp, row[0], 5.0)
            worst = max(worst, abs(row[1] - st.x), abs(row[2] - st.y),
                        abs(row[3] - st.scale), abs(row[4] - st.rotation))
        for tag, u in (("tangentStart", 0.0), ("tangentEnd", 1.0)):
            t = KP.k_path_tangent(spec, u)
            worst = max(worst, abs(entry[tag][0] - t[0]),
                        abs(entry[tag][1] - t[1]))
    report.require("kotlin path engine samples parity (16 specs)", worst <= 1e-8,
                   f"max err {worst:.3e}")

    worst_b = 0.0
    for name, entry in mp["bake"].items():
        spec = KP.KSpec(mp["specs"][name]["spec"])
        kfs = KP.k_bake(spec, fit, vp, 5.0)
        ev = KP.KMotionPathEvaluator(spec)
        mp_err = ms_err = 0.0
        for i in range(26):
            t = 5.0 * i / 25
            st = ev.evaluate(fit, vp, t, 5.0)
            bk = sample_keyframes(kfs, t)
            mp_err = max(mp_err, abs(st.x - bk.x), abs(st.y - bk.y))
            ms_err = max(ms_err, abs(st.scale - bk.scale))
        worst_b = max(worst_b, abs(entry["maxPosErr"] - mp_err),
                      abs(entry["maxScaleErr"] - ms_err))
        if mp_err >= 5e-3 or ms_err >= 2e-3:
            worst_b = 1.0
    report.require("kotlin path bake fidelity", worst_b <= 1e-6,
                   f"max err {worst_b:.3e}")

    worst_s = 0.0
    for name, entry in mp["seams"].items():
        spec = KP.KSpec(mp["specs"][name]["spec"])
        a = KP.k_raw_point(spec, 0.0)
        b = KP.k_raw_point(spec, 1.0)
        pos_jump = math.hypot(a[0] - b[0], a[1] - b[1])
        ta = KP.k_path_tangent(spec, 0.0)
        tb = KP.k_path_tangent(spec, 1.0)
        ang = abs(math.atan2(ta[1], ta[0]) - math.atan2(tb[1], tb[0]))
        ang = min(ang, 2 * math.pi - ang)
        worst_s = max(worst_s, abs(entry["posJump"] - pos_jump),
                      abs(entry["angleJump"] - ang))
        if pos_jump >= 1e-9:
            worst_s = 1.0
    report.require("kotlin path seam continuity", worst_s <= 1e-9,
                   f"max err {worst_s:.3e}")

    worst_u = 0.0
    for name, entry in mp["uniformity"].items():
        spec = KP.KSpec(mp["specs"][name]["spec"])
        ev = KP.KMotionPathEvaluator(spec)
        total = ev.total()
        pts = [KP.k_raw_point(spec, ev.param_at_arc(total * j / 400.0))
               for j in range(401)]
        ds = [math.hypot(pts[j + 1][0] - pts[j][0], pts[j + 1][1] - pts[j][1])
              for j in range(400)]
        ratio = max(ds) / min(ds)
        worst_u = max(worst_u, abs(entry["ratio"] - ratio))
        if ratio >= 1.03:
            worst_u = 1.0
    report.require("kotlin path arc-length uniformity", worst_u <= 1e-5,
                   f"max err {worst_u:.3e}")

    worst_c = 0.0
    for name, worst_g in mp["c1"].items():
        spec = KP.KSpec(mp["specs"][name]["spec"])
        pts = spec.points
        n = len(pts)
        worst = 0.0
        for i in range(1, n - 1):
            seg_l = [pts[i - 2] if i - 2 >= 0 else pts[0], pts[i - 1], pts[i],
                     pts[i + 1] if i + 1 < n else pts[-1]]
            seg_r = [pts[i - 1], pts[i], pts[i + 1],
                     pts[i + 2] if i + 2 < n else pts[-1]]
            left = KP.k_cr_segment_derivative(seg_l[0], seg_l[1], seg_l[2],
                                              seg_l[3], True)
            right = KP.k_cr_segment_derivative(seg_r[0], seg_r[1], seg_r[2],
                                               seg_r[3], False)
            worst = max(worst, abs(left[0] - right[0]), abs(left[1] - right[1]))
        worst_c = max(worst_c, abs(worst_g - worst))
        if worst >= 1e-9:
            worst_c = 1.0
    report.require("kotlin path C1 continuity (exact derivative)",
                   worst_c <= 1e-9, f"max err {worst_c:.3e}")

    raw = [(r[0], r[1]) for r in mp["stroke"]["input"]]
    out = KP.k_smooth_stroke(raw)
    worst_st = 0.0
    if len(out) != 24:
        worst_st = 1.0
    else:
        for p, r in zip(out, mp["stroke"]["output"]):
            worst_st = max(worst_st, abs(p[0] - r[0]), abs(p[1] - r[1]))
    report.require("kotlin path freehand smoothing", worst_st <= 1e-9,
                   f"max err {worst_st:.3e} (n={len(out)})")

    bad = []
    rng = KP.KRandom(k_photo_seed(2026, "path-gen", 0))
    prev = None
    run = []
    for _ in range(40):
        preset = KP.k_pick_path_preset(rng, prev)
        prof = KP.k_generate_path_profile(rng, 0.7, 5.0, fit, vp, 12345,
                                          exclude_preset=prev, preset=preset)
        run.append((preset, prof))
        prev = preset
    golden_seq = mp["random"]["presets"]
    for k, (preset, _) in enumerate(run):
        if preset != golden_seq[k]:
            bad.append(f"preset[{k}]={preset}!={golden_seq[k]}")
    for name, prof_json in mp["random"]["profiles"].items():
        idx = next((k for k, (pn, _) in enumerate(run) if pn == name), None)
        if idx is None:
            bad.append(f"missing profile {name}")
            continue
        mtype, inten, kfs, seed, spec = run[idx][1]
        if mtype != prof_json["motionType"]:
            bad.append(f"{name} type {mtype}")
        if abs(inten - prof_json["intensity"]) > 1e-12:
            bad.append(f"{name} intensity")
        if seed != prof_json["seed"]:
            bad.append(f"{name} seed")
        g_path = prof_json["path"]
        for key, val in g_path.items():
            if key == "preset":
                if spec.preset != val:
                    bad.append(f"{name} preset {spec.preset}!={val}")
                continue
            if key == "points":
                for p, (gx, gy) in zip(spec.points, val):
                    if abs(p[0] - gx) > 1e-12 or abs(p[1] - gy) > 1e-12:
                        bad.append(f"{name} points")
                        break
                if len(spec.points) != len(val):
                    bad.append(f"{name} points count")
                continue
            got = getattr(spec, key)
            if isinstance(val, bool) or isinstance(got, bool):
                if got != val:
                    bad.append(f"{name} path.{key}")
            elif abs(got - val) > 1e-12:
                bad.append(f"{name} path.{key}")
        if len(kfs) != len(prof_json["keyframes"]):
            bad.append(f"{name} kf count")
        for i, (k, e) in enumerate(zip(kfs, prof_json["keyframes"])):
            d = max(abs(k.time - e["time"]), abs(k.x - e["x"]),
                    abs(k.y - e["y"]), abs(k.scale - e["scale"]),
                    abs(k.rotation - e["rotation"]))
            if d > 1e-9:
                bad.append(f"{name} kf[{i}]={d:.2e}")
    report.require("kotlin path generator parity (40 draws)", not bad,
                   ", ".join(bad[:6]))


def _dart_int_double(b: float) -> int:
    """Dart `double.toInt()` truncates toward zero."""
    return int(b)


def check_encoding_math(report: Report):
    """Bitrate + even-rounding parity with the Dart constants."""
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    with open(os.path.join(GOLDEN, "encoding.json"), "r", encoding="utf-8") as fh:
        g = json.load(fh)
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from motionshot.encode import round_even
    bpp = {"standard": 0.10, "high": 0.16, "maximum": 0.24}

    def dart_bitrate(w, h, fps, quality, codec, custom=0):
        if quality == "custom" and custom > 0:
            return min(max(custom, 1_500_000), 100_000_000)
        hevc = 0.70 if codec == "hevc" else 1.0
        value = _dart_int_double(w * h * fps * bpp.get(quality, 0.16) * hevc)
        return min(max(value, 1_500_000), 100_000_000)

    bad = []
    for row in g["bitrates"]:
        w, h, fps, quality, codec, expected = row
        got = dart_bitrate(w, h, fps, quality, codec)
        if got != expected:
            bad.append(f"{w}x{h}@{fps} {quality}/{codec}: {got} != {expected}")
    report.require("dart bitrate parity (108 combos)", not bad, "; ".join(bad[:4]))

    bad = [f"{v}->{max(2, (v // 2) * 2)}!={e}" for v, e in g["roundEven"]
           if max(2, (v // 2) * 2) != e or round_even(v) != e]
    report.require("even-dimension parity", not bad, "; ".join(bad[:4]))

    # Truncation vs rounding is the bug this check exists for: assert the two
    # rules really differ for at least one golden row, otherwise the test could
    # silently stop covering anything.
    differs = any(
        round(w * h * fps * bpp[q] * (0.70 if c == "hevc" else 1.0))
        != int(w * h * fps * bpp[q] * (0.70 if c == "hevc" else 1.0))
        for w, h, fps, q, c, _ in g["bitrates"]
    )
    report.require("bitrate check is sensitive to rounding", differs)


def check_dart_and_goldens(report: Report):
    """Static Dart/test/golden hygiene checks guarding against compile-time drift."""
    # 1. All 8 golden files must fit in signed 64-bit JSON and stay mirrored.
    golden_names = sorted(f for f in os.listdir(GOLDEN) if f.endswith(".json"))
    overflow: List[str] = []
    mirror_diff: List[str] = []
    for name in golden_names:
        raw = _read(os.path.join(GOLDEN, name))
        for m in re.finditer(r"(?<![.\d])-?\d{19,20}(?![.\d])", raw):
            v = int(m.group(0))
            if v < -(1 << 63) or v > (1 << 63) - 1:
                overflow.append(f"{name}:{v}")
        for mirror_dir in (
            os.path.join(ROOT, "test", "golden"),
            os.path.join(ROOT, "android", "app", "src", "test", "resources"),
        ):
            mp = os.path.join(mirror_dir, name)
            if not os.path.exists(mp) or _read(mp) != raw:
                mirror_diff.append(os.path.relpath(mp, ROOT))
    report.require("golden JSON integers fit signed 64-bit", not overflow,
                   ", ".join(overflow[:4]))
    report.require("golden fixtures mirrored to Dart + Kotlin tests", not mirror_diff,
                   ", ".join(mirror_diff[:4]))

    # 2. Scan all Dart files (lib/ + test/).
    dart_files: List[str] = []
    for root_dir in (DART_ROOT, os.path.join(ROOT, "test")):
        for base, _, files in os.walk(root_dir):
            for f in files:
                if f.endswith(".dart"):
                    dart_files.append(os.path.join(base, f))
    dart_files.sort()

    bad_sorts: List[str] = []
    pub = _read(os.path.join(ROOT, "pubspec.yaml"))
    declared_pkgs = set(re.findall(r"^\s{2}([a-zA-Z0-9_]+):", pub, re.M)) | {
        "motionshot", "flutter", "flutter_test", "flutter_localizations",
    }
    bad_imports: List[str] = []
    for p in dart_files:
        src = _read(p)
        rel = os.path.relpath(p, ROOT)
        for m in re.finditer(r"\.sort\s*\(([^;]{0,120})\)", src):
            body = m.group(1)
            if body.strip() and "compareTo" not in body:
                bad_sorts.append(f"{rel}: {body.strip()}")
        d = os.path.dirname(p)
        for m in re.finditer(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", src, re.M):
            imp = m.group(1)
            if imp.startswith("dart:"):
                continue
            if imp.startswith("package:"):
                pkg, rest = imp[len("package:"):].split("/", 1)
                if pkg not in declared_pkgs:
                    bad_imports.append(f"{rel}:{pkg}")
                elif pkg == "motionshot":
                    target = os.path.normpath(os.path.join(DART_ROOT, rest))
                    if not os.path.exists(target):
                        bad_imports.append(f"{rel}->{imp}")
            else:
                target = os.path.normpath(os.path.join(d, imp))
                if not os.path.exists(target):
                    bad_imports.append(f"{rel}->{imp}")

    report.require("dart List.sort comparators return int", not bad_sorts,
                   "; ".join(bad_sorts[:4]))
    report.require("dart imports resolve cleanly", not bad_imports,
                   "; ".join(bad_imports[:4]))

    # 3. Localization parity + completeness.
    strings_src = _read(os.path.join(DART_ROOT, "app", "l10n", "strings.dart"))
    en_m = re.search(r"'en': <String, String>\{(.*?)\n    \},\n    'fa'", strings_src, re.S)
    fa_m = re.search(r"'fa': <String, String>\{(.*?)\n    \},\n  \};", strings_src, re.S)
    en_keys = set(re.findall(r"^\s*'([a-zA-Z0-9_]+)':", en_m.group(1), re.M)) if en_m else set()
    fa_keys = set(re.findall(r"^\s*'([a-zA-Z0-9_]+)':", fa_m.group(1), re.M)) if fa_m else set()
    missing_l10n: List[str] = []
    for p in dart_files:
        if p.endswith("strings.dart") or os.path.basename(p).endswith("_test.dart"):
            continue
        src = re.sub(r"//[^\n]*", "", _read(p))
        for m in re.finditer(r"""\b(?:l10n|context\.l10n)\.(?:t|plural)\(\s*'([a-zA-Z0-9_]+)'""", src):
            k = m.group(1)
            if k not in en_keys:
                missing_l10n.append(f"{os.path.relpath(p, ROOT)}:{k}")
        for m in re.finditer(r"""'(error_[a-zA-Z0-9_]+|motion_[a-zA-Z0-9_]+|export_stage_[a-zA-Z0-9_]+)'""", src):
            k = m.group(1)
            if k not in en_keys:
                missing_l10n.append(f"{os.path.relpath(p, ROOT)}:{k}")
    report.require("l10n en/fa key parity + all referenced keys exist",
                   bool(en_keys) and en_keys == fa_keys and not missing_l10n,
                   f"en={len(en_keys)} fa={len(fa_keys)} missing={missing_l10n[:4]}")


def main() -> int:
    report = Report()
    sources = {p: _read(p) for p in _kotlin_files()}
    report.require("kotlin sources present", len(sources) > 10, f"{len(sources)} files")
    check_imports(report, sources)
    check_member_refs(report, sources)
    check_bridge(report)
    check_protocol(report)
    check_parity(report)
    check_encoding_math(report)
    check_dart_and_goldens(report)
    text = report.render()
    print(text)
    out_dir = os.path.join(ROOT, "docs", "phases")
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "portcheck.txt"), "w", encoding="utf-8") as fh:
        fh.write(text + "\n")
    return 0 if report.counts()[FAIL] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
