import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import '../font_config.dart';

/// Builds the total summary section when there are returns
/// Includes: Order total, return total, final total, amount in words
class TotalSummarySectionBuilder {
  List<int> build(
    Generator generator,
    String formattedTotal,
    OrderReturns orderReturns,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    PosFontType fontType,
    Map<String, DisplayOption>? displayConfig,
    {bool isArabic = false}
  ) {
    List<int> bytes = [];

    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return bytes;
    }

    debugPrint("===== BUILD TOTAL SUMMARY SECTION =====");

    double orderTotal = double.tryParse(formattedTotal) ?? 0.0;

    // Calculate return total
    double returnTotal = 0.0;
    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final itemQuantity = returnItem.quantity ?? 0;

      double itemRate = 0.0;

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
          returnTotal += itemQuantity * itemRate;
          break;
        }
      }

      // Fallback to average rate
      if (itemRate == 0.0 && orderReturns.returnTotalAmount != null) {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;

        num totalQuantity = 0;
        for (var item in orderReturns.returnItems!) {
          totalQuantity += item.quantity ?? 0;
        }

        final averageRate =
            totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
        returnTotal += itemQuantity * averageRate;
      }
    }

    double finalTotal = orderTotal - returnTotal;

    // Labels from config
    String purchaseLabel =
        (displayConfig?['showFinalPurchase']?.value as String?) ??
            'Order Total:';
    String returnLabel =
        (displayConfig?['showFinalReturn']?.value as String?) ??
            'Return Total:';
    String finalTotalLabel =
        (displayConfig?['showFinalNetAmount']?.value as String?) ??
            'Final Total:';

    // Order Total row
    bytes += generator.row([
      PosColumn(
        text: purchaseLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
      PosColumn(
        text: orderTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
    ]);

    // Return Total row
    bytes += generator.row([
      PosColumn(
        text: returnLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
      PosColumn(
        text: returnTotal.toStringAsFixed(2),
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

    // Final Total row
    bytes += generator.row([
      PosColumn(
        text: finalTotalLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
      PosColumn(
        text: finalTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: ThermalFontConfig.textSizeSmall,
        ),
      ),
    ]);

    // Amount in words for final total
    if (displayConfig?['showFinalAmountInWords']?.visible == true) {
      debugPrint("Building final amount in words...");
      bytes +=
          _buildAmountInWords(generator, finalTotal, fontType, isArabic: isArabic);
    }

    bytes += generator.emptyLines(1);

    debugPrint("===== END BUILD TOTAL SUMMARY SECTION =====");
    return bytes;
  }

  List<int> _buildAmountInWords(
    Generator generator,
    double amount,
    PosFontType fontType,
    {bool isArabic = false}
  ) {
    List<int> bytes = [];

    bytes += generator.text(
      isArabic ? '?????? ????????:' : 'Amount in words:',
      styles: PosStyles(
        fontType: fontType,
        align: PosAlign.left,
        bold: true,
        height: ThermalFontConfig.textSizeSmall,
      ),
    );

    String amountInWords =
        '${AmountHelper().convertNumberToWords(amount, language: isArabic ? 'ar' : 'en')}${isArabic ? ' ???.' : ' Only.'}';

    int maxCharsPerLine = 48;
    if (amountInWords.length <= maxCharsPerLine) {
      bytes += generator.text(
        amountInWords,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: false,
          height: ThermalFontConfig.textSizeSmall,
        ),
      );
    } else {
      // Text wrapping
      String remainingText = amountInWords;
      while (remainingText.isNotEmpty) {
        String currentLine;
        if (remainingText.length <= maxCharsPerLine) {
          currentLine = remainingText;
          remainingText = '';
        } else {
          int breakPoint = maxCharsPerLine;
          for (int i = maxCharsPerLine - 1;
              i >= maxCharsPerLine - 10 && i >= 0;
              i--) {
            if (i < remainingText.length && remainingText[i] == ' ') {
              breakPoint = i;
              break;
            }
          }
          currentLine = remainingText.substring(0, breakPoint).trim();
          remainingText = remainingText.substring(breakPoint).trim();
        }
        bytes += generator.text(
          currentLine,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: false,
            height: ThermalFontConfig.textSizeSmall,
          ),
        );
      }
    }

    return bytes;
  }
}
