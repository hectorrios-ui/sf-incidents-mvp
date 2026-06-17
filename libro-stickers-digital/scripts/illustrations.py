#!/usr/bin/env python3
"""
Generador de ilustraciones vectoriales (SVG) para el
"Libro de Actividades con Stickers de Colores" — Mi Dulce Emma.

Diseño plano, moderno y alegre. Cada actividad se exporta como SVG
independiente (ideal para un futuro libro interactivo y digital).

>>> Homologación de stickers <<<
Todos los stickers son círculos de 16 mm de diámetro. Para garantizarlo,
TODO el libro usa una escala física común: MM_PER_UNIT (mm por unidad SVG).
Cada zona de sticker (slot) se dibuja con radio SLOT_R, de modo que su
diámetro impreso = 2 * SLOT_R * MM_PER_UNIT = 16 mm. En el documento Word,
cada ilustración se coloca con un ancho = (ancho_del_viewBox) * MM_PER_UNIT,
por lo que cualquier slot, en cualquier página, mide exactamente 16 mm.
"""

import os
import math

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_DIR = os.path.join(BASE, "assets", "svg")
os.makedirs(SVG_DIR, exist_ok=True)

# --- Escala física común (no cambiar sin recalcular lienzos) ---------------
MM_PER_UNIT = 0.20            # 1 unidad SVG = 0.20 mm
STICKER_MM = 16.0             # diámetro objetivo de cada sticker
SLOT_R = STICKER_MM / 2 / MM_PER_UNIT   # = 40 unidades  -> diámetro 80u = 16 mm

# --- Paleta alegre y amigable ----------------------------------------------
RED, RED_D       = "#FF5168", "#E23B50"
BLUE, BLUE_D     = "#2E8BFF", "#1F6FE0"
YELLOW, YELLOW_D = "#FFC83D", "#F0B021"
GREEN, GREEN_D   = "#34C76E", "#22A455"
PURPLE, PURPLE_D = "#9B6DD6", "#7E4FC0"
ORANGE, ORANGE_D = "#FF9F43", "#F08A23"
LEAF, LEAF_D     = "#2FB463", "#1E8C49"
BROWN, BROWN_D   = "#B5774A", "#925C36"
INK              = "#3A3A4A"
SKY              = "#EAF4FF"
WHITE            = "#FFFFFF"
SLOT_FILL        = "#F6F8FC"
SLOT_GREY        = "#C7CCD8"
SHADOW           = "#E6E1D6"


def doc(w, h, body, bg=None):
    rect = f'<rect width="{w}" height="{h}" rx="36" fill="{bg}"/>' if bg else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
        f'font-family="Fredoka, sans-serif">\n{rect}\n{body}\n</svg>\n'
    )


def slot(cx, cy, color=SLOT_GREY, r=SLOT_R, show_plus=True):
    """Zona punteada donde se pega un sticker de 16 mm (r = SLOT_R)."""
    plus = ""
    if show_plus:
        s = r * 0.42
        plus = (f'<path d="M{cx-s:.1f},{cy:.1f} H{cx+s:.1f} '
                f'M{cx:.1f},{cy-s:.1f} V{cy+s:.1f}" '
                f'stroke="{color}" stroke-width="{max(3,r*0.10):.1f}" '
                f'stroke-linecap="round" opacity="0.55"/>')
    return (
        f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{SLOT_FILL}" '
        f'stroke="{color}" stroke-width="{max(3,r*0.13):.1f}" '
        f'stroke-dasharray="{r*0.55:.1f} {r*0.45:.1f}" stroke-linecap="round"/>{plus}'
    )


def ground(cx, cy, rx, ry=None):
    ry = ry or rx * 0.22
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{SHADOW}" opacity="0.55"/>'


def save(name, svg):
    path = os.path.join(SVG_DIR, name)
    with open(path, "w", encoding="utf-8") as f:
        f.write(svg)
    print("svg  ->", os.path.relpath(path, BASE))


# ===========================================================================
# 1. CARROS
# ===========================================================================
def draw_car(cx, by, color, dark, slots=True, sc=1.0):
    """Carrito plano y moderno. (cx, by) = centro sobre el suelo (eje de ruedas).
    slots=True -> ruedas como zonas de sticker (16 mm); False -> ruedas pintadas."""
    body = (
        "M-158,-58 Q-158,-80 -132,-82 L-104,-82 "
        "Q-84,-140 -30,-144 L66,-144 "
        "Q114,-142 130,-86 L140,-82 Q160,-80 158,-58 "
        "L158,-20 Q158,-6 142,-6 L-142,-6 Q-158,-6 -158,-20 Z"
    )
    inner = (
        f'<ellipse cx="0" cy="30" rx="155" ry="20" fill="{SHADOW}" opacity="0.5"/>'
        f'<path d="{body}" fill="{color}"/>'
        f'<path d="M-150,-30 L150,-30 Q156,-30 156,-22 L156,-18 Q156,-6 142,-6 '
        f'L-142,-6 Q-156,-6 -156,-18 L-156,-22 Q-156,-30 -150,-30 Z" fill="{dark}" opacity="0.16"/>'
        f'<rect x="-92" y="-130" width="56" height="44" rx="14" fill="{SKY}" stroke="{dark}" stroke-width="3" opacity="0.95"/>'
        f'<rect x="-24" y="-130" width="60" height="44" rx="14" fill="{SKY}" stroke="{dark}" stroke-width="3" opacity="0.95"/>'
        f'<ellipse cx="150" cy="-44" rx="11" ry="14" fill="{YELLOW}" stroke="{YELLOW_D}" stroke-width="3"/>'
        f'<ellipse cx="-152" cy="-44" rx="9" ry="12" fill="{RED}" stroke="{RED_D}" stroke-width="2" opacity="0.8"/>'
    )
    for wx in (-84, 88):
        if slots:
            inner += slot(wx, -2, dark)
        else:
            inner += (f'<circle cx="{wx}" cy="-2" r="40" fill="{INK}"/>'
                      f'<circle cx="{wx}" cy="-2" r="17" fill="#fff"/>'
                      f'<circle cx="{wx}" cy="-2" r="6" fill="{INK}"/>')
    return f'<g transform="translate({cx},{by}) scale({sc})">{inner}</g>'


def build_cars():
    cars = [(BLUE, BLUE_D), (RED, RED_D), (YELLOW, YELLOW_D), (GREEN, GREEN_D)]
    pos = [(210, 200), (610, 200), (210, 540), (610, 540)]
    body = "".join(draw_car(x, y, c, d) for (c, d), (x, y) in zip(cars, pos))
    save("04_carros.svg", doc(820, 700, body))


# ===========================================================================
# 2. CORAZONES (6: amarillo, azul, rojo, verde, morado, naranja)
# ===========================================================================
def heart(cx, cy, s, color):
    path = (
        f'M{cx},{cy+s*0.95} '
        f'C{cx-s*1.35},{cy+s*0.05} {cx-s*1.15},{cy-s*0.95} {cx-s*0.5},{cy-s*0.95} '
        f'C{cx-s*0.18},{cy-s*0.95} {cx},{cy-s*0.62} {cx},{cy-s*0.42} '
        f'C{cx},{cy-s*0.62} {cx+s*0.18},{cy-s*0.95} {cx+s*0.5},{cy-s*0.95} '
        f'C{cx+s*1.15},{cy-s*0.95} {cx+s*1.35},{cy+s*0.05} {cx},{cy+s*0.95} Z'
    )
    return (
        f'<path d="{path}" fill="{SLOT_FILL}" stroke="{color}" '
        f'stroke-width="14" stroke-linejoin="round"/>'
    )


