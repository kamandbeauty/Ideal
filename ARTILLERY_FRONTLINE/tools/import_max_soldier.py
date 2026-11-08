#!/usr/bin/env python3
"""Convert the user-supplied 3ds Max infantryman into engine-ready source data.

The uploaded reference (`D0307048A1.max` + three `.dds` atlases) is a proprietary
format that neither Blender nor Assimp can open on Linux. This tool reads it
directly with the standard library only -- no Blender, no third-party packages --
and emits:

  * assets/models/source/uploaded_soldier.json  (posed mesh, UVs, rig, weights)
  * assets/textures/uploaded/soldier_*.png      (decoded diffuse atlases)

`create_models.py` then instantiates that data in Blender and adds the rifle, so
CI remains the single source of truth for `soldier.glb`.

What is read from the .max
--------------------------
The file is an OLE/CFB container. Its `Scene` stream is a 3ds Max chunk tree
(uint16 id + uint32 size; the high bit of the *size* dword marks a container and
the size includes the 6-byte header). One Editable Mesh object is present:

  0x0914  positions        uint32 count, then count * 3 float32
  0x0912  faces            count * (3 * uint32 indices, uint32 smoothing groups,
                                   uint16 edge flags, uint16 material index)
  0x2394  map vertices     uint32 count, then count * 3 float32 (u, v, w)
  0x2396  map faces        count * 3 uint32 indices into the map vertices

There is no Skin modifier and there are no bone weights in the file: the mesh is
a static A-pose. Rigging is authored here, not extracted.

Coordinate system
-----------------
3ds Max is Z-up with the model facing +Y. ARTILLERY FRONTLINE authors in Blender
Z-up metres with the model facing -Y, so the conversion is a 180 degree rotation
about Z plus a uniform scale. The source is 206 units tall; it is normalised to
the project's 1.82 m infantry height with the soles at z = 0.

Normals
-------
The uploaded winding is inward-facing (negative signed volume). Triangles are
reversed on export. Vertices are additionally duplicated wherever the 3ds Max
smoothing groups disagree, so hard gear edges stay hard while cloth and skin
stay smooth without relying on Blender-version-specific auto-smooth settings.
"""
import argparse
import json
import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(ROOT)

TARGET_HEIGHT_M = 1.82
SOURCE_HEIGHT_UNITS = 206.0
SOURCE_CENTER_X = 7.1

# Material index in the .max -> (engine material name, decoded atlas, source dds).
# Index 3 covers four stray faces of the body shell and shares the body atlas.
MATERIALS = [
    ("Uploaded infantry body", "soldier_body.png", "de387a0.dds"),
    ("Uploaded infantry gear", "soldier_gear.png", "de0fc20.dds"),
    ("Uploaded infantry head", "soldier_head.png", "de30540.dds"),
    ("Uploaded infantry body", "soldier_body.png", "de387a0.dds"),
]


# --------------------------------------------------------------------------
# OLE / Compound File Binary reader (the subset 3ds Max needs)
# --------------------------------------------------------------------------
ENDOFCHAIN = 0xFFFFFFFE
FREESECT = 0xFFFFFFFF


