#!/usr/bin/env bash
# Validate every installed skill against the Agent Skills specification.
# Requires: python3 -m pip install -r requirements-dev.txt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT/.agents/skills"

# The reference library exposes its CLI as `skills-ref` (source build) or
# `agentskills` (PyPI release), so invoke the module directly instead of
# relying on the console-script name.
if [ -x "$ROOT/.venv/bin/python" ] && "$ROOT/.venv/bin/python" -c 'import skills_ref' 2>/dev/null; then
  VALIDATE=("$ROOT/.venv/bin/python" -m skills_ref.cli validate)
elif python3 -c 'import skills_ref' 2>/dev/null; then
  VALIDATE=(python3 -m skills_ref.cli validate)
elif command -v skills-ref >/dev/null 2>&1; then
  VALIDATE=(skills-ref validate)
elif command -v agentskills >/dev/null 2>&1; then
  VALIDATE=(agentskills validate)
else
  echo "skills-ref is missing. Install it with:" >&2
  echo "  python3 -m pip install -r requirements-dev.txt" >&2
  exit 1
fi

status=0
found=0
for skill in "$SKILLS_DIR"/*; do
  [ -d "$skill" ] || continue
  found=1
  "${VALIDATE[@]}" "$skill" || status=1
done

if [ "$found" -eq 0 ]; then
  echo "No skills found in $SKILLS_DIR" >&2
  exit 1
fi
exit "$status"
