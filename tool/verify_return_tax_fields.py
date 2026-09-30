"""Check HSN and tax-rate data and language labels in every return PDF."""
import json
import re
from pathlib import Path
import pdfplumber

root = Path('build/receipt_output_matrix_full_builder_only_Return-Bill')
manifest = json.loads((root / 'manifest.json').read_text())
assert len(manifest) == 115
results = []
for entry in manifest:
    if entry['kind'] != 'pdf':
        continue
    with pdfplumber.open(entry['files'][0]) as pdf:
        text = ''.join(char['text'] for page in pdf.pages for char in page.chars)
    compact = re.sub(r'\s+', '', text)
    for value in ['090121', '090240', '18%', '0%']:
        assert compact.count(value) == 1, (entry['scenario'], entry['theme'], value)
    for marker in ['EN82X', 'EN83X']:
        # PDF tables repeat their headings when the returned lines span pages.
        assert (compact.count(marker) > 0) == (entry['scenario'] in ('en', 'both')), (entry, marker)
    results.append({'scenario': entry['scenario'], 'theme': entry['theme'], 'passed': True})
assert len(results) == 30
(root / 'return_tax_fields_audit.json').write_text(json.dumps(results, indent=2))
print('30 PDF HSN/tax-rate checks passed across all five language cases.')
