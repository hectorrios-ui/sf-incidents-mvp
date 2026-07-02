#!/usr/bin/env python3
from pathlib import Path
from playwright.sync_api import sync_playwright

DIR = Path(__file__).parent
HTML = DIR / "flyer.html"
PDF = DIR / "Mi-Dulce-Emma-Flyer.pdf"
PREVIEW = Path("/opt/cursor/artifacts/screenshots/mi-dulce-emma-flyer-preview.png")

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 794, "height": 1123})
    page.goto(HTML.as_uri(), wait_until="networkidle")
    page.pdf(path=str(PDF), format="A4", print_background=True, margin={"top": "0", "right": "0", "bottom": "0", "left": "0"})
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(PREVIEW), full_page=True)
    browser.close()

print(f"PDF: {PDF}")
print(f"Preview: {PREVIEW}")
