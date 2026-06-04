#!/usr/bin/env python3
"""
Embebe (incrusta) las fuentes TrueType dentro del .docx siguiendo el
mecanismo OOXML (fuentes ofuscadas .odttf), para que el documento se vea
idéntico en cualquier equipo aunque no tenga las fuentes instaladas.
"""
import os
import re
import uuid
import shutil
import zipfile

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(BASE, "fonts")
DOCX = os.path.join(BASE, "Libro_Actividades_Stickers_Mi_Dulce_Emma.docx")

# Familia (tal como se usa en el documento) -> {estilo: archivo}
FAMILIES = {
    "Baloo 2 ExtraBold": {"Regular": "Baloo2-ExtraBold.ttf"},
    "Fredoka": {"Regular": "Fredoka-Regular.ttf", "Bold": "Fredoka-Bold.ttf"},
    "Nunito": {"Regular": "Nunito-Regular.ttf", "Bold": "Nunito-Bold.ttf"},
}
STYLE_TAG = {
    "Regular": "w:embedRegular",
    "Bold": "w:embedBold",
    "Italic": "w:embedItalic",
    "BoldItalic": "w:embedBoldItalic",
}
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def obfuscate(data: bytes, guid_str: str) -> bytes:
    """XOR de los primeros 32 bytes con el GUID (orden de pantalla, invertido)."""
    hexd = guid_str.replace("-", "")
    key = bytes.fromhex(hexd)
    mask = key[::-1]
    out = bytearray(data)
    for i in range(32):
        out[i] ^= mask[i % 16]
    return bytes(out)


def main():
    rid = 0
    font_parts = {}      # zip path -> bytes (obfuscado)
    rels = []            # (relId, target)
    fonts_xml = []       # entradas <w:font>

    for family, styles in FAMILIES.items():
        embeds = []
        for style, fname in styles.items():
            rid += 1
            relId = f"rIdF{rid}"
            guid = str(uuid.uuid4()).upper()
            with open(os.path.join(FONTS, fname), "rb") as f:
                data = f.read()
            zippath = f"word/fonts/font{rid}.odttf"
            font_parts[zippath] = obfuscate(data, guid)
            rels.append((relId, f"fonts/font{rid}.odttf"))
            embeds.append(f'<{STYLE_TAG[style]} r:id="{relId}" '
                          f'w:fontKey="{{{guid}}}"/>')
        fonts_xml.append(
            f'<w:font w:name="{family}">'
            f'<w:charset w:val="00"/><w:family w:val="auto"/>'
            f'<w:pitch w:val="variable"/>'
            + "".join(embeds) + "</w:font>"
        )

    font_table = (
        "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n"
        '<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        f'xmlns:r="{R}">' + "".join(fonts_xml) + "</w:fonts>"
    )

    font_rels = (
        "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n"
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + "".join(f'<Relationship Id="{rid_}" Type="{R}/font" Target="{tgt}"/>'
                  for rid_, tgt in rels)
        + "</Relationships>"
    )

    # Reescribir el zip
    tmp = DOCX + ".tmp"
    with zipfile.ZipFile(DOCX, "r") as zin, \
         zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.namelist():
            data = zin.read(item)
            if item == "word/fontTable.xml":
                data = font_table.encode()
            elif item == "[Content_Types].xml":
                txt = data.decode()
                if "Extension=\"odttf\"" not in txt:
                    ins = ('<Default Extension="odttf" '
                           'ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"/>')
                    txt = txt.replace("<Default Extension=\"png\"",
                                      ins + "<Default Extension=\"png\"")
                data = txt.encode()
            elif item == "word/settings.xml":
                txt = data.decode()
                if "<w:embedTrueTypeFonts/>" not in txt:
                    add = '<w:embedTrueTypeFonts/><w:saveSubsetFonts w:val="false"/>'
                    # justo después de <w:zoom .../>
                    txt = re.sub(r"(<w:zoom[^/]*/>)", r"\1" + add, txt, count=1)
                data = txt.encode()
            zout.writestr(item, data)
        # añadir nuevas partes
        zout.writestr("word/_rels/fontTable.xml.rels", font_rels)
        for zippath, content in font_parts.items():
            zout.writestr(zippath, content)

    shutil.move(tmp, DOCX)
    print(f"Fuentes embebidas: {len(font_parts)} archivos .odttf")
    for f in font_parts:
        print("  +", f)


if __name__ == "__main__":
    main()
