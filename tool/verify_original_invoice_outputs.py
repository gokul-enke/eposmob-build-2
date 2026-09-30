"""Check original-sale values and language labels in all return PDF themes."""
import json
import re
from pathlib import Path

import pdfplumber

root = Path('build/receipt_output_matrix_full_builder_only_Return-Bill')
manifest = json.loads((root / 'manifest.json').read_text())
assert len(manifest) == 115, len(manifest)
results = []
for entry in manifest:
    if entry['kind'] != 'pdf':
        continue
    with pdfplumber.open(entry['files'][0]) as pdf:
        text = ''.join(char['text'] for page in pdf.pages for char in page.chars)
    compact = re.sub(r'\s+', '', text)
    assert compact.count('SALE-789') == 1, entry
    assert compact.count('20-08-2026') == 1, entry
    scenario = entry['scenario']
    for marker in ('EN80X', 'EN81X'):
        assert compact.count(marker) == (1 if scenario in ('en', 'both') else 0), (entry, marker)
    results.append({'scenario': scenario, 'theme': entry['theme'], 'verified': True})
assert len(results) == 30, len(results)
(root / 'original_invoice_audit.json').write_text(json.dumps(results, indent=2))
print('30 PDF checks passed across all five language scenarios and six themes.')
