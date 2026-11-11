"""Skeleton, pose and animation helpers. Bones are world aligned in the bind
pose (identity rest rotation), so a bone's rest matrix is a pure translation."""
import math

import numpy as np


def quat_from_axis_angle(axis, degrees):
    axis = np.asarray(axis, np.float64)
    norm = np.linalg.norm(axis)
    if norm < 1e-12:
        return np.array([0.0, 0.0, 0.0, 1.0])
    axis = axis / norm
    half = math.radians(degrees) * 0.5
    return np.array([axis[0] * math.sin(half), axis[1] * math.sin(half), axis[2] * math.sin(half), math.cos(half)])


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ])


def quat_inv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def quat_rotate(q, v):
    u = np.array(q[:3])
    v = np.asarray(v, np.float64)
    return v + 2.0 * np.cross(u, np.cross(u, v) + q[3] * v)


def quat_euler(rx=0.0, ry=0.0, rz=0.0):
    """Yaw (Y), then pitch (X), then roll (Z); degrees."""
    q = quat_from_axis_angle((0, 1, 0), ry)
    q = quat_mul(q, quat_from_axis_angle((1, 0, 0), rx))
    return quat_mul(q, quat_from_axis_angle((0, 0, 1), rz))


def quat_between(a, b):
    """Shortest arc taking direction a to direction b."""
    a = np.asarray(a, np.float64)
    b = np.asarray(b, np.float64)
    a = a / max(np.linalg.norm(a), 1e-12)
    b = b / max(np.linalg.norm(b), 1e-12)
    dot = float(np.dot(a, b))
    if dot > 0.999999:
        return np.array([0.0, 0.0, 0.0, 1.0])
    if dot < -0.999999:
        axis = np.cross(a, (1.0, 0.0, 0.0))
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, (0.0, 0.0, 1.0))
        return quat_from_axis_angle(axis, 180.0)
    axis = np.cross(a, b)
    q = np.array([axis[0], axis[1], axis[2], 1.0 + dot])
    return q / np.linalg.norm(q)


def quat_to_matrix(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def two_bone(root, target, upper, lower, pole):
    """Analytic two-bone IK. Returns the middle joint position."""
    root = np.asarray(root, np.float64)
    target = np.asarray(target, np.float64)
    to_target = target - root
    distance = np.linalg.norm(to_target)
    reach = upper + lower - 1e-4
    if distance > reach:
        to_target = to_target / distance * reach
        distance = reach
    distance = max(distance, abs(upper - lower) + 1e-4)
    forward = to_target / max(np.linalg.norm(to_target), 1e-9)
    pole = np.asarray(pole, np.float64)
    side = pole - forward * np.dot(pole, forward)
    if np.linalg.norm(side) < 1e-6:
        side = np.cross(forward, (1.0, 0.0, 0.0))
    side = side / np.linalg.norm(side)
    along = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
    height = math.sqrt(max(upper * upper - along * along, 0.0))
    return root + forward * along + side * height


class Skeleton:
    def __init__(self):
        self.names = []
        self.parents = []
        self.positions = []

    def add(self, name, position, parent=None):
        self.names.append(name)
        self.parents.append(-1 if parent is None else self.names.index(parent))
        self.positions.append(np.asarray(position, np.float64))
        return len(self.names) - 1

    def index(self, name):
        return self.names.index(name)

    def position(self, name):
        return self.positions[self.index(name)]

    def offset(self, name):
        i = self.index(name)
        if self.parents[i] < 0:
            return self.positions[i].copy()
        return self.positions[i] - self.positions[self.parents[i]]

    def inverse_bind(self):
        out = np.tile(np.eye(4), (len(self.names), 1, 1))
        for i, p in enumerate(self.positions):
            out[i, :3, 3] = -p
        return out

    def world(self, rotations, translations=None):
        """Forward kinematics. rotations: name -> quaternion (local).
        Returns lists of world quaternions and world positions."""
        translations = translations or {}
        world_q, world_p = [], []
        for i, name in enumerate(self.names):
            local_q = rotations.get(name, np.array([0.0, 0.0, 0.0, 1.0]))
            local_t = self.offset(name) + np.asarray(translations.get(name, (0.0, 0.0, 0.0)), np.float64)
            parent = self.parents[i]
            if parent < 0:
                world_q.append(local_q)
                world_p.append(local_t)
            else:
                world_q.append(quat_mul(world_q[parent], local_q))
                world_p.append(world_p[parent] + quat_rotate(world_q[parent], local_t))
        return world_q, world_p


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def keyed(keys, t):
    """Piecewise eased interpolation of (time, value) keys; values may be tuples."""
    if t <= keys[0][0]:
        return np.asarray(keys[0][1], np.float64)
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            w = ease((t - t0) / max(t1 - t0, 1e-9))
            return np.asarray(v0, np.float64) * (1.0 - w) + np.asarray(v1, np.float64) * w
    return np.asarray(keys[-1][1], np.float64)
