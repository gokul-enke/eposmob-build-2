import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/resources/localization_service.dart';
import '../font_config.dart';
import '../printer_utils.dart';

/// Builds the cart items section of the thermal receipt
/// Includes: Table header and item rows with MRP, qty, rate, total
class CartItemsSectionBuilder {
  final ThermalPrinterUtils printerUtils;

  CartItemsSectionBuilder({ThermalPrinterUtils? utils})
      : printerUtils = utils ?? ThermalPrinterUtils();

  List<int> build(
    Generator generator,
    List<dynamic> cartItems,
    Map<String, DisplayOption>? displayConfig,
    bool isFromLocalStorage,
    String selectedPaperSize,
    DocumentConfig? billDocumentConfig,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    final isArabic = LocalizationService.locale.languageCode == 'ar';
    bool is58mm = selectedPaperSize == '58mm';

    debugPrint("===== BUILD CART ITEMS DEBUG =====");
    debugPrint("Cart items count: ${cartItems.length}");

    // Build table headers
    List<PosColumn> headerColumns = [];

    if (displayConfig?['showSLNumber']?.visible == true) {
      final slLabel =
          (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSLNumber']!.value as String
              : (billDocumentConfig?.resolvedLabels?.slNumber?.isNotEmpty ==
                      true
                  ? billDocumentConfig!.resolvedLabels!.slNumber!
                  : 'SL#');
      headerColumns.add(PosColumn(
          text: slLabel,
          width: 1,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.getBodySize(is58mm))));
    }

    if (displayConfig?['showParticulars']?.visible == true) {
      final label = (displayConfig?['showParticulars']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showParticulars']!.value as String
          : (billDocumentConfig?.resolvedLabels?.particulars?.isNotEmpty == true
              ? billDocumentConfig!.resolvedLabels!.particulars!
              : 'PARTICULARS');
      int particularsWidth = 3;
      if (displayConfig?['showSLNumber']?.visible != true) {
        particularsWidth += 1;
      }
      if (displayConfig?['showMRP']?.visible != true) {
        particularsWidth += 2;
      }
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: particularsWidth,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.getBodySize(is58mm))));
    }

    if (displayConfig?['showMRP']?.visible == true) {
      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : (billDocumentConfig?.resolvedLabels?.mrp?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.mrp!
                  : 'MRP');
      headerColumns.add(PosColumn(
          text: mrpLabel.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.getBodySize(is58mm))));
    }

    if (displayConfig?['showQty']?.visible == true) {
      final label =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : (billDocumentConfig?.resolvedLabels?.qty?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.qty!
                  : 'QTY');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.getBodySize(is58mm))));
    }

    if (displayConfig?['showRate']?.visible == true) {
      final label =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : (billDocumentConfig?.resolvedLabels?.rate?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.rate!
                  : 'RATE');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.getBodySize(is58mm))));
    }

    if (displayConfig?['showTotal']?.visible == true) {
      final label =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : (billDocumentConfig?.resolvedLabels?.total?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.total!
                  : 'TOTAL');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.getBodySize(is58mm))));
    }

    if (headerColumns.isNotEmpty) {
      bytes += generator.row(headerColumns);
      bytes += generator.hr();
    }

    // Process each cart item
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';

      if (isFromLocalStorage) {
        productName = item['productName'] ?? '';
        mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        quantity = item['quantity'] ?? '0';
        unitPrice =
            (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
        totalPrice =
            (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
      } else {
        productName = item.productName ?? '';
        mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        totalPrice =
            (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
      }

      String slNumber = (i + 1).toString();

      // Product Name Row
      if (displayConfig?['showParticulars']?.visible == true ||
          displayConfig?['showSLNumber']?.visible == true) {
        int maxCharsPerLine = 40;

        String leftColumnText = '';
        if (displayConfig?['showSLNumber']?.visible == true &&
            displayConfig?['showParticulars']?.visible == true) {
          leftColumnText =
              '$slNumber ${printerUtils.sanitizeText(productName, isArabic: isArabic)}';
        } else if (displayConfig?['showSLNumber']?.visible == true) {
          leftColumnText = slNumber;
        } else {
          leftColumnText =
              printerUtils.sanitizeText(productName, isArabic: isArabic);
        }

        if (leftColumnText.length <= maxCharsPerLine) {
          bytes += generator.row([
            PosColumn(
                text: leftColumnText,
                width: 11,
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.left,
                    bold: false,
                    height: ThermalFontConfig.getBodySize(is58mm))),
            PosColumn(
                text: '',
                width: 1,
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.right,
                    bold: false,
                    height: ThermalFontConfig.getBodySize(is58mm))),
          ]);
        } else {
          // Text wrapping
          String remainingText = leftColumnText;
          while (remainingText.isNotEmpty) {
            String currentLine;
            if (remainingText.length <= maxCharsPerLine) {
              currentLine = remainingText;
              remainingText = '';
            } else {
              int breakPoint = maxCharsPerLine;
              for (int j = maxCharsPerLine - 1;
                  j >= maxCharsPerLine - 10 && j >= 0;
                  j--) {
                if (j < remainingText.length && remainingText[j] == ' ') {
                  breakPoint = j;
                  break;
                }
              }
              currentLine = remainingText.substring(0, breakPoint).trim();
              remainingText = remainingText.substring(breakPoint).trim();
            }
            bytes += generator.row([
              PosColumn(
                  text: currentLine,
                  width: 11,
                  styles: PosStyles(
                      fontType: fontType,
                      align: PosAlign.left,
                      bold: false,
                      height: ThermalFontConfig.getBodySize(is58mm))),
              PosColumn(
                  text: '',
                  width: 1,
                  styles: PosStyles(
                      fontType: fontType,
                      align: PosAlign.right,
                      bold: false,
                      height: ThermalFontConfig.getBodySize(is58mm))),
            ]);
          }
        }
      }

      // Price details row
      List<PosColumn> priceDetailsRow = [];
      int emptySpaceWidth = 4;
      if (displayConfig?['showMRP']?.visible != true) {
        emptySpaceWidth += 2;
      }
      priceDetailsRow.add(PosColumn(
          text: '',
          width: emptySpaceWidth,
          styles: PosStyles(fontType: fontType, align: PosAlign.left)));

      if (displayConfig?['showMRP']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: mrp,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.getBodySize(is58mm))));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: quantity,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.getBodySize(is58mm))));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: unitPrice,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.getBodySize(is58mm))));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: totalPrice,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.getBodySize(is58mm))));
      }

      if (priceDetailsRow.isNotEmpty) {
        bytes += generator.row(priceDetailsRow);
      }
    }

    bytes += generator.hr();
    debugPrint("===== END BUILD CART ITEMS DEBUG =====");
    return bytes;
  }
}
