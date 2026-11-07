#!/usr/bin/env python3
"""Assert the invariants Phase 1's plan depends on.

`02-inventory.csv` being current keeps the numbers honest; this file keeps the *assumptions* honest.
Each assertion below is a sentence from `migration/01-audit.md` that would quietly stop being true:

  * the audit is pointed at a tree that actually holds the game (not an empty checkout);
  * there are still ~9,000 handwritten lines to port, so an estimate cannot shrink by accident;
  * no `.unity` scene, prefab, material, shader, animator or audio file has appeared — if one does,
    §1 and §3 of the audit are wrong and the port plan has to be re-reviewed before Phase 2;
  * the Unity project is still intact (a port that deletes its source is not a port);
  * the Godot project, when it exists, is GDScript — no C# copied across.

Usage: python3 migration/tools/check_audit.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit  # noqa: E402

ROOT = audit.ROOT


def fail(message: str) -> None:
    print("audit check: " + message, file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    info = audit.summary(audit.scan())

    if info["cs_files"] < 50:
        fail(f"only {info['cs_files']} C# scripts found — is the audit pointed at client/Assets?")
    if info["handwritten_cs_loc"] < 8000:
        fail(f"handwritten C# shrank to {info['handwritten_cs_loc']} lines: re-check the estimate in 01-audit.md §8")

    unity = info["punity_assets"]
    for label in ("scenes (.unity)", "prefabs (.prefab)", "materials (.mat)",
                  "shaders (.shader/.shadergraph)", "animation clips (.anim)",
                  "animator controllers (.controller)", "audio (.wav/.mp3/.ogg)"):
        if unity[label]:
            fail(f"{unity[label]} × {label} appeared — 01-audit.md §1/§3/§6 no longer holds; re-review before Phase 2")

    for kept in ("client/ProjectSettings/ProjectVersion.txt",
                 "client/Assets/Core/Shazdeh.Core.asmdef",
                 "client/Packages/manifest.json"):
        if not (ROOT / kept).exists():
            fail(f"{kept} is gone — the migration must never modify or delete the Unity project")

    godot = ROOT / "godot-port"
    if godot.exists():
        copied = list(godot.rglob("*.cs"))
        if copied:
            fail(f"{len(copied)} C# file(s) inside godot-port — the port is GDScript, not a source copy")

    print(f"audit check: {info['cs_files']} scripts, {info['cs_loc']} non-blank lines, "
          f"{info['handwritten_cs_loc']} handwritten, 0 serialised Unity assets — assumptions hold")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
