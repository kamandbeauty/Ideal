#!/usr/bin/env bash
# Generates the Flutter platform scaffolding that must NOT be hand-written
# (gradle wrapper jar, launcher icons, local.properties) without touching
# SubFlow's own Kotlin / C++ / resource files.
#
# Usage:  bash subflow/tools/bootstrap-android.sh
# Requires: flutter 3.22+ on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: 'flutter' is not on PATH. Install Flutter 3.22+ first." >&2
  exit 1
fi

echo "==> flutter pub get"
flutter pub get

SCAFFOLD="$(mktemp -d)"
trap 'rm -rf "$SCAFFOLD"' EXIT

echo "==> generating a throw-away scaffold to copy the wrapper from"
flutter create --platforms=android --org app.subflow --project-name subflow "$SCAFFOLD/scaffold" >/dev/null

echo "==> copying gradle wrapper"
cp "$SCAFFOLD/scaffold/android/gradlew" android/gradlew
cp "$SCAFFOLD/scaffold/android/gradlew.bat" android/gradlew.bat
chmod +x android/gradlew
mkdir -p android/gradle/wrapper
cp "$SCAFFOLD/scaffold/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/

echo "==> copying launcher icons (mipmap) if missing"
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  src="$SCAFFOLD/scaffold/android/app/src/main/res/mipmap-$density"
  dst="android/app/src/main/res/mipmap-$density"
  if [ -d "$src" ] && [ ! -d "$dst" ]; then
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
  fi
done

echo "==> writing android/local.properties"
FLUTTER_SDK="$(dirname "$(dirname "$(command -v flutter)")")"
cat > android/local.properties <<PROPS
flutter.sdk=$FLUTTER_SDK
sdk.dir=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}
PROPS

echo
echo "Done. SubFlow's Kotlin and CMake sources were not modified."
echo "Next:"
echo "  cd subflow && flutter run --release            # device or emulator"
echo "  cd subflow && flutter build apk --release      # ARM64 + x86_64"
