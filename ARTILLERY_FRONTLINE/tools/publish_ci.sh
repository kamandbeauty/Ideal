#!/usr/bin/env bash
set -euo pipefail
MESSAGE="$1"; shift
BRANCH="${GITHUB_REF_NAME:-arena/40ad7d87-ideal}"
if [ "$BRANCH" != "arena/40ad7d87-ideal" ]; then echo 'Refusing to publish outside the active Arena session branch'; exit 1; fi
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -f -- "$@"
if git diff --cached --quiet; then exit 0; fi
git commit -m "$MESSAGE"
for attempt in 1 2 3 4 5; do
  git pull --rebase --autostash origin "$BRANCH"
  if git push origin "HEAD:$BRANCH"; then exit 0; fi
  sleep "$((attempt * 3))"
done
exit 1
