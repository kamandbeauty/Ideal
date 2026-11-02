#!/usr/bin/env python3
"""Does the Unity project agree with the pipeline that builds it?

Three things have to line up before a Unity build means anything, and all three are cheap to check
without Unity:

  1. `client/ProjectSettings/ProjectVersion.txt` exists — it is what tells GameCI which editor to
     install, and it is what `unity.yml` looks for before it builds anything at all;
  2. its `m_EditorVersion` is *character for character* the `UNITY_VERSION` in `unity.yml` — a
     one-letter drift installs an editor, imports the project and fails with an upgrade dialog;
  3. every package in `client/Packages/manifest.json` is pinned to an exact version. A floating range
     makes two runs of the same commit produce two different builds, which is the one thing a CI
     build must never do.

Usage:
    python3 tools/ci/check_unity_pin.py           # exit 1 on any disagreement
    python3 tools/ci/check_unity_pin.py --json    # machine-readable
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERSION_FILE = ROOT / "client" / "ProjectSettings" / "ProjectVersion.txt"
MANIFEST = ROOT / "client" / "Packages" / "manifest.json"
WORKFLOW = ROOT / ".github" / "workflows" / "unity.yml"

# "6000.0.32f1" and friends: <year>.<minor>.<patch><stream><build>
RELEASE = re.compile(r"^\d{4}\.\d+\.\d+[abfp]\d+$")


def project_version() -> str | None:
    if not VERSION_FILE.exists():
        return None

    for line in VERSION_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("m_EditorVersion:"):
            return line.split(":", 1)[1].strip()
    return None


def pinned_version() -> str | None:
    if not WORKFLOW.exists():
        return None

    for line in WORKFLOW.read_text(encoding="utf-8").splitlines():
        match = re.match(r"\s*UNITY_VERSION:\s*\"?([^\"\s]+)\"?\s*$", line)
        if match:
            return match.group(1)
    return None


def packages() -> list[tuple[str, str]]:
    if not MANIFEST.exists():
        return []

    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    return list(data.get("dependencies", {}).items())


def main(argv: list[str]) -> int:
    problems: list[str] = []
    notes: list[str] = []

    version = project_version()
    pinned = pinned_version()

    if not VERSION_FILE.exists():
        problems.append(
            "client/ProjectSettings/ProjectVersion.txt is missing — unity.yml stays dormant and "
            "nothing can be built or tested")
    elif version is None:
        problems.append("ProjectVersion.txt has no m_EditorVersion line")
    elif not RELEASE.match(version):
        problems.append(f"m_EditorVersion looks wrong: {version!r}")

    if pinned is None:
        problems.append("unity.yml has no UNITY_VERSION in env:")
    elif version and pinned and version != pinned:
        problems.append(
            f"the project is pinned to {version} but unity.yml installs {pinned} — "
            "GameCI will install one editor and open a project that asks for another")

    revision = False
    if VERSION_FILE.exists():
        for line in VERSION_FILE.read_text(encoding="utf-8").splitlines():
            if line.startswith("m_EditorVersionWithRevision:") and "(" in line and ")" in line:
                revision = True
        if not revision:
            notes.append("ProjectVersion.txt has no revision — the Hub will add one on first open, "
                         "and a build without it cannot pin the exact changeset")

    deps = packages()
    if not deps:
        problems.append("client/Packages/manifest.json is missing or has no dependencies")

    for name, spec in deps:
        if not re.match(r"^\d+\.\d+\.\d+", str(spec)):
            problems.append(f"package {name} is not pinned to an exact version: {spec!r}")

    if argv and argv[0] == "--json":
        print(json.dumps({
            "project": version,
            "pinned": pinned,
            "revision": revision,
            "packages": len(deps),
            "problems": problems,
            "notes": notes,
        }, indent=2))
    else:
        for note in notes:
            print("  note: " + note)
        for problem in problems:
            print("  " + problem, file=sys.stderr)

        if problems:
            print(f"unity pin: {len(problems)} problem(s)", file=sys.stderr)
            return 1

        print(f"unity pin: project and pipeline agree on {version}, "
              f"{len(deps)} package(s) pinned")

    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
