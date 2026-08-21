/// Barrel export for receipt layouts
///
/// Usage:
/// ```dart
/// import 'package:pos_machine/screens/print/layouts/layouts.dart';
///
/// final layout = ReceiptLayoutFactory.getLayout(config.activeTheme);
/// await layout.printThermal(params);
/// ```
library;

export 'receipt_layout.dart';
export 'receipt_layout_params.dart';
export 'receipt_configuration_contract.dart';
export 'contract_receipt_layout.dart';
export 'receipt_layout_factory.dart';
export 'classic_receipt_layout.dart';
export 'premium_receipt_layout.dart';
export 'standard_receipt_layout.dart';
export 'arabic_english_table_headers_receipt_layout.dart';
export 'arabic_and_english_3_receipt_layout.dart';
export 'multi_store_receipt_layout.dart';
export 'supermarket2_bilingual_receipt_layout.dart';
//export 'premium2_bilingual_receipt_layout.dart';
// Do not barrel-export these cloned layouts: they redefine shared helper
// classes (ThinDividerRow, DottedDividerRow, BoxedTotalsRow, BoxedLineItem)
// already exported from premium_receipt_layout.dart, which causes
// ambiguous_export. ReceiptLayoutFactory imports them directly.
// export 'mobile_shop_tax_invoice_receipt_layout.dart';
// export 'premium2_bilingual_receipt_layout.dart';