def build_hearts():
    s = 108
    layout = [
        (160, 215, YELLOW), (440, 215, BLUE), (720, 215, RED),
        (160, 490, GREEN), (440, 490, PURPLE), (720, 490, ORANGE),
    ]
    body = "".join(heart(x, y, s, c) for x, y, c in layout)
    save("05_corazones.svg", doc(880, 630, body))


# ===========================================================================
# 3. SOL
# ===========================================================================
def build_sun():
    cx, cy, R = 330, 370, 120
    ring = R + 105
    body = ""
    n = 12
    for i in range(n):
        a = math.radians(i * 360 / n - 90)
        body += slot(cx + math.cos(a) * ring, cy + math.sin(a) * ring, YELLOW_D)
    body += f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="{YELLOW}"/>'
    body += f'''
      <g>
        <rect x="{cx-92}" y="{cy-34}" width="78" height="58" rx="22" fill="{INK}"/>
        <rect x="{cx+14}" y="{cy-34}" width="78" height="58" rx="22" fill="{INK}"/>
        <rect x="{cx-18}" y="{cy-20}" width="36" height="10" rx="5" fill="{INK}"/>
        <rect x="{cx-80}" y="{cy-26}" width="26" height="16" rx="8" fill="#FFFFFF" opacity="0.35"/>
        <rect x="{cx+26}" y="{cy-26}" width="26" height="16" rx="8" fill="#FFFFFF" opacity="0.35"/>
      </g>'''
    body += (
        f'<path d="M{cx-46},{cy+46} Q{cx},{cy+96} {cx+46},{cy+46}" '
        f'fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
        f'<path d="M{cx-30},{cy+58} Q{cx},{cy+74} {cx+30},{cy+58}" '
        f'fill="{RED}" stroke="none" opacity="0.85"/>'
    )
    save("06_sol.svg", doc(660, 690, body))


# ===========================================================================
# 4. NUBE Y LLUVIA
# ===========================================================================
_CLOUD_PATH = (
    "M24,78 C10,78 2,66 8,54 C0,44 6,28 22,30 C26,14 48,8 60,20 "
    "C70,6 98,8 102,26 C118,26 122,46 110,56 C118,66 110,78 96,78 Z"
)
_CLOUD_W = 124.0


def cloud(x, y, w, color, fill=WHITE, stroke=12, face=False):
    sc = w / _CLOUD_W
    tx, ty = x, y - 6 * sc
    sw = stroke / sc
    g = (f'<g transform="translate({tx:.2f},{ty:.2f}) scale({sc:.4f})">'
         f'<path d="{_CLOUD_PATH}" fill="{fill}" stroke="{color}" '
         f'stroke-width="{sw:.1f}" stroke-linejoin="round"/>')
    if face:
        g += (
            f'<circle cx="48" cy="40" r="5.5" fill="{INK}"/>'
            f'<circle cx="74" cy="40" r="5.5" fill="{INK}"/>'
            f'<path d="M46,52 Q61,66 76,52" fill="none" stroke="{INK}" '
            f'stroke-width="4.5" stroke-linecap="round"/>'
            f'<circle cx="40" cy="50" r="6.5" fill="{RED}" opacity="0.22"/>'
            f'<circle cx="82" cy="50" r="6.5" fill="{RED}" opacity="0.22"/>'
        )
    return g + "</g>"


def build_cloud():
    body = cloud(60, 40, 600, BLUE, WHITE, stroke=14, face=True)
    layout = [(180, 480), (360, 520), (540, 480),
              (180, 615), (360, 655), (540, 615),
              (180, 750), (360, 750), (540, 750)]
    for (x, y) in layout:
        body += slot(x, y, BLUE_D)
    save("07_nube_lluvia.svg", doc(720, 820, body))


# ===========================================================================
# 5. ÁRBOL
# ===========================================================================
def build_tree():
    body = ground(380, 770, 230, 34)
    body += f'''
      <path d="M380,90
        C250,70 150,150 165,255
        C90,270 70,360 150,400
        C120,470 200,540 290,510
        C330,560 440,560 480,505
        C575,540 650,470 615,398
        C695,360 675,265 600,255
        C615,150 510,72 380,90 Z"
        fill="#Dff3e4" stroke="{GREEN_D}" stroke-width="12" stroke-linejoin="round"/>'''
    body += f'<path d="M345,470 C338,560 330,640 322,720 L438,720 C432,640 424,560 418,470 Z" fill="{BROWN}"/>'
    body += f'<path d="M380,500 C376,560 372,640 368,720" stroke="{BROWN_D}" stroke-width="8" fill="none" opacity="0.6"/>'
    for i in range(14):
        x = 60 + i * 48
        body += f'<path d="M{x},770 q10,-40 20,0" fill="none" stroke="{GREEN}" stroke-width="9" stroke-linecap="round"/>'
    apples = [(250, 200), (380, 195), (510, 205),
              (190, 300), (320, 300), (450, 300), (575, 295),
              (255, 400), (385, 400), (510, 400)]
    for (x, y) in apples:
        body += slot(x, y, RED_D)
    save("08_arbol_manzanas.svg", doc(760, 820, body))


# ===========================================================================
# 6. ORUGUITAS
# ===========================================================================
def caterpillar(x, y, color, dark):
    g = f'''
      <g transform="translate({x},{y})">
        <path d="M-2,-58 q-14,-26 -4,-40" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
        <path d="M14,-58 q10,-28 24,-34" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
        <circle cx="-6" cy="-62" r="6" fill="{INK}"/>
        <circle cx="40" cy="-94" r="6" fill="{INK}"/>
        <circle cx="0" cy="0" r="44" fill="{color}"/>
        <circle cx="-14" cy="-6" r="7" fill="{INK}"/>
        <circle cx="16" cy="-6" r="7" fill="{INK}"/>
        <circle cx="-11" cy="-9" r="2.5" fill="#fff"/>
        <circle cx="19" cy="-9" r="2.5" fill="#fff"/>
        <path d="M-16,16 Q2,34 22,14" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
        <circle cx="-22" cy="10" r="8" fill="{RED}" opacity="0.22"/>
        <circle cx="26" cy="10" r="8" fill="{RED}" opacity="0.22"/>
      </g>'''
    for i in range(5):
        g += slot(x + 96 + i * 92, y, dark)
    return g


def build_caterpillars():
    rows = [(YELLOW, YELLOW_D), (GREEN, GREEN_D), (BROWN, BROWN_D),
            (RED, RED_D), (BLUE, BLUE_D)]
    body = ""
    for i, (c, d) in enumerate(rows):
        body += caterpillar(70, 130 + i * 150, c, d)
    save("09_oruguitas.svg", doc(620, 850, body))


