from __future__ import annotations

import argparse
from pathlib import Path

import fitz
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph


PAGE_SIZE = letter
PAGE_W, PAGE_H = PAGE_SIZE
SOURCE_DEFAULT = Path(
    "/home/ubuntu/.cursor/projects/workspace/uploads/Documento_2026-06-03_225033_dd51.pdf"
)

PALETTE = {
    "blue": colors.HexColor("#00A7E1"),
    "green": colors.HexColor("#21B573"),
    "yellow": colors.HexColor("#FFE45E"),
    "pink": colors.HexColor("#EF476F"),
    "brown": colors.HexColor("#7A4E2D"),
    "ink": colors.HexColor("#24323F"),
    "muted": colors.HexColor("#52616B"),
    "paper": colors.HexColor("#FFFDF7"),
    "cream": colors.HexColor("#FFF4D6"),
    "mint": colors.HexColor("#E8F8EF"),
    "sky": colors.HexColor("#E8F6FC"),
    "rose": colors.HexColor("#FFEAF0"),
}


def register_fonts() -> tuple[str, str, str]:
    fonts = {
        "NotoSans": "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
        "NotoSans-Bold": "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
        "NotoSans-Italic": "/usr/share/fonts/truetype/noto/NotoSans-Italic.ttf",
    }
    for name, path in fonts.items():
        if Path(path).exists():
            pdfmetrics.registerFont(TTFont(name, path))
    return "NotoSans", "NotoSans-Bold", "NotoSans-Italic"


FONT_REGULAR, FONT_BOLD, FONT_ITALIC = register_fonts()


def ensure_dirs(base_dir: Path) -> dict[str, Path]:
    paths = {
        "source": base_dir / "source_pages",
        "cleaned": base_dir / "cleaned_pages",
        "assets": base_dir / "assets",
        "output": base_dir / "output",
    }
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    return paths


def render_pdf_pages(source_pdf: Path, output_dir: Path, scale: float = 2.0) -> list[Path]:
    doc = fitz.open(source_pdf)
    image_paths: list[Path] = []
    for page_number, page in enumerate(doc, start=1):
        pix = page.get_pixmap(matrix=fitz.Matrix(scale, scale), alpha=False)
        image_path = output_dir / f"page_{page_number:02d}.png"
        pix.save(image_path)
        image_paths.append(image_path)
    return image_paths


def clean_page_image(source_path: Path, target_path: Path) -> None:
    image = Image.open(source_path).convert("RGB")
    image = ImageOps.autocontrast(image, cutoff=1)

    arr = np.asarray(image).astype(np.uint8)
    bright_mask = (arr[:, :, 0] > 224) & (arr[:, :, 1] > 224) & (arr[:, :, 2] > 224)
    arr[bright_mask] = 255
    image = Image.fromarray(arr, "RGB")

    image = ImageEnhance.Color(image).enhance(1.08)
    image = ImageEnhance.Contrast(image).enhance(1.14)
    image = ImageEnhance.Sharpness(image).enhance(1.25)
    image = image.filter(ImageFilter.MedianFilter(size=3))
    image.save(target_path, quality=95, dpi=(300, 300))


def create_clean_pdf(cleaned_paths: list[Path], target_pdf: Path) -> None:
    c = canvas.Canvas(str(target_pdf), pagesize=PAGE_SIZE)
    c.setTitle("Libro de actividades con stickers de colores - limpio")
    for path in cleaned_paths:
        c.drawImage(str(path), 0, 0, width=PAGE_W, height=PAGE_H, preserveAspectRatio=True, anchor="c")
        c.showPage()
    c.save()


def crop_brand_asset(page_three: Path, target_path: Path) -> None:
    image = Image.open(page_three).convert("RGB")
    # Crop the illustration and existing brand lockup from the scanned intro page.
    crop = image.crop((300, 320, 935, 980))
    crop = ImageOps.autocontrast(crop, cutoff=1)
    arr = np.asarray(crop).astype(np.uint8)
    bright_mask = (arr[:, :, 0] > 230) & (arr[:, :, 1] > 230) & (arr[:, :, 2] > 230)
    arr[bright_mask] = 255
    top_band = arr[:80, :, :]
    leftover_marker_mask = (top_band[:, :, 0] > 150) & (top_band[:, :, 1] < 130) & (top_band[:, :, 2] < 150)
    top_band[leftover_marker_mask] = 255
    arr[:95, :85, :] = 255
    arr[:95, -85:, :] = 255
    crop = Image.fromarray(arr, "RGB")
    crop.save(target_path, quality=95)


