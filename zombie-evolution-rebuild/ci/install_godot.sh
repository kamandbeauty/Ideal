#!/usr/bin/env bash
# Official release assets and checksums; requires network access on the runner.
set -euo pipefail
version=4.4.1-stable
base="https://github.com/godotengine/godot-builds/releases/download/$version"
asset="Godot_v4.4.1-stable_linux.x86_64.zip"
dir="${RUNNER_TEMP:-/tmp}/godot-4.4.1"
mkdir -p "$dir"
cd "$dir"
curl -fL --retry 3 -o "$asset" "$base/$asset"
curl -fL --retry 3 -o SHA512-SUMS.txt "$base/SHA512-SUMS.txt"
awk -v name="$asset" '$2 == name || $2 == "*" name {print $1 "  " name; found++} END {if (found != 1) exit 1}' SHA512-SUMS.txt > editor.sha512
sha512sum --check editor.sha512
unzip -o "$asset" >/dev/null
chmod +x Godot_v4.4.1-stable_linux.x86_64
./Godot_v4.4.1-stable_linux.x86_64 --version
if [ -n "${GITHUB_PATH:-}" ]; then echo "$dir" >> "$GITHUB_PATH"; fi
