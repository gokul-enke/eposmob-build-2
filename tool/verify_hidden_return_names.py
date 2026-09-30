"""Check return PDFs with particulars disabled and serial numbers enabled."""
import json
import re
import sys
from pathlib import Path

import pdfplumber

root = Path(sys.argv[1])
entries = [entry for entry in json.loads((root / 'manifest.json').read_text())
           if entry['kind'] == 'pdf' and entry['document'] == 'Return Bill']
assert len(entries) == 30
results = []
for entry in entries:
    with pdfplumber.open(entry['files'][0]) as pdf:
        text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
    compact = re.sub(r'\s+', '', text)
    for hidden in ['Coffee', 'Tea', 'EN63X']:
        assert hidden not in compact, (entry['id'], hidden)
    for retained in ['090121', '090240', '18%', '0%']:
        assert compact.count(retained) == 1, (entry['id'], retained)
    if entry['scenario'] in ['en', 'both', 'table_en']:
        assert 'EN62X' in compact, (entry['id'], 'serial heading missing')
    results.append({'id': entry['id'], 'passed': True})
(root / 'hidden_return_names_audit.json').write_text(json.dumps(results, indent=2))
print('30 PDF visibility checks passed: product names hidden; serial heading and classification retained.')