def paragraph(
    text: str,
    size: float = 12,
    leading: float | None = None,
    color: colors.Color = PALETTE["ink"],
    font: str = FONT_REGULAR,
    alignment: int = TA_LEFT,
) -> Paragraph:
    return Paragraph(
        text,
        ParagraphStyle(
            name=f"style-{size}-{font}",
            fontName=font,
            fontSize=size,
            leading=leading or size * 1.35,
            textColor=color,
            alignment=alignment,
            spaceAfter=0,
        ),
    )


def draw_paragraph(
    c: canvas.Canvas,
    text: str,
    x: float,
    y_top: float,
    width: float,
    size: float = 12,
    leading: float | None = None,
    color: colors.Color = PALETTE["ink"],
    font: str = FONT_REGULAR,
    alignment: int = TA_LEFT,
) -> float:
    p = paragraph(text, size, leading, color, font, alignment)
    _, height = p.wrap(width, PAGE_H)
    p.drawOn(c, x, y_top - height)
    return height


def draw_background(c: canvas.Canvas) -> None:
    c.setFillColor(PALETTE["paper"])
    c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)

    c.setStrokeColor(colors.HexColor("#F2E9D8"))
    c.setLineWidth(1)
    c.roundRect(0.35 * inch, 0.35 * inch, PAGE_W - 0.7 * inch, PAGE_H - 0.7 * inch, 20, stroke=1, fill=0)


def draw_sticker_dot(c: canvas.Canvas, x: float, y: float, radius: float, fill: colors.Color) -> None:
    c.setFillColor(colors.Color(0, 0, 0, alpha=0.10))
    c.circle(x + 2, y - 2, radius, stroke=0, fill=1)
    c.setFillColor(fill)
    c.circle(x, y, radius, stroke=0, fill=1)
    c.setStrokeColor(colors.Color(1, 1, 1, alpha=0.75))
    c.setLineWidth(2)
    c.circle(x - radius * 0.25, y + radius * 0.22, radius * 0.35, stroke=1, fill=0)


def draw_confetti(c: canvas.Canvas) -> None:
    dots = [
        (65, 675, 23, PALETTE["yellow"]),
        (115, 118, 24, PALETTE["pink"]),
        (430, 714, 28, PALETTE["blue"]),
        (538, 641, 20, PALETTE["pink"]),
        (533, 95, 13, PALETTE["yellow"]),
        (76, 313, 13, PALETTE["blue"]),
        (545, 338, 24, PALETTE["yellow"]),
        (190, 720, 14, PALETTE["green"]),
        (311, 119, 19, PALETTE["green"]),
        (463, 708, 9, PALETTE["yellow"]),
        (490, 116, 8, PALETTE["brown"]),
    ]
    for x, y, radius, fill in dots:
        draw_sticker_dot(c, x, y, radius, fill)


def draw_multicolor_word(c: canvas.Canvas, word: str, x: float, y: float, size: float, palette: list[colors.Color]) -> None:
    c.setFont(FONT_BOLD, size)
    cursor = x
    for index, char in enumerate(word):
        c.setFillColor(palette[index % len(palette)])
        c.drawString(cursor, y, char)
        cursor += pdfmetrics.stringWidth(char, FONT_BOLD, size)


def draw_centered_title_line(c: canvas.Canvas, text: str, y: float, size: float, fill: colors.Color) -> None:
    c.setFont(FONT_BOLD, size)
    width = pdfmetrics.stringWidth(text, FONT_BOLD, size)
    c.setFillColor(fill)
    c.drawString((PAGE_W - width) / 2, y, text)


