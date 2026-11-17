# Developer scripts

Two dependency-light checkers used while building JavidAI. They are **not** a
replacement for `flutter analyze`; they exist because the CI runner is the only
place with a Flutter SDK and the turnaround is a few minutes per push.

| Script | What it does |
| --- | --- |
| `dartcheck.py` | Parses every `.dart` file with tree-sitter and fails on syntax errors. |
| `importcheck.py` | Resolves the project's import graph and reports (a) symbols used in a file that are declared elsewhere but never imported, and (b) project imports that are never used. |

```bash
python3 -m venv .venv && .venv/bin/pip install tree_sitter tree_sitter_dart
.venv/bin/python tools/dartcheck.py
.venv/bin/python tools/importcheck.py
```

`importcheck.py` is heuristic: it only flags CamelCase (type-style) names and
top-level functions, so a false negative is possible but a false positive is
rare. `flutter analyze` in CI remains the source of truth.
