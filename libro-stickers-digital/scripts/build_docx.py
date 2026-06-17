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
import re
from PIL import Image
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PNG = os.path.join(BASE, "assets", "png")
SVG = os.path.join(BASE, "assets", "svg")
OUT = os.path.join(BASE, "Libro_Actividades_Stickers_Mi_Dulce_Emma.docx")

# Escala física común: 1 unidad SVG = 0.20 mm  ->  cada slot (r=40) = 16 mm.
MM_PER_UNIT = 0.20
CONTENT_W_MM = (21.59 - 1.8 - 1.8) * 10   # ancho útil en Carta = 179.9 mm

# Paleta
RED, BLUE, YELLOW, GREEN = "FF5168", "2E8BFF", "F0B021", "22A455"
PURPLE, ORANGE = "7E4FC0", "F08A23"
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


def _viewbox_width(png_name):
    """Lee el ancho del viewBox del SVG correspondiente (en unidades)."""
    svg_path = os.path.join(SVG, os.path.splitext(png_name)[0] + ".svg")
    with open(svg_path, encoding="utf-8") as f:
        head = f.read(600)
    m = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', head)
    return float(m.group(1))


def add_sticker_image(doc, name, max_h_cm=19.5, align=WD_ALIGN_PARAGRAPH.CENTER):
    """Coloca la ilustración a su ancho FÍSICO real, de modo que cada zona
    de sticker imprima exactamente 16 mm (escala común MM_PER_UNIT)."""
    path = os.path.join(PNG, name)
    vbw = _viewbox_width(name)
    w_mm = vbw * MM_PER_UNIT
    if w_mm > CONTENT_W_MM:          # salvaguarda: nunca exceder el ancho útil
        w_mm = CONTENT_W_MM
    with Image.open(path) as im:
        pw, ph = im.size
    h_mm = w_mm * ph / pw
    if h_mm > max_h_cm * 10:         # salvaguarda de alto
        w_mm = w_mm * (max_h_cm * 10) / h_mm
    p = para(doc, align=align, before=4, after=4, line=1.0)
    p.add_run().add_picture(path, width=Emu(int(w_mm / 10 * EMU_CM)))
    return p


def page_break(doc):
    doc.add_page_break()


