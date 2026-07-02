# Mi Dulce Emma — Flyer Imprimible

## Usar tus imágenes reales

### Opción rápida (recomendada)
1. Guarda la imagen de referencia del flyer como `assets/referencia.jpg`
2. Ejecuta:
   ```bash
   ./export-pdf.sh
   ```
   Esto extrae automáticamente la **foto central**, el **fondo de pasto** y actualiza el logo.

### Logo
El logo se genera desde la ilustración real del libro de actividades (`libro_actividades_*.pdf`).

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `flyer.html` | Diseño del flyer |
| `Mi-Dulce-Emma-Flyer.pdf` | PDF para imprimir |
| `assets/logo.png` | Logo circular con ilustración real |
| `assets/foto-fondo.jpg` | Foto central (desde referencia) |
| `assets/fondo-pasto.jpg` | Fondo difuminado (desde referencia) |

## Impresión

- Tamaño: **A4** (210 × 297 mm)
- Papel couché 150–200 g, a color
- En Chrome: Imprimir → Guardar como PDF → márgenes: ninguno
