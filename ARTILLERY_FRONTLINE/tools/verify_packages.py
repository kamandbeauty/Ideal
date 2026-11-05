#!/usr/bin/env python3
"""Inspect actual ZIP contents; never infer Android validation from an export."""
import pathlib,sys,zipfile,hashlib,json
root=pathlib.Path(sys.argv[1]);report={}
for name in ['Artillery-Frontline-arm64.apk','Artillery-Frontline-arm64.aab','Artillery-Frontline-compatibility.apk']:
 p=root/name
 assert p.is_file() and p.stat().st_size>1000000, name
 with zipfile.ZipFile(p) as z:
  names=z.namelist()
  assert any(n.endswith('libgodot_android.so') and 'arm64-v8a' in n for n in names), 'ARM64 native engine missing'
  assert not any('armeabi-v7a' in n or 'x86_64' in n for n in names), 'Unexpected architecture'
  assert any(n.endswith('project.binary') for n in names), 'Project data missing'
  assert z.testzip() is None, 'ZIP CRC failure'
 report[name]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'arm64':True,'zip_crc':'pass'}
metadata=(root/'package-metadata.txt').read_text()
assert 'com.frontline.artillery' in metadata
assert 'android.permission.INTERNET' not in metadata, 'Offline build requests INTERNET'
assert 'screenOrientation' in metadata or 'landscape' in metadata, 'Inspect orientation in package metadata'
(root/'package-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
