import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/models/document_configurations.dart';
import '../font_config.dart';
import 'base_totals_section.dart';

/// Builds the totals section of the thermal receipt
/// Includes: Items count, total qty, MRP total, discount, net amount
class TotalsSectionBuilder implements TotalsSection {
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

    debugPrint("===== BUILD TOTAL AMOUNT DEBUG =====");

    double saved = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(formattedTotal) ?? 0.0;
    double discountAmountValue =
        double.tryParse(discountAmount ?? '0.0') ?? 0.0;
    double totalMrp = saved + total;

    // Calculate total quantity
    double totalQuantity = 0.0;
    for (var item in cartItems) {
      if (isFromLocalStorage) {
        totalQuantity +=
            double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      } else {
        totalQuantity +=
            double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0;
      }
    }

    // Build left/right side items
    List<Map<String, String>> leftSideItems = [];
    List<Map<String, String>> rightSideItems = [];

    if (displayConfig?['showItemsCount']?.visible == true) {
      leftSideItems.add({
        'label': 'Items',
        'value': itemCount.toString(),
        'textSize': 'small',
        'bold': 'false',
        'fontType': 'fontA'
      });
    }

    leftSideItems.add({
      'label': 'Total Qty',
      'value': totalQuantity % 1 == 0
          ? totalQuantity.toInt().toString()
          : totalQuantity.toStringAsFixed(2),
      'textSize': 'small',
      'bold': 'false',
      'fontType': 'fontA'
    });

    if (displayConfig?['showMRPTotal']?.visible == true) {
      leftSideItems.add({
        'label': 'Total MRP',
        'value': totalMrp.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'false',
        'fontType': 'fontA'
      });
    }

    if (displayConfig?['showDiscount']?.visible == true) {
      final discountLabel =
          (displayConfig?['showDiscount']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showDiscount']!.value as String
              : 'Discount';

      rightSideItems.add({
        'label': discountLabel,
        'value': discountAmountValue.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'false',
        'fontType': 'fontA'
      });
    }

    // Add Tax row if visible
    if (displayConfig?['showTax']?.visible == true) {
      final taxLabel =
          (displayConfig?['showTax']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTax']!.value as String
              : (billDocumentConfig?.resolvedLabels?.tax?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.tax!
                  : 'Tax');

      rightSideItems.add({
        'label': taxLabel,
        'value': taxAmount.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'false',
        'fontType': 'fontA'
      });
    }

    if (displayConfig?['showNetAmount']?.visible == true) {
      final netTotalLabel =
          (displayConfig?['showNetAmount']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showNetAmount']!.value as String
              : 'Net Total';

      rightSideItems.add({
        'label': netTotalLabel,
        'value': total.toStringAsFixed(2),
        'textSize': 'big',
        'bold': 'true',
        'fontType': 'fontA'
      });
    }

    // Column widths
    int leftLabelWidth = 3;
    int leftValueWidth = paperSize == PaperSize.mm58 ? 3 : 2;
    int gapWidth = paperSize == PaperSize.mm58 ? 0 : 2;
    int rightLabelWidth = 3;
    int rightValueWidth = paperSize == PaperSize.mm58 ? 3 : 2;

    int maxRows = leftSideItems.length > rightSideItems.length
        ? leftSideItems.length
        : rightSideItems.length;

    for (int i = 0; i < maxRows; i++) {
      List<PosColumn> columns = [];

      // Left side
      if (i < leftSideItems.length) {
        final leftItem = leftSideItems[i];
        PosTextSize textSize = leftItem['textSize'] == 'big'
            ? ThermalFontConfig.textSizeBig
            : leftItem['textSize'] == 'medium'
                ? ThermalFontConfig.textSizeMedium
                : ThermalFontConfig.textSizeSmall;
        bool isBold = leftItem['bold'] == 'true';
        PosFontType itemFontType = leftItem['fontType'] == 'fontA'
            ? PosFontType.fontA
            : PosFontType.fontB;

        columns.add(PosColumn(
            text: '${leftItem['label']!}: ',
            width: leftLabelWidth,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.left,
                bold: isBold,
                height: textSize)));
        columns.add(PosColumn(
            text: leftItem['value']!,
            width: leftValueWidth,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.right,
                bold: true,
                height: textSize)));
      } else {
        columns.add(PosColumn(
            text: '',
            width: leftLabelWidth,
            styles: PosStyles(fontType: fontType)));
        columns.add(PosColumn(
            text: '',
            width: leftValueWidth,
            styles: PosStyles(fontType: fontType)));
      }

      // Gap
      if (gapWidth > 0) {
        columns.add(PosColumn(
            text: '', width: gapWidth, styles: PosStyles(fontType: fontType)));
      }

      // Right side
      if (i < rightSideItems.length) {
        final rightItem = rightSideItems[i];
        PosTextSize textSize = rightItem['textSize'] == 'big'
            ? ThermalFontConfig.textSizeBig
            : rightItem['textSize'] == 'medium'
                ? ThermalFontConfig.textSizeMedium
                : ThermalFontConfig.textSizeSmall;
        bool isBold = rightItem['bold'] == 'true';
        PosFontType itemFontType = rightItem['fontType'] == 'fontA'
            ? PosFontType.fontA
            : PosFontType.fontB;

        columns.add(PosColumn(
            text: '${rightItem['label']!}: ',
            width: rightLabelWidth,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.left,
                bold: isBold,
                height: textSize,
                width: textSize)));
        columns.add(PosColumn(
            text: rightItem['value']!,
            width: rightValueWidth,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.right,
                bold: isBold,
                height: textSize,
                width: textSize)));
      } else {
        columns.add(PosColumn(
            text: '',
            width: rightLabelWidth,
            styles: PosStyles(fontType: fontType)));
        columns.add(PosColumn(
            text: '',
            width: rightValueWidth,
            styles: PosStyles(fontType: fontType)));
      }

      bytes += generator.row(columns);
    }

    // You Saved message
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      bytes += generator.emptyLines(1);
      bytes += generator.text('You Saved: ${saved.toStringAsFixed(2)}',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: ThermalFontConfig.textSizeSmall,
              width: ThermalFontConfig.textSizeSmall));
    }

    // Separator
    if ((displayConfig?['showItemsCount']?.visible == true) ||
        (displayConfig?['showMRPTotal']?.visible == true) ||
        (displayConfig?['showSaved']?.visible == true && saved > 0) ||
        (displayConfig?['showDiscount']?.visible == true) ||
        (displayConfig?['showNetAmount']?.visible == true)) {
      bytes += generator.hr();
    }

    debugPrint("===== END BUILD TOTAL AMOUNT DEBUG =====");
    return bytes;
  }
}
