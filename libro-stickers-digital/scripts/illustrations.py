#!/usr/bin/env python3
"""
Generador de ilustraciones vectoriales (SVG) para el
"Libro de Actividades con Stickers de Colores" — Mi Dulce Emma.

Diseño plano, moderno y alegre. Cada actividad se exporta como SVG
independiente (ideal para un futuro libro interactivo y digital) en
assets/svg/. Las zonas punteadas marcan dónde el peque pega su sticker.
"""

import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_DIR = os.path.join(BASE, "assets", "svg")
os.makedirs(SVG_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Paleta alegre y amigable
# ---------------------------------------------------------------------------
RED, RED_D       = "#FF5168", "#E23B50"
BLUE, BLUE_D     = "#2E8BFF", "#1F6FE0"
YELLOW, YELLOW_D = "#FFC83D", "#F0B021"
GREEN, GREEN_D   = "#34C76E", "#22A455"
LEAF, LEAF_D     = "#2FB463", "#1E8C49"
BROWN, BROWN_D   = "#B5774A", "#925C36"
INK              = "#3A3A4A"
SKY              = "#EAF4FF"
CREAM            = "#FFFCF4"
WHITE            = "#FFFFFF"
SLOT_FILL        = "#F6F8FC"
SLOT_GREY        = "#C7CCD8"
SHADOW           = "#E6E1D6"


def doc(w, h, body, bg=None):
    """Envuelve el contenido en un SVG completo y responsivo."""
    rect = f'<rect width="{w}" height="{h}" rx="36" fill="{bg}"/>' if bg else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
        f'font-family="Fredoka, sans-serif">\n{rect}\n{body}\n</svg>\n'
    )


