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
def quat_matrix(q):
    x, y, z, w = q
    return [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
            [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
            [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]

def mul(a, b):
    return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

def transform_point(m, t, p):
    return [sum(m[i][k]*p[k] for k in range(3)) + t[i] for i in range(3)]

world = {}
def visit(index, parent_m, parent_t):
    node = doc["nodes"][index]
    r = quat_matrix(node.get("rotation", [0, 0, 0, 1]))
    s = node.get("scale", [1, 1, 1])
    m = mul(parent_m, [[r[i][j]*s[j] for j in range(3)] for i in range(3)])
    t = transform_point(parent_m, parent_t, node.get("translation", [0, 0, 0]))
    world[index] = (m, t)
    for child in node.get("children", []):
        visit(child, m, t)
for root in doc["scenes"][doc.get("scene", 0)]["nodes"]:
    visit(root, [[1,0,0],[0,1,0],[0,0,1]], [0,0,0])
points = []
for index, node in enumerate(doc["nodes"]):
    if "mesh" not in node:
        continue
    m, t = world[index]
    for prim in doc["meshes"][node["mesh"]]["primitives"]:
        acc = doc["accessors"][prim["attributes"]["POSITION"]]
        mn, mx = acc["min"], acc["max"]
        for cx in (mn[0], mx[0]):
            for cy in (mn[1], mx[1]):
                for cz in (mn[2], mx[2]):
                    points.append(transform_point(m, t, [cx, cy, cz]))
lo = [min(p[i] for p in points) for i in range(3)]
hi = [max(p[i] for p in points) for i in range(3)]
span = [hi[i]-lo[i] for i in range(3)]
print("WORLD_BOUNDS_SPAN", span)
assert span[0] < 1.6 and span[1] < 1.6 and span[2] < 2.6, f"Unexpected metre scale: {span}"
report = {"pass": "art-pass-01", "model": "mounted_twin_hmg", "triangles": triangles, "uv_primitives": uv_primitives, "meshes": len(doc["meshes"]), "materials": [m["name"] for m in doc["materials"]], "bounds_m": {"min": lo, "max": hi, "span": span}, "pivots": sorted(required), "source": "Original Blender construction; no proprietary reference assets"}
out = ROOT / "documentation/art-pass-01.json"
out.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))


def read_glb(path):
    data = path.read_bytes()
    size = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20+size])