class CompoundFile:
    """Minimal CFB reader: DIFAT -> FAT -> directory, plus the mini-FAT stream."""

    def __init__(self, path):
        with open(path, "rb") as handle:
            self.data = handle.read()
        data = self.data
        if data[:8] != b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1":
            raise ValueError("%s is not an OLE compound file" % path)
        self.sector_size = 1 << struct.unpack_from("<H", data, 30)[0]
        self.mini_size = 1 << struct.unpack_from("<H", data, 32)[0]
        directory_start = struct.unpack_from("<I", data, 48)[0]
        self.cutoff = struct.unpack_from("<I", data, 56)[0]
        mini_fat_start = struct.unpack_from("<I", data, 60)[0]
        difat_start = struct.unpack_from("<I", data, 68)[0]
        difat_count = struct.unpack_from("<I", data, 72)[0]

        fat_sectors = list(struct.unpack_from("<109I", data, 76))
        sector = difat_start
        for _ in range(difat_count):
            if sector >= ENDOFCHAIN:
                break
            block = self.sector(sector)
            entries = self.sector_size // 4
            fat_sectors.extend(struct.unpack_from("<%dI" % (entries - 1), block, 0))
            sector = struct.unpack_from("<I", block, self.sector_size - 4)[0]

        self.fat = []
        for sector in fat_sectors:
            if sector >= ENDOFCHAIN:
                continue
            block = self.sector(sector)
            self.fat.extend(struct.unpack_from("<%dI" % (self.sector_size // 4), block, 0))

        directory = self.chain(directory_start)
        self.entries = {}
        self.root = None
        for offset in range(0, len(directory) - 127, 128):
            name_length = struct.unpack_from("<H", directory, offset + 64)[0]
            kind = directory[offset + 66]
            start = struct.unpack_from("<I", directory, offset + 116)[0]
            size = struct.unpack_from("<Q", directory, offset + 120)[0]
            if kind == 5:
                self.root = (start, size)
            elif kind == 2 and name_length >= 2:
                name = directory[offset:offset + name_length - 2].decode("utf-16-le", "replace")
                self.entries[name] = (start, size)

        self.mini_fat = []
        if mini_fat_start < ENDOFCHAIN:
            block = self.chain(mini_fat_start)
            self.mini_fat = list(struct.unpack_from("<%dI" % (len(block) // 4), block, 0))
        self.mini_stream = self.chain(self.root[0])[:self.root[1]] if self.root else b""

    def sector(self, index):
        start = (index + 1) * self.sector_size
        return self.data[start:start + self.sector_size]

    def chain(self, start):
        out = bytearray()
        sector = start
        seen = set()
        while sector < ENDOFCHAIN:
            if sector in seen or sector >= len(self.fat):
                break
            seen.add(sector)
            out.extend(self.sector(sector))
            sector = self.fat[sector]
        return bytes(out)

    def mini_chain(self, start, size):
        out = bytearray()
        sector = start
        seen = set()
        while sector < ENDOFCHAIN and len(out) < size:
            if sector in seen:
                break
            seen.add(sector)
            offset = sector * self.mini_size
            out.extend(self.mini_stream[offset:offset + self.mini_size])
            sector = self.mini_fat[sector]
        return bytes(out[:size])

    def read(self, name):
        if name not in self.entries:
            raise ValueError("stream %r not found; have %s" % (name, sorted(self.entries)))
        start, size = self.entries[name]
        if size < self.cutoff:
            return self.mini_chain(start, size)
        return self.chain(start)[:size]


# --------------------------------------------------------------------------
# 3ds Max chunk tree
# --------------------------------------------------------------------------
def walk_chunks(buffer, base=0, end=None):
    """Yield (chunk_id, payload_offset, payload_length) for one nesting level."""
    end = len(buffer) if end is None else end
    offset = base
    while offset + 6 <= end:
        chunk_id, raw_size = struct.unpack_from("<HI", buffer, offset)
        size = raw_size & 0x7FFFFFFF
        if size < 6 or offset + size > end:
            return
        yield chunk_id, offset + 6, size - 6, bool(raw_size & 0x80000000)
        offset += size


def find_chunk(buffer, wanted):
    """Depth-first search for the first chunk with the given id."""
    stack = [(0, len(buffer))]
    while stack:
        base, end = stack.pop()
        children = []
        for chunk_id, payload, length, container in walk_chunks(buffer, base, end):
            if chunk_id == wanted:
                return payload, length
            if container:
                children.append((payload, payload + length))
        stack.extend(reversed(children))
    raise ValueError("chunk 0x%04x not found" % wanted)


def _records(buffer, wanted, stride):
    payload, length = find_chunk(buffer, wanted)
    count = struct.unpack_from("<I", buffer, payload)[0]
    header = length - count * stride
    if header < 4 or header > 64:
        raise ValueError("chunk 0x%04x: %d records of %d B do not fit %d B"
                         % (wanted, count, stride, length))
    return buffer, payload + header, count


def read_positions(buffer, wanted):
    data, start, count = _records(buffer, wanted, 12)
    return [struct.unpack_from("<3f", data, start + i * 12) for i in range(count)]


def read_faces(buffer):
    data, start, count = _records(buffer, 0x0912, 20)
    faces, smoothing, materials = [], [], []
    for i in range(count):
        offset = start + i * 20
        faces.append(struct.unpack_from("<3I", data, offset))
        smoothing.append(struct.unpack_from("<I", data, offset + 12)[0])
        # Offset 16 holds edge-visibility flags (always 71 here); 18 is the
        # sub-material index of the Multi/Sub-Object material.
        materials.append(struct.unpack_from("<H", data, offset + 18)[0])
    return faces, smoothing, materials


def read_map_faces(buffer):
    data, start, count = _records(buffer, 0x2396, 12)
    return [struct.unpack_from("<3I", data, start + i * 12) for i in range(count)]


# --------------------------------------------------------------------------
# DDS (DXT1 / DXT5) decode + PNG encode
# --------------------------------------------------------------------------
def _rgb565(value):
    return (((value >> 11) & 31) * 255 // 31,
            ((value >> 5) & 63) * 255 // 63,
            (value & 31) * 255 // 31)


def decode_dds(path):
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"DDS ":
        raise ValueError("%s is not a DDS file" % path)
    height = struct.unpack_from("<I", data, 12)[0]
    width = struct.unpack_from("<I", data, 16)[0]
    # DDS_PIXELFORMAT starts at 76; dwFourCC is its third dword.
    fourcc = data[84:88].decode("ascii", "replace")
    if fourcc not in ("DXT1", "DXT3", "DXT5"):
        raise ValueError("%s uses unsupported compression %r" % (path, fourcc))
    rgba = bytearray(width * height * 4)
    block_bytes = 8 if fourcc == "DXT1" else 16
    alpha_offset = 0 if fourcc == "DXT1" else 8
    # dwPitchOrLinearSize is unreliable; derive the grid and read the top mip.
    offset = 128
    for by in range((height + 3) // 4):
        for bx in range((width + 3) // 4):
            if fourcc == "DXT5":
                a0, a1 = data[offset], data[offset + 1]
                levels = [a0, a1]
                if a0 > a1:
                    levels += [(6 * a0 + 1 * a1) // 7, (5 * a0 + 2 * a1) // 7,
                               (4 * a0 + 3 * a1) // 7, (3 * a0 + 4 * a1) // 7,
                               (2 * a0 + 5 * a1) // 7, (1 * a0 + 6 * a1) // 7]
                else:
                    levels += [(4 * a0 + 1 * a1) // 5, (3 * a0 + 2 * a1) // 5,
                               (2 * a0 + 3 * a1) // 5, (1 * a0 + 4 * a1) // 5, 0, 255]
                bits = int.from_bytes(data[offset + 2:offset + 8], "little")
                alpha = [(bits >> (3 * i)) & 7 for i in range(16)]
            else:
                alpha = None
            colour = offset + alpha_offset
            c0, c1 = struct.unpack_from("<HH", data, colour)
            r0, g0, b0 = _rgb565(c0)
            r1, g1, b1 = _rgb565(c1)
            palette = [(r0, g0, b0, 255), (r1, g1, b1, 255)]
            if fourcc != "DXT1" or c0 > c1:
                palette.append(((2 * r0 + r1) // 3, (2 * g0 + g1) // 3, (2 * b0 + b1) // 3, 255))
                palette.append(((r0 + 2 * r1) // 3, (g0 + 2 * g1) // 3, (b0 + 2 * b1) // 3, 255))
            else:
                palette.append(((r0 + r1) // 2, (g0 + g1) // 2, (b0 + b1) // 2, 255))
                palette.append((0, 0, 0, 255))
            indices = struct.unpack_from("<I", data, colour + 4)[0]
            for py in range(4):
                for px in range(4):
                    x, y = bx * 4 + px, by * 4 + py
                    if x >= width or y >= height:
                        continue
                    index = py * 4 + px
                    r, g, b, a = palette[(indices >> (2 * index)) & 3]
                    if alpha is not None:
                        a = levels[alpha[index]]
                    target = (y * width + x) * 4
                    rgba[target:target + 4] = bytes((r, g, b, a))
            # A DXT colour block is 8 bytes: two 565 words plus 32 index bits.
            offset += block_bytes
    return width, height, bytes(rgba)


def write_png(path, width, height, rgba):
    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])
    blob = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))
    with open(path, "wb") as handle:
        handle.write(blob)


# --------------------------------------------------------------------------
# Topology helpers
# --------------------------------------------------------------------------
def _union_find(size):
    parent = list(range(size))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    return find, union


def face_components(faces, vertex_count):
    """Connected-component label per source vertex, largest component first."""
    find, union = _union_find(vertex_count)
    for a, b, c in faces:
        union(a, b)
        union(a, c)
    sizes = {}
    for vertex in range(vertex_count):
        root = find(vertex)
        sizes[root] = sizes.get(root, 0) + 1
    order = sorted(sizes, key=lambda root: (-sizes[root], root))
    labels = {root: i for i, root in enumerate(order)}
    return [labels[find(v)] for v in range(vertex_count)]


def split_by_smoothing(faces, smoothing):
    """Duplicate vertices where smoothing groups disagree, so averaged normals
    reproduce 3ds Max's shading without version-specific auto-smooth flags."""
    corner_count = len(faces) * 3
    find, union = _union_find(corner_count)
    incident = {}
    for fi, face in enumerate(faces):
        for k, vertex in enumerate(face):
            incident.setdefault(vertex, []).append((fi * 3 + k, smoothing[fi]))
    for corners in incident.values():
        for i, (corner, mask) in enumerate(corners):
            if mask == 0:
                continue
            for other, other_mask in corners[i + 1:]:
                if mask & other_mask:
                    union(corner, other)
    remapped = {}
    source_vertex = []
    out_faces = []
    for fi, face in enumerate(faces):
        out = []
        for k, vertex in enumerate(face):
            root = find(fi * 3 + k)
            if root not in remapped:
                remapped[root] = len(source_vertex)
                source_vertex.append(vertex)
            out.append(remapped[root])
        out_faces.append(tuple(out))
    return out_faces, source_vertex


# --------------------------------------------------------------------------
# Rig authoring
# --------------------------------------------------------------------------
# The upload is a static A-pose with no skeleton. The runtime gait in
# scripts/coastal/enemy_soldier.gd only adds *compliance* to the arms -- it never
# re-solves a grip -- so the exported rest pose must already hold the rifle.
# We therefore bind in the A-pose, solve a two-bone IK for both arms, bake that
# pose into the vertices, and publish the posed skeleton as the rest pose.

HIPS_Z = 0.95
TORSO_Z = 1.15
HEAD_Z = 1.52
SHOULDER = (0.201, 0.032, 1.489)
ELBOW = (0.395, 0.038, 1.284)
UPPER_ARM = 0.282
FOREARM = 0.249
RIFLE_LOCAL = (0.09, -0.15, 0.21)
RIFLE_EULER = (-0.10, 0.0, -0.25)
GRIP_LOCAL = (0.0, -0.09, -0.055)
GUARD_LOCAL = (0.0, -0.26, 0.005)
MUZZLE_LOCAL = (0.0, -0.47, 0.01)

BONE_ORDER = ["Hips", "Torso", "Head", "LegL", "KneeL", "LegR", "KneeR",
              "ArmL", "ElbowL", "ArmR", "ElbowR"]
BONE_PARENT = {"Hips": None, "Torso": "Hips", "Head": "Torso",
               "LegL": "Hips", "KneeL": "LegL", "LegR": "Hips", "KneeR": "LegR",
               "ArmL": "Torso", "ElbowL": "ArmL", "ArmR": "Torso", "ElbowR": "ArmR"}


def identity():
    return (1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0)


def translation(t):
    return (1.0, 0.0, 0.0, t[0], 0.0, 1.0, 0.0, t[1], 0.0, 0.0, 1.0, t[2])


def transform_point(m, p):
    return (m[0] * p[0] + m[1] * p[1] + m[2] * p[2] + m[3],
            m[4] * p[0] + m[5] * p[1] + m[6] * p[2] + m[7],
            m[8] * p[0] + m[9] * p[1] + m[10] * p[2] + m[11])


def transform_direction(m, p):
    return (m[0] * p[0] + m[1] * p[1] + m[2] * p[2],
            m[4] * p[0] + m[5] * p[1] + m[6] * p[2],
            m[8] * p[0] + m[9] * p[1] + m[10] * p[2])


def mat_mul(a, b):
    """Multiply two rigid 3x4 transforms (row-major, implicit bottom row 0 0 0 1)."""
    out = []
    for row in range(3):
        for col in range(3):
            out.append(sum(a[row * 4 + k] * b[k * 4 + col] for k in range(3)))
        out.append(sum(a[row * 4 + k] * b[k * 4 + 3] for k in range(3)) + a[row * 4 + 3])
    return tuple(out)


def mat_inverse(m):
    """Inverse of a rigid transform: transpose the basis, negate the rotated origin."""
    it = (m[0] * m[3] + m[4] * m[7] + m[8] * m[11],
          m[1] * m[3] + m[5] * m[7] + m[9] * m[11],
          m[2] * m[3] + m[6] * m[7] + m[10] * m[11])
    return (m[0], m[4], m[8], -it[0],
            m[1], m[5], m[9], -it[1],
            m[2], m[6], m[10], -it[2])


def normalize(v):
    length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if length < 1e-12:
        return (0.0, 0.0, 1.0)
    return (v[0] / length, v[1] / length, v[2] / length)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def scale(v, s):
    return (v[0] * s, v[1] * s, v[2] * s)


def basis_from_direction(origin, direction):
    """Blender's to_track_quat('-Z', 'Y'): local -Z aims along `direction`."""
    z_axis = scale(normalize(direction), -1.0)
    up = (0.0, 0.0, 1.0)
    if abs(dot(up, z_axis)) > 0.999:
        up = (0.0, 1.0, 0.0)
    y_axis = normalize(sub(up, scale(z_axis, dot(up, z_axis))))
    x_axis = normalize(cross(y_axis, z_axis))
    return (x_axis[0], y_axis[0], z_axis[0], origin[0],
            x_axis[1], y_axis[1], z_axis[1], origin[1],
            x_axis[2], y_axis[2], z_axis[2], origin[2])


def euler_xyz_matrix(rx, ry, rz):
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    mx = (1, 0, 0, 0, 0, cx, -sx, 0, 0, sx, cx, 0)
    my = (cy, 0, sy, 0, 0, 1, 0, 0, -sy, 0, cy, 0)
    mz = (cz, -sz, 0, 0, sz, cz, 0, 0, 0, 0, 1, 0)
    return mat_mul(mz, mat_mul(my, mx))


def matrix_to_quaternion(m):
    trace = m[0] + m[5] + m[10]
    if trace > 0.0:
        s = math.sqrt(trace + 1.0) * 2.0
        w, x, y, z = 0.25 * s, (m[9] - m[6]) / s, (m[2] - m[8]) / s, (m[1] - m[4]) / s
    elif m[0] > m[5] and m[0] > m[10]:
        s = math.sqrt(1.0 + m[0] - m[5] - m[10]) * 2.0
        w, x, y, z = (m[9] - m[6]) / s, 0.25 * s, (m[1] + m[4]) / s, (m[2] + m[8]) / s
    elif m[5] > m[10]:
        s = math.sqrt(1.0 + m[5] - m[0] - m[10]) * 2.0
        w, x, y, z = (m[2] - m[8]) / s, (m[1] + m[4]) / s, 0.25 * s, (m[6] + m[9]) / s
    else:
        s = math.sqrt(1.0 + m[10] - m[0] - m[5]) * 2.0
        w, x, y, z = (m[1] - m[4]) / s, (m[2] + m[8]) / s, (m[6] + m[9]) / s, 0.25 * s
    q = (x, y, z, w)
    length = math.sqrt(sum(c * c for c in q)) or 1.0
    return tuple(round(c / length, 7) for c in q)


def segment_distance(point, a, b):
    ab = sub(b, a)
    denominator = max(dot(ab, ab), 1e-9)
    t = max(0.0, min(1.0, dot(sub(point, a), ab) / denominator))
    closest = add(a, scale(ab, t))
    delta = sub(point, closest)
    return math.sqrt(max(0.0, dot(delta, delta)))


def bind_skeleton():
    """World-space A-pose joints matching the uploaded anatomy."""
    joints = {"Hips": translation((0.0, 0.0, HIPS_Z)),
              "Torso": translation((0.0, 0.0, TORSO_Z)),
              "Head": translation((0.0, 0.005, HEAD_Z))}
    for side, sign in (("L", -1.0), ("R", 1.0)):
        joints["Leg" + side] = translation((sign * 0.115, 0.0, 0.93))
        joints["Knee" + side] = translation((sign * 0.140, -0.012, 0.52))
        shoulder = (sign * SHOULDER[0], SHOULDER[1], SHOULDER[2])
        elbow = (sign * ELBOW[0], ELBOW[1], ELBOW[2])
        joints["Arm" + side] = basis_from_direction(shoulder, sub(elbow, shoulder))
        joints["Elbow" + side] = basis_from_direction(elbow, sub(elbow, shoulder))
    return joints


def skin_segments(joints):
    def origin(name):
        m = joints[name]
        return (m[3], m[7], m[11])

    def tail(name, length):
        return transform_point(joints[name], (0.0, 0.0, -length))

    pairs = [("Hips", "Torso"), ("Torso", "Head"), ("LegL", "KneeL"), ("LegR", "KneeR"),
             ("ArmL", "ElbowL"), ("ArmR", "ElbowR")]
    segments = [(a, origin(a), origin(b)) for a, b in pairs]
    segments.append(("KneeL", origin("KneeL"), tail("KneeL", 0.47)))
    segments.append(("KneeR", origin("KneeR"), tail("KneeR", 0.47)))
    segments.append(("ElbowL", origin("ElbowL"), tail("ElbowL", FOREARM)))
    segments.append(("ElbowR", origin("ElbowR"), tail("ElbowR", FOREARM)))
    segments.append(("Head", origin("Head"), add(origin("Head"), (0.0, 0.0, 0.20))))
    return segments


def solve_arm(joints, side, target, pole):
    """Two-bone IK; returns replacement Arm/Elbow world matrices."""
    shoulder_m = joints["Arm" + side]
    shoulder = (shoulder_m[3], shoulder_m[7], shoulder_m[11])
    delta = sub(target, shoulder)
    distance = min(max(math.sqrt(dot(delta, delta)), 0.12), UPPER_ARM + FOREARM - 0.012)
    direction = normalize(delta)
    a = (UPPER_ARM ** 2 - FOREARM ** 2 + distance ** 2) / (2.0 * distance)
    h = math.sqrt(max(UPPER_ARM ** 2 - a * a, 0.0))
    pole_vector = sub(pole, shoulder)
    pole_vector = normalize(sub(pole_vector, scale(direction, dot(pole_vector, direction))))
    elbow = add(add(shoulder, scale(direction, a)), scale(pole_vector, h))
    wrist = add(elbow, scale(normalize(sub(target, elbow)), FOREARM))
    return (basis_from_direction(shoulder, sub(elbow, shoulder)),
            basis_from_direction(elbow, sub(wrist, elbow)))


def author_rig(vertices, faces, vertex_component):
    joints = bind_skeleton()
    segments = skin_segments(joints)
    index_of = {name: i for i, name in enumerate(BONE_ORDER)}

    # The largest connected component is the continuous body; every other shell
    # is a piece of gear (pouches, pads, hands, head) and stays rigid on one bone.
    sizes = {}
    for component in vertex_component:
        sizes[component] = sizes.get(component, 0) + 1
    body_component = max(sizes, key=lambda c: sizes[c])

    component_bone = {}
    for component in sorted(sizes):
        if component == body_component:
            continue
        members = [i for i, c in enumerate(vertex_component) if c == component]
        centre = tuple(sum(vertices[i][k] for i in members) / len(members) for k in range(3))
        component_bone[component] = min(segments, key=lambda s: segment_distance(centre, s[1], s[2]))[0]

    weights = []
    for i, point in enumerate(vertices):
        component = vertex_component[i]
        if component != body_component:
            weights.append([(index_of[component_bone[component]], 1.0)])
            continue
        near = sorted((segment_distance(point, a, b), name) for name, a, b in segments)[:3]
        raw = [1.0 / max(d, 0.015) ** 4 for d, _ in near]
        total = sum(raw)
        weights.append([(index_of[name], round(w / total, 6)) for (_, name), w in zip(near, raw)])

    # Solve the rifle grip in torso space, then bake it.
    torso = joints["Torso"]
    rifle_rotation = euler_xyz_matrix(*RIFLE_EULER)
    rifle_world = mat_mul(torso, mat_mul(translation(RIFLE_LOCAL), rifle_rotation))
    grip = transform_point(rifle_world, GRIP_LOCAL)
    guard = transform_point(rifle_world, GUARD_LOCAL)
    pole_r = transform_point(torso, (0.55, -0.10, -0.05))
    pole_l = transform_point(torso, (-0.55, -0.10, -0.05))
    posed = dict(joints)
    posed["ArmR"], posed["ElbowR"] = solve_arm(joints, "R", grip, pole_r)
    posed["ArmL"], posed["ElbowL"] = solve_arm(joints, "L", guard, pole_l)

    deltas = {name: mat_mul(posed[name], mat_inverse(joints[name])) for name in BONE_ORDER}
    baked = []
    for point, influences in zip(vertices, weights):
        x = y = z = 0.0
        for joint, weight in influences:
            moved = transform_point(deltas[BONE_ORDER[joint]], point)
            x += moved[0] * weight
            y += moved[1] * weight
            z += moved[2] * weight
        baked.append((round(x, 6), round(y, 6), round(z, 6)))

    # Area-weighted normals; hard edges are already split by smoothing group.
    accum = [[0.0, 0.0, 0.0] for _ in baked]
    for a, b, c in faces:
        pa, pb, pc = baked[a], baked[b], baked[c]
        n = cross(sub(pb, pa), sub(pc, pa))
        for vertex in (a, b, c):
            accum[vertex][0] += n[0]
            accum[vertex][1] += n[1]
            accum[vertex][2] += n[2]
    normals = [tuple(round(c, 6) for c in normalize(tuple(n))) for n in accum]

    joint_records = []
    for name in BONE_ORDER:
        parent = BONE_PARENT[name]
        world = posed[name]
        local = mat_mul(mat_inverse(posed[parent]), world) if parent else world
        joint_records.append({"name": name, "parent": parent,
                              "translation": [round(local[3], 6), round(local[7], 6), round(local[11], 6)],
                              "rotation": matrix_to_quaternion(local)})
    return baked, normals, weights, joint_records, {
        "parent": "Torso", "translation": list(RIFLE_LOCAL), "rotation_euler": list(RIFLE_EULER),
        "muzzle_translation": list(MUZZLE_LOCAL),
    }


def convert(source_dir, out_json, out_textures):
    max_path = os.path.join(source_dir, "D0307048A1.max")
    scene = CompoundFile(max_path).read("Scene")
    positions = read_positions(scene, 0x0914)
    faces, smoothing, material_ids = read_faces(scene)
    map_vertices = read_positions(scene, 0x2394)
    map_faces = read_map_faces(scene)
    if len(faces) != len(map_faces):
        raise ValueError("face/map-face count mismatch: %d vs %d" % (len(faces), len(map_faces)))
    if max(material_ids) >= len(MATERIALS):
        raise ValueError("unexpected material index %d" % max(material_ids))

    components = face_components(faces, len(positions))
    remapped, source_vertex = split_by_smoothing(faces, smoothing)

    unit_scale = TARGET_HEIGHT_M / SOURCE_HEIGHT_UNITS
    floor_z = min(p[2] for p in positions)
    vertices = []
    for index in source_vertex:
        x, y, z = positions[index]
        vertices.append((round(-(x - SOURCE_CENTER_X) * unit_scale, 6),
                         round(-y * unit_scale, 6),
                         round((z - floor_z) * unit_scale, 6)))
    # The source winding faces inward; reverse it for glTF/Blender.
    out_faces = [tuple(reversed(face)) for face in remapped]
    out_map_faces = [tuple(reversed(face)) for face in map_faces]
    uvs = [[round(uv[0], 6), round(uv[1], 6)] for uv in map_vertices]

    vertex_component = [0] * len(vertices)
    for face in out_faces:
        for vertex in face:
            vertex_component[vertex] = components[source_vertex[vertex]]
    face_component = [components[face[0]] for face in faces]

    posed, normals, weights, joints, rifle = author_rig(vertices, out_faces, vertex_component)

    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    os.makedirs(out_textures, exist_ok=True)
    written = {}
    for _, filename, dds in MATERIALS:
        if filename in written:
            continue
        width, height, rgba = decode_dds(os.path.join(source_dir, dds))
        write_png(os.path.join(out_textures, filename), width, height, rgba)
        written[filename] = [width, height]

    document = {
        "schema": "artillery.uploaded-infantry/2",
        "provenance": {
            "source_files": ["D0307048A1.max"] + [m[2] for m in MATERIALS[:3]],
            "origin": "User-supplied 3ds Max scene; not authored by this project.",
            "rig": "No Skin modifier or weights exist in the source. The 11-bone rig, "
                   "the nearest-segment weights and the baked rifle grip are authored "
                   "by this converter.",
            "weapon": "The source has no weapon; the rifle is the project's original geometry.",
            "source_units_height": SOURCE_HEIGHT_UNITS,
            "normalised_height_m": TARGET_HEIGHT_M,
            "source_vertices": len(positions),
            "source_triangles": len(faces),
        },
        "materials": [{"name": name, "texture": texture} for name, texture, _ in MATERIALS],
        "texture_sizes": written,
        "space": "Blender Z-up metres, model faces -Y. Vertices are already posed.",
        "vertices": posed,
        "normals": normals,
        "uvs": uvs,
        "faces": out_faces,
        "map_faces": out_map_faces,
        "face_material": material_ids,
        "face_component": face_component,
        "vertex_component": vertex_component,
        "joints": joints,
        "weights": weights,
        "rifle": rifle,
    }
    with open(out_json, "w", encoding="utf8") as handle:
        json.dump(document, handle, separators=(",", ":"))
        handle.write("\n")

    counts = {}
    for index in material_ids:
        counts[MATERIALS[index][0]] = counts.get(MATERIALS[index][0], 0) + 1
    xs = [v[0] for v in posed]
    ys = [v[1] for v in posed]
    zs = [v[2] for v in posed]
    print("IMPORTED uploaded infantry")
    print("  source triangles : %d" % len(faces))
    print("  source vertices  : %d -> %d after smoothing split" % (len(positions), len(vertices)))
    print("  components       : %d" % (max(components) + 1))
    print("  material split   : %s" % counts)
    print("  joints / weights : %d bones, %d skinned vertices" % (len(joints), len(weights)))
    print("  posed bounds m   : x[%.3f, %.3f] y[%.3f, %.3f] z[%.3f, %.3f]"
          % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    print("  textures         : %s" % written)
    print("  json             : %s (%d bytes)" % (out_json, os.path.getsize(out_json)))
    return document


def main():
    parser = argparse.ArgumentParser(description="Convert the uploaded 3ds Max infantryman.")
    parser.add_argument("--source-dir", default=REPO, help="directory holding the uploaded .max and .dds files")
    parser.add_argument("--json", default=os.path.join(ROOT, "assets", "models", "source", "uploaded_soldier.json"))
    parser.add_argument("--textures", default=os.path.join(ROOT, "assets", "textures", "uploaded"))
    args = parser.parse_args()
    convert(args.source_dir, args.json, args.textures)
    return 0


if __name__ == "__main__":
    sys.exit(main())
