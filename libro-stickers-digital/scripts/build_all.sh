#!/usr/bin/env bash
# Pipeline completo: SVG -> PNG -> DOCX (con fuentes embebidas) -> PDF
set -e
cd "$(dirname "$0")/.."

echo "==> 1/4  Generando ilustraciones SVG..."
python3 scripts/illustrations.py

echo "==> 2/4  Renderizando SVG a PNG de alta resolución..."
python3 - <<'PY'
import cairosvg, glob, os
os.makedirs("assets/png", exist_ok=True)
for f in sorted(glob.glob("assets/svg/*.svg")):
    out = "assets/png/" + os.path.basename(f)[:-4] + ".png"
    cairosvg.svg2png(url=f, write_to=out, output_width=1700, background_color=None)
print("PNG listos.")
PY

echo "==> 3/4  Construyendo el documento Word..."
python3 scripts/build_docx.py

echo "==> 3.5  Embebiendo fuentes en el .docx..."
python3 scripts/embed_fonts.py

echo "==> 4/4  Exportando PDF de cortesía (requiere LibreOffice)..."
if command -v soffice >/dev/null 2>&1; then
  soffice --headless --convert-to pdf --outdir . \
    Libro_Actividades_Stickers_Mi_Dulce_Emma.docx >/dev/null 2>&1
  echo "PDF generado."
else
  echo "LibreOffice no encontrado; se omite el PDF (el DOCX ya está listo)."
fi

echo "Listo. Revisa Libro_Actividades_Stickers_Mi_Dulce_Emma.docx"
