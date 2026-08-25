#!/usr/bin/env python3
"""Genera publicidades tipo Historia (1080x1920) para Mi Dulce Emma."""

from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
FONTS = ROOT / "fonts"
OUT = ROOT / "output"

W, H = 1080, 1920

# Paleta inspirada en el logo y publicaciones de @_mi_dulce_emma
MINT = (168, 216, 200)
PINK = (245, 198, 214)
YELLOW = (255, 243, 176)
SKY = (184, 223, 245)
SAGE = (107, 158, 120)
WHITE = (255, 255, 255)
DARK = (45, 55, 50)
SOFT_BG = (252, 251, 248)


def load_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def vertical_gradient(size: tuple[int, int], top: tuple[int, ...], bottom: tuple[int, ...]) -> Image.Image:
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        color = tuple(lerp(top[i], bottom[i], t) for i in range(3))
        for x in range(size[0]):
            px[x, y] = color
    return img


def add_soft_blobs(base: Image.Image, colors: list[tuple[int, ...]]) -> Image.Image:
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    blobs = [
        (120, 260, 420, colors[0]),
        (760, 180, 360, colors[1]),
        (80, 980, 500, colors[2]),
        (820, 1180, 380, colors[3]),
        (420, 1500, 460, colors[0]),
    ]
    for cx, cy, r, color in blobs:
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, 70))
    blurred = overlay.filter(ImageFilter.GaussianBlur(45))
    return Image.alpha_composite(base.convert("RGBA"), blurred)


def draw_ring(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, width: int, color: tuple[int, ...]):
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=color, width=width)


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def wrap_text(text: str, font: ImageFont.FreeTypeFont, draw: ImageDraw.ImageDraw, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if text_size(draw, trial, font)[0] <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_outlined_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, ...] = WHITE,
    outline: tuple[int, ...] = DARK,
    outline_width: int = 4,
    anchor: str = "mm",
    glow: tuple[int, ...] | None = YELLOW,
):
    x, y = xy
    if glow:
        for dx, dy in [(0, 3), (2, 2), (-2, 2), (0, 4)]:
            draw.text((x + dx, y + dy), text, font=font, fill=(*glow, 180), anchor=anchor)
    for dx in range(-outline_width, outline_width + 1):
        for dy in range(-outline_width, outline_width + 1):
            if dx * dx + dy * dy <= outline_width * outline_width:
                draw.text((x + dx, y + dy), text, font=font, fill=outline, anchor=anchor)
    draw.text((x, y), text, font=font, fill=fill, anchor=anchor)


def draw_multiline_centered(
    draw: ImageDraw.ImageDraw,
    center_x: int,
    start_y: int,
    lines: list[str],
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, ...],
    line_gap: int = 18,
    outline: tuple[int, ...] = DARK,
    outline_width: int = 3,
    glow: tuple[int, ...] | None = None,
) -> int:
    y = start_y
    for line in lines:
        draw_outlined_text(draw, (center_x, y), line, font, fill=fill, outline=outline, outline_width=outline_width, anchor="mm", glow=glow)
        y += text_size(draw, line, font)[1] + line_gap
    return y


def paste_logo(canvas: Image.Image, size: int = 220, y: int = 90):
    logo_path = ASSETS / "profile_pic.jpg"
    logo = Image.open(logo_path).convert("RGBA")
    logo = logo.resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size, size), fill=255)
    logo.putalpha(mask)
    x = (W - size) // 2
    canvas.alpha_composite(logo, (x, y))
    return y + size + 24


