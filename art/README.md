# art/ — the contract

`manifest.json` is the list of every sprite the game may draw: its id, its exact size, whether the game
needs it to ship, what it is, and the brief an artist draws from. The PNGs themselves live where Unity
loads them, and are drawn from code — `tools/art/gen_art.py` — so the repo carries the source of every
sprite, not just the result.

- **Where the files go:** `client/Assets/Game/Resources/art/<id>.png` (see `docs/art.md`).
- **Where the brief is:** inside the manifest, next to the size, so the two cannot drift.
- **How to check:** `python3 tools/art/art.py` (report) · `--check` (CI) · `--check --strict` (release).
- **How to redraw:** `python3 tools/art/gen_art.py` · `python3 tools/art/gen_art.py --check` (CI).
- **How to look at it:** `python3 tools/art/preview.py` writes `art/preview/index.html` (a review sheet),
  `contact-sheet.png` and `silhouettes.png`; `--check` is the 48 px greyscale silhouette gate.

Do not put concept images here. Concepts are reference, not product: `replica/design/concepts/`.
