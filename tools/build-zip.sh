#!/usr/bin/env bash
#
# Build an installable WordPress plugin ZIP.
#
#   ./tools/build-zip.sh          -> dist/custom-product-designer-<version>.zip
#
# The folder inside the ZIP is named custom-product-designer, not
# tshirt-designer: the plugin derives every path from plugin_dir_path()/
# plugin_basename(), so the directory name is free, and the product is no
# longer T-shirt specific.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/tshirt-designer"
SLUG="custom-product-designer"

VERSION="$(grep -oP "define\(\s*'TD_VERSION',\s*'\K[^']+" "$SRC/tshirt-designer.php")"
[ -n "$VERSION" ] || { echo "could not read TD_VERSION" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -r "$SRC" "$STAGE/$SLUG"

# Development-only material must never reach a live site.
rm -rf "$STAGE/$SLUG/tests"
find "$STAGE/$SLUG" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
find "$STAGE/$SLUG" \( -name '*.map' -o -name '.DS_Store' -o -name 'Thumbs.db' -o -name '*.swp' \) -delete 2>/dev/null || true

mkdir -p "$REPO/dist"
OUT="$REPO/dist/$SLUG-$VERSION.zip"
rm -f "$OUT"
( cd "$STAGE" && zip -rq "$OUT" "$SLUG" )

# A broken archive is worse than no archive.
unzip -tq "$OUT" >/dev/null

# List once. Piping `unzip -l` straight into `grep -q` makes grep exit at the
# first match, and the resulting SIGPIPE trips `set -o pipefail`, so the guard
# failed on a perfectly good archive.
LIST="$(unzip -l "$OUT")"

check_present() {
  case "$LIST" in
    *"$1"*) : ;;
    *) echo "missing from the archive: $1" >&2; exit 1 ;;
  esac
}
check_present "$SLUG/tshirt-designer.php"
check_present "$SLUG/readme.txt"
check_present "$SLUG/uninstall.php"
check_present "$SLUG/assets/models/classic-tshirt.glb"
check_present "$SLUG/assets/models/classic-tote.glb"
check_present "$SLUG/languages/tshirt-designer-fa_IR.mo"

case "$LIST" in
  *"$SLUG/tests/"*) echo "tests leaked into the archive" >&2; exit 1 ;;
esac

echo "built $OUT"
du -h "$OUT" | cut -f1