def draw_footer(canvas: Image.Image):
    draw = ImageDraw.Draw(canvas)
    footer_y = H - 120
    draw.rounded_rectangle((70, footer_y - 28, W - 70, footer_y + 58), radius=28, fill=(*SAGE, 235))
    font = load_font("Nunito-SemiBold.ttf", 34)
    draw.text((W // 2, footer_y + 8), "Síguenos en Instagram", font=font, fill=WHITE, anchor="mm")
    font_ig = load_font("Baloo2-Bold.ttf", 40)
    draw.text((W // 2, footer_y + 48), "@_mi_dulce_emma", font=font_ig, fill=WHITE, anchor="mm")


def rounded_photo(image: Image.Image, box: tuple[int, int, int, int], radius: int = 36) -> Image.Image:
    w = box[2] - box[0]
    h = box[3] - box[1]
    fitted = ImageOps.fit(image.convert("RGBA"), (w, h), method=Image.Resampling.LANCZOS)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=radius, fill=255)
    fitted.putalpha(mask)
    return fitted


def create_base_canvas(accent_colors: list[tuple[int, ...]] | None = None) -> Image.Image:
    colors = accent_colors or [MINT, PINK, YELLOW, SKY]
    base = vertical_gradient((W, H), SOFT_BG, (250, 248, 252))
    base = add_soft_blobs(base, colors)
    draw = ImageDraw.Draw(base)
    draw_ring(draw, (W // 2, 430), 300, 10, (*MINT, 120))
    draw_ring(draw, (W // 2, 430), 330, 8, (*PINK, 110))
    draw_ring(draw, (W // 2, 430), 360, 6, (*YELLOW, 100))
    return base


def save_canvas(canvas: Image.Image, name: str):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    canvas.convert("RGB").save(path, quality=95)
    print(f"Saved {path}")


def historia_invitacion_principal():
    canvas = create_base_canvas()
    draw = ImageDraw.Draw(canvas)
    y = paste_logo(canvas, size=210, y=80)

    title_font = load_font("Baloo2-Bold.ttf", 72)
    draw_outlined_text(draw, (W // 2, y + 70), "Asiste a la", title_font, fill=WHITE, outline_width=5)
    draw_outlined_text(draw, (W // 2, y + 155), "Feria de Valmonti", title_font, fill=(*SAGE,), outline=WHITE, outline_width=4, glow=None)

    card_top = y + 250
    draw.rounded_rectangle((80, card_top, W - 80, card_top + 520), radius=40, fill=(255, 255, 255, 230))
    info_font = load_font("Nunito-Bold.ttf", 42)
    body_font = load_font("Nunito-SemiBold.ttf", 34)

    items = [
        ("📅  Fecha", "Sábado 29 de agosto"),
        ("📍  Lugar", "Salón social\nConjunto Valmonti\nFloridablanca"),
        ("✨  Ven y conoce", "Nuestra línea de juegos educativos\ny clases de estimulación"),
    ]
    cy = card_top + 70
    for label, value in items:
        draw.text((130, cy), label, font=info_font, fill=SAGE)
        cy += 52
        for line in value.split("\n"):
            draw.text((130, cy), line, font=body_font, fill=DARK)
            cy += 44
        cy += 24

    draw.rounded_rectangle((130, H - 290, W - 130, H - 210), radius=30, fill=(*MINT, 220))
    cta_font = load_font("Baloo2-Bold.ttf", 46)
    draw_outlined_text(draw, (W // 2, H - 250), "¡Te esperamos!", cta_font, fill=WHITE, outline_width=4)

    draw_footer(canvas)
    save_canvas(canvas, "propuesta1_historia01_invitacion.png")


def historia_juegos_educativos():
    canvas = create_base_canvas([YELLOW, MINT, SKY, PINK])
    draw = ImageDraw.Draw(canvas)
    y = paste_logo(canvas, size=180, y=70)

    title_font = load_font("Baloo2-Bold.ttf", 68)
    draw_outlined_text(draw, (W // 2, y + 60), "Juegos educativos", title_font, fill=WHITE, outline_width=5)
    draw_outlined_text(draw, (W // 2, y + 145), "para aprender jugando", load_font("Nunito-Bold.ttf", 40), fill=SAGE, outline=WHITE, outline_width=3, glow=None)

    post = Image.open(ASSETS / "posts" / "post_3.jpg")
    # Recorte inferior para evitar texto superpuesto del post original.
    w, h = post.size
    post = post.crop((0, int(h * 0.22), w, h))
    photo = rounded_photo(post, (110, 430, W - 110, 1180), radius=42)
    canvas.alpha_composite(photo, (110, 430))

    body_font = load_font("Nunito-SemiBold.ttf", 36)
    lines = wrap_text(
        "Descubre materiales didácticos, actividades sensoriales y propuestas lúdicas para el desarrollo de tus pequeños.",
        body_font,
        draw,
        W - 180,
    )
    draw_multiline_centered(draw, W // 2, 1240, lines, body_font, DARK, line_gap=12, outline=WHITE, outline_width=0, glow=None)

    draw.rounded_rectangle((120, 1460, W - 120, 1540), radius=28, fill=(*PINK, 220))
    draw_outlined_text(draw, (W // 2, 1500), "Feria de Valmonti · 29 de agosto", load_font("Nunito-Bold.ttf", 34), fill=WHITE, outline_width=3)

    draw_footer(canvas)
    save_canvas(canvas, "propuesta1_historia02_juegos.png")


def historia_estimulacion():
    canvas = create_base_canvas([SKY, MINT, PINK, YELLOW])
    draw = ImageDraw.Draw(canvas)
    y = paste_logo(canvas, size=180, y=70)

    title_font = load_font("Baloo2-Bold.ttf", 68)
    draw_outlined_text(draw, (W // 2, y + 60), "Clases de", title_font, fill=WHITE, outline_width=5)
    draw_outlined_text(draw, (W // 2, y + 145), "estimulación infantil", title_font, fill=(*SAGE,), outline=WHITE, outline_width=4, glow=None)

    post = Image.open(ASSETS / "posts" / "post_0.jpg")
    photo = rounded_photo(post, (110, 430, W - 110, 1180), radius=42)
    canvas.alpha_composite(photo, (110, 430))

    body_font = load_font("Nunito-SemiBold.ttf", 36)
    lines = wrap_text(
        "Espacios de conexión, juego y aprendizaje para bebés y niños. Ven a conocer nuestras clases grupales.",
        body_font,
        draw,
        W - 180,
    )
    draw_multiline_centered(draw, W // 2, 1240, lines, body_font, DARK, line_gap=12, outline=WHITE, outline_width=0, glow=None)

    draw.rounded_rectangle((120, 1460, W - 120, 1540), radius=28, fill=(*SKY, 230))
    draw_outlined_text(draw, (W // 2, 1500), "Salón social · Conjunto Valmonti", load_font("Nunito-Bold.ttf", 34), fill=DARK, outline=WHITE, outline_width=2)

    draw_footer(canvas)
    save_canvas(canvas, "propuesta1_historia03_estimulacion.png")


def historia_crecer_jugando():
    canvas = create_base_canvas([PINK, YELLOW, MINT, SKY])
    draw = ImageDraw.Draw(canvas)
    y = paste_logo(canvas, size=200, y=80)

    slogan_font = load_font("Baloo2-Bold.ttf", 58)
    draw_outlined_text(draw, (W // 2, y + 55), "Crecer Jugando", slogan_font, fill=SAGE, outline=WHITE, outline_width=4, glow=None)

    draw.rounded_rectangle((90, y + 130, W - 90, y + 430), radius=36, fill=(255, 255, 255, 235))
    info_font = load_font("Nunito-Bold.ttf", 40)
    draw.text((W // 2, y + 190), "Este sábado 29 de agosto", font=info_font, fill=DARK, anchor="mm")
    draw.text((W // 2, y + 250), "te invitamos a la", font=load_font("Nunito-Regular.ttf", 34), fill=DARK, anchor="mm")
    draw_outlined_text(draw, (W // 2, y + 330), "Feria de Valmonti", load_font("Baloo2-Bold.ttf", 56), fill=(*SAGE,), outline=WHITE, outline_width=3, glow=None)

    post = Image.open(ASSETS / "posts" / "post_3.jpg")
    photo = rounded_photo(post, (110, 620, W - 110, 980), radius=36)
    canvas.alpha_composite(photo, (110, 620))

    chips = ["Juegos educativos", "Estimulación infantil", "Actividades en familia"]
    chip_font = load_font("Nunito-SemiBold.ttf", 30)
    cy = 1040
    for chip in chips:
        tw, th = text_size(draw, chip, chip_font)
        pad_x, pad_y = 34, 16
        x0 = (W - tw - pad_x * 2) // 2
        draw.rounded_rectangle((x0, cy, x0 + tw + pad_x * 2, cy + th + pad_y * 2), radius=24, fill=(*MINT, 210))
        draw.text((W // 2, cy + pad_y + th // 2), chip, font=chip_font, fill=DARK, anchor="mm")
        cy += th + pad_y * 2 + 18

    draw.rounded_rectangle((100, 1320, W - 100, 1460), radius=30, fill=(255, 255, 255, 230))
    draw.text((W // 2, 1360), "Salón social · Conjunto Valmonti", font=load_font("Nunito-Bold.ttf", 34), fill=DARK, anchor="mm")
    draw.text((W // 2, 1415), "Floridablanca", font=load_font("Nunito-SemiBold.ttf", 34), fill=SAGE, anchor="mm")

    draw_footer(canvas)
    save_canvas(canvas, "propuesta1_historia04_resumen.png")


def propuesta_plantilla_3_fotos():
    canvas = create_base_canvas([MINT, SKY, PINK, YELLOW])
    draw = ImageDraw.Draw(canvas)
    y = paste_logo(canvas, size=170, y=60)

    title_font = load_font("Baloo2-Bold.ttf", 62)
    draw_outlined_text(draw, (W // 2, y + 45), "Feria de Valmonti", title_font, fill=WHITE, outline_width=5)
    draw.text((W // 2, y + 115), "Sábado 29 de agosto", font=load_font("Nunito-Bold.ttf", 34), fill=SAGE, anchor="mm")

    slots = [
        (90, 430, W - 90, 780),
        (90, 810, W - 90, 1160),
        (90, 1190, W - 90, 1540),
    ]
    slot_font = load_font("Nunito-SemiBold.ttf", 30)
    for idx, box in enumerate(slots, start=1):
        x0, y0, x1, y1 = box
        draw.rounded_rectangle(box, radius=34, fill=(255, 255, 255, 210), outline=(*SAGE, 180), width=4)
        # guías punteadas internas
        inner = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        idraw = ImageDraw.Draw(inner)
        dash = 16
        gap = 12
        for edge in [
            ((x0 + 24, y0 + 24), (x1 - 24, y0 + 24)),
            ((x0 + 24, y1 - 24), (x1 - 24, y1 - 24)),
            ((x0 + 24, y0 + 24), (x0 + 24, y1 - 24)),
            ((x1 - 24, y0 + 24), (x1 - 24, y1 - 24)),
        ]:
            (sx, sy), (ex, ey) = edge
            length = math.hypot(ex - sx, ey - sy)
            steps = int(length / (dash + gap))
            for i in range(steps):
                t0 = i / steps
                t1 = min(t0 + dash / length, 1.0)
                idraw.line(
                    (sx + (ex - sx) * t0, sy + (ey - sy) * t0, sx + (ex - sx) * t1, sy + (ey - sy) * t1),
                    fill=(*SAGE, 120),
                    width=3,
                )
        canvas = Image.alpha_composite(canvas, inner)
        draw = ImageDraw.Draw(canvas)
        draw.text((W // 2, (y0 + y1) // 2 - 18), f"Pega aquí tu imagen {idx}", font=slot_font, fill=(*SAGE, 220), anchor="mm")
        draw.text((W // 2, (y0 + y1) // 2 + 22), "1080 x 350 px aprox.", font=load_font("Nunito-Regular.ttf", 24), fill=(120, 130, 125), anchor="mm")

    draw.rounded_rectangle((100, 1570, W - 100, 1650), radius=26, fill=(*YELLOW, 220))
    draw.text((W // 2, 1610), "Juegos educativos · Clases de estimulación", font=load_font("Nunito-Bold.ttf", 30), fill=DARK, anchor="mm")

    draw.text((W // 2, 1700), "Salón social · Conjunto Valmonti · Floridablanca", font=load_font("Nunito-SemiBold.ttf", 28), fill=DARK, anchor="mm")

    draw_footer(canvas)
    save_canvas(canvas, "propuesta2_plantilla_3_fotos.png")


def main():
    historia_invitacion_principal()
    historia_juegos_educativos()
    historia_estimulacion()
    historia_crecer_jugando()
    propuesta_plantilla_3_fotos()


if __name__ == "__main__":
    main()
