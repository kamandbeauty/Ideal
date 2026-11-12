#!/usr/bin/env python3
"""Skin a free zombie character mesh onto the shared 18-bone skeleton.

The horde already has four procedural figures. This writes extra GLBs that
use the same bones and limp clips, so a spawned zombie can pick one at random.

    python3 tools/import_characters.py
"""
import io
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assetlib.gltf import GLB  # noqa: E402
from build_zombies import WALKER, Animator, Sculpt, clips  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(PROJECT, "assets", "models", "zombies")
REPO = os.path.dirname(PROJECT)

# Standing height of the bloat in metres, before the type's scale_min/max.
BLOAT_HEIGHT = 2.15


def load_obj(path):
    positions, uvs, faces = [], [], []
    with open(path, "r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            if line.startswith("v "):
                positions.append([float(v) for v in line.split()[1:4]])
            elif line.startswith("vt "):
                parts = line.split()
                uvs.append([float(parts[1]), float(parts[2])])
            elif line.startswith("f "):
                corners = []
                for token in line.split()[1:]:
                    bits = token.split("/")
                    vi = int(bits[0]) - 1
                    ti = int(bits[1]) - 1 if len(bits) > 1 and bits[1] else -1
                    corners.append((vi, ti))
                for i in range(1, len(corners) - 1):
                    faces.append((corners[0], corners[i], corners[i + 1]))
    return np.asarray(positions, np.float64), np.asarray(uvs, np.float64), faces


def weld(positions, uvs, faces):
    """One GLB vertex per unique (position, uv) pair; compute smooth normals."""
    keys, verts, tex, indices = {}, [], [], []
    for corner in (c for tri in faces for c in tri):
        if corner not in keys:
            keys[corner] = len(verts)
            vi, ti = corner
            verts.append(positions[vi])
            tex.append(uvs[ti] if ti >= 0 else (0.0, 0.0))
        indices.append(keys[corner])
    verts = np.asarray(verts, np.float64)
    tex = np.asarray(tex, np.float64)
    idx = np.asarray(indices, np.int64).reshape(-1, 3)
    normals = np.zeros_like(verts)
    v0, v1, v2 = verts[idx[:, 0]], verts[idx[:, 1]], verts[idx[:, 2]]
    face_n = np.cross(v1 - v0, v2 - v0)
    for i in range(3):
        np.add.at(normals, idx[:, i], face_n)
    length = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = np.divide(normals, np.maximum(length, 1e-8))
    return verts, normals, tex, idx


def fit_standing(verts, height):
    """Feet on y=0, centred on XZ, scaled so the figure is `height` metres tall."""
    lo, hi = verts.min(axis=0), verts.max(axis=0)
    size = hi - lo
    scale = height / max(size[1], 1e-6)
    out = verts.copy()
    out -= (lo + hi) * 0.5
    out[:, 1] -= lo[1] - (lo[1] + hi[1]) * 0.5
    out *= scale
    out[:, 1] -= out[:, 1].min()
    return out.astype(np.float32)


def auto_skin(skeleton, vertices, sigma=0.11):
    bones = np.stack(skeleton.positions).astype(np.float64)
    distance = np.linalg.norm(vertices[:, None, :] - bones[None, :, :], axis=2)
    weights = np.exp(-np.maximum(distance, 0.0) / sigma)
    names = skeleton.names
    weights[:, names.index("Root")] = 0.0
    head, neck = names.index("Head"), names.index("Neck")
    # Crown of the skull stays rigid; blend into the neck at its base.
    blend = np.clip((vertices[:, 1] - 1.52) / 0.12, 0.0, 1.0)
    rigid = vertices[:, 1] > 1.58
    weights[rigid] = 0.0
    weights[rigid, head] = blend[rigid]
    weights[rigid, neck] = 1.0 - blend[rigid]
    order = np.argsort(-weights, axis=1)[:, :4]
    top = np.take_along_axis(weights, order, axis=1)
    top[top < 0.02] = 0.0
    top /= np.maximum(top.sum(axis=1, keepdims=True), 1e-9)
    order[top == 0.0] = 0
    return order.astype(np.uint8), top.astype(np.float32)


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    return buffer.getvalue()


def export_look(name, verts, normals, uvs, faces, texture, sculpt):
    glb = GLB(generator="LAST WALL character import")
    tex = glb.image(png_bytes(texture), name)
    material = glb.material(name, (1, 1, 1, 1), 0.0, 0.86, tex)
    sk = sculpt.skeleton
    root = glb.node("Zombie_" + name)
    joint_nodes = []
    for i, bone in enumerate(sk.names):
        parent = root if sk.parents[i] < 0 else joint_nodes[sk.parents[i]]
        joint_nodes.append(glb.node(bone, translation=sk.offset(bone), parent=parent))
    skin = glb.skin("ZombieSkin", joint_nodes, sk.inverse_bind(), joint_nodes[0])
    joints, weights = auto_skin(sk, verts)
    mesh = glb.mesh("Zombie_%s_mesh" % name, [{
        "positions": verts, "normals": normals, "uvs": uvs.astype(np.float32),
        "indices": faces, "joints": joints, "weights": weights,
        "material": material,
    }])
    glb.node("Body", mesh=mesh, skin=skin, parent=root)
    animator = Animator(sculpt)
    for clip, (pose_fn, duration, loop) in clips(sculpt).items():
        times, rotations, hips = animator.bake(pose_fn, duration, 24, loop)
        tracks = [(joint_nodes[sk.index("Hips")], "translation", times, hips)]
        for bone, keys in rotations.items():
            if bone == "Root":
                continue
            tracks.append((joint_nodes[sk.index(bone)], "rotation", times, np.asarray(keys)))
        glb.animation(clip, tracks)
    os.makedirs(MODEL_DIR, exist_ok=True)
    path = os.path.join(MODEL_DIR, "zombie_%s.glb" % name)
    size = glb.write(path)
    print("%s: %d triangles, height %.2f m, %d KB" % (name, faces.shape[0], float(verts[:, 1].max()), size // 1024))
    return path


def _bloat_sources():
    """OBJ and PNG of the free bloat, from a local extract or the root zip."""
    obj = os.path.join(
        "/tmp/chars/13899/13899_open3dmodel/open3dmodel.com/Model_D0406011/Bloat_Summer.obj"
    )
    png = os.path.join(
        "/tmp/chars/13899/13899_open3dmodel/open3dmodel.com/Model_D0406011/T_Bloat_Summer_Diffuse.png"
    )
    if os.path.isfile(obj) and os.path.isfile(png):
        return obj, png
    import zipfile
    import tempfile
    archive = os.path.join(REPO, "13899_open3dmodel.zip")
    scratch = tempfile.mkdtemp(prefix="bloat_")
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(scratch)
    for dirpath, _names, files in os.walk(scratch):
        if "Bloat_Summer.obj" in files:
            return os.path.join(dirpath, "Bloat_Summer.obj"), os.path.join(dirpath, "T_Bloat_Summer_Diffuse.png")
    raise FileNotFoundError("Bloat_Summer.obj not found in %s" % archive)


def main():
    obj, png = _bloat_sources()
    positions, texcoords, faces = load_obj(obj)
    verts, normals, uvs, indices = weld(positions, texcoords, faces)
    verts = fit_standing(verts, BLOAT_HEIGHT)
    # glTF UVs have their origin at the top-left.
    uvs = uvs.copy()
    uvs[:, 1] = 1.0 - uvs[:, 1]
    texture = Image.open(png).convert("RGB")
    if max(texture.size) > 1024:
        texture = texture.resize((1024, 1024), Image.LANCZOS)
    sculpt = Sculpt(WALKER)
    export_look("bloat", verts, normals.astype(np.float32), uvs, indices, texture, sculpt)


if __name__ == "__main__":
    main()