# ---------------------------------------------------------------------------
# Documento
# ---------------------------------------------------------------------------
doc = Document()
sec = doc.sections[0]
# Tamaño CARTA (Letter) — estándar de impresión en Colombia
sec.page_height = Cm(27.94)
sec.page_width = Cm(21.59)
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
     "¡Estos carritos quieren rodar, pero perdieron sus llantas! Observa bien de "
     "qué color es cada coche y pégale sus ruedas usando los stickers del mismo "
     "color. Así practicamos la asociación de colores y la motricidad fina de los deditos.",
     "04_carros.png"),
    ("02", "Corazones de colores", RED,
     "Cada corazón tiene su propio color. Pega los stickers dentro de cada uno "
     "usando el mismo color de su contorno: amarillo con amarillo, azul con azul "
     "y rojo con rojo. Es un juego ideal para reconocer y asociar los colores.",
     "05_corazones.png"),
    ("03", "El sol coqueto", YELLOW,
     "Nuestro sol con gafas quiere brillar muy fuerte. Pega sus rayos alrededor "
     "con stickers de color amarillo y complétalos uno a uno hasta que ilumine "
     "todo el cielo. ¡No olvides contarlos mientras los pegas!",
     "06_sol.png"),
    ("04", "La nube y la lluvia", BLUE,
     "¡Va a llover! Pega las gotitas debajo de la nubecita feliz usando stickers "
     "azules y practica este color. Mientras las colocas, cuenta cuántas gotas "
     "caen para trabajar también los números.",
     "07_nube_lluvia.png"),
    ("05", "El árbol de manzanas", GREEN,
     "El árbol ya está listo para dar sus frutos. Pon una manzana roja en cada "
     "círculo usando tus stickers y llénalo de color. Trabajamos la coordinación "
     "ojo-mano y la conciencia del espacio.",
     "08_arbol_manzanas.png"),
    ("06", "Oruguitas glotonas", GREEN,
     "Cada oruga necesita completar su cuerpo. Fíjate muy bien en el color de su "
     "cabecita y continúa pegando stickers del mismo color hasta el final. "
     "¡Crearás patrones de colores divertidos!",
     "09_oruguitas.png"),
    ("07", "Las arañitas", INK,
     "Estas simpáticas arañitas perdieron su cuerpo. Pon un sticker negro en el "
     "centro de cada una para completarlas y, al terminar, cuéntalas todas para "
     "saber cuántas arañitas hay.",
     "10_aranas.png"),
    ("08", "Cerezas dulces", RED,
     "Forma cada par de cerezas pegando stickers rojos en su lugar. Practicamos "
     "el color rojo y el movimiento de pinza de los dedos, tan importante para "
     "aprender a escribir más adelante.",
     "11_cerezas.png"),
    ("09", "Huevos ricos", YELLOW,
     "A cada huevo le falta su yema. Pega un sticker amarillo justo en el centro "
     "de cada uno para terminarlos. ¡Quedarán listos y deliciosos para el desayuno!",
     "12_huevos.png"),
    ("10", "Sandía fresca", GREEN,
     "Esta sandía está jugosa y fresquita, pero le faltan las semillas. Pégalas "
     "con stickers negros y decórala. Al final, cuenta cuántas semillas pusiste "
     "en total.",
     "13_sandia.png"),
    ("11", "Flores del jardín", GREEN,
     "Decora los pétalos de cada flor con stickers de colores. Puedes seguir un "
     "patrón (un color sí y otro no) o crear tu propia combinación. ¡Deja volar "
     "tu imaginación y llena el jardín de color!",
     "14_flores.png"),
    ("12", "El arcoíris", BLUE,
     "Completa el arcoíris pegando stickers de colores sobre cada uno de sus "
     "arcos. Respeta el color de cada franja —rojo, amarillo, verde y azul— y "
     "haz que brille después de la lluvia.",
     "15_arcoiris.png"),
    ("13", "El semáforo", RED,
     "Aprende los colores del semáforo y para qué sirven: pega el sticker rojo "
     "arriba, el amarillo en el medio y el verde abajo. Recuerda que el rojo "
     "significa parar, el amarillo esperar y el verde avanzar.",
     "17_semaforo.png"),
    ("14", "La mariposa", BLUE,
     "Decora las alas de la mariposa con stickers de colores. El reto es lograr "
     "que el lado izquierdo y el derecho queden iguales para descubrir la "
     "simetría. ¡Elige tus colores favoritos y hazla volar!",
     "18_mariposa.png"),
    ("15", "La mariquita", RED,
     "Esta mariquita necesita sus puntitos para lucir hermosa. Pega stickers "
     "negros sobre su espalda roja repartiéndolos a ambos lados y, al terminar, "
     "cuéntalos uno por uno.",
     "19_mariquita.png"),
    ("16", "A contar mariquitas", RED,
     "Cada mariquita lleva su número. Pega tantas manchas negras como indique "
     "cada una: 1 mancha a la primera, 2 a la segunda, 3 a la tercera y 4 a la "
     "cuarta. Cuenta en voz alta mientras las colocas para practicar los números "
     "y la correspondencia uno a uno.",
     "21_conteo.png"),
    ("17", "Helado de chispas", GREEN,
     "¡Qué rico helado! Decóralo con chispas de colores: pega un sticker en cada "
     "puntito de las bolas. Combina los colores como más te gusten y trabaja la "
     "motricidad fina colocando cada chispita en su lugar.",
     "20_helado.png"),
    ("18", "Muchos y pocos", YELLOW,
     "Mira los frascos de ejemplo: uno tiene pocos stickers y el otro tiene "
     "muchos. Ahora llena tú los frascos vacíos: uno con pocos y otro con muchos. "
     "Así aprendemos las cantidades y comparamos dónde hay más y dónde hay menos.",
     "16_frascos.png"),
    ("19", "Manos contadoras", BLUE,
     "¡A contar con los deditos! Pega un sticker en la yema de cada dedo y "
     "cuéntalos uno a uno: 1, 2, 3… hasta llegar a 10. Ideal para practicar el "
     "conteo uno a uno y la coordinación de las manitos.",
     "22_manos.png"),
    ("20", "La abeja y la flor", YELLOW,
     "Ayuda a la abejita a bajar hasta la flor. Pega un sticker en cada círculo "
     "siguiendo la línea de arriba hacia abajo, sin salirte. Así practicamos el "
     "trazo vertical, tan importante para empezar a escribir.",
     "23_abeja.png"),
    ("21", "Mi cometa", RED,
     "¡A volar la cometa! Decora su cola pegando un moño (sticker) en cada "
     "círculo, de arriba hacia abajo. Trabajamos el trazo vertical y la atención "
     "mientras la cola se llena de color.",
     "24_cometa.png"),
    ("22", "Del carro a la casa", GREEN,
     "El carrito quiere llegar a su casa. Pega un sticker en cada círculo del "
     "camino, de izquierda a derecha, para completar la ruta. Practicamos el "
     "trazo horizontal y la direccionalidad.",
     "25_camino.png"),
    ("23", "Collar de colores", PURPLE,
     "¡Arma un collar precioso! Observa el patrón de colores que ya empezó "
     "(rojo, azul, amarillo…) y continúalo pegando los stickers en el mismo "
     "orden. Trabajamos los patrones y la secuencia lógica.",
     "26_collar.png"),
    ("24", "Tabla de conteo", BLUE,
     "Mira el número de cada columna y pega esa cantidad de stickers debajo: "
     "1 en la columna del 1, 2 en la del 2… hasta el 5. Cuenta en voz alta para "
     "reforzar el conteo uno a uno y la noción de cantidad.",
     "27_tabla.png"),
    ("25", "Cupcakes ricos", RED,
     "¡Cupcakes deliciosos! Cada uno tiene un número dentro de un corazón. Pega "
     "encima esa cantidad de cerezas (stickers): 1 cereza al cupcake 1, 2 al "
     "cupcake 2 y 3 al cupcake 3.",
     "28_cupcakes.png"),
    ("26", "Tren de colores", GREEN,
     "¡Sube la carga al tren! Cada vagón tiene su número, del 1 al 5. Pega encima "
     "de cada vagón esa cantidad de stickers como si fueran su carga y cuéntalos "
     "mientras el tren avanza por las vías.",
     "29_tren.png"),
]

