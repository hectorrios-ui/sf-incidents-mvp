#!/usr/bin/env python3
"""
Construye el documento Word profesional del
"Libro de Actividades con Stickers de Colores" — Mi Dulce Emma.

- Layout limpio y alegre (estilo digital, no hecho a mano).
- Fuentes infantiles muy claras: Baloo 2 (títulos), Fredoka (subtítulos)
  y Nunito (texto). Las fuentes se EMBEBEN en el .docx.
- Ilustraciones vectoriales (renderizadas desde SVG) en cada actividad.
"""

import os
from PIL import Image
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PNG = os.path.join(BASE, "assets", "png")
OUT = os.path.join(BASE, "Libro_Actividades_Stickers_Mi_Dulce_Emma.docx")

# Paleta
RED, BLUE, YELLOW, GREEN = "FF5168", "2E8BFF", "F0B021", "22A455"
INK, SOFT = "3A3A4A", "8A8AA0"
CYCLE = [RED, BLUE, YELLOW, GREEN]

F_TITLE = "Baloo 2 ExtraBold"
F_HEAD = "Fredoka"
F_BODY = "Nunito"

EMU_CM = 360000


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def set_run(run, name=F_BODY, size=12, color=INK, bold=False, italic=False,
            spacing=None):
    run.font.name = name
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)
    run.bold = bold
    run.italic = italic
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.find(qn('w:rFonts'))
    if rfonts is None:
        rfonts = OxmlElement('w:rFonts')
        rpr.append(rfonts)
    for a in ('w:ascii', 'w:hAnsi', 'w:cs'):
        rfonts.set(qn(a), name)
    if spacing is not None:
        sp = OxmlElement('w:spacing')
        sp.set(qn('w:val'), str(int(spacing)))
        rpr.append(sp)


def para(doc, align=WD_ALIGN_PARAGRAPH.LEFT, before=0, after=8,
         line=1.18, keep=False):
    p = doc.add_paragraph()
    p.alignment = align
    pf = p.paragraph_format
    pf.space_before = Pt(before)
    pf.space_after = Pt(after)
    pf.line_spacing = line
    if keep:
        pf.keep_with_next = True
    return p


def multicolor(p, text, font, size, colors=CYCLE, bold=True, spacing=None):
    i = 0
    for ch in text:
        run = p.add_run(ch)
        if ch == " ":
            set_run(run, font, size, INK, bold)
        else:
            set_run(run, font, size, colors[i % len(colors)], bold, spacing=spacing)
            i += 1


def shade_paragraph(p, color):
    pPr = p._p.get_or_add_pPr()
    sh = OxmlElement('w:shd')
    sh.set(qn('w:val'), 'clear')
    sh.set(qn('w:color'), 'auto')
    sh.set(qn('w:fill'), color)
    pPr.append(sh)


def bottom_rule(p, color, size=18):
    pPr = p._p.get_or_add_pPr()
    pbdr = OxmlElement('w:pBdr')
    bottom = OxmlElement('w:bottom')
    bottom.set(qn('w:val'), 'single')
    bottom.set(qn('w:sz'), str(size))
    bottom.set(qn('w:space'), '6')
    bottom.set(qn('w:color'), color)
    pbdr.append(bottom)
    pPr.append(pbdr)


def add_image(doc, name, max_w_cm=15.5, max_h_cm=18.5, align=WD_ALIGN_PARAGRAPH.CENTER):
    path = os.path.join(PNG, name)
    with Image.open(path) as im:
        w, h = im.size
    ratio = h / w
    w_cm = max_w_cm
    h_cm = w_cm * ratio
    if h_cm > max_h_cm:
        h_cm = max_h_cm
        w_cm = h_cm / ratio
    p = para(doc, align=align, before=4, after=4, line=1.0)
    p.add_run().add_picture(path, width=Emu(int(w_cm * EMU_CM)))
    return p


def page_break(doc):
    doc.add_page_break()


