"""Hard-surface mesh assembly for environment kits.

Geometry is collected per (node, material) so the exporter writes one mesh
node per spatial chunk with one primitive per material. Faces are flat shaded
quads/triangles with box-projected, world-scaled UVs and vertex colours.
Coordinates: Y up, metres.
"""
import math

import numpy as np

from . import noise
from .gltf import GLB


def rot_y(degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]])


def rot_x(degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1.0, 0.0, 0.0], [0.0, c, -s], [0.0, s, c]])


def rot_z(degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0.0], [s, c, 0.0], [0.0, 0.0, 1.0]])


class Part:
    def __init__(self):
        self.positions = []
        self.normals = []
        self.uvs = []
        self.colors = []
        self.indices = []
        self.count = 0

    def add(self, positions, normals, uvs, colors, triangles):
        self.positions.append(np.asarray(positions, np.float32))
        self.normals.append(np.asarray(normals, np.float32))
        self.uvs.append(np.asarray(uvs, np.float32))
        self.colors.append(np.asarray(colors, np.float32))
        self.indices.append(np.asarray(triangles, np.int64) + self.count)
        self.count += len(positions)

    def arrays(self):
        return (np.concatenate(self.positions), np.concatenate(self.normals), np.concatenate(self.uvs),
                np.concatenate(self.colors), np.concatenate(self.indices))


