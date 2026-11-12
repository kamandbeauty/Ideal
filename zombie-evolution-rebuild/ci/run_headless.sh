#!/usr/bin/env bash
# Run every existing engine test, retain logs, and fail on errors or timeouts.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$ROOT/zombie-evolution-rebuild"
cd "$ROOT"
LOG_DIR="${LOG_DIR:-$ROOT/ci-artifacts/headless}"
GODOT="${GODOT:-godot}"
mkdir -p "$LOG_DIR" "$LOG_DIR/user-data"
export XDG_DATA_HOME="$LOG_DIR/user-data"
passed=0
failed=0
warnings=0
run() {
    local name="$1"; shift
    echo "RUN $name: $*"
    timeout 180 "$@" >"$LOG_DIR/$name.log" 2>&1
    local code=$?
    cat "$LOG_DIR/$name.log"
    local warning_count
    warning_count=$(grep -Eic '(^|[[:space:]])WARNING:' "$LOG_DIR/$name.log" || true)
    warnings=$((warnings + warning_count))
    if [ "$code" -eq 0 ] && ! grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR|FAIL):' "$LOG_DIR/$name.log"; then
        passed=$((passed + 1))
        echo "PASS $name exit=$code warnings=$warning_count"
    else
        failed=$((failed + 1))
        echo "FAIL $name exit=$code warnings=$warning_count"
    fi
}
if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "FAIL dependency: Godot binary not found: $GODOT" | tee "$LOG_DIR/dependency.log"
    exit 1
fi
run godot_version "$GODOT" --version
# Preserve and authenticate the historical baseline while checking every current
# project file against the separately maintained post-fix manifest.
run manifest bash -c 'echo "91eb09119c7c8b26b5387d9dacf2720aa481de028ef263be4eff2e97db971280  $1/SOURCE_MANIFEST.sha256" | sha256sum -c - && sha256sum -c "$1/CURRENT_MANIFEST.sha256"' _ "$PROJECT"
run export_config python3 "$PROJECT/tests/export_config_test.py"
run import "$GODOT" --headless --editor --path "$PROJECT" --quit
run launcher "$GODOT" --headless --path "$PROJECT" --quit-after 5
run level_load "$GODOT" --headless --path "$PROJECT" res://scenes/level/sky_bridge.tscn --fixed-fps 60 --quit-after 240
for test in preferences_test level_test launcher_and_controls_test persian_ui_test autoplay_test imported_gate_edge_test visual_assets_test effects_test; do
    run "$test" "$GODOT" --headless --path "$PROJECT" --fixed-fps 60 --script "res://tests/$test.gd"
done
printf 'Checks passed=%d failed=%d warnings=%d\n' "$passed" "$failed" "$warnings" | tee "$LOG_DIR/summary.txt"
[ "$failed" -eq 0 ]
