#!/usr/bin/env bash
# Executes against an already-booted Android emulator. No network access is needed by the app.
set -Eeuo pipefail
trap 'status=$?; echo "::error title=Android smoke failed::Line $LINENO exited with status $status"; exit "$status"' ERR
apk=${1:?usage: android_smoke.sh path/to/x86_64.apk}
adb wait-for-device
adb logcat -c
adb shell wm size 1280x720
adb shell wm density 160
adb install -r "$apk"
adb shell am start -n com.artilleryfrontline.game/com.godot.game.GodotAppLauncher
# First launch compiles shaders on the software GPU; give it time to become interactive.
sleep 20
pid=$(adb shell pidof com.artilleryfrontline.game | tr -d '\r')
test -n "$pid"
mkdir -p build
adb exec-out screencap -p > build/android-menu.png
read -r width height < <(python3 - <<'PY'
import struct
with open('build/android-menu.png', 'rb') as f:
    assert f.read(8) == b'\x89PNG\r\n\x1a\n'
    f.read(8)
    print(*struct.unpack('>II', f.read(8)))
PY
)
if [ "$width" -le "$height" ]; then
  echo "Expected landscape output, got ${width}x${height}" >&2
  exit 1
fi
# Coordinates are relative to the screenshot, so the test works with either landscape rotation.
# Open the bundled license screen, then return to the menu before deploying.
adb shell input tap "$((width * 39 / 100))" "$((height * 89 / 100))"
sleep 2
adb exec-out screencap -p > build/android-licenses.png
adb shell input tap "$((width * 50 / 100))" "$((height * 84 / 100))"
sleep 2
adb shell input tap "$((width * 17 / 100))" "$((height * 80 / 100))"
sleep 3
adb shell input swipe "$((width * 50 / 100))" "$((height * 42 / 100))" "$((width * 54 / 100))" "$((height * 42 / 100))" 300
adb shell input tap "$((width * 90 / 100))" "$((height * 84 / 100))"
sleep 2
adb shell input tap "$((width * 71 / 100))" "$((height * 90 / 100))"
sleep 5
adb exec-out screencap -p > build/android-gameplay.png
if cmp -s build/android-menu.png build/android-gameplay.png; then
  echo "Screen did not change after touch input" >&2
  exit 1
fi
adb shell pidof com.artilleryfrontline.game >/dev/null
adb logcat -d > build/android-logcat.txt
if grep -E 'FATAL EXCEPTION|SCRIPT ERROR' build/android-logcat.txt; then
  echo "Android runtime reported a fatal or GDScript error" >&2
  exit 1
fi
echo "::notice title=Android emulator smoke::Installed and launched; landscape ${width}x${height}; touch actions sent; process alive"