def slot(cx, cy, r, color=SLOT_GREY, show_plus=True):
    """Zona punteada donde el niño pega el sticker."""
    plus = ""
    if show_plus:
        s = r * 0.42
        plus = (
            f'<path d="M{cx-s},{cy} H{cx+s} M{cx},{cy-s} V{cy+s}" '
            f'stroke="{color}" stroke-width="{max(3,r*0.10):.1f}" '
            f'stroke-linecap="round" opacity="0.55"/>'
        )
    return (
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{SLOT_FILL}" '
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
# 1. CARROS  — Pon las llantas al carro según el color
# ===========================================================================
def car(color, dark):
    """Devuelve un <g> con un carrito (viewBox interno 0 0 380 250)."""
    win = SKY
    return f'''
    <g>
      {ground(190, 232, 150)}
      <!-- cabina -->
      <rect x="86" y="44" width="208" height="96" rx="34" fill="{color}"/>
      <!-- cuerpo -->
      <rect x="18" y="104" width="344" height="92" rx="44" fill="{color}"/>
      <rect x="18" y="150" width="344" height="46" rx="20" fill="{dark}" opacity="0.18"/>
      <!-- ventanas -->
      <rect x="104" y="58" width="78" height="64" rx="20" fill="{win}"/>
      <rect x="198" y="58" width="78" height="64" rx="20" fill="{win}"/>
      <!-- faro -->
      <ellipse cx="350" cy="128" rx="13" ry="16" fill="{YELLOW}" stroke="{YELLOW_D}" stroke-width="3"/>
      <!-- ruedas (zonas de sticker) -->
      {slot(112, 196, 38, dark)}
      {slot(290, 196, 38, dark)}
    </g>'''


def build_cars():
    cars = [(BLUE, BLUE_D), (RED, RED_D), (YELLOW, YELLOW_D), (GREEN, GREEN_D)]
    body = ""
    positions = [(40, 30), (470, 230), (40, 380), (470, 30)]
    # arrange 2 columns, staggered for dynamism
    positions = [(30, 20), (490, 60), (30, 360), (490, 400)]
    for (c, d), (x, y) in zip(cars, positions):
        body += f'<g transform="translate({x},{y}) scale(1.05)">{car(c, d)}</g>'
    save("04_carros.svg", doc(940, 700, body))


# ===========================================================================
# 2. CORAZONES — Asociación de colores
# ===========================================================================
def heart(cx, cy, s, color, dark, filled=False):
    # corazón centrado en cx,cy con "radio" s
    path = (
        f'M{cx},{cy+s*0.95} '
        f'C{cx-s*1.35},{cy+s*0.05} {cx-s*1.15},{cy-s*0.95} {cx-s*0.5},{cy-s*0.95} '
        f'C{cx-s*0.18},{cy-s*0.95} {cx},{cy-s*0.62} {cx},{cy-s*0.42} '
        f'C{cx},{cy-s*0.62} {cx+s*0.18},{cy-s*0.95} {cx+s*0.5},{cy-s*0.95} '
        f'C{cx+s*1.15},{cy-s*0.95} {cx+s*1.35},{cy+s*0.05} {cx},{cy+s*0.95} Z'
    )
    if filled:
        return f'<path d="{path}" fill="{color}"/>'
    return (
        f'<path d="{path}" fill="{SLOT_FILL}" stroke="{color}" '
        f'stroke-width="14" stroke-linejoin="round"/>'
        f'<text x="{cx}" y="{cy+8}" font-size="34" fill="{color}" '
        f'text-anchor="middle" opacity="0.5" font-weight="700">+</text>'
    )


def build_hearts():
    body = (
        heart(190, 230, 130, YELLOW, YELLOW_D)
        + heart(660, 200, 140, BLUE, BLUE_D)
        + heart(420, 470, 135, RED, RED_D)
    )
    save("05_corazones.svg", doc(900, 700, body))


# ===========================================================================
# 3. SOL — Pega los rayos del sol (amarillo)
# ===========================================================================
def build_sun():
    cx, cy, R = 380, 390, 130
    import math
    body = ""
    # rayos = slots amarillos alrededor
    n = 12
    for i in range(n):
        a = math.radians(i * 360 / n - 90)
        rx = cx + math.cos(a) * (R + 110)
        ry = cy + math.sin(a) * (R + 110)
        body += slot(rx, ry, 34, YELLOW_D)
    # cara del sol
    body += f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="{YELLOW}"/>'
    body += f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="{YELLOW_D}" opacity="0.0"/>'
    # gafas de sol cool
    body += f'''
      <g>
        <rect x="{cx-92}" y="{cy-34}" width="78" height="58" rx="22" fill="{INK}"/>
        <rect x="{cx+14}" y="{cy-34}" width="78" height="58" rx="22" fill="{INK}"/>
        <rect x="{cx-18}" y="{cy-20}" width="36" height="10" rx="5" fill="{INK}"/>
        <rect x="{cx-80}" y="{cy-26}" width="26" height="16" rx="8" fill="#FFFFFF" opacity="0.35"/>
        <rect x="{cx+26}" y="{cy-26}" width="26" height="16" rx="8" fill="#FFFFFF" opacity="0.35"/>
      </g>'''
    # sonrisa
    body += (
        f'<path d="M{cx-46},{cy+46} Q{cx},{cy+96} {cx+46},{cy+46}" '
        f'fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
        f'<path d="M{cx-30},{cy+58} Q{cx},{cy+74} {cx+30},{cy+58}" '
        f'fill="{RED}" stroke="none" opacity="0.85"/>'
    )
    save("06_sol.svg", doc(760, 780, body))


# ===========================================================================
# 4. NUBE Y LLUVIA — Pega la lluvia (azul)
# ===========================================================================
# Silueta de nube normalizada (caja de diseño 0..124 x 6..80) -> bbox limpio
_CLOUD_PATH = (
    "M24,78 C10,78 2,66 8,54 C0,44 6,28 22,30 C26,14 48,8 60,20 "
    "C70,6 98,8 102,26 C118,26 122,46 110,56 C118,66 110,78 96,78 Z"
)
_CLOUD_W, _CLOUD_H = 124.0, 74.0   # ancho de diseño y alto (de y=6 a y=80)


def cloud(x, y, w, color, fill=WHITE, stroke=12, face=False):
    """Dibuja una nube COMPLETA dentro de la caja (x, y, w, w*0.6).
    (x, y) = esquina superior-izquierda de la caja."""
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
    # nube completa centrada arriba (caja 620 ancho -> alto ~372)
    body = cloud(110, 40, 620, BLUE, WHITE, stroke=14, face=True)
    # gotas en zig-zag debajo
    layout = [
        (210, 470), (390, 510), (570, 470),
        (300, 620), (480, 620), (660, 580),
        (210, 730), (390, 740), (570, 730),
    ]
    for (x, y) in layout:
        body += slot(x, y, 30, BLUE_D)
    save("07_nube_lluvia.svg", doc(840, 800, body))


# ===========================================================================
# 5. ÁRBOL — Pon las manzanas rojas
# ===========================================================================
def build_tree():
    body = ground(380, 770, 230, 34)
    # copa
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
    # tronco
    body += f'<path d="M345,470 C338,560 330,640 322,720 L438,720 C432,640 424,560 418,470 Z" fill="{BROWN}"/>'
    body += f'<path d="M380,500 C376,560 372,640 368,720" stroke="{BROWN_D}" stroke-width="8" fill="none" opacity="0.6"/>'
    # pasto
    grass = ""
    for i in range(14):
        x = 60 + i * 48
        grass += f'<path d="M{x},770 q10,-40 20,0" fill="none" stroke="{GREEN}" stroke-width="9" stroke-linecap="round"/>'
    body += grass
    # manzanas (slots rojos)
    apples = [
        (230, 200), (360, 175), (480, 215),
        (175, 300), (300, 290), (430, 300), (545, 285),
        (250, 400), (380, 395), (500, 400),
        (335, 470),
    ]
    for (x, y) in apples:
        body += slot(x, y, 30, RED_D)
    save("08_arbol_manzanas.svg", doc(760, 820, body))


# ===========================================================================
# 6. ORUGUITAS GLOTONAS — Completa cada oruga según el color
# ===========================================================================
def caterpillar(x, y, color, dark):
    # cabeza
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
    # cuerpo: 5 slots
    for i in range(5):
        g += slot(x + 92 + i * 86, y, 40, dark)
    return g


def build_caterpillars():
    rows = [
        (YELLOW, YELLOW_D),
        (GREEN, GREEN_D),
        (BROWN, BROWN_D),
        (RED, RED_D),
        (BLUE, BLUE_D),
    ]
    body = ""
    for i, (c, d) in enumerate(rows):
        body += caterpillar(70, 125 + i * 152, c, d)
    save("09_oruguitas.svg", doc(640, 860, body))


# ===========================================================================
# 7. ARAÑAS — Pon el sticker negro
# ===========================================================================
def spider(x, y, s=1.0):
    legs = ""
    import math
    for side in (-1, 1):
        for k, ang in enumerate((28, 8, -10, -28)):
            a = math.radians(ang)
            x1 = x + side * 30 * s
            y1 = y - 6 * s + k * 0  # base near body
            lx = x + side * (78) * s
            ly = y + (-34 + k * 24) * s
            mx = x + side * 50 * s
            my = y + (-30 + k * 22) * s - 14 * s
            legs += (f'<path d="M{x1},{y+(-26+k*18)*s} Q{mx},{my} {lx},{ly}" '
                     f'fill="none" stroke="{INK}" stroke-width="{7*s:.1f}" stroke-linecap="round"/>')
    body = legs
    body += f'<circle cx="{x}" cy="{y}" r="{30*s}" fill="{SLOT_FILL}" stroke="{INK}" stroke-width="{4*s:.1f}" stroke-dasharray="{16*s:.1f} {13*s:.1f}" stroke-linecap="round"/>'
    body += f'<path d="M{x-12*s},{y} h{24*s} M{x},{y-12*s} v{24*s}" stroke="{INK}" stroke-width="{3.5*s:.1f}" stroke-linecap="round" opacity="0.5"/>'
    # cabecita arriba
    body += f'<circle cx="{x}" cy="{y-40*s}" r="{12*s}" fill="{INK}"/>'
    body += f'<circle cx="{x-4*s}" cy="{y-42*s}" r="{2.6*s}" fill="#fff"/><circle cx="{x+4*s}" cy="{y-42*s}" r="{2.6*s}" fill="#fff"/>'
    return body


def build_spiders():
    body = ""
    coords = [
        (150, 130), (470, 120),
        (300, 250), (610, 250),
        (150, 380), (440, 380),
        (300, 510), (640, 500),
        (150, 630), (470, 630),
        (310, 760), (640, 760),
    ]
    for (x, y) in coords:
        body += spider(x, y, 1.0)
    save("10_aranas.svg", doc(780, 870, body))


# ===========================================================================
# 8. CEREZAS — Usa el sticker rojo
# ===========================================================================
def cherry_pair(x, y):
    g = f'''
      <g transform="translate({x},{y})">
        <path d="M40,-150 C20,-90 -20,-40 -55,-10" fill="none" stroke="{LEAF}" stroke-width="11" stroke-linecap="round"/>
        <path d="M40,-150 C60,-92 95,-44 120,-12" fill="none" stroke="{LEAF}" stroke-width="11" stroke-linecap="round"/>
        <path d="M40,-150 C70,-176 118,-170 126,-150 C108,-132 64,-138 40,-150 Z" fill="{LEAF}"/>
        <path d="M40,-150 C64,-150 108,-132 126,-150" fill="none" stroke="{LEAF_D}" stroke-width="4" opacity="0.6"/>
      </g>'''
    g += slot(x - 55, y - 10 + 36, 34, RED_D)
    g += slot(x + 120, y - 12 + 36, 34, RED_D)
    return g


def build_cherries():
    body = ""
    spots = [(170, 240), (520, 240), (170, 470), (520, 470), (170, 700), (520, 700)]
    for (x, y) in spots:
        body += cherry_pair(x, y)
    save("11_cerezas.svg", doc(820, 800, body))


# ===========================================================================
# 9. HUEVOS — Pega la yema (amarillo)
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
    g += slot(cx, cy, 38, YELLOW_D)
    return g


def build_eggs():
    body = egg(200, 170) + egg(560, 190) + egg(210, 470) + egg(580, 500)
    save("12_huevos.svg", doc(820, 700, body))


# ===========================================================================
# 10. SANDÍA — Pega las semillas (negro)
# ===========================================================================
def build_watermelon():
    cx = 400
    body = ground(cx, 600, 250, 28)
    # corteza verde (arco exterior)
    body += f'''
      <path d="M120,470 Q400,640 680,470 Q700,520 690,545 Q400,720 110,545 Q100,520 120,470 Z"
            fill="{GREEN}" stroke="{GREEN_D}" stroke-width="8" stroke-linejoin="round"/>'''
    # pulpa roja (triángulo redondeado)
    body += f'''
      <path d="M400,110 L150,500 Q400,610 650,500 Z"
            fill="{RED}" stroke="{RED_D}" stroke-width="8" stroke-linejoin="round"/>'''
    body += f'<path d="M400,130 L175,495 Q400,592 625,495 Z" fill="#FFFFFF" opacity="0.10"/>'
    # semillas (slots negros)
    seeds = [(400, 245), (340, 330), (455, 330), (300, 415),
             (400, 405), (505, 415), (250, 480), (400, 485), (555, 480)]
    for (x, y) in seeds:
        body += slot(x, y, 22, INK)
    save("13_sandia.svg", doc(800, 660, body))


# ===========================================================================
# 11. FLORES — Decora las flores
# ===========================================================================
def flower(cx, cy, scale=1.0):
    import math
    g = f'<g transform="translate({cx},{cy}) scale({scale})">'
    # tallo
    g += f'<path d="M0,40 C-6,160 -6,250 0,330" stroke="{LEAF}" stroke-width="16" fill="none" stroke-linecap="round"/>'
    # hojas
    g += f'<path d="M0,150 C-70,120 -110,150 -120,200 C-60,210 -10,195 0,160 Z" fill="{LEAF}"/>'
    g += f'<path d="M0,200 C70,170 110,200 120,250 C60,260 10,245 0,210 Z" fill="{LEAF_D}"/>'
    # pétalos = 5 slots alrededor
    R = 78
    for i in range(5):
        a = math.radians(i * 72 - 90)
        g += slot(math.cos(a) * R, math.sin(a) * R, 40, INK if False else SLOT_GREY)
    # centro
    g += f'<circle cx="0" cy="0" r="38" fill="{YELLOW}" stroke="{YELLOW_D}" stroke-width="5"/>'
    g += "</g>"
    return g


def build_flowers():
    body = ground(440, 760, 360, 30)
    body += flower(440, 230, 1.0)
    body += flower(180, 360, 0.86)
    body += flower(700, 380, 0.86)
    # pasto
    for i in range(16):
        x = 40 + i * 50
        body += f'<path d="M{x},770 q9,-38 18,0" fill="none" stroke="{GREEN}" stroke-width="8" stroke-linecap="round"/>'
    save("14_flores.svg", doc(880, 800, body))


# ===========================================================================
# 12. ARCOÍRIS — Pega los círculos de colores
# ===========================================================================
def build_rainbow():
    """Arcoíris horizontal (panorámico) con nubes completas en las bases."""
    import math
    cx, base_y = 590, 470
    arcs = [(RED, 430), (YELLOW, 365), (GREEN, 300), (BLUE, 235)]
    stroke_map = {RED: RED_D, YELLOW: YELLOW_D, GREEN: GREEN_D, BLUE: BLUE_D}
    band = 60
    body = ""
    # bandas suaves de color
    for color, r in arcs:
        body += (f'<path d="M{cx-r},{base_y} A{r},{r} 0 0 1 {cx+r},{base_y}" '
                 f'fill="none" stroke="{color}" stroke-width="{band}" opacity="0.16"/>')
    # slots sobre cada arco (zona superior, despejada de las nubes)
    n = 7
    for color, r in arcs:
        for i in range(n):
            ang = math.radians(30 + i * (120 / (n - 1)))
            x = cx + math.cos(ang) * r
            y = base_y - math.sin(ang) * r
            body += slot(x, y, 24, stroke_map[color])
    # nubes completas encima de las bases
    body += cloud(10, 392, 300, "#B9C7DE", WHITE, stroke=11)
    body += cloud(870, 392, 300, "#B9C7DE", WHITE, stroke=11)
    save("15_arcoiris.svg", doc(1180, 590, body))


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
    # puntos (ejemplo)
    for (dx, dy, col) in dots:
        body += f'<circle cx="{cx+dx}" cy="{cy+dy}" r="{w*0.075:.0f}" fill="{col}"/>'
    # etiqueta encima
    body += (f'<rect x="{cx-half*0.64}" y="{cy-h/2+34}" width="{half*1.28}" height="{fs+16:.0f}" '
             f'rx="13" fill="{WHITE}" stroke="{INK}" stroke-width="3.5"/>'
             f'<text x="{cx}" y="{cy-h/2+38+fs:.0f}" text-anchor="middle" '
             f'font-size="{fs:.0f}" font-weight="700" fill="{INK}">{label}</text></g>')
    return body


def build_jars():
    pal = [RED, BLUE, YELLOW, GREEN, BROWN, LEAF]
    body = ""
    # --- Columna POCOS: ejemplo (pocos puntos) + frasco a llenar ---
    pocos_dots = [(-26, 18, RED), (24, 0, GREEN), (-2, 58, YELLOW), (30, 52, BLUE)]
    body += jar(230, 150, 150, 210, "Pocos", dots=pocos_dots, sw=5)
    body += jar(230, 570, 250, 440, "Pocos")
    # --- Columna MUCHOS: ejemplo (muchos puntos) + frasco a llenar ---
    grid = [(-46,-8),(-2,-12),(42,-6),(-50,30),(-8,28),(36,32),
            (-44,68),(0,66),(44,66),(-24,104),(22,104),(58,30)]
    muchos_dots = [(dx, dy, pal[i % len(pal)]) for i, (dx, dy) in enumerate(grid)]
    body += jar(660, 165, 175, 250, "Muchos", dots=muchos_dots, sw=5)
    body += jar(660, 580, 270, 460, "Muchos")
    save("16_frascos.svg", doc(900, 840, body))


# ===========================================================================
# 14. SEMÁFORO — Pon los stickers: rojo, amarillo y verde
# ===========================================================================
def build_semaforo():
    cx = 380
    body = ground(cx, 800, 150, 26)
    # poste
    body += f'<rect x="{cx-16}" y="600" width="32" height="200" rx="12" fill="{INK}" opacity="0.85"/>'
    # caja del semáforo
    body += (f'<rect x="{cx-130}" y="70" width="260" height="540" rx="60" '
             f'fill="{INK}"/>')
    body += (f'<rect x="{cx-104}" y="96" width="208" height="488" rx="46" '
             f'fill="#4A4A5E"/>')
    # tres luces (slots) con visera
    lights = [(210, RED, RED_D), (340, YELLOW, YELLOW_D), (470, GREEN, GREEN_D)]
    for (cy, col, cold) in lights:
        # visera
        body += (f'<path d="M{cx-66},{cy-72} q66,-30 132,0 l0,16 q-66,-26 -132,0 Z" '
                 f'fill="{INK}"/>')
        body += slot(cx, cy, 58, cold)
    save("17_semaforo.svg", doc(760, 840, body))


# ===========================================================================
# 15. MARIPOSA — Decora las alas (simetría)
# ===========================================================================
def build_mariposa():
    """Mariposa simétrica con alas de silueta real (lado derecho espejado)."""
    cx = 450
    fore_fill, fore_line = "#EAF1FF", BLUE_D
    hind_fill, hind_line = "#FFE9EC", RED_D

    # --- lado derecho (se reflejará para el izquierdo) ---
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
        # detalle decorativo del borde
        f'<path d="M{cx+250},170 C{cx+300},195 {cx+322},240 {cx+318},285" '
        f'fill="none" stroke="{fore_line}" stroke-width="5" opacity="0.35" stroke-linecap="round"/>'
        # slots (zonas de sticker)
        + slot(cx + 165, 232, 34, fore_line)
        + slot(cx + 245, 270, 27, fore_line)
        + slot(cx + 150, 318, 29, fore_line)
        + slot(cx + 140, 442, 30, hind_line)
        + slot(cx + 196, 502, 25, hind_line)
    )

    body = ground(cx, 760, 250, 26)
    body += right
    body += f'<g transform="translate({2*cx},0) scale(-1,1)">{right}</g>'

    # --- cuerpo central (simétrico) ---
    body += (
        # abdomen segmentado
        f'<path d="M{cx-24},278 Q{cx-30},470 {cx},632 Q{cx+30},470 {cx+24},278 Z" fill="{INK}"/>'
    )
    for yy in (330, 380, 430, 480, 530, 575):
        wv = 22 - (yy - 330) * 0.018
        body += (f'<path d="M{cx-wv:.0f},{yy} Q{cx},{yy+9} {cx+wv:.0f},{yy}" '
                 f'fill="none" stroke="#5A5A6E" stroke-width="3.5" stroke-linecap="round"/>')
    # tórax y cabeza
    body += f'<ellipse cx="{cx}" cy="262" rx="30" ry="40" fill="{INK}"/>'
    body += f'<circle cx="{cx}" cy="200" r="30" fill="{INK}"/>'
    # carita
    body += (f'<circle cx="{cx-11}" cy="196" r="5" fill="#fff"/>'
             f'<circle cx="{cx+11}" cy="196" r="5" fill="#fff"/>'
             f'<path d="M{cx-11},208 q11,11 22,0" fill="none" stroke="#fff" '
             f'stroke-width="3.5" stroke-linecap="round"/>')
    # antenas con bolita
    body += (f'<path d="M{cx-13},176 C{cx-42},120 {cx-74},100 {cx-92},96" '
             f'fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
             f'<path d="M{cx+13},176 C{cx+42},120 {cx+74},100 {cx+92},96" '
             f'fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
             f'<circle cx="{cx-92}" cy="92" r="12" fill="{INK}"/>'
             f'<circle cx="{cx+92}" cy="92" r="12" fill="{INK}"/>')
    save("18_mariposa.svg", doc(900, 800, body))


