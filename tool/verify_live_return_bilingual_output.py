"""Audit saved live Return language cases, retaining failures for backend repair.

Checks configured English markers in six PDF themes per case. This does not
certify Arabic shaping, thermal pixels, store overrides, or hidden controls.
"""
import json
import re
from pathlib import Path

import pdfplumber


visible = {1, 2, 4, 5, 6, 7, 12, 19, 20, 21, 22, 25, 26, 27, 30,
           31, 32, 34, 36, 40, 41, 48, 49, 50, 51, 56, 57}
cases = {'both_filled': visible, 'empty_english': set(),
         'table_english': {31, 32, 34, 36, 40, 41}}
results = []
for case, fields in cases.items():
    root = Path(f'build/receipt_live_render_return_bilingual_{case}')
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
    assert len(manifest) == 69, f'Incomplete render: {case}'
    expected = {f'ER{i}X' for i in fields}
    entries = [e for e in manifest if e['document'] == 'Return Bill' and e['kind'] == 'pdf']
    assert len(entries) == 6
    for entry in entries:
        with pdfplumber.open(entry['files'][0]) as pdf:
            text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
        actual = set(re.findall(r'ER\d+X', re.sub(r'\s+', '', text)))
        results.append({'case': case, 'theme': entry['theme'],
                        'missing': sorted(expected - actual),
                        'unexpected': sorted(actual - expected)})

report = {'scope': __doc__, 'results': results}
Path('build/receipt_live_audit/return_bilingual_pdf_audit.json').write_text(
    json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
for case in cases:
    group = [r for r in results if r['case'] == case]
    failures = [r for r in group if r['missing'] or r['unexpected']]
    print(f'{case}: {len(group)-len(failures)}/{len(group)} PDF themes passed')
    if failures:
        print(json.dumps(failures[0], ensure_ascii=False))
raise SystemExit(1 if any(r['missing'] or r['unexpected'] for r in results) else 0)
