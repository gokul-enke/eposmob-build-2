import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';

const _standardPdfThemes = <String>[
  'classic',
  'tax_invoice',
  'detailed_tax_invoice',
  'standard_tax_invoice',
  'new_classic',
  'simplified_tax_invoice',
  'centered_simplified_tax_invoice',
  'bilingual_centered_tax_invoice',
  'boxed_bilingual_tax_invoice',
  'boxed_header_tax_invoice',
  'corporate_tax_invoice',
  'letterhead_tax_invoice',
];

void main() {
  test('A4/A5 factory exposes all registered standard PDF themes', () {
    expect(
      StandardPdfLayoutFactory.availableThemes,
      orderedEquals(_standardPdfThemes),
    );
    expect(
      StandardPdfLayoutFactory.availableThemes.toSet().length,
      _standardPdfThemes.length,
    );

    for (final theme in _standardPdfThemes) {
      final layout = StandardPdfLayoutFactory.getLayout(theme);
      expect(layout.layoutId, theme);
      expect(layout.displayName.trim(), isNotEmpty, reason: theme);
    }
  });

  test('unknown or missing A4/A5 themes fall back to classic', () {
    expect(StandardPdfLayoutFactory.getLayout(null).layoutId, 'classic');
    expect(StandardPdfLayoutFactory.getLayout('does_not_exist').layoutId,
        'classic');
    expect(StandardPdfLayoutFactory.hasTheme('TAX_INVOICE'), isTrue);
  });
}