class Builder:
    def __init__(self, seed=1):
        self.parts = {}
        self.order = []
        self.materials = {}
        self.markers = []
        self.collision = Part()
        self.rng = np.random.default_rng(seed)
        self.pivots = {}
        self.parents = {}

    # -- bookkeeping ------------------------------------------------------
    def material(self, name, color=(1, 1, 1, 1), metallic=0.0, roughness=0.9, tile=2.0, emissive=None, double_sided=False):
        self.materials[name] = {"color": color, "metallic": metallic, "roughness": roughness, "tile": tile,
                                "emissive": emissive, "double_sided": double_sided}

    def part(self, node, material):
        key = (node, material)
        if key not in self.parts:
            self.parts[key] = Part()
            if node not in self.order:
                self.order.append(node)
        return self.parts[key]

    def pivot(self, node, position):
        """Give a node its own origin so it can be animated in the engine."""
        self.pivots[node] = np.asarray(position, np.float64)

    def attach(self, node, parent):
        """Hang a node under another one (both need a pivot), so that it moves with it in the engine."""
        self.parents[node] = parent

    def marker(self, name, position, parent=None):
        """An empty node at a position; under `parent` it rides along with that node."""
        self.markers.append((name, tuple(float(v) for v in position), parent))

    # -- primitives -------------------------------------------------------
    def _uv(self, positions, normal, tile, frame=None, origin=None):
        """Box projection in the object's frame so textures follow rotated objects."""
        p = np.asarray(positions, np.float64)
        n = np.asarray(normal, np.float64)
        if frame is not None:
            p = (p - (origin if origin is not None else 0.0)) @ frame
            n = n @ frame
        axis = int(np.argmax(np.abs(n)))
        if axis == 0:
            u, v = p[:, 2] * (-1.0 if n[0] > 0 else 1.0), p[:, 1]
        elif axis == 1:
            u, v = p[:, 0], p[:, 2] * (1.0 if n[1] > 0 else -1.0)
        else:
            u, v = p[:, 0] * (1.0 if n[2] > 0 else -1.0), p[:, 1]
        return np.stack([u / tile, -v / tile], axis=1)

    def quad(self, node, material, corners, color=(1, 1, 1), cell=0.0, frame=None, origin=None, tile=None, colors=None):
        """corners: 4 points, counter-clockwise seen from the front. `cell` > 0
        subdivides so vertex colour shading has something to work with."""
        c = np.asarray(corners, np.float64)
        normal = np.cross(c[1] - c[0], c[3] - c[0])
        length = np.linalg.norm(normal)
        if length < 1e-12:
            return
        normal = normal / length
        nu = nv = 1
        if cell > 0.0:
            nu = max(1, int(math.ceil(np.linalg.norm(c[1] - c[0]) / cell)))
            nv = max(1, int(math.ceil(np.linalg.norm(c[3] - c[0]) / cell)))
        us = np.linspace(0.0, 1.0, nu + 1)
        vs = np.linspace(0.0, 1.0, nv + 1)
        grid = []
        for v in vs:
            left = c[0] * (1 - v) + c[3] * v
            right = c[1] * (1 - v) + c[2] * v
            for u in us:
                grid.append(left * (1 - u) + right * u)
        grid = np.asarray(grid)
        triangles = []
        for j in range(nv):
            for i in range(nu):
                a = j * (nu + 1) + i
                b = a + 1
                d = a + (nu + 1)
                e = d + 1
                triangles.append((a, b, e))
                triangles.append((a, e, d))
        tile = tile or self.materials.get(material, {}).get("tile", 2.0)
        uvs = self._uv(grid, normal, tile, frame, origin)
        if colors is None:
            cols = np.tile(np.asarray(color, np.float32)[:3], (len(grid), 1))
        else:
            # Bilinear blend of four corner colours.
            cc = np.asarray(colors, np.float64)
            cols = []
            for v in vs:
                for u in us:
                    cols.append((cc[0] * (1 - u) + cc[1] * u) * (1 - v) + (cc[3] * (1 - u) + cc[2] * u) * v)
            cols = np.asarray(cols)
        self.part(node, material).add(grid, np.tile(normal, (len(grid), 1)), uvs, cols, triangles)

    def tri(self, node, material, corners, color=(1, 1, 1), frame=None, origin=None, tile=None):
        c = np.asarray(corners, np.float64)
        normal = np.cross(c[1] - c[0], c[2] - c[0])
        length = np.linalg.norm(normal)
        if length < 1e-12:
            return
        normal = normal / length
        tile = tile or self.materials.get(material, {}).get("tile", 2.0)
        self.part(node, material).add(c, np.tile(normal, (3, 1)), self._uv(c, normal, tile, frame, origin),
                                      np.tile(np.asarray(color, np.float32)[:3], (3, 1)), [(0, 1, 2)])

    def box(self, node, material, center, size, yaw=0.0, color=(1, 1, 1), cell=0.0, skip="", basis=None, tile=None, collide=False,
            taper=None):
        """Axis box with optional yaw. skip: any of 'x+x-y+y-z+z-' face codes.
        taper=(sx, sz) scales the top face for battered walls."""
        cx, cy, cz = center
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        frame = basis if basis is not None else rot_y(yaw)
        origin = np.array([cx, cy, cz], np.float64)
        tx, tz = taper if taper else (1.0, 1.0)

        def corner(sx, sy, sz):
            scale_x, scale_z = (tx, tz) if sy > 0 else (1.0, 1.0)
            return origin + frame @ np.array([sx * hx * scale_x, sy * hy, sz * hz * scale_z])

        faces = {
            "x+": [corner(1, -1, 1), corner(1, -1, -1), corner(1, 1, -1), corner(1, 1, 1)],
            "x-": [corner(-1, -1, -1), corner(-1, -1, 1), corner(-1, 1, 1), corner(-1, 1, -1)],
            "y+": [corner(-1, 1, 1), corner(1, 1, 1), corner(1, 1, -1), corner(-1, 1, -1)],
            "y-": [corner(-1, -1, -1), corner(1, -1, -1), corner(1, -1, 1), corner(-1, -1, 1)],
            "z+": [corner(-1, -1, 1), corner(1, -1, 1), corner(1, 1, 1), corner(-1, 1, 1)],
            "z-": [corner(1, -1, -1), corner(-1, -1, -1), corner(-1, 1, -1), corner(1, 1, -1)],
        }
        for code, corners in faces.items():
            if code in skip:
                continue
            self.quad(node, material, corners, color, cell, frame, origin, tile)
        if collide:
            self.collide_box(center, size, yaw, basis)

    def collide_box(self, center, size, yaw=0.0, basis=None):
        frame = basis if basis is not None else rot_y(yaw)
        origin = np.asarray(center, np.float64)
        h = np.asarray(size, np.float64) * 0.5
        corners = np.array([origin + frame @ (np.array([sx, sy, sz]) * h) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)])
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        triangles = []
        for a, b, c, d in quads:
            triangles.append((a, b, c))
            triangles.append((a, c, d))
        zeros = np.zeros((8, 3))
        self.collision.add(corners, zeros, zeros[:, :2], zeros, triangles)

    def collide_quad(self, corners):
        c = np.asarray(corners, np.float64)
        zeros = np.zeros((4, 3))
        self.collision.add(c, zeros, zeros[:, :2], zeros, [(0, 1, 2), (0, 2, 3)])

    def cylinder(self, node, material, base, radius, height, segments=10, color=(1, 1, 1), top_radius=None, caps=True,
                 axis=(0, 1, 0), tile=None, smooth=True):
        """Cylinder or cone frustum along `axis` starting at `base`."""
        top_radius = radius if top_radius is None else top_radius
        axis = np.asarray(axis, np.float64)
        axis = axis / np.linalg.norm(axis)
        helper = np.array([1.0, 0.0, 0.0]) if abs(axis[0]) < 0.9 else np.array([0.0, 0.0, 1.0])
        u = np.cross(axis, helper)
        u /= np.linalg.norm(u)
        v = np.cross(axis, u)
        base = np.asarray(base, np.float64)
        tile = tile or self.materials.get(material, {}).get("tile", 2.0)
        col = np.asarray(color, np.float32)[:3]
        part = self.part(node, material)
        angles = np.linspace(0.0, math.tau, segments + 1)
        ring = [u * math.cos(a) + v * math.sin(a) for a in angles]
        positions, normals, uvs = [], [], []
        slope = (radius - top_radius) / max(height, 1e-6)
        for i, direction in enumerate(ring):
            n = direction + axis * slope
            n = n / np.linalg.norm(n)
            for end, r in ((0.0, radius), (height, top_radius)):
                positions.append(base + direction * r + axis * end)
                normals.append(n if smooth else direction)
                uvs.append((i / segments * math.tau * max(radius, top_radius) / tile, -end / tile))
        triangles = []
        for i in range(segments):
            a, b, c, d = i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 3
            triangles.append((a, c, d))
            triangles.append((a, d, b))
        part.add(positions, normals, uvs, np.tile(col, (len(positions), 1)), triangles)
        if caps:
            for end, r, flip in ((0.0, radius, True), (height, top_radius, False)):
                if r <= 1e-6:
                    continue
                center = base + axis * end
                pts = [center] + [center + d * r for d in ring[:-1]]
                normal = -axis if flip else axis
                tris = []
                for i in range(segments):
                    a, b = 1 + i, 1 + (i + 1) % segments
                    tris.append((0, b, a) if flip else (0, a, b))
                part.add(pts, np.tile(normal, (len(pts), 1)), self._uv(np.asarray(pts), normal, tile),
                         np.tile(col, (len(pts), 1)), tris)

    def prism(self, node, material, outline, depth, origin=(0, 0, 0), yaw=0.0, color=(1, 1, 1), tile=None, caps=True, colors=None):
        """Extrude a 2D outline (list of (z, y), counter-clockwise seen from +x)
        across the local x axis by `depth`, centred. Used for vehicle bodies."""
        frame = rot_y(yaw)
        origin = np.asarray(origin, np.float64)
        pts = np.asarray(outline, np.float64)
        n = len(pts)

        def world(x, point):
            return origin + frame @ np.array([x, point[1], point[0]])

        half = depth * 0.5
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            col = color if colors is None else colors[i]
            self.quad(node, material, [world(half, a), world(-half, a), world(-half, b), world(half, b)], col, 0.0, frame, origin, tile)
        if caps:
            triangles = triangulate(pts)
            for side in (1.0, -1.0):
                for a, b, c in triangles:
                    corners = [world(half * side, pts[a]), world(half * side, pts[b]), world(half * side, pts[c])]
                    if side < 0:
                        corners = corners[::-1]
                    self.tri(node, material, corners, color, frame, origin, tile)

    def rock(self, node, material, center, size, seed=0, color=(1, 1, 1), detail=1, flatten=0.7, tile=None):
        """Faceted rubble chunk: a noise-displaced icosphere."""
        vertices, faces = icosphere(detail)
        rng = np.random.default_rng(seed)
        offset = rng.uniform(0, 50, 3)
        displacement = 0.62 + 0.75 * noise.fbm(vertices * 1.3 + offset, 1.0, 2, seed)
        vertices = vertices * displacement[:, None]
        vertices = vertices @ rot_y(rng.uniform(0, 360)).T
        vertices = vertices * np.asarray(size, np.float64) * 0.5
        vertices[:, 1] = np.maximum(vertices[:, 1] * flatten, -size[1] * 0.18)
        vertices += np.asarray(center, np.float64)
        tile = tile or self.materials.get(material, {}).get("tile", 2.0)
        part = self.part(node, material)
        col = np.asarray(color, np.float32)[:3]
        for face in faces:
            c = vertices[face]
            normal = np.cross(c[1] - c[0], c[2] - c[0])
            length = np.linalg.norm(normal)
            if length < 1e-12:
                continue
            normal /= length
            shade = 0.82 + 0.18 * max(0.0, normal[1])
            part.add(c, np.tile(normal, (3, 1)), self._uv(c, normal, tile), np.tile(col * shade, (3, 1)), [(0, 1, 2)])

    def blob(self, node, material, center, radii, segments=8, rings=5, color=(1, 1, 1), yaw=0.0, squash=2.6, tile=None):
        """Superellipsoid: a pillow shape for sandbags, tyres and sacks."""
        frame = rot_y(yaw)
        center = np.asarray(center, np.float64)
        radii = np.asarray(radii, np.float64)
        tile = tile or self.materials.get(material, {}).get("tile", 2.0)

        def sp(value, power):
            return math.copysign(abs(value) ** power, value)

        power = 2.0 / squash
        positions, normals, uvs = [], [], []
        for j in range(rings + 1):
            phi = -math.pi / 2 + math.pi * j / rings
            for i in range(segments + 1):
                theta = math.tau * i / segments
                local = np.array([sp(math.cos(phi), power) * sp(math.cos(theta), power),
                                  sp(math.sin(phi), power),
                                  sp(math.cos(phi), power) * sp(math.sin(theta), power)])
                normal = local / np.maximum(radii, 1e-6)
                normal = frame @ (normal / max(np.linalg.norm(normal), 1e-9))
                positions.append(center + frame @ (local * radii))
                normals.append(normal)
                uvs.append((i / segments * 2.0 * radii[0] * 2.0 / tile, -j / rings * radii[2] * 2.0 / tile))
        triangles = []
        for j in range(rings):
            for i in range(segments):
                a = j * (segments + 1) + i
                b = a + 1
                c = a + segments + 1
                d = c + 1
                triangles.append((a, c, d))
                triangles.append((a, d, b))
        col = np.asarray(color, np.float32)[:3]
        self.part(node, material).add(positions, normals, uvs, np.tile(col, (len(positions), 1)), triangles)

    # -- shading ----------------------------------------------------------
    def shade(self, function, materials=None, nodes=None):
        """Multiply vertex colours by function(positions, normals) -> (N,) or (N, 3)."""
        for (node, material), part in self.parts.items():
            if materials is not None and material not in materials:
                continue
            if nodes is not None and node not in nodes:
                continue
            positions, normals, uvs, colors, indices = part.arrays()
            factor = function(positions, normals)
            if factor.ndim == 1:
                factor = factor[:, None]
            colors = colors * factor
            part.positions, part.normals, part.uvs, part.colors, part.indices = [positions], [normals], [uvs], [colors], [indices]

    # -- export -----------------------------------------------------------
    def triangle_count(self):
        return sum(sum(len(i) for i in part.indices) for part in self.parts.values())

    def export(self, path, root_name="Environment"):
        glb = GLB()
        root = glb.node(root_name)
        material_index = {}
        for name, spec in self.materials.items():
            material_index[name] = glb.material(name, spec["color"], spec["metallic"], spec["roughness"], emissive=spec["emissive"],
                                                double_sided=spec["double_sided"])
        report = []
        made = {}

        def depth(name):
            return 0 if name not in self.parents else 1 + depth(self.parents[name])

        for node in sorted(self.order, key=depth):
            primitives = []
            pivot = self.pivots.get(node, np.zeros(3))
            triangles = 0
            for (owner, material), part in self.parts.items():
                if owner != node or part.count == 0:
                    continue
                positions, normals, uvs, colors, indices = part.arrays()
                primitives.append({"positions": positions - pivot, "normals": normals, "uvs": uvs, "colors": colors, "indices": indices,
                                   "material": material_index[material]})
                triangles += len(indices)
            if not primitives:
                continue
            mesh = glb.mesh(node + "_mesh", primitives)
            above = self.parents.get(node)
            if above is not None:
                made[node] = glb.node(node, mesh=mesh, parent=made[above], translation=pivot - self.pivots.get(above, np.zeros(3)))
            else:
                made[node] = glb.node(node, mesh=mesh, parent=root, translation=pivot if node in self.pivots else None)
            report.append((node, triangles, len(primitives)))
        if self.collision.count:
            positions, _n, _u, _c, indices = self.collision.arrays()
            mesh = glb.mesh("Collision_mesh", [{"positions": positions, "indices": indices}])
            # Godot's importer turns the -colonly suffix into a StaticBody3D with a trimesh shape.
            glb.node("World-colonly", mesh=mesh, parent=root)
        loose = [marker for marker in self.markers if marker[2] is None]
        if loose:
            holder = glb.node("Markers", parent=root)
            for name, position, _parent in loose:
                glb.node(name, translation=position, parent=holder)
        for name, position, above in self.markers:
            if above is not None:
                glb.node(name, translation=np.asarray(position) - self.pivots.get(above, np.zeros(3)), parent=made[above])
        size = glb.write(path)
        return size, report


