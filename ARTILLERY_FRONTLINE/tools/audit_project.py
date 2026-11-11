#!/usr/bin/env python3
"""Static audit of the project tree: nothing broken, nothing left over.

    python3 tools/audit_project.py [project dir] [report.json]

It reads files only (no engine needed) and checks that
  - every res:// path named in a script, scene, resource or the project file exists;
  - every script, scene, resource and asset is used by something that ships;
  - every sound on disk is in the mixer's list and is asked for somewhere, and the other way round;
  - every text key exists in both languages and is used;
  - no two assets are the same file, no importer sidecar has lost its source;
  - no debugging print is left in the game scripts.
A name counts as used when it appears as a path, as a quoted word (the game
builds some paths from names) or as the stem of a path built with a format.
Problems fail the run; the findings are written as JSON.
"""
import hashlib
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent).resolve()
report_path = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None
NOT_SHIPPED = ("tests", "tools", "documentation", ".godot", "android")
TEXT = (".gd", ".tscn", ".tres", ".godot", ".cfg", ".gdshader")
SIDECARS = (".import", ".uid")
problems = []
notes = {}


def rel(path):
    return path.relative_to(root).as_posix()


def shipped(path):
    return rel(path).split("/")[0] not in NOT_SHIPPED


files = [p for p in root.rglob("*") if p.is_file() and ".godot" not in p.relative_to(root).parts]
game_files = [p for p in files if shipped(p)]
texts = {p: p.read_text(encoding="utf-8", errors="replace") for p in files if p.suffix in TEXT}
game_texts = {p: t for p, t in texts.items() if shipped(p)}


def used_elsewhere(path, needles, pool=None):
    """True when any needle occurs in a shipped text file other than `path` itself."""
    for other, text in (pool or game_texts).items():
        if other == path:
            continue
        if any(needle in text for needle in needles):
            return True
    return False


# 1. Paths that are named must exist.
named = 0
for path, text in texts.items():
    for found in re.findall(r"res://[A-Za-z0-9_./\-]+", text):
        if "%" in found or found.endswith("/") or found in ("res://", "res://..") or found.startswith("res://.."):
            continue
        # A path that is completed in code ("res://assets/audio/" + name) ends on a separator and was skipped above.
        target = root / found[len("res://"):]
        named += 1
        if not target.exists():
            # A prefix that is completed by a format or a concatenation: accept when it is the start of something real.
            parent = target.parent
            if parent.is_dir() and any(child.name.startswith(target.name) for child in parent.iterdir()):
                continue
            problems.append("%s names %s, which does not exist" % (rel(path), found))
notes["paths_checked"] = named

# Formats such as "zombie_%s_%s" become patterns for names built at run time.
patterns = []
for text in game_texts.values():
    for literal in re.findall(r'"([^"\n]*%[sd][^"\n]*)"', text):
        stem = literal.rsplit("/", 1)[-1]
        stem = stem.rsplit(".", 1)[0] if "." in stem else stem
        if len(stem.replace("%s", "").replace("%d", "")) < 3:
            continue
        patterns.append(re.compile("^" + re.escape(stem).replace("%s", ".+").replace("%d", r"\d+") + "$"))


# Endings that are added to a name in code (name + "_n.png").
endings = set()
for text in game_texts.values():
    endings.update(re.findall(r'\+\s*"([_.][A-Za-z0-9_.]+)"', text))


def named_somewhere(path):
    stem = path.name.split(".")[0]
    needles = ["res://" + rel(path), '"%s"' % stem, "&\"%s\"" % stem, '"%s"' % path.name]
    if used_elsewhere(path, needles):
        return True
    for ending in endings:
        if path.name.endswith(ending) and used_elsewhere(path, ['"%s"' % path.name[:-len(ending)]]):
            return True
    return any(pattern.match(stem) for pattern in patterns)


# 2. Scripts, scenes and resources that ship must be used.
project_file = texts[root / "project.godot"]
unused = []
for path in game_files:
    if path.suffix == ".gd":
        text = texts[path]
        name = re.search(r"^class_name\s+(\w+)", text, re.M)
        needles = ["res://" + rel(path)]
        if name:
            needles.append(name.group(1))
        if not used_elsewhere(path, needles):
            unused.append(rel(path))
    elif path.suffix in (".tscn", ".tres"):
        if not used_elsewhere(path, ["res://" + rel(path)]):
            unused.append(rel(path))
