#!/usr/bin/env python3
"""Contact sheet of a GLB for art review, drawn in software (numpy and pillow only).

    python3 tools/preview_glb.py model.glb out.png [--poses walk:0.2,attack:0.5] [--views front,side] \
        [--size 360x520] [--target 0,0.9,0] [--distance 3.4] [--fov 30] [--texture file.png] [--hide Name,Name]

A pose is clip:fraction (0..1 of the clip's length); "rest" is the bind pose.
This is a review aid only: nothing in the game depends on it, and the picture
is a plain lit rasterisation, not what the game's renderer will show.
"""
import argparse
import io
import json
import math
import struct

import numpy as np
from PIL import Image, ImageDraw

VIEWS = {"front": (0.0, 8.0), "side": (90.0, 6.0), "back": (180.0, 8.0), "three": (35.0, 14.0), "top": (20.0, 55.0), "low": (25.0, -6.0),
         "gunner": (180.0, 14.0), "left": (-90.0, 6.0), "rear": (150.0, 16.0)}
TYPES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPES = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}


class Model:
    def __init__(self, path):
        with open(path, "rb") as handle:
            data = handle.read()
        length = struct.unpack_from("<I", data, 12)[0]
        self.doc = json.loads(data[20:20 + length])
        self.bin = data[20 + length + 8:]
        self.nodes = self.doc["nodes"]
        self.parent = {}
        for index, node in enumerate(self.nodes):
            for child in node.get("children", []):
                self.parent[child] = index
        self.images = {}

    def accessor(self, index):
        entry = self.doc["accessors"][index]
        view = self.doc["bufferViews"][entry["bufferView"]]
        size = TYPES[entry["type"]]
        dtype = np.dtype(DTYPES[entry["componentType"]])
        offset = view.get("byteOffset", 0) + entry.get("byteOffset", 0)
        stride = view.get("byteStride", 0)
        if stride and stride != size * dtype.itemsize:
            raw = np.frombuffer(self.bin, np.uint8, stride * entry["count"], offset).reshape(entry["count"], stride)
            array = raw[:, :size * dtype.itemsize].copy().view(dtype).reshape(entry["count"], size)
        else:
            array = np.frombuffer(self.bin, dtype, entry["count"] * size, offset).reshape(entry["count"], size)
        if entry.get("normalized"):
            array = array.astype(np.float32) / float(np.iinfo(dtype).max)
        return array

    def image(self, texture_index):
        source = self.doc["textures"][texture_index]["source"]
        if source not in self.images:
            view = self.doc["bufferViews"][self.doc["images"][source]["bufferView"]]
            start = view.get("byteOffset", 0)
            picture = Image.open(io.BytesIO(self.bin[start:start + view["byteLength"]])).convert("RGB")
            self.images[source] = np.asarray(picture, np.float32) / 255.0
        return self.images[source]

    def local(self, index, pose):
        node = self.nodes[index]
        if "matrix" in node:
            return np.asarray(node["matrix"], np.float64).reshape(4, 4).T
        t = pose.get((index, "translation"), node.get("translation", (0, 0, 0)))
        q = pose.get((index, "rotation"), node.get("rotation", (0, 0, 0, 1)))
        s = pose.get((index, "scale"), node.get("scale", (1, 1, 1)))
        x, y, z, w = np.asarray(q, np.float64) / np.linalg.norm(q)
        matrix = np.eye(4)
        matrix[:3, :3] = np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]) * np.asarray(s, np.float64)
        matrix[:3, 3] = t
        return matrix

    def world(self, pose):
        cache = {}

        def solve(index):
            if index not in cache:
                matrix = self.local(index, pose)
                cache[index] = solve(self.parent[index]) @ matrix if index in self.parent else matrix
            return cache[index]
        return [solve(index) for index in range(len(self.nodes))]

    def pose(self, spec):
        """{(node, path): value} for "clip:fraction"; empty for the bind pose."""
        if spec in ("", "rest"):
            return {}
        name, _, fraction = spec.partition(":")
        clips = {clip["name"]: clip for clip in self.doc.get("animations", [])}
        if name not in clips:
            raise SystemExit("no clip %s; the file has: %s" % (name, ", ".join(sorted(clips))))
        clip = clips[name]
        length = max(float(self.accessor(sampler["input"]).max()) for sampler in clip["samplers"])
        at = float(fraction or 0.0) * length
        out = {}
        for channel in clip["channels"]:
            sampler = clip["samplers"][channel["sampler"]]
            times = self.accessor(sampler["input"])[:, 0]
            values = self.accessor(sampler["output"]).astype(np.float64)
            after = int(np.clip(np.searchsorted(times, at), 1, len(times) - 1))
            span = float(times[after] - times[after - 1])
            mix = 0.0 if span <= 0.0 else float(np.clip((at - times[after - 1]) / span, 0.0, 1.0))
            a, b = values[after - 1], values[after]
            if channel["target"]["path"] == "rotation" and float(np.dot(a, b)) < 0.0:
                b = -b
            out[(channel["target"]["node"], channel["target"]["path"])] = a * (1.0 - mix) + b * mix
        return out

    def triangles(self, pose, hide=(), texture=None):
        """World-space triangles of every mesh: corners (n, 3, 3), normals (n, 3, 3) and colours (n, 3, 3) in linear light."""
        world = self.world(pose)
        corners, normals, colors = [], [], []
        for index, node in enumerate(self.nodes):
            if "mesh" not in node or node.get("name") in hide:
                continue
            for prim in self.doc["meshes"][node["mesh"]]["primitives"]:
                attributes = prim["attributes"]
                points = self.accessor(attributes["POSITION"]).astype(np.float64)
                count = points.shape[0]
                normal = self.accessor(attributes["NORMAL"]).astype(np.float64) if "NORMAL" in attributes else np.zeros((count, 3))
                homogeneous = np.concatenate([points, np.ones((count, 1))], axis=1)
                if "skin" in node and "JOINTS_0" in attributes:
                    skin = self.doc["skins"][node["skin"]]
                    bind = self.accessor(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1).astype(np.float64)
                    joint = np.stack([world[j] @ bind[i] for i, j in enumerate(skin["joints"])])
                    which = self.accessor(attributes["JOINTS_0"]).astype(np.int64)
                    weight = self.accessor(attributes["WEIGHTS_0"]).astype(np.float64)
                    blend = np.einsum("vk,vkij->vij", weight, joint[which])
                else:
                    blend = np.broadcast_to(world[index], (count, 4, 4))
                moved = np.einsum("vij,vj->vi", blend, homogeneous)[:, :3]
                turned = np.einsum("vij,vj->vi", blend[:, :3, :3], normal)
                material = self.doc["materials"][prim["material"]] if "material" in prim else {}
                pbr = material.get("pbrMetallicRoughness", {})
                color = np.tile(np.asarray(pbr.get("baseColorFactor", (1, 1, 1, 1)), np.float64)[:3], (count, 1))
                picture = texture if texture is not None else (self.image(pbr["baseColorTexture"]["index"]) if "baseColorTexture" in pbr else None)
                if picture is not None and "TEXCOORD_0" in attributes:
                    uv = self.accessor(attributes["TEXCOORD_0"]).astype(np.float64)
                    height, width = picture.shape[:2]
                    px = np.clip((uv[:, 0] % 1.0) * width, 0, width - 1).astype(int)
                    py = np.clip((uv[:, 1] % 1.0) * height, 0, height - 1).astype(int)
                    color = color * (picture[py, px] ** 2.2)
                    # Keep the picture and the corners' texture coordinates so the fill can sample per pixel.
                    extra = (picture, uv)
                else:
                    extra = None
                if "COLOR_0" in attributes:
                    color = color * (self.accessor(attributes["COLOR_0"]).astype(np.float64)[:, :3] ** 2.2)
                emissive = np.asarray(material.get("emissiveFactor", (0, 0, 0)), np.float64)
                faces = self.accessor(prim["indices"]).reshape(-1, 3).astype(np.int64) if "indices" in prim else np.arange(count).reshape(-1, 3)
                corners.append(moved[faces])
                normals.append(turned[faces])
                colors.append((color[faces], extra, faces, emissive, pbr.get("baseColorFactor", (1, 1, 1, 1))[:3]))
        return corners, normals, colors