# ===========================================================================
# 16. MARIQUITA — Pon los puntos negros
# ===========================================================================
def build_mariquita():
    cx, cy = 410, 440
    RX, RY = 250, 262
    body = ground(cx, cy + RY + 18, 235, 28)

    # --- patitas (detrás del cuerpo): 3 por lado, dobladas ---
    legs = ""
    for sx in (-1, 1):
        for yy in (-150, -10, 130):
            ex = cx + sx * RX * 0.86
            ey = cy + yy
            j1x, j1y = ex + sx * 46, ey - 6
            ftx, fty = j1x + sx * 30, ey + 46
            legs += (f'<path d="M{cx + sx * RX * 0.5},{ey} L{ex},{ey} '
                     f'L{j1x},{j1y} L{ftx},{fty}" fill="none" stroke="{INK}" '
                     f'stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>')
    body += legs

    # --- antenas con bolita ---
    body += (f'<path d="M{cx-58},{cy-RY+70} C{cx-92},{cy-RY-10} {cx-120},{cy-RY-40} {cx-128},{cy-RY-58}" '
             f'fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
             f'<path d="M{cx+58},{cy-RY+70} C{cx+92},{cy-RY-10} {cx+120},{cy-RY-40} {cx+128},{cy-RY-58}" '
             f'fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
             f'<circle cx="{cx-128}" cy="{cy-RY-58}" r="15" fill="{INK}"/>'
             f'<circle cx="{cx+128}" cy="{cy-RY-58}" r="15" fill="{INK}"/>')

    # --- cuerpo rojo (óvalo) ---
    body += f'<ellipse cx="{cx}" cy="{cy}" rx="{RX}" ry="{RY}" fill="{RED}"/>'
    body += f'<ellipse cx="{cx}" cy="{cy}" rx="{RX}" ry="{RY}" fill="{RED_D}" opacity="0.10"/>'

    # --- cabeza negra (domo superior) ---
    hy = cy - RY + 70
    body += (f'<path d="M{cx-150},{hy} '
             f'a150,128 0 0 1 300,0 '
             f'C{cx+150},{hy+30} {cx-150},{hy+30} {cx-150},{hy} Z" fill="{INK}"/>')
    # ojitos + cachetes + sonrisa
    body += (f'<circle cx="{cx-58}" cy="{hy-26}" r="20" fill="#fff"/>'
             f'<circle cx="{cx+58}" cy="{hy-26}" r="20" fill="#fff"/>'
             f'<circle cx="{cx-54}" cy="{hy-22}" r="9" fill="{INK}"/>'
             f'<circle cx="{cx+62}" cy="{hy-22}" r="9" fill="{INK}"/>'
             f'<circle cx="{cx-58}" cy="{hy-30}" r="3.2" fill="#fff"/>'
             f'<circle cx="{cx+58}" cy="{hy-30}" r="3.2" fill="#fff"/>')

    # --- línea central de las alas ---
    body += (f'<path d="M{cx},{hy+24} L{cx},{cy+RY-26}" stroke="{RED_D}" '
             f'stroke-width="11" stroke-linecap="round"/>')

    # --- puntos negros (slots) simétricos, 3 por ala ---
    spots = [(-118, -54), (-150, 70), (-86, 176),
             (118, -54), (150, 70), (86, 176)]
    for (dx, dy) in spots:
        body += slot(cx + dx, cy + dy, 42, INK)

    save("19_mariquita.svg", doc(820, 800, body))


# ===========================================================================
# Avatar de presentación (mamá + peque) y confeti de portada
# ===========================================================================
def build_avatar():
    body = f'''
      <g>
        {ground(260, 540, 200, 26)}
        <!-- Mamá -->
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
        <!-- Peque -->
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
          <!-- lacito -->
          <path d="M375,250 l-26,-16 l0,32 Z" fill="{RED}"/>
          <path d="M375,250 l26,-16 l0,32 Z" fill="{RED}"/>
          <circle cx="375" cy="250" r="8" fill="{RED_D}"/>
        </g>
      </g>'''
    save("02_avatar.svg", doc(560, 600, body, bg=None))


def build_confetti(name, w, h):
    import random
    random.seed(7)
    cols = [RED, BLUE, YELLOW, GREEN, BROWN, LEAF]
    body = ""
    for _ in range(46):
        x = random.uniform(10, w - 10)
        y = random.uniform(10, h - 10)
        r = random.uniform(7, 18)
        c = random.choice(cols)
        body += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r:.0f}" fill="{c}" opacity="0.92"/>'
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
    build_mariquita()
    build_jars()
    build_avatar()
    build_confetti("confetti_band.svg", 1200, 240)
    print("\nListo: SVGs generados en assets/svg/")
