#!/usr/bin/env bash
# Commits CI outputs (test evidence, screenshots, the APK) back to the session
# branch so they can be reviewed without downloading workflow artifacts.
set -euo pipefail
MESSAGE="$1"; shift
SESSION_BRANCH="${SESSION_BRANCH:-arena/93ab6e29-ideal}"
BRANCH="${GITHUB_REF_NAME:-$SESSION_BRANCH}"
if [ "$BRANCH" != "$SESSION_BRANCH" ]; then echo 'Refusing to publish outside the session branch'; exit 1; fi
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -A -f -- "$@"
if git diff --cached --quiet; then exit 0; fi
git commit -m "$MESSAGE"
for attempt in 1 2 3 4 5; do
  git pull --rebase --autostash origin "$BRANCH"
  if git push origin "HEAD:$BRANCH"; then exit 0; fi
  sleep "$((attempt * 3))"
done
exit 1
