import json,struct,copy
from pathlib import Path
base=Path('ARTILLERY_FRONTLINE/assets/models/zombies')
def decode(p):
 b=p.read_bytes(); n=struct.unpack_from('<I',b,12)[0]; doc=json.loads(b[20:20+n]); off=20+n; length=struct.unpack_from('<I',b,off)[0]; return doc,bytearray(b[off+8:off+8+length])
def encode(doc,buf):
 doc['buffers'][0]['byteLength']=len(buf)
 j=json.dumps(doc,separators=(',',':')).encode(); j+=b' '*((-len(j))%4); buf+=b'\x00'*((-len(buf))%4)
 return b'glTF'+struct.pack('<II',2,12+8+len(j)+8+len(buf))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(buf),b'BIN\x00')+buf
src,sbuf=decode(base/'zombie_walker.glb')
for name in ['bloat','boomer','gibberling']:
 path=base/f'zombie_{name}.glb'; dst,dbuf=decode(path); dst['animations']=[a for a in dst['animations'] if a.get('name') not in ('walk_clean','run_clean')]; nodes={n.get('name'):i for i,n in enumerate(dst['nodes'])}; copied={}
 def accessor(i):
  if i in copied:return copied[i]
  a=copy.deepcopy(src['accessors'][i]); v=src['bufferViews'][a['bufferView']]; offset=v.get('byteOffset',0); n=v['byteLength']; dbuf.extend(b'\x00'*((-len(dbuf))%4)); vnew=copy.deepcopy(v); vnew['byteOffset']=len(dbuf); dbuf.extend(sbuf[offset:offset+n]); a['bufferView']=len(dst['bufferViews']); dst['bufferViews'].append(vnew); copied[i]=len(dst['accessors']); dst['accessors'].append(a); return copied[i]
 for a in src['animations']:
  if a.get('name') not in ('walk_clean','run_clean'):continue
  out=copy.deepcopy(a)
  for sampler in out['samplers']:sampler['input']=accessor(sampler['input']); sampler['output']=accessor(sampler['output'])
  for ch in out['channels']:ch['target']['node']=nodes[src['nodes'][ch['target']['node']]['name']]
  dst['animations'].append(out)
 path.write_bytes(encode(dst,dbuf)); print(name,len(dbuf))
