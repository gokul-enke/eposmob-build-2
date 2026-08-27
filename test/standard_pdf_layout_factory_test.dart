import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/standard_layouts/bilingual_centered_tax_invoice_standard_pdf_layout.dart';
import 'package:pos_machine/screens/print/standard_layouts/boxed_bilingual_tax_invoice_standard_pdf_layout.dart';
import 'package:pos_machine/screens/print/standard_layouts/boxed_header_tax_invoice_standard_pdf_layout.dart';
import 'package:pos_machine/screens/print/standard_layouts/centered_simplified_tax_invoice_standard_pdf_layout.dart';
import 'package:pos_machine/screens/print/standard_layouts/classic_standard_pdf_layout.dart';
import 'package:pos_machine/screens/print/standard_layouts/simplified_tax_invoice_standard_pdf_layout.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';

const _standardPdfThemes = <String>[
  'classic',
  'simplified_tax_invoice',
  'centered_simplified_tax_invoice',
  'bilingual_centered_tax_invoice',
  'boxed_bilingual_tax_invoice',
  'boxed_header_tax_invoice',
];

final _concreteTypes = <String, Type>{
  'classic': ClassicStandardPdfLayout,
  'simplified_tax_invoice': SimplifiedTaxInvoiceStandardPdfLayout,
  'centered_simplified_tax_invoice':
      CenteredSimplifiedTaxInvoiceStandardPdfLayout,
  'bilingual_centered_tax_invoice':
      BilingualCenteredTaxInvoiceStandardPdfLayout,
  'boxed_bilingual_tax_invoice': BoxedBilingualTaxInvoiceStandardPdfLayout,
  'boxed_header_tax_invoice': BoxedHeaderTaxInvoiceStandardPdfLayout,
};

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
      expect(layout.runtimeType, _concreteTypes[theme], reason: theme);
    }
  });

  test('unknown or missing A4/A5 themes fall back to classic', () {
    expect(StandardPdfLayoutFactory.getLayout(null).layoutId, 'classic');
    expect(StandardPdfLayoutFactory.getLayout('does_not_exist').layoutId,
        'classic');
    expect(StandardPdfLayoutFactory.hasTheme('TAX_INVOICE'), isFalse);
  });
}
