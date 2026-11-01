#!/usr/bin/env python3
"""Author the M0 level set (chapter 1) and validate it against the same rules the C# validator uses.

Levels are data, not code: the board itself is not stored, only the board's parameters (size, piece
set, move limit), the obstacle layout and the goals. The client builds the same board from a seed, so
the seed and the JSON together are the level.

    python3 tools/levels/gen_levels.py            # write + validate
    python3 tools/levels/gen_levels.py --check    # validate only, exit 1 on a problem

The ramp here is a placeholder for real design work: 5 normal, 3 hard, 2 super hard. Tuning it is a
design job that needs playtests, not a script.
"""

import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "client", "Assets", "Content", "Resources", "levels", "ch01")

PIECES = ["firouzeh", "lajvard", "aqiq", "zomorrod", "morvarid"]

# (number, type, move_limit, goals, obstacles, rewards, notes)
LEVELS = [
    (1, "normal", 22,
     [{"kind": "clear_pieces", "piece": "aqiq", "target": 15}],
     [],
     (8, 10),
     "teaches the swap; one colour only"),

    (2, "normal", 22,
     [{"kind": "clear_pieces", "piece": "firouzeh", "target": 18},
      {"kind": "clear_pieces", "piece": "lajvard", "target": 12}],
     [],
     (9, 12),
     "two colours, teaches reading goals"),

    (3, "normal", 20,
     [{"kind": "clear_pieces", "piece": "zomorrod", "target": 20}],
     [],
     (9, 12),
     "fewer moves, bigger ask"),

    (4, "normal", 24,
     [{"kind": "clear_obstacle", "obstacle": "crate", "target": 3},
      {"kind": "clear_pieces", "piece": "morvarid", "target": 15}],
     [(2, 4, "crate", 1), (6, 4, "crate", 1), (4, 6, "crate", 1)],
     (10, 14),
     "first obstacle: crates fall to any match on their cell"),

    (5, "normal", 22,
     [{"kind": "clear_obstacle", "obstacle": "crate", "target": 4}],
     [(1, 7, "crate", 1), (7, 7, "crate", 1), (1, 1, "crate", 1), (7, 1, "crate", 1)],
     (10, 14),
     "four crates in the corners: teaches planning around edges"),

    (6, "hard", 20,
     [{"kind": "clear_obstacle", "obstacle": "crate", "target": 6},
      {"kind": "clear_pieces", "piece": "aqiq", "target": 15}],
     [(3, 5, "crate", 1), (4, 5, "crate", 1), (5, 5, "crate", 1),
      (3, 2, "crate", 1), (4, 2, "crate", 1), (5, 2, "crate", 1)],
     (12, 16),
     "first hard level: a wall of crates in the middle"),

    (7, "hard", 20,
     [{"kind": "clear_obstacle", "obstacle": "frost", "target": 8}],
     [(4, 7, "frost", 2), (4, 6, "frost", 2), (4, 5, "frost", 2), (4, 4, "frost", 2)],
     (12, 16),
     "frost needs two hits per layer; a column of it"),

    (8, "hard", 20,
     [{"kind": "clear_pieces", "piece": "lajvard", "target": 20},
      {"kind": "clear_obstacle", "obstacle": "vial", "target": 3}],
     [(0, 4, "vial", 1), (8, 4, "vial", 1), (4, 0, "vial", 1)],
     (12, 18),
     "vials on the edges: power-ups become the answer"),

    (9, "super_hard", 18,
     [{"kind": "clear_obstacle", "obstacle": "crate", "target": 12}],
     [(2, 6, "crate", 2), (6, 6, "crate", 2), (2, 2, "crate", 2), (6, 2, "crate", 2),
      (4, 4, "crate", 2), (4, 7, "crate", 2)],
     (14, 20),
     "six double-layer crates: 18 moves, no slack"),

    (10, "kingdom", 20,
     [{"kind": "clear_obstacle", "obstacle": "samovar", "target": 6},
      {"kind": "clear_pieces", "piece": "aqiq", "target": 25}],
     [(1, 5, "samovar", 1), (3, 5, "samovar", 1), (5, 5, "samovar", 1), (7, 5, "samovar", 1),
      (2, 3, "samovar", 1), (6, 3, "samovar", 1)],
     (18, 24),
     "chapter end: samovars and a piece goal, two stages"),
]


def build(entry):
    number, kind, moves, goals, obstacles, rewards, notes = entry
    return {
        "id": "ch01-%03d" % number,
        "chapter": "ch01",
        "number": number,
        "type": kind,
        "width": 9,
        "height": 9,
        "gravity": "down",
        "move_limit": moves,
        "pieces": PIECES,
        "goals": goals,
        "obstacles": [
            {"x": x, "y": y, "kind": o, "layers": layers} for (x, y, o, layers) in obstacles
        ],
        "blocked": [],
        "reward_potions": rewards[0],
        "reward_coins": rewards[1],
        "stages": 2 if number == 10 else 1,
        "notes": notes,
    }


