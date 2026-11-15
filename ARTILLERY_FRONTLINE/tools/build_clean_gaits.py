#!/usr/bin/env python3
"""Add the generated even-legged walk/run to existing zombie GLBs in-place.

Preserves meshes, textures and the retargeted hit reactions. Requires numpy and
pillow. The same gait definitions are also exported by build_zombies.py.
"""
import numpy as np
from build_zombies import SPECS, Sculpt, Animator, clips
from retarget_hits import PROJECT, decode, encode


def add_accessor(doc, blob, values, width):
    while len(blob) % 4:
        blob.append(0)
    values = np.asarray(values, dtype='<f4').reshape(-1, width)
    raw = values.tobytes()
    view = len(doc['bufferViews'])
    doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(raw)})
    blob.extend(raw)
    index = len(doc['accessors'])
    item = {'bufferView': view, 'componentType': 5126, 'count': len(values),
            'type': {1: 'SCALAR', 3: 'VEC3', 4: 'VEC4'}[width]}
    if width == 1:
        item['min'] = [float(values.min())]
        item['max'] = [float(values.max())]
    doc['accessors'].append(item)
    return index


def main():
    for kind, spec in SPECS.items():
        path = PROJECT / 'assets/models/zombies' / ('zombie_' + kind + '.glb')
        doc, blob = decode(path.read_bytes())
        sculpt = Sculpt(spec)
        animator = Animator(sculpt)
        nodes = {n.get('name'): i for i, n in enumerate(doc['nodes'])}
        doc['animations'] = [a for a in doc['animations'] if a['name'] not in ('walk_clean', 'run_clean')]
        for name in ('walk_clean', 'run_clean'):
            pose, duration, loop = clips(sculpt)[name]
            times, rotations, hips = animator.bake(pose, duration, 24, loop)
            time = add_accessor(doc, blob, times, 1)
            anim = {'name': name, 'channels': [], 'samplers': []}
            tracks = [('Hips', 'translation', hips * spec['scale'], 3)]
            tracks += [(bone, 'rotation', keys, 4) for bone, keys in rotations.items() if bone != 'Root']
            for bone, prop, keys, width in tracks:
                sampler = len(anim['samplers'])
                anim['samplers'].append({'input': time, 'output': add_accessor(doc, blob, keys, width), 'interpolation': 'LINEAR'})
                anim['channels'].append({'sampler': sampler, 'target': {'node': nodes[bone], 'path': prop}})
            doc['animations'].append(anim)
        path.write_bytes(encode(doc, blob))
        print(path.name, 'added walk_clean and run_clean')


if __name__ == '__main__':
    main()