def draw_cover(c: canvas.Canvas) -> None:
    draw_background(c)
    draw_confetti(c)

    c.setFillColor(PALETTE["mint"])
    c.roundRect(1.05 * inch, 5.2 * inch, PAGE_W - 2.1 * inch, 2.55 * inch, 28, stroke=0, fill=1)

    draw_centered_title_line(c, "Libro de", 6.95 * inch, 45, PALETTE["ink"])
    draw_centered_title_line(c, "actividades", 6.22 * inch, 42, PALETTE["ink"])
    draw_centered_title_line(c, "con stickers", 5.55 * inch, 40, PALETTE["ink"])
    draw_centered_title_line(c, "de colores", 4.95 * inch, 36, PALETTE["ink"])

    c.setFillColor(PALETTE["yellow"])
    c.roundRect(2.0 * inch, 4.17 * inch, PAGE_W - 4.0 * inch, 0.46 * inch, 16, stroke=0, fill=1)
    draw_paragraph(
        c,
        "Actividades infantiles para aprender jugando",
        2.1 * inch,
        4.49 * inch,
        PAGE_W - 4.2 * inch,
        size=10.5,
        leading=13,
        font=FONT_BOLD,
        alignment=TA_CENTER,
    )

    draw_paragraph(
        c,
        "con amor",
        0,
        2.45 * inch,
        PAGE_W,
        size=12,
        color=PALETTE["muted"],
        font=FONT_ITALIC,
        alignment=TA_CENTER,
    )
    draw_paragraph(
        c,
        "@_mi_dulce_emma",
        0,
        2.18 * inch,
        PAGE_W,
        size=16,
        color=PALETTE["pink"],
        font=FONT_BOLD,
        alignment=TA_CENTER,
    )


def draw_welcome(c: canvas.Canvas) -> None:
    draw_background(c)
    draw_sticker_dot(c, 91, 707, 24, PALETTE["pink"])
    draw_sticker_dot(c, 548, 702, 22, PALETTE["green"])
    draw_multicolor_word(
        c,
        "Stickers",
        80,
        650,
        58,
        [PALETTE["pink"], PALETTE["blue"], PALETTE["yellow"], PALETTE["green"]],
    )

    intro = (
        "Bienvenidos al libro de actividades con stickers de colores para niños. "
        "Este material apoya el desarrollo integral y los mantiene alejados de las pantallas "
        "mientras aprenden."
    )
    c.setFillColor(PALETTE["sky"])
    c.roundRect(0.8 * inch, 7.42 * inch, PAGE_W - 1.6 * inch, 1.04 * inch, 18, stroke=0, fill=1)
    draw_paragraph(c, intro, 1.0 * inch, 8.22 * inch, PAGE_W - 2.0 * inch, size=12.5, leading=17)

    benefit = (
        "Al despegar y pegar stickers, ejercitan músculos clave de sus manos, "
        "mejoran su concentración y desarrollan su autonomía de forma divertida."
    )
    c.setFillColor(PALETTE["cream"])
    c.roundRect(0.8 * inch, 6.55 * inch, PAGE_W - 1.6 * inch, 0.72 * inch, 18, stroke=0, fill=1)
    draw_paragraph(c, benefit, 1.0 * inch, 7.08 * inch, PAGE_W - 2.0 * inch, size=11.5, leading=15.5)

    draw_paragraph(
        c,
        "Los niños trabajan:",
        0.86 * inch,
        6.12 * inch,
        PAGE_W - 1.72 * inch,
        size=17,
        font=FONT_BOLD,
        color=PALETTE["ink"],
    )

    items = [
        ("Motricidad fina", PALETTE["green"]),
        ("Coordinación óculo-manual", PALETTE["blue"]),
        ("Conciencia espacial", PALETTE["pink"]),
        ("Estimulación cognitiva", PALETTE["yellow"]),
        ("Asociación de colores", PALETTE["green"]),
        ("Trazos con stickers", PALETTE["blue"]),
        ("Fomento de la autonomía", PALETTE["pink"]),
    ]
    y = 5.72 * inch
    for label, color in items:
        c.setFillColor(colors.white)
        c.roundRect(1.02 * inch, y - 0.13 * inch, PAGE_W - 2.04 * inch, 0.32 * inch, 10, stroke=0, fill=1)
        draw_sticker_dot(c, 1.18 * inch, y + 0.02 * inch, 5.5, color)
        draw_paragraph(c, label, 1.35 * inch, y + 0.12 * inch, PAGE_W - 2.7 * inch, size=12, leading=14)
        y -= 0.42 * inch