# ---------------------------------------------------------------------------
# Documento
# ---------------------------------------------------------------------------
doc = Document()
sec = doc.sections[0]
sec.page_height = Cm(29.7)
sec.page_width = Cm(21.0)
sec.top_margin = Cm(1.5)
sec.bottom_margin = Cm(1.5)
sec.left_margin = Cm(1.8)
sec.right_margin = Cm(1.8)

# Estilo base Normal -> Nunito
normal = doc.styles['Normal']
normal.font.name = F_BODY
normal.font.size = Pt(12)
normal.font.color.rgb = RGBColor.from_string(INK)
rpr = normal.element.get_or_add_rPr()
rf = rpr.find(qn('w:rFonts'))
if rf is None:
    rf = OxmlElement('w:rFonts')
    rpr.append(rf)
for a in ('w:ascii', 'w:hAnsi', 'w:cs'):
    rf.set(qn(a), F_BODY)


# ========================= PORTADA =========================
add_image(doc, "confetti_band.png", max_w_cm=17.4, max_h_cm=3.6)

para(doc, after=2, before=18)
p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=0)
r = p.add_run("Libro de Actividades")
set_run(r, F_TITLE, 40, INK, True)

p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=6, before=2)
multicolor(p, "con Stickers de Colores", F_TITLE, 30)

p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=2, before=10)
r = p.add_run("Estimulación temprana para peques curiosos")
set_run(r, F_HEAD, 15, SOFT, False)

p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=4, before=26)
r = p.add_run("con amor")
set_run(r, F_HEAD, 14, SOFT, italic=True)
p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=10, before=0)
r = p.add_run("@_mi_dulce_emma")
set_run(r, F_HEAD, 18, RED, True)

para(doc, after=2, before=10)
add_image(doc, "confetti_band.png", max_w_cm=17.4, max_h_cm=3.6)
page_break(doc)


# ========================= ¡HOLA! (presentación) =========================
p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=4, before=4)
multicolor(p, "¡Hola!", F_TITLE, 46)

add_image(doc, "02_avatar.png", max_w_cm=7.2, max_h_cm=8.0)

p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=0, before=2)
r = p.add_run("Mi Dulce Emma")
set_run(r, F_HEAD, 18, BLUE, True)
p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=12, before=0)
r = p.add_run("Actividades y juegos")
set_run(r, F_HEAD, 13, SOFT, False)

intro = [
    ("Soy Andrea: ", True), ("mamá, economista creativa con alma de maestra, "
     "apasionada por la estimulación temprana y fan de mi hija curiosa y "
     "amante de los animales.", False),
]
p = para(doc, after=10, line=1.25)
for txt, b in intro:
    set_run(p.add_run(txt), F_BODY, 12.5, INK, b)

for txt in [
    "Gracias por unirte y ser parte de esta linda comunidad de papitos y "
    "peques comprometidos con impulsar el desarrollo de sus hijos por medio "
    "de diferentes actividades.",
    "Estas son nuestras actividades favoritas con stickers. "
    "¡Espero que se diviertan mucho!",
]:
    p = para(doc, after=10, line=1.25)
    set_run(p.add_run(txt), F_BODY, 12.5, INK)

p = para(doc, after=0, before=6)
set_run(p.add_run("Con amor,"), F_BODY, 12.5, INK, italic=True)
p = para(doc, after=0)
set_run(p.add_run("@_mi_dulce_emma"), F_HEAD, 14, RED, True)
page_break(doc)


# ========================= STICKERS (pedagogía) =========================
p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=10, before=2)
multicolor(p, "Stickers", F_TITLE, 44)

for txt in [
    "Bienvenidos al libro de actividades con stickers de colores para niños. "
    "Apoya el desarrollo integral de los peques y los mantiene alejados de las "
    "pantallas mientras aprenden.",
    "Al despegar y pegar los stickers, los niños ejercitan músculos clave de "
    "sus manos, mejoran su concentración y desarrollan su autonomía de forma "
    "divertida.",
]:
    p = para(doc, after=10, line=1.3)
    set_run(p.add_run(txt), F_BODY, 12.5, INK)

p = para(doc, after=8, before=4)
set_run(p.add_run("Los peques trabajan:"), F_HEAD, 16, GREEN, True)

