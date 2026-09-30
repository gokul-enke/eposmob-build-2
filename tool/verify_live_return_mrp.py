"""Verify live MRP configuration output and restoration."""
import json
import re
from pathlib import Path

import pdfplumber

audit = Path('build/receipt_live_audit')
def configs(path):
    value = json.loads(path.read_text(encoding='utf-8-sig'))['document_configurations']
    for config in value.values():
        config.pop('updated_at', None)
    return value

assert configs(audit / 'baseline/return_mrp_before.json') == configs(
    audit / 'return_mrp_restored.json'), 'Configuration restoration mismatch'
checks = []
for case in ('on', 'restored'):
    root = Path(f'build/receipt_live_render_return_mrp_{case}_builder_only_Return-Bill')
    entries = json.loads((root / 'manifest.json').read_text())
    assert len(entries) == 23
    for entry in entries:
        if entry['kind'] != 'pdf':
            continue
        with pdfplumber.open(entry['files'][0]) as pdf:
            text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
        compact = re.sub(r'\s+', '', text)
        assert ('LIVERETURNMRP' in compact) == (case == 'on'), entry
        assert ('24.00' in compact) == (case == 'on'), entry
        assert '21.00' in compact, entry
        checks.append({'case': case, 'theme': entry['theme'], 'passed': True})
assert len(checks) == 12
(audit / 'return_mrp_live_audit.json').write_text(json.dumps(checks, indent=2))
print('12 saved-config PDF MRP checks passed; all five configs restored except updated_at.')
