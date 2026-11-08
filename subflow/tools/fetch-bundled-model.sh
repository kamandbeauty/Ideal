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

# ggml stores its magic as the uint32 0x67676d6c, which lands on disk as the bytes
# "lmgg" on little-endian writers (the string "ggml" is the big-endian spelling).
# Both are accepted, plus the older container magics still found in the wild.
is_valid() {
  [ -s "$1" ] || return 1
  MAGIC=$(head -c 4 "$1" | od -An -tx1 | tr -d ' \n')
  case "$MAGIC" in
    67676d6c|6c6d6767|67676d66|666d6767|67676a74|746a6767|67677566|66756767) ;;
    *) return 1 ;;
  esac
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

# Every failure has to explain itself: the build log is not readable from
# automation, so the reason is printed on one line and republished as an
# annotation by the workflow.
for URL in "${URLS[@]}"; do
  echo "probing $URL"
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' -I -A "SubFlow-CI" \
    --connect-timeout 20 --max-time 60 "$URL" 2>&1) || CODE="curl-error"
  echo "probe result: $CODE"

  echo "fetching $URL"
  CURL_LOG="$(mktemp)"
  if curl -fL -A "SubFlow-CI" --retry 3 --retry-delay 2 --connect-timeout 20 \
      --max-time 900 -o "$TARGET.part" "$URL" 2>"$CURL_LOG"; then
    if is_valid "$TARGET.part"; then
      mv "$TARGET.part" "$TARGET"
      echo "bundled model ready: $TARGET ($(wc -c < "$TARGET") bytes)"
      rm -f "$CURL_LOG"
      exit 0
    fi
    echo "rejected $URL: downloaded $(wc -c < "$TARGET.part" 2>/dev/null || echo 0) bytes, not a valid ggml file" >&2
    head -c 120 "$TARGET.part" 2>/dev/null | tr -d '\0' | head -1 >&2 || true
    rm -f "$TARGET.part"
  else
    echo "curl failed: $(tail -3 "$CURL_LOG" | tr '\n' ' ')" >&2
    rm -f "$TARGET.part"
  fi
  rm -f "$CURL_LOG"
done

echo "could not fetch $MODEL from any source (probe=$CODE)" >&2
exit 1
