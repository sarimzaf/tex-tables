"""Rasterize current example PDFs. Optional: pypdfium2 and Pillow."""
import json
from pathlib import Path
import re
import pypdfium2 as pdfium
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "examples" / "stata"
OUT = EXAMPLES / "output"
QA = OUT / "visual-qa"
QA.mkdir(exist_ok=True)
names = json.loads((EXAMPLES / "manifest.json").read_text(encoding="utf-8"))
pages, report = [], {}
# Remove only this helper's generated page/contact images, including obsolete pages.
# Never recursively delete the QA folder or unrelated images.
for p in QA.iterdir():
    own_page = any(re.fullmatch(re.escape(n) + r"-\d+\.png", p.name) for n in names)
    if p.is_file() and (own_page or re.fullmatch(r"contact-\d+\.png", p.name)):
        p.unlink()
for name in names:
    pdf = pdfium.PdfDocument(str(OUT / f"{name}-preview.pdf"))
    report[name] = len(pdf)
    for i in range(len(pdf)):
        page = pdf[i]
        img = page.render(scale=1.5).to_pil()
        img.save(QA / f"{name}-{i+1}.png")
        thumb = img.copy()
        thumb.thumbnail((590, 820))
        pages.append((f"{name} / page {i+1}", thumb))
        page.close()
    pdf.close()
for start in range(0, len(pages), 4):
    sheet = Image.new("RGB", (1240, 1740), "#d9dde2")
    draw = ImageDraw.Draw(sheet)
    for k, (label, img) in enumerate(pages[start:start+4]):
        x, y = 20 + (k % 2)*620, 15 + (k // 2)*870
        draw.text((x, y), label, fill="black")
        sheet.paste(img, (x, y+25))
    sheet.save(QA / f"contact-{start//4+1}.png")
(QA / "pages.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report))
