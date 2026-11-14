#!/usr/bin/env python3
"""Add subtle Quaternius hit reactions to the existing zombie GLBs.

Reads the CC0 Godot GLB directly from the user-supplied archive. Only the
upper-body rotation deltas of Hit_Chest / Hit_Head are retargeted: their rest
frames are transformed into the generated zombie rig's axes and blended over
its original hit pose. The other joints, mesh, and timings remain untouched.
Run after tools/build_zombies.py; existing retargeted clips are left alone.
"""
import copy
import json
import math
import struct
import zipfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
REPO = PROJECT.parent
ARCHIVE = REPO / 'Universal_Animation_LibraryStandard.zip'
SOURCE = 'Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb'
MAPPING = {'Spine': 'DEF-spine.001', 'Chest': 'DEF-spine.003', 'Neck': 'DEF-neck', 'Head': 'DEF-head'}
IDENTITY = (0.0, 0.0, 0.0, 1.0)


def multiply(a, b):
    x, y, z, w = a
    X, Y, Z, W = b
    return (w*X + x*W + y*Z - z*Y, w*Y - x*Z + y*W + z*X,
            w*Z + x*Y - y*X + z*W, w*W - x*X - y*Y - z*Z)


def normalize(q):
    mag = math.sqrt(sum(x*x for x in q))
    return tuple(x / mag for x in q)


def inverse(q):
    q = normalize(q)
    return (-q[0], -q[1], -q[2], q[3])


def slerp(a, b, fraction):
    a, b = normalize(a), normalize(b)
    dot = sum(x*y for x, y in zip(a, b))
    if dot < 0:
        b, dot = tuple(-x for x in b), -dot
    dot = min(1.0, dot)
    if dot > 0.9995:
        return normalize(tuple(x + fraction*(y-x) for x, y in zip(a, b)))
    angle = math.acos(dot)
    return normalize(tuple((math.sin((1-fraction)*angle)*x + math.sin(fraction*angle)*y) / math.sin(angle)
                           for x, y in zip(a, b)))


def decode(data):
    if data[:4] != b'glTF' or struct.unpack_from('<I', data, 4)[0] != 2:
        raise ValueError('not a glTF 2.0 binary')
    length, kind = struct.unpack_from('<I4s', data, 12)
    if kind != b'JSON':
        raise ValueError('missing JSON chunk')
    doc = json.loads(data[20:20+length])
    start = 20 + length
    size, kind = struct.unpack_from('<I4s', data, start)
    if kind != b'BIN\0':
        raise ValueError('missing binary chunk')
    return doc, bytearray(data[start+8:start+8+size])


def accessor(doc, blob, index):
    a = doc['accessors'][index]
    if a['componentType'] != 5126 or a['type'] not in ('SCALAR', 'VEC4'):
        raise ValueError('unexpected animation accessor')
    view = doc['bufferViews'][a['bufferView']]
    width = 1 if a['type'] == 'SCALAR' else 4
    stride = view.get('byteStride', 4*width)
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from('<'+'f'*width, blob, start+i*stride) for i in range(a['count'])]


def add_quaternions(doc, blob, values):
    while len(blob) % 4:
        blob.append(0)
    data = b''.join(struct.pack('<4f', *v) for v in values)
    view = len(doc['bufferViews'])
    doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(data)})
    blob.extend(data)
    index = len(doc['accessors'])
    doc['accessors'].append({'bufferView': view, 'componentType': 5126, 'count': len(values), 'type': 'VEC4'})
    return index


def rotation_track(doc, blob, animation, node_name):
    for channel in animation['channels']:
        target = channel['target']
        if target['path'] == 'rotation' and doc['nodes'][target['node']].get('name') == node_name:
            sampler = animation['samplers'][channel['sampler']]
            if sampler.get('interpolation', 'LINEAR') != 'LINEAR':
                raise ValueError('unsupported animation interpolation')
            times = [x[0] for x in accessor(doc, blob, sampler['input'])]
            return times, accessor(doc, blob, sampler['output'])
    raise ValueError('missing rotation for ' + node_name)


def sample(times, values, t):
    if t <= times[0]:
        return values[0]
    for i in range(1, len(times)):
        if t <= times[i]:
            return slerp(values[i-1], values[i], (t-times[i-1])/(times[i]-times[i-1]))
    return values[-1]


def world_rest(doc, node_index):
    parents = {child: index for index, node in enumerate(doc['nodes']) for child in node.get('children', [])}
    chain = []
    while node_index is not None:
        chain.append(node_index)
        node_index = parents.get(node_index)
    result = IDENTITY
    for index in reversed(chain):
        result = multiply(result, doc['nodes'][index].get('rotation', IDENTITY))
    return normalize(result)


def encode(doc, blob):
    while len(blob) % 4:
        blob.append(0)
    doc['buffers'][0]['byteLength'] = len(blob)
    js = json.dumps(doc, separators=(',', ':'), ensure_ascii=False).encode('utf8')
    js += b' ' * ((-len(js)) % 4)
    return (struct.pack('<4sII', b'glTF', 2, 12+8+len(js)+8+len(blob)) +
            struct.pack('<I4s', len(js), b'JSON') + js + struct.pack('<I4s', len(blob), b'BIN\0') + blob)


def main():
    with zipfile.ZipFile(ARCHIVE) as bundle:
        source, source_blob = decode(bundle.read(SOURCE))
    source_nodes = {n.get('name'): i for i, n in enumerate(source['nodes'])}
    source_clips = {a['name']: a for a in source['animations']}
    for kind in ('walker', 'runner', 'brute', 'boss'):
        path = PROJECT / 'assets/models/zombies' / ('zombie_' + kind + '.glb')
        doc, blob = decode(path.read_bytes())
        if any(a['name'] in ('hit_chest', 'hit_head') for a in doc['animations']):
            print(path.name, 'already has retargeted clips; skipped')
            continue
        original = next(a for a in doc['animations'] if a['name'] == 'hit')
        for source_name, name in [('Hit_Chest', 'hit_chest'), ('Hit_Head', 'hit_head')]:
            clip = copy.deepcopy(original)
            clip['name'] = name
            for channel in clip['channels']:
                node_name = doc['nodes'][channel['target']['node']].get('name')
                if channel['target']['path'] != 'rotation' or node_name not in MAPPING:
                    continue
                source_node = MAPPING[node_name]
                src_t, src_q = rotation_track(source, source_blob, source_clips[source_name], source_node)
                sampler = clip['samplers'][channel['sampler']]
                target_t = [x[0] for x in accessor(doc, blob, sampler['input'])]
                base = accessor(doc, blob, sampler['output'])
                basis = world_rest(source, source_nodes[source_node])
                initial = inverse(src_q[0])
                output = []
                for time, base_q in zip(target_t, base):
                    fraction = min(1.0, max(0.0, time/target_t[-1]))
                    motion = multiply(initial, sample(src_t, src_q, src_t[-1]*fraction))
                    aligned = multiply(multiply(basis, motion), inverse(basis))
                    # Begin and end in the original pose; preserve the zombie's style.
                    blend = 0.5 * math.sin(math.pi*fraction)
                    output.append(normalize(multiply(base_q, slerp(IDENTITY, aligned, blend))))
                sampler['output'] = add_quaternions(doc, blob, output)
            doc['animations'].append(clip)
        path.write_bytes(encode(doc, blob))
        print(path.name, 'added hit_chest and hit_head')


if __name__ == '__main__':
    main()