for idx, (n, title, accent, instr, img) in enumerate(activities):
    # Encabezado: badge nº + título + regla de color (cada actividad en su página)
    p = para(doc, WD_ALIGN_PARAGRAPH.LEFT, after=2, before=0, keep=True)
    if idx > 0:
        p.paragraph_format.page_break_before = True
    badge = p.add_run(f"  {n}  ")
    set_run(badge, F_HEAD, 14, "FFFFFF", True)
    rpr = badge._element.get_or_add_rPr()
    sh = OxmlElement('w:shd'); sh.set(qn('w:val'), 'clear')
    sh.set(qn('w:color'), 'auto'); sh.set(qn('w:fill'), accent)
    rpr.append(sh)
    set_run(p.add_run("   "), F_HEAD, 14, INK)
    set_run(p.add_run(title), F_HEAD, 24, accent, True)
    bottom_rule(p, accent, size=16)

    # Instrucción (sin keep_with_next para que la imagen pueda fluir si hace falta)
    p = para(doc, WD_ALIGN_PARAGRAPH.LEFT, after=6, before=6, line=1.2)
    set_run(p.add_run(instr), F_BODY, 14, INK)

    # Ilustración(es) — colocadas a su tamaño físico (stickers de 16 mm)
    images = img if isinstance(img, list) else [img]
    for k, im_name in enumerate(images):
        if k > 0:
            p = para(doc, WD_ALIGN_PARAGRAPH.LEFT, after=6, before=0, line=1.2, keep=True)
            p.paragraph_format.page_break_before = True
            set_run(p.add_run(f"{title} (continuación)"), F_HEAD, 16, accent, True)
        add_sticker_image(doc, im_name, max_h_cm=20.5)

# Pie final
para(doc, after=2, before=18)
p = para(doc, WD_ALIGN_PARAGRAPH.CENTER, after=0)
set_run(p.add_run("Hecho con amor · @_mi_dulce_emma"), F_HEAD, 12, SOFT, italic=True)

doc.save(OUT)
print("docx ->", os.path.relpath(OUT, BASE))