def render(model, pose, yaw, pitch, size, target, distance, fov, hide, texture):
    width, height = size
    corners, normals, colors = model.triangles(pose, hide, texture)
    yaw_r, pitch_r = math.radians(yaw), math.radians(pitch)
    eye = np.asarray(target) + distance * np.array([math.sin(yaw_r) * math.cos(pitch_r), math.sin(pitch_r), math.cos(yaw_r) * math.cos(pitch_r)])
    forward = np.asarray(target) - eye
    forward /= np.linalg.norm(forward)
    right = np.cross(forward, (0.0, 1.0, 0.0))
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    focal = 0.5 * height / math.tan(math.radians(fov) * 0.5)
    light = (right * -0.45 + up * 0.75 - forward * 0.5)
    light /= np.linalg.norm(light)
    rows = np.linspace(0.0, 1.0, height)[:, None, None]
    image = np.broadcast_to((0.30 + 0.1 * rows) * np.ones((1, 1, 3)), (height, width, 3)).copy()
    depth = np.full((height, width), np.inf)
    for tri, nrm, (col, extra, faces, emissive, factor) in zip(corners, normals, colors):
        rel = tri - eye
        cam = np.stack([rel @ right, rel @ up, rel @ forward], axis=-1)
        visible = (cam[:, :, 2] > 0.05).all(axis=1)
        face_normal = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        visible &= (np.einsum("ij,ij->i", face_normal, tri[:, 0] - eye) < 0.0)
        sx = width * 0.5 + cam[:, :, 0] / cam[:, :, 2] * focal
        sy = height * 0.5 - cam[:, :, 1] / cam[:, :, 2] * focal
        lengths = np.linalg.norm(nrm, axis=2, keepdims=True)
        unit = np.where(lengths > 1e-9, nrm / np.maximum(lengths, 1e-9), face_normal[:, None, :] / np.maximum(np.linalg.norm(face_normal, axis=1)[:, None, None], 1e-12))
        lit = 0.34 + 0.2 * (unit @ up * 0.5 + 0.5) + 0.85 * np.clip(unit @ light, 0.0, 1.0)
        for index in np.nonzero(visible)[0]:
            x, y, z = sx[index], sy[index], cam[index, :, 2]
            x0, x1 = max(int(math.floor(x.min())), 0), min(int(math.ceil(x.max())), width - 1)
            y0, y1 = max(int(math.floor(y.min())), 0), min(int(math.ceil(y.max())), height - 1)
            if x0 > x1 or y0 > y1:
                continue
            det = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
            if abs(det) < 1e-12:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            w0 = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / det
            w1 = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / det
            w2 = 1.0 - w0 - w1
            inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
            if not inside.any():
                continue
            # Perspective-correct weights.
            p0, p1, p2 = w0 / z[0], w1 / z[1], w2 / z[2]
            total = p0 + p1 + p2
            zed = 1.0 / np.maximum(total, 1e-12)
            window = depth[y0:y1 + 1, x0:x1 + 1]
            draw = inside & (zed < window)
            if not draw.any():
                continue
            b0, b1, b2 = (p0 * zed)[draw], (p1 * zed)[draw], (p2 * zed)[draw]
            shade = b0 * lit[index, 0] + b1 * lit[index, 1] + b2 * lit[index, 2]
            if extra is not None:
                picture, uv = extra
                corner = uv[faces[index]]
                u = b0 * corner[0, 0] + b1 * corner[1, 0] + b2 * corner[2, 0]
                v = b0 * corner[0, 1] + b1 * corner[1, 1] + b2 * corner[2, 1]
                tall, wide = picture.shape[:2]
                texel = picture[np.clip((v % 1.0) * tall, 0, tall - 1).astype(int), np.clip((u % 1.0) * wide, 0, wide - 1).astype(int)] ** 2.2
                base = texel * np.asarray(factor)
            else:
                base = b0[:, None] * col[index, 0] + b1[:, None] * col[index, 1] + b2[:, None] * col[index, 2]
            window[draw] = zed[draw]
            image[y0:y1 + 1, x0:x1 + 1][draw] = np.clip(base * shade[:, None] + emissive, 0.0, 1.0) ** (1.0 / 2.2)
    return Image.fromarray(np.round(np.clip(image, 0.0, 1.0) * 255.0).astype(np.uint8), "RGB")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("model")
    parser.add_argument("out")
    parser.add_argument("--poses", default="rest")
    parser.add_argument("--views", default="front,side,back")
    parser.add_argument("--size", default="360x520")
    parser.add_argument("--target", default="0,0.9,0")
    parser.add_argument("--distance", type=float, default=3.4)
    parser.add_argument("--fov", type=float, default=30.0)
    parser.add_argument("--texture", default="")
    parser.add_argument("--hide", default="")
    args = parser.parse_args()
    size = tuple(int(v) for v in args.size.split("x"))
    target = tuple(float(v) for v in args.target.split(","))
    model = Model(args.model)
    texture = np.asarray(Image.open(args.texture).convert("RGB"), np.float32) / 255.0 if args.texture else None
    poses = [p for p in args.poses.split(",") if p]
    views = [v for v in args.views.split(",") if v]
    sheet = Image.new("RGB", (size[0] * len(views), size[1] * len(poses)), (20, 20, 20))
    pen = ImageDraw.Draw(sheet)
    for row, spec in enumerate(poses):
        pose = model.pose(spec)
        for column, view in enumerate(views):
            yaw, pitch = VIEWS[view] if view in VIEWS else tuple(float(v) for v in view.split("/"))
            picture = render(model, pose, yaw, pitch, size, target, args.distance, args.fov, set(args.hide.split(",")), texture)
            sheet.paste(picture, (column * size[0], row * size[1]))
            pen.text((column * size[0] + 6, row * size[1] + 4), "%s  %s" % (spec, view), fill=(255, 255, 255))
    sheet.save(args.out)
    print("wrote %s (%d x %d)" % (args.out, sheet.width, sheet.height))


if __name__ == "__main__":
    main()
