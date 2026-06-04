# Rediseño inicial del libro de stickers

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
python3 -m pip install -r book_redesign/requirements.txt
python3 book_redesign/scripts/generate_book_redesign.py
```
