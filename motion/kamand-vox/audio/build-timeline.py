#!/usr/bin/env python3
"""Convert words.json into a plain-JS timeline the HTML can load from file://.

  .venv/bin/python motion/kamand-vox/audio/build-timeline.py
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "timeline.js"
data = json.loads((HERE / "words.json").read_text(encoding="utf-8"))
payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
OUT.write_text("window.__VOX__ = " + payload + ";\n", encoding="utf-8")
print(f"wrote {OUT} ({len(data['words'])} words, {data['duration']}s)")
