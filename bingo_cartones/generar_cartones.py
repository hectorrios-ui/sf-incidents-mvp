#!/usr/bin/env python3
"""Genera 10 cartones de bingo 3x3 estilo referencia BINGO ANIMALES."""

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
OUT = ROOT / "cartones"
OUT.mkdir(exist_ok=True)

CARD_SIZE = 2400
OUTER_MARGIN = 36
BORDER_WIDTH = 52
PANEL_PADDING = 70
TITLE_AREA = 200
GAP = 22
CELL_RADIUS = 28

ANIMAL_BATCHES = {
    "ref_batch1": ["Oveja", "León", "Buey", "Tiburón"],
    "ref_batch2": ["Delfín", "Perro", "Foca", "Morsa"],
    "ref_batch3": ["Vaca", "Cerdo", "Elefante", "Cebra"],
    "ref_batch4": ["Oso", "Pulpo", "Caballo", "Burro"],
    "ref_batch5": ["Jirafa", "Tortuga", "Estrella de mar", "Langosta"],
}

TITLE_COLORS = [
    (255, 107, 129),
    (255, 179, 71),
    (255, 230, 109),
    (126, 217, 87),
    (87, 204, 255),
    (162, 132, 255),
    (255, 143, 214),
    (255, 120, 88),
    (120, 196, 255),
    (255, 196, 120),
    (140, 220, 120),
    (255, 150, 170),
    (255, 210, 90),
]

RNG = random.Random(20260625)


def split_grid(image_path: Path, names: list[str]) -> dict[str, Image.Image]:
    img = Image.open(image_path).convert("RGBA")
    w, h = img.size
    hw, hh = w // 2, h // 2
    boxes = [(0, 0), (hw, 0), (0, hh), (hw, hh)]
    return {name: img.crop((x, y, x + hw, y + hh)) for name, (x, y) in zip(names, boxes)}


def load_animals() -> dict[str, Image.Image]:
    animals: dict[str, Image.Image] = {}
    for batch, names in ANIMAL_BATCHES.items():
        path = ASSETS / f"animals_{batch}.png"
        animals.update(split_grid(path, names))
    return animals


def load_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def rounded_mask(w: int, h: int, radius: int) -> Image.Image:
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=radius, fill=255)
    return mask


def draw_soft_jungle_bg(size: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGB", (size, size), (214, 236, 206))
    draw = ImageDraw.Draw(img, "RGBA")
    for y in range(size):
        t = y / size
        c = (
            int(205 + 20 * t),
            int(232 - 10 * t),
            int(198 + 15 * (1 - t)),
        )
        draw.line([(0, y), (size, y)], fill=c + (255,))
    for _ in range(30):
        cx, cy = rng.randint(0, size), rng.randint(0, size)
        rx, ry = rng.randint(70, 180), rng.randint(40, 120)
        col = rng.choice(
            [
                (170, 210, 155, 55),
                (195, 228, 180, 45),
                (255, 230, 200, 35),
                (180, 220, 190, 40),
            ]
        )
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=col)
    return img.convert("RGBA")


def draw_scallop_border(card: Image.Image, panel_box: tuple[int, int, int, int]) -> None:
    draw = ImageDraw.Draw(card)
    x0, y0, x1, y1 = panel_box
    colors = [
        (255, 120, 150),
        (255, 190, 90),
        (255, 240, 120),
        (120, 210, 130),
        (100, 190, 255),
        (180, 140, 255),
        (255, 160, 200),
    ]
    radius = 18
    step = 34
    for i, t in enumerate(range(0, (x1 - x0) + (y1 - y0) * 2, step)):
        color = colors[i % len(colors)]
        if t < (x1 - x0):
            cx, cy = x0 + t, y0 - 8
        elif t < (x1 - x0) + (y1 - y0):
            cx, cy = x1 + 8, y0 + (t - (x1 - x0))
        elif t < 2 * (x1 - x0) + (y1 - y0):
            cx, cy = x1 - (t - (x1 - x0) - (y1 - y0)), y1 + 8
        else:
            cx, cy = x0 - 8, y1 - (t - 2 * (x1 - x0) - (y1 - y0))
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color + (255,))


def draw_star(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill: tuple[int, int, int]) -> None:
    points = []
    for i in range(10):
        angle = math.pi / 2 + i * math.pi / 5
        r = size if i % 2 == 0 else size * 0.45
        points.append((cx + r * math.cos(angle), cy - r * math.sin(angle)))
    draw.polygon(points, fill=fill, outline=(30, 30, 30), width=3)


def draw_letter_3d(
    draw: ImageDraw.ImageDraw,
    char: str,
    x: int,
    y: int,
    size: int,
    fill: tuple[int, int, int],
    font: ImageFont.ImageFont,
) -> int:
    shadow = (45, 45, 45)
    for ox, oy in [(4, 5), (3, 4), (2, 3)]:
        draw.text((x + ox, y + oy), char, font=font, fill=shadow)
    for ox, oy in [(-2, -2), (2, -2), (-2, 2), (2, 2), (0, -2), (0, 2), (-2, 0), (2, 0)]:
        draw.text((x + ox, y + oy), char, font=font, fill=(20, 20, 20))
    draw.text((x, y), char, font=font, fill=fill)
    bbox = draw.textbbox((x, y), char, font=font)
    return bbox[2] - bbox[0]


