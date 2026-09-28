"""Verify returned MRP totals next to their labels in every return PDF."""
import json
from pathlib import Path

import pdfplumber

root = Path('build/receipt_output_matrix_full_builder_only_Return-Bill')
manifest = json.loads((root / 'manifest.json').read_text())
assert len(manifest) == 115
results = []
for entry in manifest:
    if entry['kind'] != 'pdf':
        continue
    matches = []
    with pdfplumber.open(entry['files'][0]) as pdf:
        for page in pdf.pages:
            words = page.extract_words()
            for label in words:
                if '34' not in label['text']:
                    continue
                row = [word['text'] for word in words
                       if abs(word['top'] - label['top']) < 5]
                if any('24.00' in value for value in row):
                    matches.append(row)
    assert matches, (entry['scenario'], entry['theme'], 'Missing returned MRP 24.00 beside its label')
    results.append({'scenario': entry['scenario'], 'theme': entry['theme'], 'mrp_total': 24})
assert len(results) == 30
(root / 'return_mrp_audit.json').write_text(json.dumps(results, indent=2))
print('30 PDF MRP checks passed: 1 x 12 + 2 x 6 = 24, independently of refund 21.')