skills = [
    "Motricidad fina", "Coordinación óculo-manual", "Conciencia espacial",
    "Estimulación cognitiva", "Asociación de colores", "Trazos con stickers",
    "Fomento de la autonomía",
]
for i, s in enumerate(skills):
    p = para(doc, after=6, before=0, line=1.15)
    p.paragraph_format.left_indent = Cm(0.8)
    dot = p.add_run("●  ")
    set_run(dot, F_BODY, 13, CYCLE[i % len(CYCLE)], True)
    set_run(p.add_run(s), F_BODY, 13, INK, False)
page_break(doc)


# ========================= ACTIVIDADES =========================
activities = [
    ("01", "Carritos de colores", BLUE,
     "Pon las llantas a cada carrito usando los stickers del mismo color del coche.",
     "04_carros.png"),
    ("02", "Corazones de colores", RED,
     "Asociación de colores: pega los stickers según el color de cada corazón.",
     "05_corazones.png"),
    ("03", "El sol coqueto", YELLOW,
     "Pega los rayos del sol usando stickers de color amarillo.",
     "06_sol.png"),
    ("04", "La nube y la lluvia", BLUE,
     "Pega la lluvia debajo de la nube y practica el color azul con tus stickers.",
     "07_nube_lluvia.png"),
    ("05", "El árbol de manzanas", GREEN,
     "Pon las manzanas rojas en el árbol pegando un sticker en cada círculo.",
     "08_arbol_manzanas.png"),
    ("06", "Oruguitas glotonas", GREEN,
     "Completa el cuerpo de cada oruga con stickers del mismo color que su cabecita.",
     "09_oruguitas.png"),
    ("07", "Las arañitas", INK,
     "Pon un sticker negro en el cuerpo de cada arañita.",
     "10_aranas.png"),
    ("08", "Cerezas dulces", RED,
     "Usa stickers rojos para formar las cerezas.",
     "11_cerezas.png"),
    ("09", "Huevos ricos", YELLOW,
     "Pega la yema de cada huevo con un sticker amarillo.",
     "12_huevos.png"),
    ("10", "Sandía fresca", GREEN,
     "Pega las semillas de la sandía con stickers negros.",
     "13_sandia.png"),
    ("11", "Flores del jardín", GREEN,
     "Decora los pétalos de las flores con stickers de colores.",
     "14_flores.png"),
    ("12", "El arcoíris", BLUE,
     "Pega stickers de colores sobre cada arco del arcoíris siguiendo sus colores.",
     "15_arcoiris.png"),
    ("13", "Muchos y pocos", RED,
     "Llena un frasco con pocos stickers y el otro con muchos. ¡Aprende las cantidades!",
     "16_frascos.png"),
]

for n, title, accent, instr, img in activities:
    # Encabezado: badge nº + título + regla de color
    p = para(doc, WD_ALIGN_PARAGRAPH.LEFT, after=2, before=0, keep=True)
    badge = p.add_run(f"  {n}  ")
    set_run(badge, F_HEAD, 14, "FFFFFF", True)
    # sombrear el badge
    rpr = badge._element.get_or_add_rPr()
    sh = OxmlElement('w:shd'); sh.set(qn('w:val'), 'clear')
    sh.set(qn('w:color'), 'auto'); sh.set(qn('w:fill'), accent)
    rpr.append(sh)
    set_run(p.add_run("   "), F_HEAD, 14, INK)
    set_run(p.add_run(title), F_HEAD, 24, accent, True)
    bottom_rule(p, accent, size=16)

    # Instrucción
    p = para(doc, WD_ALIGN_PARAGRAPH.LEFT, after=6, before=6, line=1.2, keep=True)
    set_run(p.add_run(instr), F_BODY, 14, INK)

    # Ilustración
    add_image(doc, img, max_w_cm=15.8, max_h_cm=19.0)

    if n != activities[-1][0]:
        page_break(doc)

# Pie final
para(doc, after=2, before=18)
p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=0)
set_run(p.add_run("Hecho con amor · @_mi_dulce_emma"), F_HEAD, 12, SOFT, italic=True)

doc.save(OUT)
print("docx ->", os.path.relpath(OUT, BASE))
