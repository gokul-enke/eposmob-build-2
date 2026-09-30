"""Check saved five-case Return Bill PDFs for isolated table headers.

This checks the current two-line fixture, not arbitrary receipt lengths.
Arabic glyph extraction can be in visual order, so accept both observed orders.
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

import pdfplumber

root = Path(sys.argv[1] if len(sys.argv) > 1 else
            'build/receipt_output_matrix_full_builder_only_Return-Bill')
entries = [entry for entry in json.loads((root / 'manifest.json').read_text())
           if entry['kind'] == 'pdf' and entry['document'] == 'Return Bill']
assert len(entries) == 30
results = []
for entry in entries:
    header_pages = 0
    with pdfplumber.open(entry['files'][0]) as pdf:
        for number, page in enumerate(pdf.pages, 1):
            text = re.sub(r'\s+', '', unicodedata.normalize(
                'NFKC', ''.join(char['text'] for char in page.chars)))
            header = any(marker in text for marker in (
                'EN63X', 'عربي63', '63عربي', 'يبرع63', '63يبرع'))
            data = '090121' in text or '090240' in text
            if header:
                header_pages += 1
                assert data, (entry['id'], number, 'isolated table header')
            results.append({'id': entry['id'], 'page': number,
                            'header': header, 'data': data})
    assert header_pages, (entry['id'], 'header detection failed')
(root / 'return_pagination_audit.json').write_text(json.dumps(results, indent=2))
print(f'Checked {len(entries)} PDFs / {len(results)} pages: '
      'every detected return-table header shares its page with an item.')
