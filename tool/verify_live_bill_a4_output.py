"""Check saved Bill A4 live-admin markers across all six PDF themes.

This deliberately reports missing configured bank labels and bilingual document
headers as failures. Marker checks do not certify Arabic shaping or geometry.
"""
import json
import re
from pathlib import Path

import pdfplumber

visible = set(range(1, 52)) - {3, 4, 6, 7, 12, 15, 16, 22, 31, 51}
# 3 is the fallback footer, 4 the B2C title (fixture is B2B), 6/7/12/16/22/31
# have disabled switches; 15/51 contain numeric phone test values, not markers.
cases = {
    'english_filled': visible,
    'arabic_filled': set(),
    'bilingual_both_filled': visible,
    'bilingual_empty_english': set(),
    'bilingual_table_english': {20, 21, 23, 24, 25, 26, 27, 28},
}
results = []
for case, expected_fields in cases.items():
    root = Path(f'build/receipt_live_render_bill_a4_{case}')
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
    assert len(manifest) == 69
    entries = [e for e in manifest if e['document'] == 'Bill A4' and e['kind'] == 'pdf']
    assert len(entries) == 6
    expected = {f'A4E{i}X' for i in expected_fields}
    for entry in entries:
        with pdfplumber.open(entry['files'][0]) as pdf:
            text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
        actual = set(re.findall(r'A4E\d+X', re.sub(r'\s+', '', text)))
        results.append({'case': case, 'theme': entry['theme'],
                        'missing': sorted(expected - actual),
                        'unexpected': sorted(actual - expected)})
Path('build/receipt_live_audit/bill_a4_pdf_audit.json').write_text(
    json.dumps({'scope': __doc__, 'results': results}, indent=2), encoding='utf-8')
for case in cases:
    group = [r for r in results if r['case'] == case]
    failures = [r for r in group if r['missing'] or r['unexpected']]
    print(f'{case}: {len(group)-len(failures)}/6 PDF marker checks passed')
    if failures:
        print(json.dumps(failures[0]))
raise SystemExit(int(any(r['missing'] or r['unexpected'] for r in results)))
