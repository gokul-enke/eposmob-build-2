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
export 'contract_standard_pdf_layout.dart';
export 'standard_pdf_contract_delegate.dart';
export 'classic_standard_pdf_layout.dart';
export 'simplified_tax_invoice_standard_pdf_layout.dart';
export 'centered_simplified_tax_invoice_standard_pdf_layout.dart';
export 'bilingual_centered_tax_invoice_standard_pdf_layout.dart';
export 'boxed_bilingual_tax_invoice_standard_pdf_layout.dart';
export 'boxed_header_tax_invoice_standard_pdf_layout.dart';