# ===========================================================================
# 7. ARAÑAS
# ===========================================================================
def spider(x, y):
    g = ""
    for side in (-1, 1):
        for k in range(4):
            base_y = y - 22 + k * 15
            mx = x + side * 54
            my = y + (-28 + k * 20) - 12
            lx = x + side * 78
            ly = y + (-30 + k * 22)
            g += (f'<path d="M{x+side*32},{base_y} Q{mx},{my} {lx},{ly}" '
                  f'fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>')
    g += f'<circle cx="{x}" cy="{y-52}" r="12" fill="{INK}"/>'
    g += (f'<circle cx="{x-4}" cy="{y-54}" r="2.6" fill="#fff"/>'
          f'<circle cx="{x+4}" cy="{y-54}" r="2.6" fill="#fff"/>')
    g += slot(x, y, INK)
    return g


def build_spiders():
    cols = [165, 430, 695]
    rows = [140, 355, 570, 785]
    body = "".join(spider(x, y) for y in rows for x in cols)
    save("10_aranas.svg", doc(860, 870, body))


# ===========================================================================
# 8. CEREZAS
# ===========================================================================
def cherry_pair(x, y):
    g = f'''
      <g transform="translate({x},{y})">
        <path d="M40,-150 C20,-90 -20,-40 -55,-10" fill="none" stroke="{LEAF}" stroke-width="11" stroke-linecap="round"/>
        <path d="M40,-150 C60,-92 95,-44 120,-12" fill="none" stroke="{LEAF}" stroke-width="11" stroke-linecap="round"/>
        <path d="M40,-150 C70,-176 118,-170 126,-150 C108,-132 64,-138 40,-150 Z" fill="{LEAF}"/>
      </g>'''
    g += slot(x - 55, y + 26, RED_D)
    g += slot(x + 120, y + 24, RED_D)
    return g


def build_cherries():
    spots = [(210, 280), (560, 280), (210, 660), (560, 660)]
    body = "".join(cherry_pair(x, y) for x, y in spots)
    save("11_cerezas.svg", doc(800, 820, body))


# ===========================================================================
# 9. HUEVOS
# ===========================================================================
def egg(cx, cy):
    p = (
        f'M{cx},{cy-95} '
        f'C{cx+70},{cy-110} {cx+120},{cy-40} {cx+95},{cy+20} '
        f'C{cx+135},{cy+40} {cx+120},{cy+110} {cx+55},{cy+100} '
        f'C{cx+30},{cy+150} {cx-55},{cy+135} {cx-65},{cy+80} '
        f'C{cx-135},{cy+85} {cx-130},{cy-5} {cx-80},{cy-25} '
        f'C{cx-110},{cy-85} {cx-45},{cy-115} {cx},{cy-95} Z'
    )
    g = f'<path d="{p}" fill="{WHITE}" stroke="{INK}" stroke-width="9" stroke-linejoin="round"/>'
    g += slot(cx, cy, YELLOW_D)
    return g


def build_eggs():
    body = egg(200, 170) + egg(560, 190) + egg(210, 470) + egg(580, 500)
    save("12_huevos.svg", doc(820, 700, body))


# ===========================================================================
# 10. SANDÍA
# ===========================================================================
def build_watermelon():
    cx = 400
    body = ground(cx, 600, 250, 28)
    body += f'''
      <path d="M120,470 Q400,640 680,470 Q700,520 690,545 Q400,720 110,545 Q100,520 120,470 Z"
            fill="{GREEN}" stroke="{GREEN_D}" stroke-width="8" stroke-linejoin="round"/>'''
    body += f'''
      <path d="M400,100 L150,500 Q400,610 650,500 Z"
            fill="{RED}" stroke="{RED_D}" stroke-width="8" stroke-linejoin="round"/>'''
    body += f'<path d="M400,120 L175,495 Q400,592 625,495 Z" fill="#FFFFFF" opacity="0.10"/>'
    seeds = [(400, 250), (350, 345), (450, 345),
             (305, 440), (400, 440), (495, 440)]
    for (x, y) in seeds:
        body += slot(x, y, INK)
    save("13_sandia.svg", doc(800, 680, body))


# ===========================================================================
# 11. FLORES (todas a la misma escala -> slots de 16 mm)
# ===========================================================================
def flower(cx, cy):
    g = f'<g transform="translate({cx},{cy})">'
    g += f'<path d="M0,40 C-6,160 -6,250 0,330" stroke="{LEAF}" stroke-width="16" fill="none" stroke-linecap="round"/>'
    g += f'<path d="M0,150 C-70,120 -110,150 -120,200 C-60,210 -10,195 0,160 Z" fill="{LEAF}"/>'
    g += f'<path d="M0,200 C70,170 110,200 120,250 C60,260 10,245 0,210 Z" fill="{LEAF_D}"/>'
    R = 80
    g += "</g>"
    # pétalos (slots) en coordenadas absolutas, mismo tamaño 16 mm
    for i in range(5):
        a = math.radians(i * 72 - 90)
        g += slot(cx + math.cos(a) * R, cy + math.sin(a) * R, SLOT_GREY)
    g += f'<circle cx="{cx}" cy="{cy}" r="38" fill="{YELLOW}" stroke="{YELLOW_D}" stroke-width="5"/>'
    return g


def build_flowers():
    body = ground(440, 720, 360, 28)
    body += flower(160, 250)
    body += flower(440, 320)
    body += flower(720, 250)
    for i in range(16):
        x = 40 + i * 50
        body += f'<path d="M{x},730 q9,-38 18,0" fill="none" stroke="{GREEN}" stroke-width="8" stroke-linecap="round"/>'
    save("14_flores.svg", doc(880, 760, body))


# ===========================================================================
# 12. ARCOÍRIS (horizontal). Slots de 16 mm a lo largo de cada arco.
# ===========================================================================
def build_rainbow():
    cx, base_y = 440, 460
    arcs = [(RED, 400), (YELLOW, 305), (GREEN, 210), (BLUE, 115)]
    stroke_map = {RED: RED_D, YELLOW: YELLOW_D, GREEN: GREEN_D, BLUE: BLUE_D}
    band = 64
    body = ""
    for color, r in arcs:
        body += (f'<path d="M{cx-r},{base_y} A{r},{r} 0 0 1 {cx+r},{base_y}" '
                 f'fill="none" stroke="{color}" stroke-width="{band}" opacity="0.16"/>')
    span = math.radians(120)            # de 30° a 150°
    for color, r in arcs:
        n = max(3, round(span * r / 105))
        for i in range(n):
            ang = math.radians(30 + i * (120 / (n - 1)))
            x = cx + math.cos(ang) * r
            y = base_y - math.sin(ang) * r
            body += slot(x, y, stroke_map[color])
    body += cloud(0, 392, 300, "#B9C7DE", WHITE, stroke=11)
    body += cloud(580, 392, 300, "#B9C7DE", WHITE, stroke=11)
    save("15_arcoiris.svg", doc(880, 620, body))