def draw_about(c: canvas.Canvas, logo_path: Path) -> None:
    draw_background(c)
    draw_multicolor_word(
        c,
        "¡Hola!",
        118,
        680,
        58,
        [PALETTE["yellow"], PALETTE["pink"], PALETTE["green"], PALETTE["blue"]],
    )

    c.setFillColor(colors.white)
    c.roundRect(1.16 * inch, 5.52 * inch, PAGE_W - 2.32 * inch, 2.28 * inch, 24, stroke=0, fill=1)
    c.drawImage(
        str(logo_path),
        1.78 * inch,
        5.58 * inch,
        width=3.35 * inch,
        height=2.15 * inch,
        preserveAspectRatio=True,
        anchor="c",
        mask="auto",
    )

    c.setFillColor(PALETTE["rose"])
    c.roundRect(0.76 * inch, 1.17 * inch, PAGE_W - 1.52 * inch, 3.98 * inch, 22, stroke=0, fill=1)

    text = (
        "<b>Soy Andrea</b>, madre y economista creativa, con alma de maestra, apasionada por "
        "la estimulación temprana y fan de mi hija curiosa y amante de los animales.<br/><br/>"
        "Gracias por unirte y ser parte de esta linda comunidad de papitos y niños comprometidos "
        "en impulsar el desarrollo de sus peques por medio de diferentes actividades.<br/><br/>"
        "Estas son nuestras actividades favoritas de stickers. Espero que se diviertan mucho."
    )
    draw_paragraph(c, text, 1.05 * inch, 4.84 * inch, PAGE_W - 2.1 * inch, size=11.8, leading=15.8)

    draw_paragraph(
        c,
        "Con amor, @_mi_dulce_emma",
        0,
        0.78 * inch,
        PAGE_W,
        size=13,
        color=PALETTE["pink"],
        font=FONT_BOLD,
        alignment=TA_CENTER,
    )


def build_redesigned_pdf(target_pdf: Path, logo_path: Path) -> None:
    c = canvas.Canvas(str(target_pdf), pagesize=PAGE_SIZE)
    c.setTitle("Libro de actividades con stickers de colores - rediseñado")
    c.setAuthor("Mi dulce Emma")

    draw_cover(c)
    c.showPage()
    draw_welcome(c)
    c.showPage()
    draw_about(c, logo_path)
    c.save()


def write_readme(base_dir: Path) -> None:
    readme = base_dir / "README.md"
    readme.write_text(
        """# Rediseño inicial del libro de stickers

Esta carpeta contiene una primera optimización de las 3 páginas escaneadas.

## Archivos principales

- `output/libro_actividades_stickers_limpio.pdf`: versión limpiada del escaneo original, con fondo más blanco, mejor contraste y más nitidez.
- `output/libro_actividades_stickers_redisenado.pdf`: maqueta rediseñada con estilo más editorial/profesional.
- `cleaned_pages/`: imágenes limpias por página.
- `source_pages/`: páginas renderizadas desde el PDF original.
- `assets/mi_dulce_emma_logo.png`: recorte del logo/ilustración usado en la maqueta.

## Dirección visual aplicada

- Paleta alegre basada en los colores originales: rosado, azul, verde, amarillo y café.
- Tipografía sans-serif legible para padres, manteniendo un tono infantil con detalles tipo sticker.
- Jerarquía clara: portada, bienvenida/beneficios y presentación de la autora.
- Márgenes amplios y bloques redondeados para que el contenido respire.

Para regenerar los archivos:

```bash
python3 book_redesign/scripts/generate_book_redesign.py
```
""",
        encoding="utf-8",
    )


def generate(source_pdf: Path, base_dir: Path) -> None:
    paths = ensure_dirs(base_dir)
    source_pages = render_pdf_pages(source_pdf, paths["source"])

    cleaned_paths: list[Path] = []
    for source_page in source_pages:
        target = paths["cleaned"] / source_page.name.replace(".png", "_clean.png")
        clean_page_image(source_page, target)
        cleaned_paths.append(target)

    clean_pdf = paths["output"] / "libro_actividades_stickers_limpio.pdf"
    redesigned_pdf = paths["output"] / "libro_actividades_stickers_redisenado.pdf"
    logo_path = paths["assets"] / "mi_dulce_emma_logo.png"

    create_clean_pdf(cleaned_paths, clean_pdf)
    crop_brand_asset(source_pages[2], logo_path)
    build_redesigned_pdf(redesigned_pdf, logo_path)
    write_readme(base_dir)

    print(f"Generated: {clean_pdf}")
    print(f"Generated: {redesigned_pdf}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate cleaned and redesigned versions of the scanned sticker book pages.")
    parser.add_argument("--source", type=Path, default=SOURCE_DEFAULT, help="Path to the source scanned PDF.")
    parser.add_argument("--output-dir", type=Path, default=Path("/workspace/book_redesign"), help="Target output directory.")
    args = parser.parse_args()

    generate(args.source, args.output_dir)


if __name__ == "__main__":
    main()
