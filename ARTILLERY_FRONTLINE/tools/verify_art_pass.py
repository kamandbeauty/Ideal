#!/usr/bin/env python3
"""Structural gate for art pass 01: UVs, animation pivots, budget and scale."""
import json, struct, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
path = ROOT / "assets/models/mounted_twin_hmg.glb"
data = path.read_bytes()
magic, version, total = struct.unpack_from("<III", data, 0)
assert magic == 0x46546C67 and version == 2 and total == len(data)
size = struct.unpack_from("<I", data, 12)[0]
doc = json.loads(data[20:20+size])
nodes = {n.get("name", "") for n in doc["nodes"]}
required = {"BarrelPivot", "RecoilL", "RecoilR", "CoverL", "CoverR", "MuzzleL", "MuzzleR", "EjectionL", "EjectionR", "ReceiverL", "ReceiverR"}
missing = required - nodes
assert not missing, f"Missing pivots: {missing}"
triangles = 0
uv_primitives = 0
for mesh in doc["meshes"]:
    for prim in mesh["primitives"]:
        triangles += doc["accessors"][prim["indices"]]["count"] // 3
        if "TEXCOORD_0" in prim["attributes"]:
            uv_primitives += 1
assert uv_primitives == len(doc["meshes"]), "Every weapon primitive must carry UV0"
print("TRIANGLES", triangles, "UV_PRIMS", uv_primitives, "MESHES", len(doc["meshes"]))
assert 8000 <= triangles <= 150000, f"Triangle budget out of range: {triangles}"
positions = []
for mesh in doc["meshes"]:
    acc = doc["accessors"][mesh["primitives"][0]["attributes"]["POSITION"]]
    positions.append((acc["min"], acc["max"]))
lo = [min(p[0][i] for p in positions) for i in range(3)]
hi = [max(p[1][i] for p in positions) for i in range(3)]
span = [hi[i]-lo[i] for i in range(3)]
print("LOCAL_BOUNDS_SPAN", span)
assert span[0] < 2.0 and span[1] < 3.0 and span[2] < 2.0, f"Unexpected metre scale: {span}"
report = {"pass": "art-pass-01", "model": "mounted_twin_hmg", "triangles": triangles, "uv_primitives": uv_primitives, "meshes": len(doc["meshes"]), "materials": [m["name"] for m in doc["materials"]], "bounds_m": {"min": lo, "max": hi, "span": span}, "pivots": sorted(required), "source": "Original Blender construction; no proprietary reference assets"}
out = ROOT / "documentation/art-pass-01.json"
out.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
