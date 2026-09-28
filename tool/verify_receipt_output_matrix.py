"""Inspect generated PDF text; raster/visual and live-admin checks remain separate."""
import json
import re
import sys
from pathlib import Path

import pdfplumber


root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/receipt_output_matrix_full')
manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
if len(manifest) != 345 or len({entry['id'] for entry in manifest}) != 345:
    raise AssertionError('Expected all 345 unique renderer cases before auditing')
results = []
for entry in manifest:
    if '_pdf_' not in entry['id']:
        continue
    with pdfplumber.open(entry['files'][0]) as pdf:
        text = '\n'.join(page.extract_text() or '' for page in pdf.pages)
        drawing_text = ''.join(char['text'] for page in pdf.pages for char in page.chars)
        pages = len(pdf.pages)
    # Content-stream order keeps wrapped markers together; spatial line order
    # interleaves other columns between a marker's first line and its suffix.
    markers = sorted(set(re.findall(r'EN\d+X', re.sub(r'\s+', '', drawing_text))),
                     key=lambda s: int(s[2:-1]))
    case = entry['scenario']
    if entry['document'] != 'Return Bill' and case in ('en', 'both'):
        missing_totals = {'EN34X', 'EN49X'} - set(markers)
        if missing_totals:
            raise AssertionError(f"{entry['id']}: missing independent MRP/subtotal labels {sorted(missing_totals)}")
    allowed_table = {'EN37X', 'EN41X', 'EN43X', 'EN46X', 'EN52X', 'EN57X', 'EN58X'}
    unexpected = markers if case in ('ar', 'empty_en') else []
    if 'Return' in entry['document'] and case in ('en', 'both'):
        required_return = {f'EN{i}X' for i in range(62, 72)}
        required_return.update({'EN76X', 'EN77X', 'EN78X', 'EN79X'})
        missing_return = required_return - set(markers)
        if missing_return:
            raise AssertionError(f"{entry['id']}: missing return fields {sorted(missing_return)}")
    if entry['document'] == 'Sales and Return Bill A4' and case in ('en', 'both'):
        missing_final = {'EN72X', 'EN73X', 'EN74X'} - set(markers)
        if missing_final:
            raise AssertionError(f"{entry['id']}: missing final summary fields {sorted(missing_final)}")
    if case == 'table_en' and entry['document'] != 'Return Bill' and set(markers) != allowed_table:
        raise AssertionError(f"{entry['id']}: selective-English labels differ: {markers}")
    results.append(dict(id=entry['id'], pages=pages, english_markers=markers,
                        document=entry['document'], scenario=case,
                        unexpected_english_markers=unexpected))
differences = []
for document in {r['document'] for r in results}:
    for case in ('en', 'ar', 'both', 'empty_en', 'table_en'):
        group = [r for r in results if r['document'] == document and r['scenario'] == case]
        if not group:
            continue
        union = set().union(*(set(r['english_markers']) for r in group))
        for result in group:
            missing = sorted(union - set(result['english_markers']))
            if missing:
                differences.append({'id': result['id'], 'missing_vs_other_themes': missing})
report = {'scope': 'PDF text only; does not prove visual or live configuration correctness',
          'theme_differences': differences, 'pdfs': results}
(root / 'pdf_text_audit.json').write_text(
    json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(report, indent=2, ensure_ascii=False))
if differences or any(r['unexpected_english_markers'] for r in results):
    sys.exit(1)
