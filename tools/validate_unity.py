#!/usr/bin/env python3
import json, pathlib, re, sys
root=pathlib.Path(__file__).resolve().parents[1]
errors=[]
required=['Packages/manifest.json','ProjectSettings/ProjectVersion.txt','Assets/Scenes/Bootstrap.unity','Assets/Scripts/Core/GameBootstrap.cs','Assets/Scripts/Core/GameManager.cs','docs/DATA_SAFETY.md','docs/PRIVACY_POLICY.md']
for item in required:
    if not (root/item).exists(): errors.append('missing '+item)
manifest=json.loads((root/'Packages/manifest.json').read_text())
for package in ['com.unity.render-pipelines.universal','com.unity.inputsystem','com.unity.cinemachine']:
    if package not in manifest['dependencies']: errors.append('missing package '+package)
settings=(root/'ProjectSettings/ProjectSettings.asset').read_text()
for value in ['com.studiojavid.rubyrun','AndroidTargetSdkVersion: 36','AndroidTargetArchitectures: 2']:
    if value not in settings: errors.append('Android setting missing '+value)
audited=[root/'ProjectSettings/ProjectSettings.asset', root/'Packages/manifest.json']+list((root/'Assets').rglob('*.cs'))
all_text='\n'.join(p.read_text(errors='ignore') for p in audited)
for forbidden in ['com.javidsstudio.rubyrun','android.permission.READ_CONTACTS','android.permission.ACCESS_FINE_LOCATION','ca-app-pub-']:
    if forbidden in all_text: errors.append('forbidden value found: '+forbidden)
cs_files=list((root/'Assets').rglob('*.cs'))
if len(cs_files)<20: errors.append('expected production system split across at least 20 C# files')
for path in cs_files:
    text=path.read_text()
    if text.count('{')!=text.count('}'): errors.append(f'brace mismatch: {path.relative_to(root)}')
if errors:
    print('\n'.join('ERROR: '+error for error in errors));sys.exit(1)
print(f'Ruby Run 3D static validation passed ({len(cs_files)} C# files)')