report2 = {"pass": "art-pass-02", "models": {}}
soldier = read_glb(ROOT / "assets/models/soldier.glb")
snodes = {n.get("name", "") for n in soldier["nodes"]}
srequired = {"Hips", "Torso", "Head", "LegL", "LegR", "KneeL", "KneeR", "ArmL", "ArmR", "ElbowL", "ElbowR", "Rifle", "Muzzle"}
assert srequired <= snodes, f"Missing soldier pivots: {srequired - snodes}"
stris = sum(soldier["accessors"][p["indices"]]["count"] // 3 for m in soldier["meshes"] for p in m["primitives"])
# The infantry now comes from the user-supplied 3ds Max mesh (1,927 source
# triangles) instead of the lofted procedural stand-in, plus the original rifle.
# The old 4,000 floor described the stand-in's density, not a quality target.
assert 1200 <= stris <= 60000, f"Soldier triangle budget: {stris}"
assert all("TEXCOORD_0" in p["attributes"] for m in soldier["meshes"] for p in m["primitives"]), "Soldier UV0 missing"
# The uploaded atlases must survive the export as embedded glTF textures.
assert soldier.get("images") and soldier.get("textures"), "Soldier atlases were not embedded"
atlas_materials = [m for m in soldier["materials"] if m["name"].startswith("Uploaded infantry")]
assert len(atlas_materials) == 3, f"Expected 3 infantry atlases, found {len(atlas_materials)}"
for m in atlas_materials:
    assert "baseColorTexture" in m["pbrMetallicRoughness"], f"{m['name']} lost its diffuse atlas"
    assert m.get("alphaMode", "OPAQUE") == "OPAQUE", f"{m['name']} must be opaque"
for view_index in {soldier["images"][i]["bufferView"] for i in range(len(soldier["images"]))}:
    assert "target" not in soldier["bufferViews"][view_index], "Image bufferView must not declare a target"
assert len(soldier["images"]) == 3, f"Expected 3 embedded images, found {len(soldier['images'])}"
report2["models"]["soldier"] = {"triangles": stris, "pivots": sorted(srequired),
                                "atlases": [m["name"] for m in atlas_materials],
                                "embedded_images": len(soldier["images"]),
                                "source": "User-supplied D0307048A1.max + 3 DDS atlases; rig and rifle authored by tools/import_max_soldier.py"}
for name in ["mounted_cannon", "mounted_rocket", "mounted_autocannon", "bazooka"]:
    doc = read_glb(ROOT / f"assets/models/{name}.glb")
    nodes = {n.get("name", "") for n in doc["nodes"]}
    assert {"BarrelPivot", "RecoilAssembly", "Muzzle"} <= nodes, f"{name} missing pivots"
    tris = sum(doc["accessors"][p["indices"]]["count"] // 3 for m in doc["meshes"] for p in m["primitives"])
    assert 1500 <= tris <= 80000, f"{name} triangle budget: {tris}"
    assert all("TEXCOORD_0" in p["attributes"] for m in doc["meshes"] for p in m["primitives"]), f"{name} UV0 missing"
    report2["models"][name] = {"triangles": tris}
(ROOT / "documentation/art-pass-02.json").write_text(json.dumps(report2, indent=2) + "\n")
print(json.dumps(report2))

# Art pass 03: real skinning, organic infantry, and articulated war machines.
assert soldier.get("skins"), "Soldier must export a glTF skin"
skin = soldier["skins"][0]
assert len(skin["joints"]) >= 11, "Soldier skeleton needs anatomical joints"
assert "inverseBindMatrices" in skin, "Skin missing inverse bind matrices"
skinned_prims = [p for m in soldier["meshes"] for p in m["primitives"] if "JOINTS_0" in p["attributes"]]
assert skinned_prims, "Soldier has no skinned primitives"
for prim in skinned_prims:
    assert "WEIGHTS_0" in prim["attributes"], "Skinned primitive missing weights"
    joints_acc = soldier["accessors"][prim["attributes"]["JOINTS_0"]]
    weights_acc = soldier["accessors"][prim["attributes"]["WEIGHTS_0"]]
    assert joints_acc["componentType"] == 5123 and joints_acc["type"] == "VEC4"
    assert weights_acc["type"] == "VEC4"
report3 = {"pass": "art-pass-03", "soldier": {"skinned_primitives": len(skinned_prims), "joints": len(skin["joints"]), "triangles": stris}, "machines": {}}
machine_pivots = {
    "warden": {"Turret", "BarrelPivot", "RecoilAssembly", "Muzzle", "WheelL0", "WheelR0"},
    "nomad": {"Turret", "BarrelPivot", "RecoilAssembly", "Muzzle", "WheelL0", "WheelR0"},
    "helicopter": {"Rotor", "TailRotor"},
    "fighter": {"AileronL", "AileronR", "ElevatorL", "ElevatorR", "Rudder", "AfterburnerL", "AfterburnerR"},
    "landing_craft": {"Ramp", "Radar", "PropellerL", "PropellerR"},
    "patrol_boat": {"Radar", "PropellerL", "PropellerR", "BarrelPivot", "Muzzle"},
}
for name, required_pivots in machine_pivots.items():
    doc = read_glb(ROOT / f"assets/models/{name}.glb")
    nodes = {n.get("name", "") for n in doc["nodes"]}
    missing = required_pivots - nodes
    assert not missing, f"{name} missing animation pivots: {missing}"
    tris = sum(doc["accessors"][p["indices"]]["count"] // 3 for m in doc["meshes"] for p in m["primitives"])
    # Index accessors used to be written as VEC3, so `count // 3` under-reported
    # every model by 3x. These are the true triangle counts now that indices are
    # SCALAR; the ceiling moved with the corrected measurement, not the geometry.
    assert 1500 <= tris <= 400000, f"{name} triangle budget: {tris}"
    report3["machines"][name] = {"triangles": tris, "pivots": sorted(required_pivots)}
(ROOT / "documentation/art-pass-03.json").write_text(json.dumps(report3, indent=2) + "\n")
print(json.dumps(report3))
