import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import '../font_config.dart';
import '../printer_utils.dart';

/// Builds the order returns section of the thermal receipt
/// Includes: Returns heading, return items table, return summary
class ReturnsSectionBuilder {
  final ThermalPrinterUtils printerUtils;

  ReturnsSectionBuilder({ThermalPrinterUtils? utils})
      : printerUtils = utils ?? ThermalPrinterUtils();

  List<int> build(
    Generator generator,
    OrderReturns orderReturns,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    String selectedPaperSize,
    PosFontType fontType,
    Map<String, DisplayOption>? displayConfig,
    DocumentConfig? billDocumentConfig, {
    String returnsSectionHeading = 'RETURNS',
    String? orderNumber,
    String? orderDate,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    List<int> bytes = [];

    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return bytes;
    }

    debugPrint("===== BUILD ORDER RETURNS SECTION =====");
    debugPrint("Return items count: ${orderReturns.returnItems!.length}");

    // — Credit Note Details —
    final retDc = billDocumentConfig?.displayConfiguration?.options;
    final retLabels = billDocumentConfig?.resolvedLabels;
    final hasCreditNoteConfig = retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null;

    // Returns heading — hidden when credit note config is active
    if (!hasCreditNoteConfig) {
      bytes += generator.text(
        returnsSectionHeading,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.center,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
          width: ThermalFontConfig.textSizeSmall,
        ),
      );
      bytes += generator.emptyLines(1);
    }
    String retLbl(String key, String? resolved, String def) {
      final v = retDc?[key]?.visible == true
          ? (retDc?[key]?.value as String?)
          : null;
      if (v != null && v.isNotEmpty) return v;
      if (resolved != null && resolved.isNotEmpty) return resolved;
      return def;
    }

