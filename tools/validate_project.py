#!/usr/bin/env python3
import configparser, json, pathlib, re, sys
root=pathlib.Path(__file__).resolve().parents[1]
errors=[]
required=['project.godot','scenes/main.tscn','data/skins.json','data/release_config.json','docs/DATA_SAFETY.md','docs/PRIVACY_POLICY.md']
for p in required:
    if not (root/p).exists(): errors.append(f'missing: {p}')
config=(root/'project.godot').read_text()
presets=(root/'export_presets.cfg').read_text()
if 'textures/vram_compression/import_etc2_astc=true' not in config:
    errors.append('Android ETC2/ASTC texture import must be enabled')
for value in ['com.studiojavid.rubyrun','version/code=1','version/name="1.0.0"','gradle_build/target_sdk="36"']:
    if value not in presets: errors.append(f'export config missing {value}')
if presets.count('gradle_build/use_gradle_build=true') != 2:
    errors.append('release APK and AAB presets must use Gradle')
audited_files=[root/'project.godot', root/'export_presets.cfg'] + list((root/'scripts').rglob('*.gd'))
audited_text='\n'.join(p.read_text(errors='ignore') for p in audited_files)
for forbidden in ['android.permission.ACCESS_FINE_LOCATION','android.permission.READ_CONTACTS','android.permission.CAMERA','android.permission.RECORD_AUDIO']:
    if forbidden in audited_text: errors.append(f'forbidden permission: {forbidden}')
release=json.loads((root/'data/release_config.json').read_text())
if release['target_sdk'] != 36: errors.append('target_sdk mismatch')
skins=json.loads((root/'data/skins.json').read_text())['skins']
if len({s['id'] for s in skins}) != 5: errors.append('skins must have five unique ids')
if errors:
    print('\n'.join('ERROR: '+e for e in errors)); sys.exit(1)
print('Ruby Run static validation passed')