if unused:
    problems.append("nothing uses: " + ", ".join(sorted(unused)))
notes["scripts"] = sum(1 for p in game_files if p.suffix == ".gd")
notes["scenes"] = sum(1 for p in game_files if p.suffix == ".tscn")
notes["resources"] = sum(1 for p in game_files if p.suffix == ".tres")

# 3. Assets that ship must be used; no two may be the same file; sidecars must have their source.
assets = [p for p in game_files if rel(p).startswith("assets/") and p.suffix not in SIDECARS and p.suffix != ".txt"]
idle = [rel(p) for p in assets if not named_somewhere(p)]
if idle:
    problems.append("assets nothing asks for: " + ", ".join(sorted(idle)))
by_hash = {}
for path in assets:
    by_hash.setdefault(hashlib.sha256(path.read_bytes()).hexdigest(), []).append(rel(path))
twins = [group for group in by_hash.values() if len(group) > 1]
if twins:
    problems.append("identical assets: " + "; ".join(" = ".join(group) for group in twins))
for path in files:
    if path.suffix in SIDECARS and not path.with_suffix("").exists():
        problems.append("%s has lost the file it belongs to" % rel(path))
for path in assets:
    if not path.with_name(path.name + ".import").exists():
        problems.append("%s was never imported (no .import beside it)" % rel(path))
notes["assets"] = len(assets)
notes["asset_megabytes"] = round(sum(p.stat().st_size for p in assets) / 1e6, 1)

# 4. Sounds: the mixer's list and the files on disk are the same set, and each is asked for.
mixer = texts[root / "scripts/audio/audio_manager.gd"]
listed = set(re.findall(r'"(\w+)"', mixer.split("const CLIPS", 1)[1].split("= [", 1)[1].split("\n]", 1)[0]))
on_disk = {p.stem for p in (root / "assets/audio").glob("*.wav")}
if listed != on_disk:
    problems.append("sounds listed but missing: %s; on disk but not listed: %s" % (sorted(listed - on_disk), sorted(on_disk - listed)))
others = {p: t for p, t in game_texts.items() if p != root / "scripts/audio/audio_manager.gd"}
silent = []
for clip in sorted(on_disk):
    family = re.sub(r"_\d+$", "", clip)
    if not any('"%s"' % clip in t or '"%s"' % family in t for t in others.values()):
        silent.append(clip)
if silent:
    problems.append("sounds nothing plays: " + ", ".join(silent))
notes["sounds"] = len(on_disk)

# 5. Text keys: the same in both languages, and each one used.
loc = texts[root / "scripts/ui/loc.gd"]
tables = re.split(r'^\t"(en|fa)": \{', loc, flags=re.M)
keys = {}
for index in range(1, len(tables) - 1, 2):
    keys[tables[index]] = set(re.findall(r'^\t\t"(\w+)":', tables[index + 1].split("\n\t},", 1)[0], re.M))
if keys.get("en") != keys.get("fa"):
    problems.append("text keys differ between the languages: %s" % sorted(keys.get("en", set()) ^ keys.get("fa", set())))
prefixes = set()
for text in game_texts.values():
    prefixes.update(re.findall(r'Loc\.t\("(\w+_)" \+', text))
without_loc = {p: t for p, t in game_texts.items() if p != root / "scripts/ui/loc.gd"}
dead = sorted(key for key in keys.get("en", set())
              if not any(key.startswith(prefix) for prefix in prefixes) and not any('"%s"' % key in t for t in without_loc.values()))
if dead:
    problems.append("text keys nothing shows: " + ", ".join(dead))
notes["text_keys"] = len(keys.get("en", set()))

# 6. Nothing printed for debugging in the game scripts.
noisy = []
for path, text in game_texts.items():
    if path.suffix != ".gd":
        continue
    for number, line in enumerate(text.splitlines(), 1):
        code = line.split("#", 1)[0]
        if re.search(r"\b(print|print_debug|print_rich|prints|printt|breakpoint)\b\s*(\(|$)", code):
            noisy.append("%s:%d" % (rel(path), number))
if noisy:
    problems.append("debug output left in: " + ", ".join(noisy))

report = {"passed": not problems, "problems": problems, "counted": notes,
          "scope": "static reading of the project tree; nothing is loaded or run"}
if report_path:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
print("LASTWALL_AUDIT " + json.dumps(report, indent=1))
for problem in problems:
    print("::error title=Project audit::%s" % problem)
sys.exit(1 if problems else 0)
