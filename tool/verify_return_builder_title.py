"""Verify configured B2B titles survive the production return builder."""
import json
import re
from pathlib import Path

import pdfplumber
from PIL import Image

root = Path('build/receipt_output_matrix_full_builder_only_Return-Bill')
manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
assert len(manifest) == 115 and len({e['id'] for e in manifest}) == 115
results = []
for case in ['en', 'ar', 'both', 'empty_en', 'table_en']:
    entries = [e for e in manifest if e['scenario'] == case]
    assert sum(e['kind'] == 'pdf' for e in entries) == 6
    assert sum(e['kind'] == 'thermal' for e in entries) == 17
    for entry in entries:
        if entry['kind'] == 'thermal':
            for filename in entry['files']:
                with Image.open(filename) as image:
                    assert image.width == 576 and image.height > 0
            continue
        with pdfplumber.open(entry['files'][0]) as pdf:
            text = ''.join(c['text'] for page in pdf.pages for c in page.chars)
        compact = re.sub(r'\s+', '', text)
        expected = 1 if case in ('en', 'both') else 0
        count = compact.count('EN31X')
        assert count == expected, (entry['id'], count, expected)
        assert 'SalesReturn' not in compact
        if case in ('ar', 'empty_en', 'table_en'):
            assert not re.search(r'EN\d+X', compact), entry['id']
        results.append({'id': entry['id'], 'configured_english_title_count': count})
(root / 'builder_title_audit.json').write_text(json.dumps({
    'scope': __doc__ + ' Thermal dimensions verified; raster titles require visual review.',
    'pdf_checks': results}, indent=2), encoding='utf-8')
print(f'{len(results)} PDF title checks passed; 85 thermal outputs have valid dimensions')
