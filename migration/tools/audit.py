#!/usr/bin/env python3
"""Phase 1 audit: scan the Unity project and write the migration inventory.

Nothing here is hand-counted. Every number in `migration/01-audit.md` comes from this script, and the
CSV it writes is the checklist a phase claims against. Run it from the repo root:

    python3 migration/tools/audit.py            # write migration/02-inventory.csv + print the summary
    python3 migration/tools/audit.py --check    # fail if the CSV is stale (what CI runs)

Standard library only, like the rest of `tools/`.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UNITY = ROOT / "client" / "Assets"
OUT_CSV = ROOT / "migration" / "02-inventory.csv"

# Engine identifiers that mean "this file has to be translated, not copied".
ENGINE_MARKERS = {
    "UnityEngine": "UnityEngine",
    "UnityEditor": "UnityEditor",
    "TMPro": "TextMeshPro",
    "UnityEngine.UI": "uGUI",
    "Newtonsoft.Json": "Newtonsoft.Json",
    "NUnit.Framework": "NUnit",
    "UnityEngine.InputSystem": "InputSystem",
}

TYPE_RE = re.compile(r"^\s*(?:public|internal|private|protected|sealed|abstract|static|partial|readonly|\s)*"
                     r"(?:class|struct|enum|interface|record)\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
NS_RE = re.compile(r"^\s*namespace\s+([A-Za-z_][A-Za-z0-9_.]*)", re.MULTILINE)

# Where a file goes in the Godot project, and how much thinking it needs.
#   regenerate  generated from a source of truth that also moves (tokens, catalog, forms, golden vectors)
#   drop        editor-only or Unity-only; the Godot equivalent is a different mechanism
#   copy-logic  pure C#, no engine API: a mechanical translation to GDScript
#   translate   engine API in play: same behaviour, different calls
#   rebuild     no equivalent: the feature is reconstructed, the file is a reference
TARGETS = [
    ("client/Assets/Core.Tests/", "test", "godot-port/test/", "translate"),
    ("client/Assets/Editor/", "editor-only", "godot-port/addons/ or drop", "drop"),
    ("client/Assets/Core/Text/PersianForms.gen.cs", "generated", "godot-port/scripts/core/text/", "regenerate"),
    ("client/Assets/Core/Text/", "logic", "godot-port/scripts/core/text/", "copy-logic"),
    ("client/Assets/Core/", "logic", "godot-port/scripts/core/", "copy-logic"),
    ("client/Assets/Content/", "logic", "godot-port/scripts/content/", "copy-logic"),
    ("client/Assets/Game/Generated/", "generated", "godot-port/scripts/game/", "regenerate"),
    ("client/Assets/Game/ArtCatalog.gen.cs", "generated", "godot-port/scripts/game/", "regenerate"),
    ("client/Assets/Game/Ui/", "ui", "godot-port/scenes/ui/", "rebuild"),
    ("client/Assets/Game/PersianCheckView.cs", "ui", "godot-port/scenes/dev/", "rebuild"),
    ("client/Assets/Game/DesignSystemView.cs", "ui", "godot-port/scenes/dev/", "rebuild"),
    ("client/Assets/Game/", "runtime", "godot-port/scripts/game/", "translate"),
]

MIME = {
    ".cs": "script",
    ".png": "sprite",
    ".ttf": "font",
    ".json": "content",
    ".asmdef": "assembly",
    ".jpg": "reference-image",
    ".sql": "schema",
    ".md": "doc",
}


def classify(rel: str) -> tuple[str, str, str]:
    """(kind, godot target, port strategy) for a path relative to the repo root."""
    for prefix, kind, target, strategy in TARGETS:
        if rel.startswith(prefix):
            return kind, target, strategy
    return "other", "-", "-"


def engine_deps(text: str) -> str:
    found = [name for marker, name in ENGINE_MARKERS.items() if re.search(r"\b" + re.escape(marker), text)]
    return "|".join(sorted(set(found)))


def scan() -> list[dict]:
    rows: list[dict] = []
    for path in sorted(UNITY.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT).as_posix()
        suffix = path.suffix.lower()
        kind, target, strategy = classify(rel)

        # Only scripts are ported; everything else is imported or dropped. Classifying a PNG by its
        # folder made 85 sprites look like 85 routines to translate.
        if suffix != ".cs":
            if suffix == ".asmdef":
                kind, target, strategy = "assembly", "drop (GDScript has no assemblies)", "drop"
            elif suffix == ".png":
                kind, target, strategy = "asset", "godot-port/assets/art/", "import"
            elif suffix == ".ttf":
                kind, target, strategy = "asset", "godot-port/assets/fonts/", "import"
            elif suffix == ".json":
                kind, target, strategy = "asset", "godot-port/assets/content/", "import"
            else:
                kind, target, strategy = "asset", "-", "keep" 
        row = {
            "path": rel,
            "type": MIME.get(suffix, suffix.lstrip(".") or "none"),
            "kind": kind,
            "bytes": path.stat().st_size,
            "loc": "",
            "namespace": "",
            "types": "",
            "engine_deps": "",
            "godot_target": target,
            "strategy": strategy,
            "risk": "-",
        }

        if suffix == ".cs":
            text = path.read_text(encoding="utf-8", errors="replace")
            loc = sum(1 for line in text.splitlines() if line.strip())
            types = TYPE_RE.findall(text)
            ns = NS_RE.search(text)
            deps = engine_deps(text)
            row.update(
                loc=loc,
                namespace=ns.group(1) if ns else "",
                types="|".join(types),
                engine_deps=deps,
            )
            if strategy in ("rebuild",):
                row["risk"] = "high"
            elif loc >= 300:
                row["risk"] = "high"
            elif loc >= 120 or deps:
                row["risk"] = "medium"
            else:
                row["risk"] = "low"
            if strategy == "regenerate":
                row["risk"] = "low"  # a generator, not a port
        rows.append(row)
    return rows


def unity_assets() -> dict:
    """Unity serialised formats: the number that matters is usually zero."""
    wanted = {
        "scenes (.unity)": "*.unity",
        "prefabs (.prefab)": "*.prefab",
        "materials (.mat)": "*.mat",
        "shaders (.shader/.shadergraph)": None,
        "animation clips (.anim)": "*.anim",
        "animator controllers (.controller)": "*.controller",
        "scriptable objects (.asset)": "*.asset",
        "meta files": "*.meta",
        "audio (.wav/.mp3/.ogg)": None,
        "3D models (.fbx/.obj/.glb)": None,
    }
    counts = {}
    for label, pattern in wanted.items():
        if pattern is None:
            patterns = {
                "shaders (.shader/.shadergraph)": ["*.shader", "*.shadergraph", "*.hlsl", "*.cginc"],
                "audio (.wav/.mp3/.ogg)": ["*.wav", "*.mp3", "*.ogg", "*.flac"],
                "3D models (.fbx/.obj/.glb)": ["*.fbx", "*.obj", "*.glb", "*.gltf"],
            }[label]
            counts[label] = sum(len(list(UNITY.rglob(p))) for p in patterns)
        else:
            counts[label] = len(list(UNITY.rglob(pattern)))
    return counts


def summary(rows: list[dict]) -> dict:
    by_kind = Counter(r["kind"] for r in rows)
    by_type = Counter(r["type"] for r in rows)
    by_strategy = Counter(r["strategy"] for r in rows)
    by_risk = Counter(r["risk"] for r in rows)
    cs = [r for r in rows if r["type"] == "script"]
    generated = [r for r in cs if r["strategy"] == "regenerate"]
    return {
        "files": len(rows),
        "by_kind": dict(sorted(by_kind.items())),
        "by_type": dict(sorted(by_type.items())),
        "by_strategy": dict(sorted(by_strategy.items())),
        "by_risk": dict(sorted(by_risk.items())),
        "cs_files": len(cs),
        "cs_loc": sum(int(r["loc"]) for r in cs),
        "generated_files": len(generated),
        "generated_loc": sum(int(r["loc"]) for r in generated),
        "handwritten_cs_loc": sum(int(r["loc"]) for r in cs if r["strategy"] != "regenerate"),
        "sprite_bytes": sum(r["bytes"] for r in rows if r["type"] == "sprite"),
        "font_bytes": sum(r["bytes"] for r in rows if r["type"] == "font"),
        "content_bytes": sum(r["bytes"] for r in rows if r["type"] == "content"),
        "punity_assets": unity_assets(),
    }


def write_csv(rows: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ["path", "type", "kind", "bytes", "loc", "namespace", "types", "engine_deps",
              "godot_target", "strategy", "risk"]
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the committed CSV is stale")
    parser.add_argument("--json", action="store_true", help="print the summary as JSON")
    args = parser.parse_args(argv)

    rows = scan()
    if args.check:
        if not OUT_CSV.exists():
            print(f"audit: {OUT_CSV.relative_to(ROOT)} is missing — run migration/tools/audit.py", file=sys.stderr)
            return 1
        import io

        buffer = io.StringIO()
        fields = ["path", "type", "kind", "bytes", "loc", "namespace", "types", "engine_deps",
                  "godot_target", "strategy", "risk"]
        writer = csv.DictWriter(buffer, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
        if buffer.getvalue() != OUT_CSV.read_text(encoding="utf-8"):
            print("audit: inventory.csv is stale — re-run migration/tools/audit.py", file=sys.stderr)
            return 1
        print(f"audit: inventory is current ({len(rows)} files)")
        return 0

    write_csv(rows, OUT_CSV)
    info = summary(rows)

    if args.json:
        print(json.dumps(info, indent=2))
        return 0

    print(f"audit: {info['files']} files scanned → {OUT_CSV.relative_to(ROOT)}")
    print(f"  scripts        {info['cs_files']} files, {info['cs_loc']} non-blank lines "
          f"({info['generated_files']} generated, {info['generated_loc']} lines)")
    print(f"  handwritten    {info['handwritten_cs_loc']} non-blank lines to port")
    print(f"  by kind        {info['by_kind']}")
    print(f"  by strategy    {info['by_strategy']}")
    print(f"  by risk        {info['by_risk']}")
    print(f"  payload        sprites {info['sprite_bytes'] / 1024:.0f} KiB, "
          f"fonts {info['font_bytes'] / 1024:.0f} KiB, content {info['content_bytes'] / 1024:.0f} KiB")
    print(f"  unity assets   {info['punity_assets']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
