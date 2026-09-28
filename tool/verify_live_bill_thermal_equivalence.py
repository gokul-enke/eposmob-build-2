"""Verify all live Bill themes rendered and standard aliases are pixel-identical.

This is not a text/OCR or visual correctness assertion. It establishes which
images are equivalent so visual review can cover three distinct renderers per
language case without counting aliases as independent designs.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image


cases = ['english_filled', 'arabic_filled', 'bilingual_both_filled',
         'bilingual_empty_english', 'bilingual_table_english']
report = []
for case in cases:
    root = Path(f'build/receipt_live_render_bill_1102_{case}_only_Bill')
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
    assert len(manifest) == 17 and len({e['theme'] for e in manifest}) == 17
    digests = {}
    for entry in manifest:
        assert entry['document'] == 'Bill' and entry['kind'] == 'thermal'
        assert entry['files']
        image_hashes = []
        for filename in entry['files']:
            with Image.open(filename) as image:
                pixels = image.convert('RGBA')
                assert pixels.width > 0 and pixels.height > 0
                payload = str(pixels.size).encode() + pixels.tobytes()
                image_hashes.append(hashlib.sha256(payload).hexdigest())
        digests[entry['theme']] = image_hashes
    aliases = [name for name in digests if name not in ('premium', 'premium2_bilingual')]
    assert len(aliases) == 15
    mismatches = [name for name in aliases if digests[name] != digests['standard']]
    report.append({'case': case, 'standard_aliases': aliases,
                   'mismatches': mismatches,
                   'visual_review_files': {
                       e['theme']: e['files'] for e in manifest
                       if e['theme'] in ('standard', 'premium', 'premium2_bilingual')},
                   'pixel_hashes': digests})
    print(f'{case}: 17 outputs; {15-len(mismatches)}/15 standard aliases identical')
Path('build/receipt_live_audit/bill_1102_thermal_equivalence.json').write_text(
    json.dumps({'scope': __doc__, 'cases': report}, indent=2), encoding='utf-8')
raise SystemExit(int(any(case['mismatches'] for case in report)))