def triangulate(points):
    """Ear clipping for a simple counter-clockwise polygon. Returns index triples."""
    pts = np.asarray(points, np.float64)
    indices = list(range(len(pts)))
    out = []

    def cross(o, a, b):
        return (pts[a][0] - pts[o][0]) * (pts[b][1] - pts[o][1]) - (pts[a][1] - pts[o][1]) * (pts[b][0] - pts[o][0])

    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0:
        indices.reverse()
    guard = 0
    while len(indices) > 3 and guard < 10000:
        guard += 1
        n = len(indices)
        clipped = False
        for i in range(n):
            a, b, c = indices[(i - 1) % n], indices[i], indices[(i + 1) % n]
            if cross(a, b, c) <= 1e-12:
                continue
            ear = True
            for other in indices:
                if other in (a, b, c):
                    continue
                if cross(a, b, other) >= 0 and cross(b, c, other) >= 0 and cross(c, a, other) >= 0:
                    ear = False
                    break
            if ear:
                out.append((a, b, c))
                indices.pop(i)
                clipped = True
                break
        if not clipped:
            break
    if len(indices) == 3:
        out.append(tuple(indices))
    if area < 0:
        out = [(a, c, b) for a, b, c in out]
    return out


def icosphere(detail=1):
    t = (1.0 + math.sqrt(5.0)) / 2.0
    vertices = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
                (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    vertices = [np.asarray(v, np.float64) / np.linalg.norm(v) for v in vertices]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
             (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(detail):
        cache = {}
        new_faces = []

        def midpoint(a, b):
            key = (min(a, b), max(a, b))
            if key not in cache:
                m = vertices[a] + vertices[b]
                vertices.append(m / np.linalg.norm(m))
                cache[key] = len(vertices) - 1
            return cache[key]

        for a, b, c in faces:
            ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
            new_faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = new_faces
    return np.asarray(vertices), np.asarray(faces)
