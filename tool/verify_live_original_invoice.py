"""Verify saved original-invoice switch cases and exact config restoration."""
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

assert configs(audit / 'baseline/return_original_invoice_before.json') == configs(
    audit / 'return_original_invoice_restored.json'), 'Restoration differs beyond updated_at'
results = []
for case in ('on', 'off'):
    root = Path(f'build/receipt_live_render_return_original_invoice_{case}_builder_only_Return-Bill')
    manifest = json.loads((root / 'manifest.json').read_text())
    assert len(manifest) == 23
    for entry in manifest:
        if entry['kind'] != 'pdf':
            continue
        with pdfplumber.open(entry['files'][0]) as pdf:
            text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
        compact = re.sub(r'\s+', '', text)
        for value in ('SALE-789', '20-08-2026', 'LIVEORIGINALDATE'):
            assert compact.count(value) == (1 if case == 'on' else 0), (case, entry['theme'], value)
        assert compact.count('LIVEORIGINAL') == (2 if case == 'on' else 0), (case, entry['theme'])
        results.append({'case': case, 'theme': entry['theme'], 'passed': True})
assert len(results) == 12
(audit / 'original_invoice_live_audit.json').write_text(json.dumps(results, indent=2))
print('12 live-config PDF checks passed; all five configs restored except updated_at.')