# ===========================================================================
# 13. FRASCOS — Muchos y pocos
# ===========================================================================
def jar(cx, cy, w, h, label, dots=None, sw=7):
    dots = dots or []
    half = w / 2
    fs = max(18, min(34, w * 0.16))
    body = f'''
      <g>
        <path d="M{cx-13},{cy-h/2-22} a13,13 0 0 1 26,0" fill="none" stroke="{INK}" stroke-width="{sw}"/>
        <rect x="{cx-half*0.72}" y="{cy-h/2-10}" width="{half*1.44}" height="{h*0.085+18:.0f}" rx="14" fill="{RED}"/>
        <path d="M{cx-half},{cy-h/2+26}
                 Q{cx-half},{cy-h/2+20} {cx-half*0.8},{cy-h/2+20}
                 L{cx+half*0.8},{cy-h/2+20}
                 Q{cx+half},{cy-h/2+20} {cx+half},{cy-h/2+26}
                 L{cx+half*0.92},{cy+h/2-22}
                 Q{cx+half*0.92},{cy+h/2} {cx+half*0.7},{cy+h/2}
                 L{cx-half*0.7},{cy+h/2}
                 Q{cx-half*0.92},{cy+h/2} {cx-half*0.92},{cy+h/2-22} Z"
              fill="{SKY}" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round" opacity="0.9"/>'''
    for (dx, dy, col) in dots:
        body += f'<circle cx="{cx+dx}" cy="{cy+dy}" r="{w*0.075:.0f}" fill="{col}"/>'
    body += (f'<rect x="{cx-half*0.64}" y="{cy-h/2+34}" width="{half*1.28}" height="{fs+16:.0f}" '
             f'rx="13" fill="{WHITE}" stroke="{INK}" stroke-width="3.5"/>'
             f'<text x="{cx}" y="{cy-h/2+38+fs:.0f}" text-anchor="middle" '
             f'font-size="{fs:.0f}" font-weight="700" fill="{INK}">{label}</text></g>')
    return body


def build_jars():
    pal = [RED, BLUE, YELLOW, GREEN, BROWN, LEAF]
    body = ""
    pocos_dots = [(-26, 18, RED), (24, 0, GREEN), (-2, 58, YELLOW), (30, 52, BLUE)]
    body += jar(225, 150, 150, 210, "Pocos", dots=pocos_dots, sw=5)
    body += jar(225, 570, 250, 440, "Pocos")
    grid = [(-46, -8), (-2, -12), (42, -6), (-50, 30), (-8, 28), (36, 32),
            (-44, 68), (0, 66), (44, 66), (-24, 104), (22, 104), (58, 30)]
    muchos_dots = [(dx, dy, pal[i % len(pal)]) for i, (dx, dy) in enumerate(grid)]
    body += jar(645, 165, 175, 250, "Muchos", dots=muchos_dots, sw=5)
    body += jar(645, 580, 270, 460, "Muchos")
    save("16_frascos.svg", doc(870, 840, body))


# ===========================================================================
# 14. SEMÁFORO
# ===========================================================================
def build_semaforo():
    cx = 300
    body = ground(cx, 800, 140, 26)
    body += f'<rect x="{cx-16}" y="600" width="32" height="200" rx="12" fill="{INK}" opacity="0.85"/>'
    body += f'<rect x="{cx-110}" y="70" width="220" height="520" rx="54" fill="{INK}"/>'
    body += f'<rect x="{cx-86}" y="94" width="172" height="472" rx="40" fill="#4A4A5E"/>'
    lights = [(200, RED_D), (330, YELLOW_D), (460, GREEN_D)]
    for (cy, cold) in lights:
        body += (f'<path d="M{cx-54},{cy-62} q54,-26 108,0 l0,14 q-54,-22 -108,0 Z" '
                 f'fill="{INK}"/>')
        body += slot(cx, cy, cold)
    save("17_semaforo.svg", doc(600, 820, body))


# ===========================================================================
# 15. MARIPOSA
# ===========================================================================
def build_mariposa():
    cx = 440
    fore_fill, fore_line = "#EAF1FF", BLUE_D
    hind_fill, hind_line = "#FFE9EC", RED_D
    fore = (
        f'M{cx+10},250 '
        f'C{cx+95},168 {cx+255},150 {cx+305},232 '
        f'C{cx+342},290 {cx+305},350 {cx+212},360 '
        f'C{cx+120},370 {cx+42},348 {cx+16},320 '
        f'C{cx+2},300 {cx},276 {cx+10},250 Z'
    )
    hind = (
        f'M{cx+14},356 '
        f'C{cx+118},360 {cx+250},392 {cx+268},470 '
        f'C{cx+280},528 {cx+236},582 {cx+162},570 '
        f'C{cx+96},560 {cx+46},508 {cx+24},446 '
        f'C{cx+12},412 {cx+8},384 {cx+14},356 Z'
    )
    right = (
        f'<path d="{hind}" fill="{hind_fill}" stroke="{hind_line}" stroke-width="9" stroke-linejoin="round"/>'
        f'<path d="{fore}" fill="{fore_fill}" stroke="{fore_line}" stroke-width="9" stroke-linejoin="round"/>'
        + slot(cx + 150, 232, fore_line)
        + slot(cx + 250, 292, fore_line)
        + slot(cx + 135, 458, hind_line)
        + slot(cx + 212, 512, hind_line)
    )
    body = ground(cx, 760, 250, 26)
    body += right
    body += f'<g transform="translate({2*cx},0) scale(-1,1)">{right}</g>'
    body += (f'<path d="M{cx-24},278 Q{cx-30},470 {cx},632 Q{cx+30},470 {cx+24},278 Z" fill="{INK}"/>')
    for yy in (330, 380, 430, 480, 530, 575):
        wv = 22 - (yy - 330) * 0.018
        body += (f'<path d="M{cx-wv:.0f},{yy} Q{cx},{yy+9} {cx+wv:.0f},{yy}" '
                 f'fill="none" stroke="#5A5A6E" stroke-width="3.5" stroke-linecap="round"/>')
    body += f'<ellipse cx="{cx}" cy="262" rx="30" ry="40" fill="{INK}"/>'
    body += f'<circle cx="{cx}" cy="200" r="30" fill="{INK}"/>'
    body += (f'<circle cx="{cx-11}" cy="196" r="5" fill="#fff"/>'
             f'<circle cx="{cx+11}" cy="196" r="5" fill="#fff"/>'
             f'<path d="M{cx-11},208 q11,11 22,0" fill="none" stroke="#fff" '
             f'stroke-width="3.5" stroke-linecap="round"/>')
    body += (f'<path d="M{cx-13},176 C{cx-42},120 {cx-74},100 {cx-92},96" '
             f'fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
             f'<path d="M{cx+13},176 C{cx+42},120 {cx+74},100 {cx+92},96" '
             f'fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
             f'<circle cx="{cx-92}" cy="96" r="12" fill="{INK}"/>'
             f'<circle cx="{cx+92}" cy="96" r="12" fill="{INK}"/>')
    save("18_mariposa.svg", doc(880, 800, body))


