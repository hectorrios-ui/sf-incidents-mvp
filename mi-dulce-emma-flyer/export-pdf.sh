#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

node generate-assets.js

HTML_FILE="$DIR/flyer.html"
PDF_FILE="$DIR/Mi-Dulce-Emma-Flyer.pdf"

google-chrome \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --print-to-pdf="$PDF_FILE" \
  --print-to-pdf-no-header \
  --no-pdf-header-footer \
  "file://$HTML_FILE"

echo "PDF generado: $PDF_FILE"
