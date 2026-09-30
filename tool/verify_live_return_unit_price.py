"""Verify saved admin Unit price on/off cases and restoration."""
import json
import re
from pathlib import Path

import pdfplumber

audit = Path('build/receipt_live_audit')
before = json.loads((audit / 'baseline/return_unit_price_before.json').read_text(encoding='utf-8-sig'))['document_configurations']
after = json.loads((audit / 'return_unit_price_restored.json').read_text(encoding='utf-8-sig'))['document_configurations']
for configs in (before, after):
    for config in configs.values():
        config.pop('updated_at', None)
assert before == after, 'Configuration restoration differs beyond updated_at'

results = []
for case in ('on', 'off'):
    root = Path(f'build/receipt_live_render_return_unit_price_{case}_only_Return-Bill')
    manifest = json.loads((root / 'manifest.json').read_text())
    assert len(manifest) == 23
    for entry in manifest:
        if entry['kind'] != 'pdf':
            continue
        with pdfplumber.open(entry['files'][0]) as pdf:
            text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
        compact = re.sub(r'\s+', '', text)
        count = compact.count('LIVEUNITPRICE')
        assert count == (1 if case == 'on' else 0), (case, entry['theme'], count)
        # Unit price and the independently enabled Rate column repeat each rate.
        for rate in ('11.00', '5.00'):
            assert compact.count(rate) >= (2 if case == 'on' else 1), (case, entry['theme'], rate)
        results.append({'case': case, 'theme': entry['theme'], 'label_count': count})
assert len(results) == 12
(audit / 'return_unit_price_audit.json').write_text(json.dumps(results, indent=2))
print('12 PDF checks passed; all five configs restored except updated_at.')