# ===========================================================================
# 16/17. MARIQUITA (función reutilizable) + conteo en 2 páginas
# ===========================================================================
def ladybug(cx, cy, R, spots, legs=True, plus=True):
    s = R / 250.0
    RX, RY = R, R * 1.04
    hy = cy - RY + 70 * s
    out = ""
    if legs:
        for sx in (-1, 1):
            for yy in (-0.6, -0.04, 0.5):
                ey = cy + yy * R
                e0x = cx + sx * RX * 0.5
                ex = cx + sx * RX * 0.86
                j1x, j1y = ex + sx * 46 * s, ey - 6 * s
                ftx, fty = j1x + sx * 30 * s, ey + 46 * s
                out += (f'<path d="M{e0x:.1f},{ey:.1f} L{ex:.1f},{ey:.1f} '
                        f'L{j1x:.1f},{j1y:.1f} L{ftx:.1f},{fty:.1f}" fill="none" '
                        f'stroke="{INK}" stroke-width="{13*s:.1f}" '
                        f'stroke-linecap="round" stroke-linejoin="round"/>')
    out += (f'<path d="M{cx-58*s:.1f},{hy:.1f} C{cx-92*s:.1f},{hy-80*s:.1f} '
            f'{cx-120*s:.1f},{hy-110*s:.1f} {cx-128*s:.1f},{hy-128*s:.1f}" '
            f'fill="none" stroke="{INK}" stroke-width="{9*s:.1f}" stroke-linecap="round"/>'
            f'<path d="M{cx+58*s:.1f},{hy:.1f} C{cx+92*s:.1f},{hy-80*s:.1f} '
            f'{cx+120*s:.1f},{hy-110*s:.1f} {cx+128*s:.1f},{hy-128*s:.1f}" '
            f'fill="none" stroke="{INK}" stroke-width="{9*s:.1f}" stroke-linecap="round"/>'
            f'<circle cx="{cx-128*s:.1f}" cy="{hy-128*s:.1f}" r="{15*s:.1f}" fill="{INK}"/>'
            f'<circle cx="{cx+128*s:.1f}" cy="{hy-128*s:.1f}" r="{15*s:.1f}" fill="{INK}"/>')
    out += f'<ellipse cx="{cx}" cy="{cy}" rx="{RX}" ry="{RY}" fill="{RED}"/>'
    out += (f'<path d="M{cx-150*s:.1f},{hy:.1f} a{150*s:.1f},{128*s:.1f} 0 0 1 {300*s:.1f},0 '
            f'C{cx+150*s:.1f},{hy+30*s:.1f} {cx-150*s:.1f},{hy+30*s:.1f} {cx-150*s:.1f},{hy:.1f} Z" '
            f'fill="{INK}"/>')
    out += (f'<circle cx="{cx-58*s:.1f}" cy="{hy-26*s:.1f}" r="{20*s:.1f}" fill="#fff"/>'
            f'<circle cx="{cx+58*s:.1f}" cy="{hy-26*s:.1f}" r="{20*s:.1f}" fill="#fff"/>'
            f'<circle cx="{cx-58*s:.1f}" cy="{hy-22*s:.1f}" r="{9*s:.1f}" fill="{INK}"/>'
            f'<circle cx="{cx+58*s:.1f}" cy="{hy-22*s:.1f}" r="{9*s:.1f}" fill="{INK}"/>'
            f'<circle cx="{cx-62*s:.1f}" cy="{hy-30*s:.1f}" r="{3.2*s:.1f}" fill="#fff"/>'
            f'<circle cx="{cx+54*s:.1f}" cy="{hy-30*s:.1f}" r="{3.2*s:.1f}" fill="#fff"/>')
    out += (f'<path d="M{cx},{hy+24*s:.1f} L{cx},{cy+RY-26*s:.1f}" stroke="{RED_D}" '
            f'stroke-width="{11*s:.1f}" stroke-linecap="round"/>')
    for (dx, dy) in spots:
        out += slot(cx + dx, cy + dy, INK, show_plus=plus)
    return out


def build_mariquita():
    cx, cy, R = 410, 440, 250
    body = ground(cx, cy + R * 1.04 + 18, 235, 28)
    spots = [(-118, -54), (-150, 70), (-86, 176),
             (118, -54), (150, 70), (86, 176)]
    body += ladybug(cx, cy, R, spots)
    save("19_mariquita.svg", doc(820, 800, body))


# Distribución de manchas para conteo 1-4 (cabe en una sola página a 16 mm).
_COUNT_LAYOUT = {
    1: [(0, 5)],
    2: [(-76, 5), (76, 5)],
    3: [(-76, -40), (76, -40), (0, 64)],
    4: [(-76, -46), (76, -46), (-76, 64), (76, 64)],
}


def build_mariquitas_conteo():
    """Cuatro mariquitas (1-4) más pequeñas, espaciadas y con números grandes."""
    R = 122
    grid = [(235, 230, 1), (645, 230, 2), (235, 650, 3), (645, 650, 4)]
    body = ""
    for cx, cy, n in grid:
        body += ladybug(cx, cy, R, _COUNT_LAYOUT[n], plus=False)
        by = cy + R * 1.04 + 72            # número grande y protagonista
        col = [RED, BLUE, YELLOW, GREEN][(n - 1) % 4]
        body += (f'<circle cx="{cx}" cy="{by}" r="48" fill="{col}"/>'
                 f'<text x="{cx}" y="{by+20}" text-anchor="middle" '
                 f'font-size="62" font-weight="700" fill="#fff" '
                 f'font-family="Fredoka, sans-serif">{n}</text>')
    save("21_conteo.svg", doc(880, 880, body))


# ===========================================================================
# 18. HELADO — chispas (stickers de 16 mm)
# ===========================================================================
def build_helado():
    cx = 350
    body = ground(cx, 952, 140, 24)
    cone_path = f'M{cx-118},560 L{cx+118},560 L{cx},902 Z'
    body += f'<defs><clipPath id="cono"><path d="{cone_path}"/></clipPath></defs>'
    body += (f'<path d="{cone_path}" fill="#E0A969" stroke="#C2884A" '
             f'stroke-width="8" stroke-linejoin="round"/>')
    body += '<g clip-path="url(#cono)" stroke="#C2884A" stroke-width="4" opacity="0.45">'
    for off in range(-320, 321, 44):
        body += f'<path d="M{cx+off},540 L{cx+off+210},950"/>'
        body += f'<path d="M{cx+off},950 L{cx+off+210},540"/>'
    body += '</g>'
    body += f'<circle cx="{cx}" cy="468" r="158" fill="#FFC4CF" stroke="#F58aa0" stroke-width="8"/>'
    body += f'<circle cx="{cx}" cy="316" r="132" fill="#BFEBD6" stroke="#4FBF93" stroke-width="8"/>'
    body += (f'<path d="M{cx},192 C{cx+8},168 {cx+30},162 {cx+40},164" '
             f'fill="none" stroke="{LEAF}" stroke-width="8" stroke-linecap="round"/>'
             f'<circle cx="{cx}" cy="202" r="30" fill="{RED}" stroke="{RED_D}" stroke-width="6"/>'
             f'<circle cx="{cx-10}" cy="194" r="7" fill="#fff" opacity="0.5"/>')
    upper = [(-55, 5), (48, -22), (0, 62)]
    lower = [(-92, -28), (18, -52), (96, 12), (-52, 58), (58, 62)]
    for (dx, dy) in upper:
        body += slot(cx + dx, 316 + dy, SLOT_GREY)
    for (dx, dy) in lower:
        body += slot(cx + dx, 468 + dy, SLOT_GREY)
    save("20_helado.svg", doc(700, 980, body))


