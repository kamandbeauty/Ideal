#!/usr/bin/env python3
"""Create an approximate lightweight skin from the existing static hero GLB.

This is procedural weighting, not a recovered original rig. Source GLB is
never overwritten. Joint weights and pivots are approximate for this model.
"""
import json
import math
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'assets/models/hero-2630.glb'
target = root / 'assets/models/hero-2630-procedural-rig.glb'
data = source.read_bytes()
json_length, json_type = struct.unpack_from('<II', data, 12)
assert json_type == 0x4e4f534a
model = json.loads(data[20:20 + json_length])
bin_header = 20 + json_length
bin_length, bin_type = struct.unpack_from('<II', data, bin_header)
assert bin_type == 0x004e4942
buf = bytearray(data[bin_header + 8:bin_header + 8 + bin_length])

def append_view(blob):
    while len(buf) % 4:
        buf.append(0)
    offset = len(buf)
    buf.extend(blob)
    model['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(blob)})
    return len(model['bufferViews']) - 1

def accessor(blob, component, typ, count):
    view = append_view(blob)
    model['accessors'].append({'bufferView': view, 'componentType': component, 'count': count, 'type': typ})
    return len(model['accessors']) - 1

def access_info(i):
    a = model['accessors'][i]
    v = model['bufferViews'][a['bufferView']]
    assert a['componentType'] == 5126 and a['type'] == 'VEC3'
    return a, v['byteOffset'] + a.get('byteOffset', 0), v.get('byteStride', 12)

def convert_vec3(i):
    a, start, stride = access_info(i)
    values = []
    for n in range(a['count']):
        x, y, z = struct.unpack_from('<3f', buf, start + n * stride)
        value = (x, z, -y)
        struct.pack_into('<3f', buf, start + n * stride, *value)
        values.append(value)
    if 'min' in a:
        a['min'] = [min(v[k] for v in values) for k in range(3)]
        a['max'] = [max(v[k] for v in values) for k in range(3)]
    return values

# The original nodes apply a -90 degree X rotation. Bake that rotation into
# positions and normals so the entire skin and its joints share one space.
for node in model['nodes']:
    node.pop('matrix', None)
for mesh in model['meshes']:
    for primitive in mesh['primitives']:
        attrs = primitive['attributes']
        vertices = convert_vec3(attrs['POSITION'])
        convert_vec3(attrs['NORMAL'])
        joints, weights = bytearray(), bytearray()
        for x, y, z in vertices:
            # The coarse skin blends limbs into a fixed torso; no source mesh,
            # texture, normals, indices or material is deleted.
            leg = max(0.0, min(1.0, (42.0 - y) / 9.0))
            arm = max(0.0, min(1.0, (abs(x) - 7.0) / 9.0)) * max(0.0, min(1.0, (y - 34.0) / 9.0))
            if arm > leg:
                joint, weight = (3 if x < 0 else 4), arm
            else:
                joint, weight = (1 if x < 0 else 2), leg
            joints.extend(struct.pack('<4H', 0, joint, 0, 0))
            weights.extend(struct.pack('<4f', 1.0 - weight, weight, 0.0, 0.0))
        attrs['JOINTS_0'] = accessor(joints, 5123, 'VEC4', len(vertices))
        attrs['WEIGHTS_0'] = accessor(weights, 5126, 'VEC4', len(vertices))

pivots = [(0, 0, 0), (-4.3, 39, -3), (4.3, 39, -3), (-7, 58, -3), (7, 58, -3)]
names = ['MotionRoot', 'LegRight', 'LegLeft', 'ArmRight', 'ArmLeft']
base = len(model['nodes'])
model['nodes'].append({'name': names[0], 'children': list(range(base + 1, base + len(names)))})
for name, pos in zip(names[1:], pivots[1:]):
    model['nodes'].append({'name': name, 'translation': list(pos)})
for n in model['nodes'][:base]:
    n['skin'] = 0
inverse = bytearray()
for x, y, z in pivots:
    inverse.extend(struct.pack('<16f', 1,0,0,0, 0,1,0,0, 0,0,1,0, -x,-y,-z,1))
ibm = accessor(inverse, 5126, 'MAT4', len(pivots))
model['skins'] = [{'name': 'ApproximateHeroSkin', 'inverseBindMatrices': ibm, 'joints': list(range(base, base + len(names))), 'skeleton': base}]
model['scenes'][model.get('scene', 0)]['nodes'].append(base)
model['buffers'][0]['byteLength'] = len(buf)
while len(buf) % 4:
    buf.append(0)
encoded = json.dumps(model, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
header = struct.pack('<III', 0x46546c67, 2, 12 + 8 + len(encoded) + 8 + len(buf))
target.write_bytes(header + struct.pack('<II', len(encoded), 0x4e4f534a) + encoded + struct.pack('<II', len(buf), 0x004e4942) + buf)
print('Wrote', target, len(buf), 'binary bytes')
