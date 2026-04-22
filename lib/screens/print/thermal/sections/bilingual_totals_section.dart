import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/models/document_configurations.dart';
import '../font_config.dart';
import 'base_totals_section.dart';

/// Bilingual Totals Section Builder
/// Matches design with labels on right (Arabic + English) and amounts on left
class BilingualTotalsBuilder implements TotalsSection {
  @override
  List<int> build(
    Generator generator,
    Map<String, DisplayOption>? displayConfig,
    String formattedTotal,
    String? savedTotal,
    String? discountAmount,
    int itemCount,
    DocumentConfig? billDocumentConfig,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    PosFontType fontType,
    PaperSize paperSize,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double taxAmount,
  ) {
    List<int> bytes = [];
    bool is58mm = paperSize == PaperSize.mm58;
    PosTextSize textSize = ThermalFontConfig.textSizeSmall;

    double saved = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(formattedTotal) ?? 0.0;
    double discount = double.tryParse(discountAmount ?? '0.0') ?? 0.0;
    double subtotal = total + discount;

    // 1. Subtotal
    bytes += _buildBilingualRow(
      generator,
      'SUBTOTAL المجموع',
      subtotal.toStringAsFixed(2),
      textSize,
      fontType,
      is58mm,
    );

    // 2. Discounts
    if (discount > 0) {
      final discountLabel =
          (displayConfig?['showDiscount']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showDiscount']!.value as String
              : "DISCOUNTS الخصم";

      bytes += _buildBilingualRow(
        generator,
        discountLabel,
        discount.toStringAsFixed(2),
        textSize,
        fontType,
        is58mm,
      );
    }

    // 3. Tax / VAT
    final taxLabel =
        (displayConfig?['showTax']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showTax']!.value as String
            : (billDocumentConfig?.resolvedLabels?.tax?.isNotEmpty == true
                ? billDocumentConfig!.resolvedLabels!.tax!
                : "Tax");

    bytes += _buildBilingualRow(
      generator,
      taxLabel,
      taxAmount.toStringAsFixed(2),
      textSize,
      fontType,
      is58mm,
    );

    // 4. Grand Total
    final netTotalLabel =
        (displayConfig?['showNetAmount']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showNetAmount']!.value as String
            : "GRAND TOTAL المبلغ الاجمالي";

    bytes += generator.emptyLines(1);
    bytes += _buildBilingualRow(
      generator,
      netTotalLabel,
      total.toStringAsFixed(2),
      textSize,
      fontType,
      is58mm,
      bold: true,
    );

    bytes += generator.hr();

    // 5. Payments (Example)
    bytes += _buildBilingualRow(
      generator,
      'Cash',
      total.toStringAsFixed(2),
      textSize,
      fontType,
      is58mm,
    );

    bytes += _buildBilingualRow(
      generator,
      'CHANGE متبقي',
      '0.00',
      textSize,
      fontType,
      is58mm,
    );

    return bytes;
  }

  List<int> _buildBilingualRow(
    Generator generator,
    String label,
    String value,
    PosTextSize textSize,
    PosFontType fontType,
    bool is58mm, {
    bool bold = false,
  }) {
    // Value on Left (Column 0-4), Label on Right (Column 5-11)
    return generator.row([
      PosColumn(
        text: value,
        width: 4,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: bold,
          height: textSize,
        ),
      ),
      PosColumn(
        text: label,
        width: 8,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: bold,
          height: textSize,
        ),
      ),
    ]);
  }
}