# ===========================================================================
# 19. MANOS CONTANDO — un sticker por dedo
# ===========================================================================
def _hand(cx, py, side=-1):
    """side=-1 mano izquierda (pulgar a la izq.), side=+1 mano derecha."""
    skin, skin_d = "#F4C9A8", "#E3B492"
    tips = [(-132, py - 150), (-44, py - 188), (44, py - 176), (128, py - 118)]
    g = f'<rect x="{cx-70}" y="{py+70}" width="140" height="90" rx="34" fill="{skin}"/>'
    g += f'<ellipse cx="{cx}" cy="{py+60}" rx="118" ry="100" fill="{skin}"/>'
    fingers = [(cx + dx * (-side), ty) for dx, ty in tips]
    fingers.append((cx + side * 196, py + 4))   # pulgar hacia afuera
    for (tx, ty) in fingers:
        bx = cx + (tx - cx) * 0.42
        g += (f'<path d="M{bx:.0f},{py+10} L{tx:.0f},{ty:.0f}" stroke="{skin}" '
              f'stroke-width="54" stroke-linecap="round"/>')
    for (tx, ty) in fingers:
        g += slot(tx, ty, skin_d)
    return g


def build_manos():
    body = _hand(250, 360, side=-1)
    body += _hand(640, 360, side=+1)
    save("22_manos.svg", doc(890, 640, body))


# ===========================================================================
# 20. ABEJA HACIA LA FLOR — trazo vertical
# ===========================================================================
def _deco_flower(cx, cy, petal):
    g = ""
    for i in range(6):
        a = math.radians(i * 60)
        g += (f'<ellipse cx="{cx+math.cos(a)*52:.0f}" cy="{cy+math.sin(a)*52:.0f}" '
              f'rx="34" ry="34" fill="{petal}"/>')
    g += f'<circle cx="{cx}" cy="{cy}" r="40" fill="{YELLOW}" stroke="{YELLOW_D}" stroke-width="5"/>'
    return g


def _bee(cx, cy):
    g = f'<defs><clipPath id="beeb"><ellipse cx="{cx}" cy="{cy}" rx="78" ry="56"/></clipPath></defs>'
    g += f'<ellipse cx="{cx-86}" cy="{cy-34}" rx="46" ry="30" fill="#fff" stroke="{SLOT_GREY}" stroke-width="4"/>'
    g += f'<ellipse cx="{cx+86}" cy="{cy-34}" rx="46" ry="30" fill="#fff" stroke="{SLOT_GREY}" stroke-width="4"/>'
    g += f'<ellipse cx="{cx}" cy="{cy}" rx="78" ry="56" fill="{YELLOW}"/>'
    g += '<g clip-path="url(#beeb)">'
    for off in (-30, 14, 58):
        g += f'<rect x="{cx+off}" y="{cy-60}" width="22" height="120" fill="{INK}"/>'
    g += '</g>'
    g += f'<circle cx="{cx-78}" cy="{cy}" r="34" fill="{INK}"/>'
    g += (f'<circle cx="{cx-86}" cy="{cy-8}" r="6" fill="#fff"/>'
          f'<path d="M{cx-95},{cy+8} q10,8 20,2" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>')
    g += (f'<path d="M{cx-96},{cy-30} q-12,-18 -26,-20" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>'
          f'<circle cx="{cx-124}" cy="{cy-52}" r="6" fill="{INK}"/>')
    g += f'<path d="M{cx+78},{cy} l30,-16 l-4,18 l20,8 l-26,10 Z" fill="{INK}"/>'
    return g


def build_abeja():
    cx = 220
    body = _bee(cx, 110)
    body += _deco_flower(cx, 900, PURPLE)
    for i in range(6):
        body += slot(cx, 250 + i * 96, YELLOW_D)
    save("23_abeja.svg", doc(440, 970, body))


# ===========================================================================
# 21. COMETA CON COLA — moños en línea vertical
# ===========================================================================
def build_cometa():
    cx, ty = 250, 165
    d = 125
    body = ""
    body += (f'<path d="M{cx},{ty-d} L{cx+d},{ty} L{cx},{ty+d} L{cx-d},{ty} Z" '
             f'fill="{SKY}" stroke="{INK}" stroke-width="6"/>')
    # cuadrantes de color
    body += f'<path d="M{cx},{ty-d} L{cx+d},{ty} L{cx},{ty} Z" fill="{RED}" opacity="0.75"/>'
    body += f'<path d="M{cx+d},{ty} L{cx},{ty+d} L{cx},{ty} Z" fill="{BLUE}" opacity="0.75"/>'
    body += f'<path d="M{cx},{ty+d} L{cx-d},{ty} L{cx},{ty} Z" fill="{YELLOW}" opacity="0.75"/>'
    body += f'<path d="M{cx-d},{ty} L{cx},{ty-d} L{cx},{ty} Z" fill="{GREEN}" opacity="0.75"/>'
    body += (f'<path d="M{cx},{ty-d} L{cx},{ty+d} M{cx-d},{ty} L{cx+d},{ty}" '
             f'stroke="{INK}" stroke-width="4" opacity="0.4"/>')
    # cola ondulada vertical con moños (slots) de varios colores
    ys = [ty + d + 56 + i * 96 for i in range(6)]
    prev = (cx, ty + d)
    for i, y in enumerate(ys):
        x = cx + (28 if i % 2 else -28)
        body += (f'<path d="M{prev[0]},{prev[1]} Q{cx},{(prev[1]+y)/2:.0f} {x},{y}" '
                 f'fill="none" stroke="{BROWN}" stroke-width="6"/>')
        prev = (x, y)
    bow_cols = [RED_D, BLUE_D, GREEN_D, YELLOW_D]
    for i, y in enumerate(ys):
        x = cx + (28 if i % 2 else -28)
        body += slot(x, y, bow_cols[i % 4])
    save("24_cometa.svg", doc(500, 920, body))


# ===========================================================================
# 22. CAMINO DEL CARRO A LA CASA — línea horizontal
# ===========================================================================
def _house(cx, cy):
    g = f'<rect x="{cx-78}" y="{cy-40}" width="156" height="120" rx="8" fill="#FFE2A8" stroke="{BROWN_D}" stroke-width="5"/>'
    g += f'<path d="M{cx-96},{cy-40} L{cx},{cy-120} L{cx+96},{cy-40} Z" fill="{RED}" stroke="{RED_D}" stroke-width="5" stroke-linejoin="round"/>'
    g += f'<rect x="{cx-26}" y="{cy+12}" width="52" height="68" rx="8" fill="{BROWN}"/>'
    g += f'<rect x="{cx+30}" y="{cy-18}" width="38" height="38" rx="6" fill="{SKY}" stroke="{BROWN_D}" stroke-width="3"/>'
    return g


