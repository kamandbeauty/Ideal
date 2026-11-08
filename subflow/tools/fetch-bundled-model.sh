#!/usr/bin/env bash
# Puts the Whisper model that ships *inside* the APK where Gradle can package it.
#
# The weights are 57 MB, so they are never committed: this script fetches them at
# build time (CI runs it before `flutter build apk`) and .gitignore keeps the file
# out of the repository. The mirror is tried when Hugging Face is unreachable.
set -euo pipefail

MODEL="${SUBFLOW_BUNDLED_MODEL:-ggml-base-q5_1.bin}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/android/app/src/main/assets/models"
TARGET="$DEST/$MODEL"
MIN_BYTES=$((20 * 1024 * 1024))

mkdir -p "$DEST"

is_valid() {
  [ -s "$1" ] || return 1
  [ "$(head -c 4 "$1")" = "ggml" ] || return 1
  [ "$(wc -c < "$1")" -ge "$MIN_BYTES" ] || return 1
  return 0
}

if is_valid "$TARGET"; then
  echo "bundled model already present: $TARGET ($(wc -c < "$TARGET") bytes)"
  exit 0
fi

URLS=(
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL"
  "https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/$MODEL"
)

for URL in "${URLS[@]}"; do
  echo "fetching $URL"
  if curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
      -o "$TARGET.part" "$URL"; then
    if is_valid "$TARGET.part"; then
      mv "$TARGET.part" "$TARGET"
      echo "bundled model ready: $TARGET ($(wc -c < "$TARGET") bytes)"
      exit 0
    fi
    echo "rejected $URL: not a valid ggml file" >&2
    rm -f "$TARGET.part"
  else
    echo "failed: $URL" >&2
    rm -f "$TARGET.part"
  fi
done

echo "could not fetch $MODEL from any source" >&2
exit 1
