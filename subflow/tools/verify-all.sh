#!/usr/bin/env bash
# Everything that can be verified without an Android device or the Flutter SDK.
# Run from the repository root:  bash subflow/tools/verify-all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
status=0

step() {
  printf '\n=== %s ===\n' "$1"
}

step "native core unit tests (g++, 124 checks)"
make -C tools/native-core test || status=1

step "native core under ASan + UBSan"
make -C tools/native-core test-asan || status=1

step "JNI bridge syntax check against a stub jni.h"
make -C tools/native-core check-jni || status=1

step "SQLite schema: migrations, constraints, cascades, v1->v2 upgrade"
python3 tools/check_schema.py || status=1

step "source tree consistency (imports, assets, channel parity, JNI symbols)"
python3 tools/check-project.py || status=1

printf '\n=== summary ===\n'
if [ "$status" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "SOME CHECKS FAILED"
fi
exit "$status"
