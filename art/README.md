# art/ — the contract

`manifest.json` is the list of every sprite the game may draw: its id, its exact size, whether the game
needs it to ship, what it is, and the brief an artist draws from. Nothing else in this folder is
committed — the PNGs themselves live where Unity loads them.

- **Where the files go:** `client/Assets/Game/Resources/art/<id>.png` (see `docs/art.md`).
- **Where the brief is:** inside the manifest, next to the size, so the two cannot drift.
- **How to check:** `python3 tools/art/art.py` (report) · `--check` (CI) · `--check --strict` (release).

Do not put concept images here. Concepts are reference, not product: `replica/design/concepts/`.