# --- validation: the same rules as client/Assets/Content/LevelValidator.cs -------------------

MIN_SIDE, MAX_SIDE = 7, 10
MIN_MOVES, MAX_MOVES = 5, 100
MAX_GOALS = 3
MIN_TARGET, MAX_TARGET = 1, 200
MAX_LAYERS = 4
OBSTACLES = {"crate", "frost", "ivy", "vial", "samovar", "flower_pot", "chain", "seal"}
TYPES = {"normal", "hard", "super_hard", "kingdom", "dark_kingdom"}


def validate(level):
    errors = []
    tag = level["id"]
    if not level["id"]:
        errors.append("id is required")
    if level["number"] < 1:
        errors.append(tag + ": number must be >= 1")
    if not (MIN_SIDE <= level["width"] <= MAX_SIDE) or not (MIN_SIDE <= level["height"] <= MAX_SIDE):
        errors.append(tag + ": board must be %d..%d" % (MIN_SIDE, MAX_SIDE))
    if not (MIN_MOVES <= level["move_limit"] <= MAX_MOVES):
        errors.append(tag + ": move_limit out of range")
    if not (4 <= len(level["pieces"]) <= 6):
        errors.append(tag + ": needs 4..6 piece kinds")
    if len(set(level["pieces"])) != len(level["pieces"]):
        errors.append(tag + ": duplicate piece kind")
    if level["type"] not in TYPES:
        errors.append(tag + ": unknown type")
    if not 1 <= len(level["goals"]) <= MAX_GOALS:
        errors.append(tag + ": needs 1..%d goals" % MAX_GOALS)

    occupied = set()
    for o in level["obstacles"]:
        if not (0 <= o["x"] < level["width"] and 0 <= o["y"] < level["height"]):
            errors.append(tag + ": obstacle out of bounds")
        elif (o["x"], o["y"]) in occupied:
            errors.append(tag + ": two obstacles on one cell")
        else:
            occupied.add((o["x"], o["y"]))
        if o["kind"] not in OBSTACLES:
            errors.append(tag + ": unknown obstacle kind " + o["kind"])
        if not (1 <= o["layers"] <= MAX_LAYERS):
            errors.append(tag + ": layers out of range")

    for g in level["goals"]:
        if not (MIN_TARGET <= g["target"] <= MAX_TARGET):
            errors.append(tag + ": goal target out of range")
        if g["kind"] == "clear_pieces":
            if g["piece"] not in level["pieces"]:
                errors.append(tag + ": goal asks for an unused piece")
        elif g["kind"] == "clear_obstacle":
            layers = sum(o["layers"] for o in level["obstacles"] if o["kind"] == g["obstacle"])
            if layers == 0:
                errors.append(tag + ": goal asks for an obstacle that is not placed")
            elif g["target"] != layers:
                errors.append(tag + ": goal target %d but %d layers of %s are on the board"
                              % (g["target"], layers, g["obstacle"]))
        else:
            errors.append(tag + ": unknown goal kind")

    piece_goal = sum(g["target"] for g in level["goals"] if g["kind"] == "clear_pieces")
    if piece_goal > level["move_limit"] * 15:
        errors.append(tag + ": piece goals exceed what the move budget can clear")

    return errors


def validate_catalog(levels):
    errors = []
    numbers = [lv["number"] for lv in levels]
    if len(set(numbers)) != len(numbers):
        errors.append("duplicate level numbers")
    if sorted(numbers) != list(range(1, len(numbers) + 1)):
        errors.append("level numbers must be 1..n with no gaps")
    ids = [lv["id"] for lv in levels]
    if len(set(ids)) != len(ids):
        errors.append("duplicate level ids")
    return errors


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="validate the files on disk, do not rewrite")
    args = ap.parse_args()

    levels = [build(entry) for entry in LEVELS]

    if not args.check:
        os.makedirs(OUT_DIR, exist_ok=True)
        for level in levels:
            path = os.path.join(OUT_DIR, "level-%03d.json" % level["number"])
            with open(path, "w", encoding="utf-8") as f:
                json.dump(level, f, indent=2, ensure_ascii=False)
                f.write("\n")
        print("wrote %d levels to %s" % (len(levels), os.path.relpath(OUT_DIR, ROOT)))
    else:
        for level in levels:
            path = os.path.join(OUT_DIR, "level-%03d.json" % level["number"])
            if not os.path.exists(path):
                print("MISSING %s" % path, file=sys.stderr)
                return 1

    errors = validate_catalog(levels)
    for level in levels:
        errors.extend(validate(level))

    if errors:
        for e in errors:
            print("ERROR " + e, file=sys.stderr)
        return 1

    print("validated %d levels: 0 errors" % len(levels))
    return 0


if __name__ == "__main__":
    sys.exit(main())