    if (retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null) {
      final detailsHeading = retLbl(
          'showCreditNoteOrder', retLabels?.detailsHeading, 'CREDIT NOTE DETAILS');
      bytes += generator.text(detailsHeading,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.textSizeSmall,
              width: ThermalFontConfig.textSizeSmall));
      if (retLabels?.creditNoteNumber != null && orderNumber != null) {
        final cnLabel = retLbl(
            'showCreditNoteNumber', retLabels?.creditNoteNumber, 'Credit Note No:');
        bytes += generator.text('$cnLabel $orderNumber',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                height: ThermalFontConfig.textSizeSmall));
      }
      if (retLabels?.creditNoteDate != null && orderDate != null) {
        final cdLabel = retLbl(
            'showCreditNoteDate', retLabels?.creditNoteDate, 'Credit Note Date:');
        bytes += generator.text('$cdLabel $orderDate',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                height: ThermalFontConfig.textSizeSmall));
      }
      if (retLabels?.creditNoteReason != null) {
        final crLabel = retLbl(
            'showCreditNoteReason', retLabels?.creditNoteReason, 'Reason:');
        bytes += generator.text('$crLabel ',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                height: ThermalFontConfig.textSizeSmall));
      }
      bytes += generator.emptyLines(1);
    }

    // — Customer Details —
    if (customerName != null && customerName.trim().isNotEmpty) {
      bytes += generator.text(retLabels?.customerHeading ?? 'CUSTOMER DETAILS',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.textSizeSmall,
              width: ThermalFontConfig.textSizeSmall));
      final custLabel = 'Customer Name:';
      bytes += generator.text('$custLabel $customerName',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              height: ThermalFontConfig.textSizeSmall));
      if (customerPhone != null && customerPhone.trim().isNotEmpty) {
        bytes += generator.text('Phone: $customerPhone',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                height: ThermalFontConfig.textSizeSmall));
      }
      if (customerAddress != null && customerAddress.trim().isNotEmpty) {
        bytes += generator.text('Billing Address: $customerAddress',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                height: ThermalFontConfig.textSizeSmall));
      }
      bytes += generator.emptyLines(1);
    }

    if (retLabels?.itemsHeading != null) {
      bytes += generator.text(retLabels!.itemsHeading!,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.textSizeSmall,
              width: ThermalFontConfig.textSizeSmall));
      bytes += generator.emptyLines(1);
    }

    // Build header for return table
    List<PosColumn> headerColumns = [];

    if (displayConfig?['showReturnSLNumber']?.visible == true) {
      final label = (displayConfig?['showReturnSLNumber']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnSLNumber']!.value as String
          : (billDocumentConfig?.resolvedLabels?.returnSlNumber?.isNotEmpty ==
                  true
              ? billDocumentConfig!.resolvedLabels!.returnSlNumber!
              : 'SL#');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 1,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.textSizeSmall)));
    }

    if (displayConfig?['showReturnParticulars']?.visible == true) {
      final label = (displayConfig?['showReturnParticulars']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnParticulars']!.value as String
          : (billDocumentConfig
                      ?.resolvedLabels?.returnParticulars?.isNotEmpty ==
                  true
              ? billDocumentConfig!.resolvedLabels!.returnParticulars!
              : 'PARTICULARS');
      int particularsWidth = 3;
      if (displayConfig?['showReturnSLNumber']?.visible != true) {
        particularsWidth += 1;
      }
      if (displayConfig?['showReturnMRP']?.visible != true) {
        particularsWidth += 2;
      }
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: particularsWidth,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.textSizeSmall)));
    }

    if (displayConfig?['showReturnMRP']?.visible == true) {
      final label = (displayConfig?['showReturnMRP']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnMRP']!.value as String
          : (billDocumentConfig?.resolvedLabels?.returnMrp?.isNotEmpty == true
              ? billDocumentConfig!.resolvedLabels!.returnMrp!
              : 'MRP');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.textSizeSmall)));
    }

    if (displayConfig?['showReturnQty']?.visible == true) {
      final label = (displayConfig?['showReturnQty']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnQty']!.value as String
          : (billDocumentConfig?.resolvedLabels?.returnQty?.isNotEmpty == true
              ? billDocumentConfig!.resolvedLabels!.returnQty!
              : 'QTY');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.textSizeSmall)));
    }

    if (displayConfig?['showReturnRate']?.visible == true) {
      final label = (displayConfig?['showReturnRate']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnRate']!.value as String
          : (billDocumentConfig?.resolvedLabels?.returnRate?.isNotEmpty == true
              ? billDocumentConfig!.resolvedLabels!.returnRate!
              : 'RATE');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.textSizeSmall)));
    }

    if (displayConfig?['showReturnTotal']?.visible == true) {
      final label = (displayConfig?['showReturnTotal']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnTotal']!.value as String
          : (billDocumentConfig?.resolvedLabels?.returnTotal?.isNotEmpty == true
              ? billDocumentConfig!.resolvedLabels!.returnTotal!
              : 'TOTAL');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.textSizeSmall)));
    }

    if (headerColumns.isNotEmpty) {
      bytes += generator.row(headerColumns);
      bytes += generator.hr();
    }

    // Calculate individual item rates and amounts
    double calculatedReturnTotal = 0.0;

    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final itemQuantity = returnItem.quantity ?? 0;

      double itemMrp = 0.0;
      double itemRate = 0.0;
      double itemAmount = 0.0;

      // Find matching original cart item
      for (var cartItem in cartItems) {
        String cartItemProductName = '';
        double cartItemUnitPrice = 0.0;

        if (isFromLocalStorage) {
          cartItemProductName = cartItem['productName'] ?? '';
          cartItemUnitPrice =
              double.tryParse(cartItem['unitPrice']?.toString() ?? '0') ?? 0.0;
        } else {
          if (cartItem is Map<String, dynamic>) {
            cartItemProductName = cartItem['product_name']?.toString() ??
                cartItem['productName']?.toString() ??
                '';
            cartItemUnitPrice = double.tryParse(
                    cartItem['unit_price']?.toString() ??
                        cartItem['unitPrice']?.toString() ??
                        '0') ??
                0.0;
          } else {
            try {
              cartItemProductName = cartItem.productName?.toString() ?? '';
              cartItemUnitPrice =
                  double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
            } catch (e) {
              cartItemProductName = '';
              cartItemUnitPrice = 0.0;
            }
          }
        }

        if (cartItemProductName == returnItem.productName) {
          itemRate = cartItemUnitPrice;

          if (isFromLocalStorage) {
            itemMrp =
                double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
          } else {
            if (cartItem is Map<String, dynamic>) {
              itemMrp =
                  double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
            } else {
              try {
                itemMrp =
                    double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0;
              } catch (e) {
                itemMrp = 0.0;
              }
            }
          }

          itemAmount = itemQuantity * itemRate;
          calculatedReturnTotal += itemAmount;
          break;
        }
      }

      // Fallback to average rate if no match
      if (itemRate == 0.0 && itemAmount == 0.0) {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;

        num totalQuantity = 0;
        for (var item in orderReturns.returnItems!) {
          totalQuantity += item.quantity ?? 0;
        }

        final averageRate =
            totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
        itemAmount = itemQuantity * averageRate;
        calculatedReturnTotal += itemAmount;
        itemRate = averageRate;
      }

      String slNumber = (i + 1).toString();
      String productName = returnItem.productName ?? '';
      String mrp = itemMrp.toStringAsFixed(2);
      String quantity = itemQuantity.toString();
      String unitPrice = itemRate.toStringAsFixed(2);
      String totalPrice = itemAmount.toStringAsFixed(2);

      // Product name row
      if (displayConfig?['showReturnParticulars']?.visible == true ||
          displayConfig?['showReturnSLNumber']?.visible == true) {
        int maxCharsPerLine = 40;

        String leftColumnText = '';
        if (displayConfig?['showReturnSLNumber']?.visible == true &&
            displayConfig?['showReturnParticulars']?.visible == true) {
          leftColumnText =
              '$slNumber ${printerUtils.sanitizeText(productName)}';
        } else if (displayConfig?['showReturnSLNumber']?.visible == true) {
          leftColumnText = slNumber;
        } else {
          leftColumnText = printerUtils.sanitizeText(productName);
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
                    height: ThermalFontConfig.textSizeSmall)),
            PosColumn(
                text: '',
                width: 1,
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.right,
                    bold: false,
                    height: ThermalFontConfig.textSizeSmall)),
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
                      height: ThermalFontConfig.textSizeSmall)),
              PosColumn(
                  text: '',
                  width: 1,
                  styles: PosStyles(
                      fontType: fontType,
                      align: PosAlign.right,
                      bold: false,
                      height: ThermalFontConfig.textSizeSmall)),
            ]);
          }
        }
      }

      // Price details row
      List<PosColumn> priceDetailsRow = [];
      int emptySpaceWidth = 4;
      if (displayConfig?['showReturnMRP']?.visible != true) {
        emptySpaceWidth += 2;
      }
      priceDetailsRow.add(PosColumn(
          text: '',
          width: emptySpaceWidth,
          styles: PosStyles(fontType: fontType, align: PosAlign.left)));

      if (displayConfig?['showReturnMRP']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: mrp,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.textSizeSmall)));
      }
      if (displayConfig?['showReturnQty']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: quantity,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.textSizeSmall)));
      }
      if (displayConfig?['showReturnRate']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: unitPrice,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.textSizeSmall)));
      }
      if (displayConfig?['showReturnTotal']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: totalPrice,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: ThermalFontConfig.textSizeSmall)));
      }

      if (priceDetailsRow.isNotEmpty) {
        bytes += generator.row(priceDetailsRow);
      }
    }

    bytes += generator.hr();

    // Return summary
    final itemsCountLabel = retLabels?.creditNoteItemsCount != null
        ? retLbl('showCreditNoteItemsCount', retLabels?.creditNoteItemsCount,
            'Total Items:')
        : 'Total Items:';
    bytes += generator.row([
      PosColumn(
        text: itemsCountLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
      PosColumn(
        text: orderReturns.returnItems!.length.toString(),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
    ]);

    final totalAmountLabel =
        retLabels?.creditNoteTotalAmount != null
            ? retLbl('showCreditNoteTotalAmount',
                retLabels?.creditNoteTotalAmount, 'Total Amount:')
            : 'Total MRP:';
    bytes += generator.row([
      PosColumn(
        text: totalAmountLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
      PosColumn(
        text: calculatedReturnTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
    ]);

    bytes += generator.hr();

    final netTotalLabel = retLabels?.creditNoteRefund != null
        ? retLbl('showCreditNoteRefund', retLabels?.creditNoteRefund,
            'Credit Note Total:')
        : 'Net Total:';
    bytes += generator.row([
      PosColumn(
        text: netTotalLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
      PosColumn(
        text: calculatedReturnTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
    ]);

    if (hasCreditNoteConfig) {
      final amountText = AmountHelper().convertNumberToWords(
          calculatedReturnTotal, language: 'en');
      bytes += generator.emptyLines(1);
      bytes += generator.text(
        'Amount in Words:',
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      );
      bytes += generator.text(
        '$amountText Only.',
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          height: ThermalFontConfig.textSizeSmall,
        ),
      );
    }

    debugPrint("===== END BUILD ORDER RETURNS SECTION =====");
    return bytes;
  }
}
