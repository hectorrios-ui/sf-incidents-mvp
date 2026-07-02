#!/usr/bin/env python3
"""Extrae foto, logo y fondo desde la imagen de referencia del flyer."""

from pathlib import Path
from PIL import Image, ImageFilter

ASSETS = Path(__file__).parent / "assets"
REF = ASSETS / "referencia.jpg"


def crop_relative(img: Image.Image, box: tuple[float, float, float, float]) -> Image.Image:
    w, h = img.size
    left, top, right, bottom = box
    return img.crop((int(left * w), int(top * h), int(right * w), int(bottom * h)))


def main() -> None:
    if not REF.exists():
        for ext in (".png", ".jpeg", ".webp"):
            alt = REF.with_suffix(ext)
            if alt.exists():
                ref = alt
                break
        else:
            raise SystemExit(
                f"Coloca tu imagen de referencia en: {REF}\n"
                "(o referencia.png / referencia.webp)"
            )
    else:
        ref = REF

    img = Image.open(ref).convert("RGB")
    ASSETS.mkdir(parents=True, exist_ok=True)

    # Logo — esquina superior derecha (circular en el flyer original)
    logo = crop_relative(img, (0.72, 0.02, 0.98, 0.22))
    logo = logo.resize((600, 600), Image.Resampling.LANCZOS)
    logo.save(ASSETS / "logo.png", quality=95)

    # Foto central — grupo en el parque
    photo = crop_relative(img, (0.12, 0.18, 0.88, 0.62))
    photo.save(ASSETS / "foto-fondo.jpg", quality=92)

    # Fondo de pasto — imagen completa difuminada
    bg = img.copy()
    bg = bg.resize((int(bg.width * 1.1), int(bg.height * 1.1)), Image.Resampling.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(radius=12))
    bg.save(ASSETS / "fondo-pasto.jpg", quality=85)

    print("Listo:")
    print(f"  logo.png      ({logo.size[0]}x{logo.size[1]})")
    print(f"  foto-fondo.jpg ({photo.size[0]}x{photo.size[1]})")
    print(f"  fondo-pasto.jpg ({bg.size[0]}x{bg.size[1]})")


if __name__ == "__main__":
    main()