def draw_title(card: Image.Image, y: int) -> None:
    draw = ImageDraw.Draw(card)
    font = load_font(92)
    text = "BINGO ANIMALES"
    widths = []
    for i, ch in enumerate(text):
        if ch == " ":
            widths.append(28)
        else:
            bbox = draw.textbbox((0, 0), ch, font=font)
            widths.append(bbox[2] - bbox[0] + 8)
    total_w = sum(widths)
    x = (CARD_SIZE - total_w) // 2
    color_idx = 0
    for i, ch in enumerate(text):
        if ch == " ":
            x += widths[i]
            continue
        fill = TITLE_COLORS[color_idx % len(TITLE_COLORS)]
        color_idx += 1
        w = draw_letter_3d(draw, ch, x, y, 92, fill, font)
        x += w

    draw_star(draw, (CARD_SIZE - total_w) // 2 - 55, y + 42, 24, (255, 220, 80))
    draw_star(draw, (CARD_SIZE + total_w) // 2 + 55, y + 42, 24, (120, 200, 255))


def prepare_center_image(path: Path) -> Image.Image:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    # Focus on sticker illustration area (upper portion of page image)
    crop = img.crop((int(w * 0.08), int(h * 0.02), int(w * 0.92), int(h * 0.72)))
    return crop


def draw_cell(
    card: Image.Image,
    x: int,
    y: int,
    cell_w: int,
    cell_h: int,
    content: Image.Image,
    label: str,
    label_font: ImageFont.ImageFont,
    is_center: bool = False,
) -> None:
    label_h = 62 if not is_center else 0
    art_h = cell_h - label_h

    cell = Image.new("RGBA", (cell_w, cell_h), (255, 255, 255, 255))
    mask = rounded_mask(cell_w, cell_h, CELL_RADIUS)

    art = content.resize((cell_w, art_h), Image.Resampling.LANCZOS)
    cell.paste(art, (0, 0))

    if label:
        draw = ImageDraw.Draw(cell)
        bbox = draw.textbbox((0, 0), label, font=label_font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (cell_w - tw) // 2
        ty = art_h + (label_h - th) // 2 - 4
        draw.text((tx, ty), label, font=label_font, fill=(25, 25, 25, 255))

    card.paste(cell, (x, y), mask)

    border = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        (2, 2, cell_w - 3, cell_h - 3),
        radius=CELL_RADIUS,
        outline=(235, 235, 235, 255),
        width=4,
    )
    card.alpha_composite(border, (x, y))


def generate_card(
    card_num: int,
    animals: list[str],
    animal_images: dict[str, Image.Image],
    center_image: Image.Image,
) -> Image.Image:
    card = draw_soft_jungle_bg(CARD_SIZE, seed=card_num * 131)

    panel_x0 = OUTER_MARGIN + BORDER_WIDTH
    panel_y0 = OUTER_MARGIN + BORDER_WIDTH
    panel_x1 = CARD_SIZE - OUTER_MARGIN - BORDER_WIDTH
    panel_y1 = CARD_SIZE - OUTER_MARGIN - BORDER_WIDTH

    panel = Image.new("RGBA", (panel_x1 - panel_x0, panel_y1 - panel_y0), (255, 255, 255, 255))
    card.paste(panel, (panel_x0, panel_y0))

    draw_scallop_border(card, (panel_x0, panel_y0, panel_x1, panel_y1))

    white_frame = ImageDraw.Draw(card)
    white_frame.rounded_rectangle(
        (panel_x0, panel_y0, panel_x1, panel_y1),
        radius=18,
        outline=(255, 255, 255, 255),
        width=14,
    )

    draw_title(card, panel_y0 + 28)

    label_font = load_font(40)
    grid_x0 = panel_x0 + PANEL_PADDING
    grid_y0 = panel_y0 + TITLE_AREA
    grid_x1 = panel_x1 - PANEL_PADDING
    grid_y1 = panel_y1 - PANEL_PADDING
    grid_w = grid_x1 - grid_x0
    grid_h = grid_y1 - grid_y0
    cell_w = (grid_w - GAP * 2) // 3
    cell_h = (grid_h - GAP * 2) // 3

    animal_idx = 0
    for r in range(3):
        for c in range(3):
            x = grid_x0 + c * (cell_w + GAP)
            y = grid_y0 + r * (cell_h + GAP)
            if r == 1 and c == 1:
                draw_cell(card, x, y, cell_w, cell_h, center_image, "", label_font, is_center=True)
            else:
                name = animals[animal_idx]
                animal_idx += 1
                draw_cell(card, x, y, cell_w, cell_h, animal_images[name], name, label_font)

    draw = ImageDraw.Draw(card)
    num_font = load_font(28)
    num_text = f"Cartón {card_num}"
    nb = draw.textbbox((0, 0), num_text, font=num_font)
    draw.text(
        (panel_x1 - (nb[2] - nb[0]) - 18, panel_y1 - 42),
        num_text,
        font=num_font,
        fill=(150, 175, 145, 255),
    )

    return card.convert("RGB")


def main() -> None:
    animal_images = load_animals()
    center = prepare_center_image(ASSETS / "emma_centro.png")
    all_names = list(animal_images.keys())
    layouts = []

    for i in range(1, 11):
        picked = RNG.sample(all_names, 8)
        card = generate_card(i, picked, animal_images, center)
        out_path = OUT / f"carton_{i:02d}.png"
        card.save(out_path, "PNG", optimize=True)
        layouts.append({"carton": i, "animales": picked})
        print(f"Generado: {out_path}")

    manifest = {
        "titulo": "BINGO ANIMALES - Mi dulce Emma",
        "estilo": "referencia",
        "centro": "Mi dulce Emma",
        "cartones": layouts,
    }
    (OUT / "cartones_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
