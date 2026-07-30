/// Barrel export for standard PDF receipt layouts
///
/// Usage:
/// ```dart
/// import 'package:pos_machine/screens/print/standard_layouts/standard_layouts.dart';
///
/// final layout = StandardPdfLayoutFactory.getLayout(activeTheme);
/// await layout.generateAndPrintPdf(params);
/// ```
library;

export 'standard_pdf_layout.dart';
export 'standard_pdf_layout_factory.dart';
export 'classic_standard_pdf_layout.dart';
export 'tax_invoice_standard_pdf_layout.dart';
export 'detailed_tax_invoice_standard_pdf_layout.dart';
export 'standard_tax_invoice_standard_pdf_layout.dart';
export 'new_classic_standad_pdf_layout.dart';
export 'simplified_tax_invoice_standard_pdf_layout.dart';
export 'centered_simplified_tax_invoice_standard_pdf_layout.dart';
export 'corporate_tax_invoice_standard_pdf_layout.dart';
export 'letterhead_tax_invoice_standard_pdf_layout.dart';
