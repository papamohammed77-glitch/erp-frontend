#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$SCRIPT_DIR/dist"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Publish only browser-facing CountFlow pages and Pages headers.
# Deliberately exclude database/, functions/, tests/, docs, and source artifacts.
cp "$SCRIPT_DIR/index.html" \
   "$SCRIPT_DIR/countflow-admin.html" \
   "$SCRIPT_DIR/countflow.html" \
   "$SCRIPT_DIR/Countflow-supervisor.html" \
   "$SCRIPT_DIR/countflow-core.js" \
   "$SCRIPT_DIR/countflow-sw.js" \
   "$SCRIPT_DIR/manifest.webmanifest" \
   "$SCRIPT_DIR/countflow-icon.svg" \
   "$SCRIPT_DIR/_headers" \
   "$OUT_DIR/"

for file in index.html countflow-admin.html countflow.html Countflow-supervisor.html countflow-core.js countflow-sw.js manifest.webmanifest countflow-icon.svg _headers; do
  test -s "$OUT_DIR/$file"
done

if find "$OUT_DIR" -type f | grep -E '/(database|functions|tests)/|\.sql$|\.md$|\.ts$'; then
  echo "Unexpected non-public source artifact in Pages output" >&2
  exit 1
fi

echo "CountFlow Pages output prepared: $OUT_DIR"
find "$OUT_DIR" -maxdepth 1 -type f -print | sed 's#.*/##' | sort
