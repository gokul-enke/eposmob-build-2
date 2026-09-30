"""Check that only the seven configured English return headings print."""
import json
import re
import sys
from pathlib import Path

import pdfplumber

root = Path(sys.argv[1])
entries = [entry for entry in json.loads((root / 'manifest.json').read_text())
           if entry['kind'] == 'pdf' and entry['scenario'] == 'table_en'
           and entry['document'] == 'Return Bill']
assert len(entries) == 6
expected = {f'EN{i}X' for i in [62, 63, 64, 65, 66, 67, 79]}
results = []
for entry in entries:
    with pdfplumber.open(entry['files'][0]) as pdf:
        text = ''.join(c['text'] for p in pdf.pages for c in p.chars)
    compact = re.sub(r'\s+', '', text)
    actual = set(re.findall(r'EN\d+X', compact))
    assert actual == expected, (entry['id'], sorted(expected - actual),
                                sorted(actual - expected))
    for value in ['090121', '090240', '18%', '0%']:
        assert compact.count(value) == 1, (entry['id'], value)
    results.append({'id': entry['id'], 'english_markers': sorted(actual)})
(root / 'selected_return_english_audit.json').write_text(
    json.dumps(results, indent=2))
print('All six PDFs contain exactly the seven selected English return headings.')
