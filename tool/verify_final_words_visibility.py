"""Check final-balance words and visibility in generated Sales/Return PDFs."""
import json
import re
import unicodedata
from pathlib import Path

import pdfplumber

results = []
for mask in (0, 8, 10):
    root = Path(f'build/receipt_output_matrix_full_final_{mask}_only_Sales-and-Return-Bill-A4')
    entries = json.loads((root / 'manifest.json').read_text())
    assert len(entries) == 30
    for entry in entries:
        with pdfplumber.open(entry['files'][0]) as pdf:
            text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
        text = re.sub(r'\s+', '', unicodedata.normalize('NFKC', text))
        # Embedded Arabic presentation forms are emitted in visual word order.
        phrases = ['NineteenRiyalsOnly.'] if entry['scenario'] == 'en' else [
            'تسعةعشرريالفقط.', 'ةعسترشعلاير.طقف']
        count = sum(text.count(phrase) for phrase in phrases)
        assert count == (0 if mask == 0 else 1), (mask, entry['id'], count, phrases)
        if entry['scenario'] in ('en', 'both'):
            assert 'EN72X' not in text and 'EN74X' not in text
            assert ('EN73X' in text) == (mask == 10)
        results.append({'mask': mask, 'id': entry['id'], 'final_words_count': count})
Path('build/final_words_visibility_audit.json').write_text(json.dumps(results, indent=2))
print('90 PDF checks passed: final words describe 40 - 21 = 19 and obey their own switch.')
