# Libro de Actividades con Stickers de Colores — Mi Dulce Emma

Versión **profesional, alegre y digital** del boceto original (hecho a mano),
recreada por completo con diseño vectorial y tipografías infantiles muy
legibles. Pensada para crecer hacia un **libro interactivo y digital**.

## ✨ Qué incluye

| Archivo | Descripción |
|---|---|
| `Libro_Actividades_Stickers_Mi_Dulce_Emma.docx` | **Documento Word editable** con las fuentes incrustadas (se ve igual en cualquier PC). |
| `Libro_Actividades_Stickers_Mi_Dulce_Emma.pdf` | Versión lista para ver/imprimir (idéntica al Word). |
| `assets/svg/` | **Ilustraciones vectoriales (SVG)** de cada actividad — base ideal para el libro interactivo. |
| `assets/png/` | Render de alta resolución de cada SVG (usado dentro del Word). |
| `fonts/` | Tipografías usadas (Baloo 2, Fredoka, Nunito — Google Fonts, licencia OFL). |
| `scripts/` | Código que genera todo, de forma reproducible. |

## 🎨 Diseño

- **Estilo:** plano (flat), moderno y amigable. Cada zona punteada `( + )`
  indica dónde el peque pega su sticker.
- **Paleta:** rojo, azul, amarillo y verde vivos (coherente con las
  actividades de asociación de color del original).
- **Tipografías** (llamativas pero muy claras para niños):
  - Títulos: **Baloo 2 ExtraBold**
  - Subtítulos: **Fredoka**
  - Texto: **Nunito**

## 📖 Contenido

Portada · ¡Hola! (presentación de Andrea) · ¿Qué trabajamos? + **18 actividades**:
Carritos, Corazones, Sol, Nube y lluvia, Árbol de manzanas, Oruguitas,
Arañitas, Cerezas, Huevos, Sandía, Flores, Arcoíris, Semáforo, Mariposa,
Mariquita, A contar mariquitas (conteo), Helado de chispas y Muchos/Pocos.

## 🔁 Regenerar todo

Requisitos: `python3`, `pip install python-docx cairosvg pillow fonttools` y
(opcional) LibreOffice para el PDF.

```bash
bash scripts/build_all.sh
```

El pipeline: **SVG → PNG → DOCX (con fuentes embebidas) → PDF**.

## 🚀 Hacia el libro interactivo / digital

Las ilustraciones son **SVG** (vectoriales): escalan sin perder calidad y cada
elemento es un objeto manipulable. Para un libro interactivo se pueden:

- Resaltar/animar las zonas punteadas como “sueltos” donde arrastrar stickers
  (drag & drop) en web (HTML5/Canvas/React) o en apps.
- Añadir validación de color (p. ej., solo acepta el sticker del color correcto).
- Reproducir sonidos o animaciones al completar cada actividad.

Es totalmente posible: este es justo el formato de origen recomendado para ello.
