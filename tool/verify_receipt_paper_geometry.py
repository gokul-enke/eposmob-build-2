"""Check page/raster sizes and PDF glyph bounds, not visual readability."""
import json
import sys
from pathlib import Path

import pdfplumber
from PIL import Image

root = Path(sys.argv[1])
manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
assert len(manifest) == 345
results = []
for entry in manifest:
    failures = []
    dimensions = []
    for filename in entry['files']:
        if entry['kind'] == 'thermal':
            with Image.open(filename) as image:
                dimensions.append(list(image.size))
                expected = {'58mm': 384, '80mm': 576, '112mm': 832}[entry['paper']]
                if image.width != expected or image.height <= 0:
                    failures.append({'wrong_raster_size': list(image.size)})
        else:
            with pdfplumber.open(filename) as pdf:
                expected = {'A4': (595.276, 841.89), 'A5': (419.528, 595.276)}[entry['paper']]
                for number, page in enumerate(pdf.pages, 1):
                    dimensions.append([page.width, page.height])
                    if any(abs(a - b) > 1 for a, b in zip(dimensions[-1], expected)):
                        failures.append({'page': number, 'wrong_page_size': dimensions[-1]})
                    out = [c for c in page.chars if c['text'].strip() and (
                        c['x0'] < -1 or c['x1'] > page.width + 1
                        or c['top'] < -1 or c['bottom'] > page.height + 1)]
                    if out:
                        failures.append({'page': number, 'outside_page_glyphs': len(out),
                                         'sample': ''.join(c['text'] for c in out[:80])})
    results.append({'id': entry['id'], 'paper': entry['paper'],
                    'dimensions': dimensions, 'failures': failures})
report = {'scope': __doc__, 'outputs': len(results),
          'failed_outputs': sum(bool(r['failures']) for r in results), 'results': results}
(root / 'paper_geometry_audit.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(f"{report['outputs']} outputs; {report['failed_outputs']} failed geometry checks")
for row in results:
    if row['failures']:
        print(row['id'], row['failures'])
sys.exit(bool(report['failed_outputs']))
