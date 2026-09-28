"""Verify explicit zero, formatted refund, and missing-total fallback prints."""
import json
import re
from pathlib import Path

import pdfplumber

results = []
for case in ('missing', 'comma', 'zero'):
    for document, expected_count in [('Return-Bill', 23), ('Sales-and-Return-Bill-A4', 6)]:
        root = Path(f'build/receipt_output_matrix_full_total_{case}_lang_en_only_{document}')
        entries = json.loads((root / 'manifest.json').read_text())
        assert len(entries) == expected_count
        for entry in entries:
            if entry['kind'] != 'pdf':
                continue
            with pdfplumber.open(entry['files'][0]) as pdf:
                text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
            text = re.sub(r'\s+', '', text)
            refund_words = 'ZeroRiyalsOnly.' if case == 'zero' else 'TwentyOneRiyalsOnly.'
            assert text.count(refund_words) == 1, (case, entry['id'], refund_words)
            if document.startswith('Sales'):
                assert text.count('NineteenRiyalsOnly.') == (0 if case == 'zero' else 1)
                assert text.count('FortyRiyalsOnly.') == (2 if case == 'zero' else 1)
            results.append({'case': case, 'id': entry['id'], 'refund_words': refund_words})
assert len(results) == 36
Path('build/return_total_cases_audit.json').write_text(json.dumps(results, indent=2))
print('36 PDF checks passed: refund/final words agree for missing, formatted and explicit-zero totals.')
