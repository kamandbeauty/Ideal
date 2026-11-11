"""Minimal binary glTF 2.0 writer: meshes, materials, embedded PNG textures,
node hierarchies, skins and animations. Y-up, right-handed, metres."""
import json
import struct

import numpy as np

FLOAT, UBYTE, USHORT, UINT = 5126, 5121, 5123, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


class GLB:
    def __init__(self, generator="LAST WALL asset toolkit"):
        self.doc = {
            "asset": {"version": "2.0", "generator": generator},
            "scene": 0,
            "scenes": [{"nodes": []}],
            "nodes": [],
            "meshes": [],
            "materials": [],
            "accessors": [],
            "bufferViews": [],
            "buffers": [{}],
        }
        self.blob = bytearray()
        self._materials = {}

    # -- raw data ---------------------------------------------------------
    def _view(self, data, target=None):
        while len(self.blob) % 4:
            self.blob.append(0)
        view = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.blob.extend(data)
        self.doc["bufferViews"].append(view)
        return len(self.doc["bufferViews"]) - 1

    def accessor(self, array, kind, component=FLOAT, target=None, normalized=False, bounds=False):
        dtype = {FLOAT: "<f4", UBYTE: "u1", USHORT: "<u2", UINT: "<u4"}[component]
        array = np.ascontiguousarray(array, dtype=dtype)
        count = array.shape[0]
        entry = {"bufferView": self._view(array.tobytes(), target), "componentType": component, "count": int(count), "type": kind}
        if normalized:
            entry["normalized"] = True
        if bounds:
            flat = array.reshape(count, -1)
            entry["min"] = [float(v) for v in flat.min(axis=0)]
            entry["max"] = [float(v) for v in flat.max(axis=0)]
        self.doc["accessors"].append(entry)
        return len(self.doc["accessors"]) - 1

    # -- materials --------------------------------------------------------
    def image(self, png_bytes, name):
        self.doc.setdefault("images", []).append({"bufferView": self._view(png_bytes), "mimeType": "image/png", "name": name})
        self.doc.setdefault("samplers", [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}])
        self.doc.setdefault("textures", []).append({"sampler": 0, "source": len(self.doc["images"]) - 1})
        return len(self.doc["textures"]) - 1

    def material(self, name, color=(1, 1, 1, 1), metallic=0.0, roughness=0.9, texture=None, normal_texture=None,
                 emissive=None, double_sided=False, alpha_mode=None, alpha_cutoff=0.5):
        if name in self._materials:
            return self._materials[name]
        pbr = {"baseColorFactor": [float(c) for c in color], "metallicFactor": float(metallic), "roughnessFactor": float(roughness)}
        if texture is not None:
            pbr["baseColorTexture"] = {"index": texture}
        entry = {"name": name, "pbrMetallicRoughness": pbr}
        if normal_texture is not None:
            entry["normalTexture"] = {"index": normal_texture}
        if emissive:
            entry["emissiveFactor"] = [float(c) for c in emissive]
        if double_sided:
            entry["doubleSided"] = True
        if alpha_mode:
            entry["alphaMode"] = alpha_mode
            if alpha_mode == "MASK":
                entry["alphaCutoff"] = alpha_cutoff
        self.doc["materials"].append(entry)
        self._materials[name] = len(self.doc["materials"]) - 1
        return self._materials[name]

    # -- geometry ---------------------------------------------------------
    def mesh(self, name, primitives):
        """primitives: list of dicts with positions, indices, material and optional
        normals, uvs, colors (0..1 floats, RGBA), joints, weights."""
        out = []
        for prim in primitives:
            positions = np.asarray(prim["positions"], dtype=np.float32)
            if positions.shape[0] == 0:
                continue
            attributes = {"POSITION": self.accessor(positions, "VEC3", target=ARRAY_BUFFER, bounds=True)}
            if prim.get("normals") is not None:
                attributes["NORMAL"] = self.accessor(prim["normals"], "VEC3", target=ARRAY_BUFFER)
            if prim.get("uvs") is not None:
                attributes["TEXCOORD_0"] = self.accessor(prim["uvs"], "VEC2", target=ARRAY_BUFFER)
            if prim.get("colors") is not None:
                colors = np.clip(np.asarray(prim["colors"], dtype=np.float32), 0.0, 1.0)
                if colors.shape[1] == 3:
                    colors = np.concatenate([colors, np.ones((colors.shape[0], 1), np.float32)], axis=1)
                attributes["COLOR_0"] = self.accessor(np.round(colors * 255.0), "VEC4", UBYTE, ARRAY_BUFFER, normalized=True)
            if prim.get("joints") is not None:
                attributes["JOINTS_0"] = self.accessor(prim["joints"], "VEC4", UBYTE, ARRAY_BUFFER)
                attributes["WEIGHTS_0"] = self.accessor(prim["weights"], "VEC4", target=ARRAY_BUFFER)
            indices = np.asarray(prim["indices"]).reshape(-1)
            component = USHORT if positions.shape[0] < 65535 else UINT
            entry = {"attributes": attributes, "indices": self.accessor(indices, "SCALAR", component, ELEMENT_ARRAY_BUFFER), "mode": 4}
            if prim.get("material") is not None:
                entry["material"] = prim["material"]
            out.append(entry)
        self.doc["meshes"].append({"name": name, "primitives": out})
        return len(self.doc["meshes"]) - 1

    def node(self, name, mesh=None, translation=None, rotation=None, scale=None, parent=None, skin=None):
        entry = {"name": name}
        if mesh is not None:
            entry["mesh"] = mesh
        if skin is not None:
            entry["skin"] = skin
        if translation is not None:
            entry["translation"] = [float(v) for v in translation]
        if rotation is not None:
            entry["rotation"] = [float(v) for v in rotation]
        if scale is not None:
            entry["scale"] = [float(v) for v in scale]
        self.doc["nodes"].append(entry)
        index = len(self.doc["nodes"]) - 1
        if parent is None:
            self.doc["scenes"][0]["nodes"].append(index)
        else:
            self.doc["nodes"][parent].setdefault("children", []).append(index)
        return index

    def skin(self, name, joints, inverse_bind_matrices, skeleton=None):
        matrices = np.asarray(inverse_bind_matrices, dtype=np.float32)
        # glTF stores matrices column-major.
        data = np.transpose(matrices, (0, 2, 1)).reshape(-1, 16)
        entry = {"name": name, "joints": [int(j) for j in joints], "inverseBindMatrices": self.accessor(data, "MAT4")}
        if skeleton is not None:
            entry["skeleton"] = int(skeleton)
        self.doc.setdefault("skins", []).append(entry)
        return len(self.doc["skins"]) - 1

    def animation(self, name, tracks):
        """tracks: list of (node_index, path, times, values); path is rotation,
        translation or scale."""
        samplers, channels = [], []
        time_cache = {}
        for node, path, times, values in tracks:
            times = np.asarray(times, dtype=np.float32)
            key = times.tobytes()
            if key not in time_cache:
                time_cache[key] = self.accessor(times, "SCALAR", bounds=True)
            kind = "VEC4" if path == "rotation" else "VEC3"
            samplers.append({"input": time_cache[key], "output": self.accessor(values, kind), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": int(node), "path": path}})
        self.doc.setdefault("animations", []).append({"name": name, "samplers": samplers, "channels": channels})

    def write(self, path):
        while len(self.blob) % 4:
            self.blob.append(0)
        self.doc["buffers"][0]["byteLength"] = len(self.blob)
        text = json.dumps(self.doc, separators=(",", ":")).encode("utf-8")
        while len(text) % 4:
            text += b" "
        total = 12 + 8 + len(text) + 8 + len(self.blob)
        with open(path, "wb") as handle:
            handle.write(struct.pack("<4sII", b"glTF", 2, total))
            handle.write(struct.pack("<I4s", len(text), b"JSON"))
            handle.write(text)
            handle.write(struct.pack("<I4s", len(self.blob), b"BIN\x00"))
            handle.write(bytes(self.blob))
        return total
