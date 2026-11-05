#!/usr/bin/env python3
"""Write non-secret SDK paths to the versioned Godot editor preferences."""
import os, pathlib
home=pathlib.Path.home()
config=home/'.config/godot';config.mkdir(parents=True,exist_ok=True)
path=config/'editor_settings-4.7.tres'
text=path.read_text() if path.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
lines=[line for line in text.splitlines() if not line.startswith(('export/android/java_sdk_path','export/android/android_sdk_path'))]
lines += ['export/android/java_sdk_path = "%s"'%os.environ['JAVA_HOME'], 'export/android/android_sdk_path = "%s"'%os.environ.get('ANDROID_HOME',os.environ.get('ANDROID_SDK_ROOT',''))]
path.write_text('\n'.join(lines)+'\n')
print('Configured Java and Android SDK paths (no credentials written).')