def build_camino():
    road = 250
    body = f'<path d="M20,{road} H705" stroke="#D9D2C4" stroke-width="16" stroke-linecap="round"/>'
    # dos autos (azul detrás, rojo delante) sobre la vía
    body += draw_car(95, road, BLUE, BLUE_D, slots=False, sc=0.52)
    body += draw_car(245, road, RED, RED_D, slots=False, sc=0.52)
    # zonas de sticker a lo largo de la vía (horizontal)
    for i in range(4):
        body += slot(370 + i * 92, road, SLOT_GREY)
    body += _house(772, road - 38)
    save("25_camino.svg", doc(880, 420, body))


# ===========================================================================
# 23. COLLAR DE CUENTAS — patrón de colores
# ===========================================================================
def _collar(cx, y0, pattern):
    """Un collar: 8 cuentas en arco; las 3 primeras dan el patrón, el resto slots."""
    xs = [120 + i * 88 for i in range(8)]
    pts = [(x, y0 - 0.0019 * (x - cx) ** 2) for x in xs]
    dmap = {RED: RED_D, BLUE: BLUE_D, YELLOW: YELLOW_D, GREEN: GREEN_D}
    g = "M" + " L".join(f"{x:.0f},{y:.0f}" for x, y in pts)
    g = f'<path d="{g}" fill="none" stroke="{SLOT_GREY}" stroke-width="6"/>'
    g += f'<circle cx="{pts[0][0]}" cy="{pts[0][1]:.0f}" r="10" fill="{INK}" opacity="0.5"/>'
    g += f'<circle cx="{pts[-1][0]}" cy="{pts[-1][1]:.0f}" r="10" fill="{INK}" opacity="0.5"/>'
    for i, (x, y) in enumerate(pts):
        if i < 3:
            c = pattern[i]
            g += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{SLOT_R}" fill="{c}" stroke="{dmap[c]}" stroke-width="4"/>'
        else:
            g += slot(x, y, SLOT_GREY)
    return g


def build_collar():
    cx = 430
    body = _collar(cx, 250, [RED, BLUE, RED])
    body += _collar(cx, 620, [YELLOW, GREEN, YELLOW])
    save("26_collar.svg", doc(860, 740, body))


# ===========================================================================
# 24. TABLA DE CONTEO 1-5
# ===========================================================================
def count_hand(cx, cy, k):
    """Mano (puño) mostrando k dedos levantados, estilo limpio."""
    skin, sd = "#F6CBA6", "#E0AE85"
    fist_w, fist_h = 132, 96
    fist_top = cy - fist_h / 2
    fxs = [cx - 45, cx - 15, cx + 15, cx + 45]   # índice..meñique
    ups = {1: {0}, 2: {0, 1}, 3: {0, 1, 2}, 4: {0, 1, 2, 3}, 5: {0, 1, 2, 3}}[k]
    g = ""
    # dedos levantados (detrás del puño)
    for i, fx in enumerate(fxs):
        if i in ups:
            ftop = fist_top - 92
            g += (f'<rect x="{fx-14}" y="{ftop:.0f}" width="28" height="120" rx="14" '
                  f'fill="{skin}" stroke="{sd}" stroke-width="3"/>')
    # pulgar
    if k == 5:
        g += (f'<g transform="rotate(-32 {cx-60} {cy-6})">'
              f'<rect x="{cx-74}" y="{cy-72}" width="28" height="86" rx="14" '
              f'fill="{skin}" stroke="{sd}" stroke-width="3"/></g>')
    # puño
    g += (f'<rect x="{cx-fist_w/2:.0f}" y="{fist_top:.0f}" width="{fist_w}" '
          f'height="{fist_h}" rx="34" fill="{skin}" stroke="{sd}" stroke-width="3"/>')
    # nudillos de los dedos doblados (bultos sobre el puño)
    for i, fx in enumerate(fxs):
        if i not in ups:
            g += (f'<circle cx="{fx}" cy="{fist_top+6:.0f}" r="15" '
                  f'fill="{skin}" stroke="{sd}" stroke-width="3"/>')
    # pulgar doblado (al costado) si no es 5
    if k != 5:
        g += (f'<circle cx="{cx-fist_w/2+6:.0f}" cy="{cy+6}" r="17" '
              f'fill="{skin}" stroke="{sd}" stroke-width="3"/>')
    return g


def build_tabla():
    cols = [95, 270, 445, 620, 795]
    body = ""
    for k, cx in enumerate(cols, start=1):
        # mano que muestra el número
        body += count_hand(cx, 150, k)
        # caja del número
        body += (f'<rect x="{cx-44}" y="222" width="88" height="64" rx="14" '
                 f'fill="#fff" stroke="{INK}" stroke-width="3"/>'
                 f'<text x="{cx}" y="270" text-anchor="middle" font-size="46" '
                 f'font-weight="700" fill="{INK}" font-family="Fredoka, sans-serif">{k}</text>')
        # "tablet" con la zona de stickers
        body += (f'<rect x="{cx-74}" y="312" width="148" height="512" rx="22" '
                 f'fill="#fff" stroke="{INK}" stroke-width="4"/>'
                 f'<rect x="{cx-58}" y="342" width="116" height="448" rx="12" fill="#F1ECFA"/>'
                 f'<circle cx="{cx}" cy="808" r="7" fill="none" stroke="#B8BECC" stroke-width="3"/>')
        for j in range(k):
            body += slot(cx, 392 + j * 86, SLOT_GREY)
    save("27_tabla.svg", doc(890, 860, body))


# ===========================================================================
# 25. CUPCAKES — cereza(s) según el número
# ===========================================================================
def _filled_heart(cx, cy, s, color):
    path = (
        f'M{cx},{cy+s*0.9} '
        f'C{cx-s*1.3},{cy} {cx-s*1.1},{cy-s*0.9} {cx-s*0.48},{cy-s*0.9} '
        f'C{cx-s*0.16},{cy-s*0.9} {cx},{cy-s*0.58} {cx},{cy-s*0.4} '
        f'C{cx},{cy-s*0.58} {cx+s*0.16},{cy-s*0.9} {cx+s*0.48},{cy-s*0.9} '
        f'C{cx+s*1.1},{cy-s*0.9} {cx+s*1.3},{cy} {cx},{cy+s*0.9} Z'
    )
    return f'<path d="{path}" fill="{color}"/>'


def _cupcake(cx, fy, n, wrap, wrap_d, frost):
    """Cupcake centrado en la crema (fy). Número dentro de un corazón en el cuerpo."""
    base = fy + 200
    g = f'{ground(cx, base+10, 110)}'
    # cerezas (slots) en pirámide SOBRE la crema
    pos = {1: [(0, fy-80)],
           2: [(-54, fy-66), (54, fy-66)],
           3: [(0, fy-104), (-58, fy-56), (58, fy-56)]}[n]
    for (dx, dy) in pos:
        g += slot(cx + dx, dy, RED_D)
    # crema
    g += (f'<circle cx="{cx-48}" cy="{fy+16}" r="60" fill="{frost}"/>'
          f'<circle cx="{cx+48}" cy="{fy+16}" r="60" fill="{frost}"/>'
          f'<circle cx="{cx}" cy="{fy-18}" r="66" fill="{frost}"/>')
    # papel (wrapper)
    g += (f'<path d="M{cx-90},{fy+44} L{cx+90},{fy+44} L{cx+66},{base} '
          f'Q{cx},{base+26} {cx-66},{base} Z" fill="{wrap}"/>')
    for off in (-58, -22, 14, 50):
        g += f'<path d="M{cx+off},{fy+50} L{cx+off*0.8:.0f},{base-8}" stroke="{wrap_d}" stroke-width="5" opacity="0.5"/>'
    # corazón con el número, en el centro del cuerpo
    g += _filled_heart(cx, fy+112, 40, RED)
    g += (f'<text x="{cx}" y="{fy+126}" text-anchor="middle" font-size="44" '
          f'font-weight="700" fill="#fff" font-family="Fredoka, sans-serif">{n}</text>')
    return g


