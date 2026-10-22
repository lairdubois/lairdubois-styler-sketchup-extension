#!/usr/bin/env bash
#
# Packages the Styler extension into an installable .rbz.
#
# Usage: ./build.sh
# Output: dist/ladb_styler-<version>.rbz

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/src"
DIST="$HERE/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Version comes from the registrar, so there is a single source of truth
VERSION="$(sed -n "s/.*ex\.version *= *'\([^']*\)'.*/\1/p" "$SRC/ladb_styler.rb")"
[ -n "$VERSION" ] || { echo "Could not read ex.version from ladb_styler.rb" >&2; exit 1; }

RBZ="$DIST/ladb_styler-$VERSION.rbz"

# ----- Payload

cp "$SRC/ladb_styler.rb" "$STAGE/"
cp -R "$SRC/ladb_styler" "$STAGE/"
cp "$HERE/LICENSE" "$STAGE/ladb_styler/"
find "$STAGE" -name '.DS_Store' -delete

# ----- Archive

mkdir -p "$DIST"
rm -f "$RBZ"
( cd "$STAGE" && zip -q -r -X "$RBZ" ladb_styler.rb ladb_styler )

echo "Built $RBZ"
unzip -l "$RBZ" | sed '1,3d;$d'
