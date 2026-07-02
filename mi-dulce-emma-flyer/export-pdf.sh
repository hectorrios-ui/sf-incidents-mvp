#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -f assets/referencia.jpg ] || [ -f assets/referencia.png ] || [ -f assets/referencia.webp ]; then
  python3 extract-from-referencia.py
fi

node generate-assets.js
python3 export-pdf.py