def build_cupcakes():
    # pirámide: 3 arriba, 1 y 2 abajo
    body = _cupcake(440, 250, 3, "#C9A6F0", "#A87FE0", "#E7D6FA")
    body += _cupcake(235, 545, 1, "#FFB0C2", "#F58AA0", "#FFD7DE")
    body += _cupcake(645, 545, 2, "#8CC9FF", "#5BA8F0", "#CFEBFF")
    save("28_cupcakes.svg", doc(880, 800, body))


# ===========================================================================
# 26. TREN DE COLORES 1-5 (número + carga)
# ===========================================================================
def _wheels(cx, y):
    return (f'<circle cx="{cx-32}" cy="{y}" r="20" fill="{INK}"/><circle cx="{cx-32}" cy="{y}" r="8" fill="#fff"/>'
            f'<circle cx="{cx+32}" cy="{y}" r="20" fill="{INK}"/><circle cx="{cx+32}" cy="{y}" r="8" fill="#fff"/>')


def build_tren():
    rail_y = 640
    body = f'<path d="M40,{rail_y} H850" stroke="{BROWN_D}" stroke-width="8" stroke-linecap="round"/>'
    for tx in range(60, 840, 46):
        body += f'<path d="M{tx},{rail_y} v14" stroke="{BROWN_D}" stroke-width="5" opacity="0.4"/>'
    # locomotora
    lx = 110
    body += f'<rect x="{lx-58}" y="470" width="120" height="120" rx="16" fill="{INK}"/>'
    body += f'<rect x="{lx-58}" y="430" width="54" height="60" rx="10" fill="{INK}"/>'
    body += f'<rect x="{lx+6}" y="410" width="26" height="60" rx="8" fill="{INK}"/>'
    body += f'<circle cx="{lx+30}" cy="540" r="22" fill="{YELLOW}"/>'
    body += _wheels(lx, 600)
    # vagones 1-5
    cols = [(BLUE, BLUE_D), (RED, RED_D), (YELLOW, YELLOW_D), (GREEN, GREEN_D), (PURPLE, PURPLE_D)]
    xs = [270, 410, 550, 690, 830]
    for n, (cx, (c, d)) in enumerate(zip(xs, cols), start=1):
        body += f'<rect x="{cx-58}" y="478" width="116" height="116" rx="18" fill="{c}"/>'
        body += (f'<text x="{cx}" y="552" text-anchor="middle" font-size="56" '
                 f'font-weight="700" fill="#fff" font-family="Fredoka, sans-serif">{n}</text>')
        body += _wheels(cx, 600)
        body += f'<path d="M{cx-58},536 H{cx-78}" stroke="{INK}" stroke-width="7"/>'
        for j in range(n):
            body += slot(cx, 430 - j * 92, d)
    save("29_tren.svg", doc(890, 720, body))


# ===========================================================================
# Avatar de presentación y confeti de portada
# ===========================================================================
def build_avatar():
    body = f'''
      <g>
        {ground(260, 540, 200, 26)}
        <g>
          <rect x="120" y="300" width="180" height="230" rx="70" fill="{BLUE}"/>
          <path d="M150,310 q60,-40 120,0 l0,30 q-60,-30 -120,0 Z" fill="#fff" opacity="0.18"/>
          <circle cx="210" cy="225" r="86" fill="#F4C9A8"/>
          <path d="M126,210 q10,-110 84,-110 q74,0 84,110 q-20,-40 -84,-40 q-64,0 -84,40 Z" fill="#5A3B2E"/>
          <path d="M124,210 q-14,70 6,120 q-22,-70 -6,-150 Z" fill="#5A3B2E"/>
          <path d="M296,210 q14,70 -6,120 q22,-70 6,-150 Z" fill="#5A3B2E"/>
          <circle cx="184" cy="225" r="9" fill="{INK}"/>
          <circle cx="236" cy="225" r="9" fill="{INK}"/>
          <path d="M188,262 q22,20 44,0" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
          <circle cx="168" cy="248" r="11" fill="{RED}" opacity="0.22"/>
          <circle cx="252" cy="248" r="11" fill="{RED}" opacity="0.22"/>
        </g>
        <g>
          <rect x="300" y="360" width="150" height="180" rx="56" fill="{YELLOW}"/>
          <circle cx="375" cy="312" r="66" fill="#F8D2B4"/>
          <path d="M312,300 q6,-86 63,-86 q57,0 63,86 q-18,-34 -63,-34 q-45,0 -63,34 Z" fill="#3A2A22"/>
          <path d="M438,300 q34,-6 40,26 q-24,-16 -40,-10 Z" fill="#3A2A22"/>
          <circle cx="356" cy="312" r="7.5" fill="{INK}"/>
          <circle cx="396" cy="312" r="7.5" fill="{INK}"/>
          <path d="M358,340 q17,16 34,0" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
          <circle cx="344" cy="330" r="9" fill="{RED}" opacity="0.25"/>
          <circle cx="408" cy="330" r="9" fill="{RED}" opacity="0.25"/>
          <path d="M375,250 l-26,-16 l0,32 Z" fill="{RED}"/>
          <path d="M375,250 l26,-16 l0,32 Z" fill="{RED}"/>
          <circle cx="375" cy="250" r="8" fill="{RED_D}"/>
        </g>
      </g>'''
    save("02_avatar.svg", doc(560, 600, body, bg=None))


def build_confetti(name, w, h):
    import random
    random.seed(7)
    cols = [RED, BLUE, YELLOW, GREEN, PURPLE, ORANGE]
    body = ""
    for _ in range(46):
        x = random.uniform(10, w - 10)
        y = random.uniform(10, h - 10)
        r = random.uniform(7, 18)
        body += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r:.0f}" fill="{random.choice(cols)}" opacity="0.92"/>'
    save(name, doc(w, h, body))


# ===========================================================================
if __name__ == "__main__":
    build_cars()
    build_hearts()
    build_sun()
    build_cloud()
    build_tree()
    build_caterpillars()
    build_spiders()
    build_cherries()
    build_eggs()
    build_watermelon()
    build_flowers()
    build_rainbow()
    build_semaforo()
    build_mariposa()
    build_mariquitas_conteo()
    build_helado()
    build_abeja()
    build_cometa()
    build_camino()
    build_collar()
    build_tabla()
    build_cupcakes()
    build_tren()
    build_jars()
    build_avatar()
    build_confetti("confetti_band.svg", 1200, 240)
    print("\nListo: SVGs generados en assets/svg/")
