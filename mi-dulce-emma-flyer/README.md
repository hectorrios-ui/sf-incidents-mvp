# Mi Dulce Emma — Flyer Imprimible

Flyer en formato A4 listo para imprimir, basado en la identidad de **Mi Dulce Emma**.

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `flyer.html` | Diseño del flyer (abrir en navegador) |
| `Mi-Dulce-Emma-Flyer.pdf` | Versión exportada para imprimir |
| `assets/foto-fondo.jpg` | Foto central del flyer |
| `assets/fondo-pasto.jpg` | Textura de pasto para el fondo |
| `assets/logo.svg` | Logo (reemplazar con el tuyo) |
| `assets/qr-instagram.png` | Código QR a Instagram |

## Personalizar con tus imágenes

1. Reemplaza `assets/foto-fondo.jpg` con tu foto del grupo en el parque.
2. Reemplaza `assets/logo.svg` (o usa `logo.png`) con tu logo circular original.
3. Si usas PNG para el logo, cambia en `flyer.html` la ruta `assets/logo.svg` por `assets/logo.png`.

## Generar PDF

```bash
chmod +x export-pdf.sh
./export-pdf.sh
```

O abre `flyer.html` en Chrome → **Imprimir** → **Guardar como PDF** (tamaño A4, márgenes: ninguno).

## Impresión

- Tamaño: **A4** (210 × 297 mm)
- Papel: couché mate o brillante, 150–300 g
- Recomendado: imprimir a color con sangrado mínimo
