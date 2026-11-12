"""Signed-distance sculpting: primitives, smooth blends, meshing and baking helpers."""
import numpy as np


def smin(a, b, k):
    if k <= 0.0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def capsule(p, a, b, r1, r2=None):
    """Tapered capsule from a (radius r1) to b (radius r2)."""
    r2 = r1 if r2 is None else r2
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    closest = a + t[:, None] * ab
    return np.linalg.norm(p - closest, axis=1) - (r1 + (r2 - r1) * t)


def ellipsoid(p, center, radii, basis=None):
    q = p - np.asarray(center, np.float32)
    if basis is not None:
        q = q @ np.asarray(basis, np.float32)
    r = np.asarray(radii, np.float32)
    k0 = np.linalg.norm(q / r, axis=1)
    k1 = np.linalg.norm(q / (r * r), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sphere(p, center, radius):
    return np.linalg.norm(p - np.asarray(center, np.float32), axis=1) - radius


def box(p, center, half, radius=0.0, basis=None):
    q = p - np.asarray(center, np.float32)
    if basis is not None:
        q = q @ np.asarray(basis, np.float32)
    q = np.abs(q) - (np.asarray(half, np.float32) - radius)
    outside = np.linalg.norm(np.maximum(q, 0.0), axis=1)
    inside = np.minimum(np.max(q, axis=1), 0.0)
    return outside + inside - radius


def rotation(axis, degrees):
    """3x3 rotation matrix whose columns are the rotated basis vectors."""
    axis = np.asarray(axis, np.float64)
    axis = axis / np.linalg.norm(axis)
    angle = np.radians(degrees)
    c, s = np.cos(angle), np.sin(angle)
    x, y, z = axis
    return np.array([
        [c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
        [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
        [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)],
    ])


def grid(bounds_min, bounds_max, step):
    axes = [np.arange(bounds_min[i], bounds_max[i] + step * 0.5, step, dtype=np.float32) for i in range(3)]
    shape = tuple(len(a) for a in axes)
    xs, ys, zs = np.meshgrid(*axes, indexing="ij")
    points = np.stack([xs.ravel(), ys.ravel(), zs.ravel()], axis=1)
    return points, shape, np.array([a[0] for a in axes], np.float32)


def evaluate_chunked(function, points, chunk=400000):
    out = np.empty(points.shape[0], np.float32)
    for start in range(0, points.shape[0], chunk):
        out[start:start + chunk] = function(points[start:start + chunk])
    return out


def mesh_from_field(function, bounds_min, bounds_max, step):
    """Marching cubes over a sampled field. Returns outward-wound (vertices, faces)."""
    from skimage import measure
    points, shape, origin = grid(bounds_min, bounds_max, step)
    volume = evaluate_chunked(function, points).reshape(shape)
    vertices, faces, _normals, _values = measure.marching_cubes(volume, level=0.0, spacing=(step, step, step), gradient_direction="ascent")
    vertices = vertices.astype(np.float32) + origin
    faces = faces.astype(np.int64)
    if signed_volume(vertices, faces) < 0.0:
        faces = faces[:, ::-1].copy()
    return vertices, faces


def signed_volume(vertices, faces):
    a, b, c = vertices[faces[:, 0]], vertices[faces[:, 1]], vertices[faces[:, 2]]
    return float(np.sum(np.einsum("ij,ij->i", a, np.cross(b, c))) / 6.0)


def simplify(vertices, faces, target_faces):
    import fast_simplification
    ratio = 1.0 - min(1.0, target_faces / max(1, faces.shape[0]))
    out_v, out_f = fast_simplification.simplify(vertices.astype(np.float32), faces.astype(np.int32), target_reduction=ratio, agg=7)
    out_f = out_f.astype(np.int64)
    # Drop degenerate faces the collapse may leave behind.
    a, b, c = out_v[out_f[:, 0]], out_v[out_f[:, 1]], out_v[out_f[:, 2]]
    area = np.linalg.norm(np.cross(b - a, c - a), axis=1)
    return out_v.astype(np.float32), out_f[area > 1e-10]


def gradient(function, points, eps=0.002):
    g = np.zeros(points.shape, np.float32)
    for axis in range(3):
        offset = np.zeros(3, np.float32)
        offset[axis] = eps
        g[:, axis] = function(points + offset) - function(points - offset)
    length = np.linalg.norm(g, axis=1, keepdims=True)
    return g / np.maximum(length, 1e-9)


def project(function, points, iterations=2):
    """Pull points onto the zero level set."""
    p = points.astype(np.float32).copy()
    for _ in range(iterations):
        d = function(p)
        p -= gradient(function, p) * d[:, None]
    return p


def occlusion(function, points, normals, step=0.012, samples=5, strength=1.6):
    """Distance-field ambient occlusion: 1 is open, lower is occluded."""
    occ = np.zeros(points.shape[0], np.float32)
    scale = 1.0
    for i in range(1, samples + 1):
        h = step * i
        d = function(points + normals * h)
        occ += np.maximum(h - d, 0.0) / h * scale
        scale *= 0.7
    return np.clip(1.0 - occ * strength / samples, 0.0, 1.0)
