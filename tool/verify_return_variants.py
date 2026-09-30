"""Verify variant attributes on the synthetic two-item return PDFs."""
import json
import re
import sys
from pathlib import Path

import pdfplumber

root = Path(sys.argv[1] if len(sys.argv) > 1 else
            'build/receipt_output_matrix_full_builder_only_Return-Bill')
entries = [entry for entry in json.loads((root / 'manifest.json').read_text())
           if entry['kind'] == 'pdf' and entry['document'] == 'Return Bill']
assert len(entries) == 30
results = []
for entry in entries:
    with pdfplumber.open(entry['files'][0]) as pdf:
        text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
    compact = re.sub(r'\s+', '', text)
    for value in ['Large', 'Small']:
        assert compact.count(value) == 1, (entry['id'], value)
    results.append({'id': entry['id'], 'passed': True})
(root / 'return_variants_audit.json').write_text(json.dumps(results, indent=2))
print('30 return PDFs retain each fixture variant exactly once.')
