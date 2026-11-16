#!/usr/bin/env python3
"""Prepare the CC0 city zombie GLB for Godot (see documentation/CITY-ZOMBIE.md).

Usage: python tools/prepare_city_zombie.py /path/to/upstream-zombie.glb
The model's original centimetre-space skeleton is converted to metres so that
bone-attached collision shapes have the same units as the rest of the game.
"""
import copy
import json
import struct
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_bytes()
magic, version, _ = struct.unpack_from('<4sII', source)
assert (magic, version) == (b'glTF', 2)
json_len, json_type = struct.unpack_from('<I4s', source, 12)
assert json_type == b'JSON'
doc = json.loads(source[20:20 + json_len])
bin_start = 20 + json_len
bin_len, bin_type = struct.unpack_from('<I4s', source, bin_start)
assert bin_type == b'BIN\0'
buf = bytearray(source[bin_start + 8:bin_start + 8 + bin_len])

# Drop extra animations from the derivative (those have a different licence).
original = {a['name']: a for a in doc['animations'][:8]}
doc['animations'] = [original[k] for k in ('walk', 'idle', 'attack', 'hit', 'run', 'die')]
for src, dst in [('walk', 'walk_clean'), ('run', 'run_clean'), ('die', 'death_back'), ('die', 'death_front')]:
    clip = copy.deepcopy(original[src])
    clip['name'] = dst
    doc['animations'].append(clip)

# Keep only the 2,404-triangle LOD, one mesh and one skin per zombie.
doc['nodes'][0]['children'] = [2, 3]
doc['nodes'][0]['scale'] = [1, 1, 1]
doc['nodes'][2]['mesh'] = 2
doc['nodes'][2]['skin'] = 2
for n in doc['nodes']:
    if 'translation' in n:
        n['translation'] = [v * 0.01 for v in n['translation']]
    n.pop('extras', None)

# POSITION, inverse bind translation and animated hip translations are all in cm.
indices = {doc['meshes'][2]['primitives'][0]['attributes']['POSITION']}
translations = set()
for a in doc['animations']:
    for c in a['channels']:
        if c['target']['path'] == 'translation':
            translations.add(a['samplers'][c['sampler']]['output'])
indices |= translations
inverse = doc['skins'][2]['inverseBindMatrices']
for index in indices | {inverse}:
    acc = doc['accessors'][index]
    assert acc['componentType'] == 5126 and acc['type'] in ('VEC3', 'MAT4')
    view = doc['bufferViews'][acc['bufferView']]
    count = 3 if acc['type'] == 'VEC3' else 16
    stride = view.get('byteStride', count * 4)
    start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
    for i in range(acc['count']):
        off = start + i * stride
        values = list(struct.unpack_from('<%df' % count, buf, off))
        for c in (range(3) if count == 3 else (12, 13, 14)):
            values[c] *= 0.01
        struct.pack_into('<%df' % count, buf, off, *values)
    if count == 3:
        for key in ('min', 'max'):
            if key in acc:
                acc[key] = [v * 0.01 for v in acc[key]]

raw = json.dumps(doc, separators=(',', ':')).encode()
raw += b' ' * (-len(raw) % 4)
buf += b'\0' * (-len(buf) % 4)
out = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(raw) + 8 + len(buf))
out += struct.pack('<I4s', len(raw), b'JSON') + raw + struct.pack('<I4s', len(buf), b'BIN\0') + buf
path = Path(__file__).resolve().parent.parent / 'assets/models/zombies/zombie_city.glb'
path.write_bytes(out)
print(path, len(out))
