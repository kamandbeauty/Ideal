#!/usr/bin/env python3
"""Validate chapter meta (districts, tasks, chests) without Unity.

This is the Python twin of Shazdeh.Content.DistrictParser.Validate. It exists because CI has no
Unity: the same rules must be enforced before a bad file reaches a device. If a rule changes, change
it in both places — district_meta_test in .github/workflows/ci.yml cannot catch C# drift, only these
rules.

Usage:
    python3 tools/content/check_meta.py                  # validate every meta file
    python3 tools/content/check_meta.py --check FILE...  # explicit files
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
META_DIR = ROOT / "client" / "Assets" / "Content" / "Resources" / "meta"

MAX_TASK_COST = 500  # a single task should never cost a whole district's worth of potions


def validate(doc: dict, source: str) -> list[str]:
    errors: list[str] = []

    if not isinstance(doc, dict):
        return [f"{source}: not a JSON object"]

    districts = doc.get("districts")
    if not isinstance(districts, list) or not districts:
        return [f"{source}: no districts"]

    district_ids: set[str] = set()
    task_keys: set[str] = set()

    for d, district in enumerate(districts):
        if not isinstance(district, dict):
            errors.append(f"{source}: district {d}: not an object")
            continue

        did = district.get("id") or ""
        label = did or f"#{d}"

        if not did:
            errors.append(f"{source}: district {d}: no id")
        elif did in district_ids:
            errors.append(f"{source}: duplicate district id {did}")
        else:
            district_ids.add(did)

        if not district.get("title"):
            errors.append(f"{source}: {label}: no Persian title")
        if not district.get("title_en"):
            errors.append(f"{source}: {label}: no English title")

        tasks = district.get("tasks")
        if not isinstance(tasks, list) or not tasks:
            errors.append(f"{source}: {label}: no tasks")
            tasks = []

        total = 0
        for t, task in enumerate(tasks):
            if not isinstance(task, dict):
                errors.append(f"{source}: {label}: task {t}: not an object")
                continue

            key = task.get("key") or ""
            tlabel = key or f"#{t}"

            if not key:
                errors.append(f"{source}: {label}: task {t}: no key")
            elif key in task_keys:
                errors.append(f"{source}: duplicate task key {key}")
            else:
                task_keys.add(key)

            cost = task.get("potion_cost")
            if not isinstance(cost, int) or isinstance(cost, bool):
                errors.append(f"{source}: {label}: task {tlabel}: potion_cost must be an integer")
            else:
                if cost <= 0:
                    errors.append(f"{source}: {label}: task {tlabel}: must cost more than 0 potions")
                if cost > MAX_TASK_COST:
                    errors.append(f"{source}: {label}: task {tlabel}: costs more than a district should")
                total += cost

            if not task.get("build_asset"):
                errors.append(f"{source}: {label}: task {tlabel}: no build asset")

        chest = district.get("chest")
        if not isinstance(chest, dict):
            errors.append(f"{source}: {label}: no chest")
            continue

        coins = chest.get("coins", 0)
        potions = chest.get("potions", 0)
        if not isinstance(coins, int) or not isinstance(potions, int):
            errors.append(f"{source}: {label}: chest reward must be integers")
        elif coins < 0 or potions < 0:
            errors.append(f"{source}: {label}: negative chest reward")
        elif coins == 0 and potions == 0:
            errors.append(f"{source}: {label}: empty chest")

    return errors


def main(argv: list[str]) -> int:
    files: list[Path]
    if "--check" in argv:
        files = [Path(p) for p in argv[argv.index("--check") + 1:]]
    else:
        files = sorted(META_DIR.glob("*.json"))

    if not files:
        print(f"check_meta: no meta files found in {META_DIR}", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    summary: list[str] = []

    for path in files:
        if not path.is_file():
            all_errors.append(f"{path}: missing")
            continue
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            all_errors.append(f"{path}: invalid json: {exc}")
            continue

        errors = validate(doc, path.name)
        all_errors.extend(errors)

        if not errors:
            districts = doc["districts"]
            tasks = sum(len(d["tasks"]) for d in districts)
            potions = sum(t["potion_cost"] for d in districts for t in d["tasks"])
            summary.append(
                f"  {path.name}: {doc.get('chapter', '?')} — {len(districts)} districts, "
                f"{tasks} tasks, {potions} potions to build everything"
            )

    for line in summary:
        print(line)

    if all_errors:
        print(f"\n{len(all_errors)} error(s):", file=sys.stderr)
        for error in all_errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(f"\nvalidated {len(files)} meta file(s): 0 errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
