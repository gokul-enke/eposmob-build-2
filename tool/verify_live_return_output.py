"""Check the saved, populated English Return Bill fixture, not synthetic labels.

Only checks visible translation markers in PDFs. Store-value overrides,
disabled credit-note fields, thermal pixels and other languages remain separate.
"""
import json
import re
from pathlib import Path

import pdfplumber

root = Path('build/receipt_live_render_return_english_filled')
manifest = json.loads((root / 'manifest.json').read_text())
assert len(manifest) == 69, 'Incomplete live-configuration render'
# Original admin switches enable these label fields. Footer ER3X is a fallback
# to the explicitly populated thank-you message ER56X, so is not required here.
expected = {f'ER{i}X' for i in [
    1, 2, 4, 5, 6, 7, 12, 19, 20, 21, 22, 25, 26, 27, 30,
    31, 32, 34, 36, 40, 41, 48, 49, 50, 51, 56, 57,
]}
results = []
for entry in manifest:
    if entry['kind'] != 'pdf' or entry['document'] != 'Return Bill':
        continue
    with pdfplumber.open(entry['files'][0]) as pdf:
        text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
    markers = set(re.findall(r'ER\d+X', re.sub(r'\s+', '', text)))
    results.append({'theme': entry['theme'],
                    'missing': sorted(expected - markers),
                    'unexpected': sorted(markers - expected)})
assert len(results) == 6
(root / 'english_marker_audit.json').write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))
assert all(not r['missing'] and not r['unexpected'] for r in results), results
