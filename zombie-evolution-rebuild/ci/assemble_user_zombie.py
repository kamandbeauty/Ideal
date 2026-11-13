#!/usr/bin/env python3
"""Combine separately converted user FBX animations into one GLB.

Usage: python assemble_user_zombie.py /path/to/converted-glbs texture.png output.glb
Inputs named zombie@{walk,idle1,run,atack1,gethit,death1}.fbx.glb are
produced from the matching source FBX with assimpjs glb2. Requires no source
archives in the repository. Fails if channels cannot be mapped by unique name.
"""
import copy
import json
import struct
import sys
from pathlib import Path

source, texture, output = map(Path, sys.argv[1:])
clips = {'walk': 'Walk', 'idle1': 'Idle', 'run': 'Run', 'atack1': 'Attack', 'gethit': 'Hit', 'death1': 'Death'}

def read_glb(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from('<III', data)
    if magic != 0x46546c67 or version != 2 or size != len(data):
        raise ValueError(f'Invalid GLB: {path}')
    json_size, json_type = struct.unpack_from('<II', data, 12)
    if json_type != 0x4e4f534a:
        raise ValueError('Missing JSON chunk')
    document = json.loads(data[20:20 + json_size])
    n, kind = struct.unpack_from('<II', data, 20 + json_size)
    if kind != 0x004e4942:
        raise ValueError('Missing binary chunk')
    return document, bytearray(data[28 + json_size:28 + json_size + n])

base, binary = read_glb(source / 'zombie@walk.fbx.glb')
node_names = [node.get('name') for node in base['nodes']]
if len(node_names) != len(set(node_names)):
    raise ValueError('Duplicate node names cannot be mapped safely')
node_map = {name: i for i, name in enumerate(node_names)}
base['animations'] = []
for file_name, clip_name in clips.items():
    doc, blob = read_glb(source / f'zombie@{file_name}.fbx.glb')
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    binary.extend(blob)
    view_offset = len(base['bufferViews'])
    accessor_offset = len(base['accessors'])
    for view in doc['bufferViews']:
        view = copy.deepcopy(view)
        if view.get('buffer', 0) != 0:
            raise ValueError('Unexpected additional buffer')
        view['byteOffset'] = view.get('byteOffset', 0) + offset
        base['bufferViews'].append(view)
    for accessor in doc['accessors']:
        accessor = copy.deepcopy(accessor)
        if 'sparse' in accessor:
            raise ValueError('Sparse accessors are not supported')
        if 'bufferView' in accessor:
            accessor['bufferView'] += view_offset
        base['accessors'].append(accessor)
    if len(doc['animations']) != 1:
        raise ValueError(f'Expected one clip: {file_name}')
    anim = copy.deepcopy(doc['animations'][0])
    anim['name'] = clip_name
    for sampler in anim['samplers']:
        sampler['input'] += accessor_offset
        sampler['output'] += accessor_offset
    for channel in anim['channels']:
        target = channel['target']['node']
        name = doc['nodes'][target].get('name')
        if name not in node_map:
            raise ValueError(f'Animation target not in base model: {name}')
        channel['target']['node'] = node_map[name]
    base['animations'].append(anim)

# One supplied albedo atlas; preserve the other FBX materials for eyes/details.
while len(binary) % 4:
    binary.append(0)
image = texture.read_bytes()
base['bufferViews'].append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(image)})
binary.extend(image)
base['images'] = [{'name': 'UserZombieAlbedo', 'bufferView': len(base['bufferViews']) - 1, 'mimeType': 'image/png'}]
base['textures'] = [{'source': 0}]
base['materials'][0]['pbrMetallicRoughness']['baseColorFactor'] = [1, 1, 1, 1]
base['materials'][0]['pbrMetallicRoughness']['baseColorTexture'] = {'index': 0}
base['materials'][0]['pbrMetallicRoughness']['roughnessFactor'] = 0.9
base['buffers'][0]['byteLength'] = len(binary)
while len(binary) % 4:
    binary.append(0)
encoded = json.dumps(base, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
length = 12 + 8 + len(encoded) + 8 + len(binary)
output.write_bytes(struct.pack('<III', 0x46546c67, 2, length) + struct.pack('<II', len(encoded), 0x4e4f534a) + encoded + struct.pack('<II', len(binary), 0x004e4942) + binary)
print('Wrote', output, 'bytes', length, 'clips', ', '.join(clips.values()))
