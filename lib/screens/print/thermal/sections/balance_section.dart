import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import '../font_config.dart';

/// Builds the balance and amount in words sections of the thermal receipt
class BalanceSectionBuilder {
  List<int> buildAmountInWords(
    Generator generator,
    double amount,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    bytes += generator.text(
      'Amount in words:',
      styles: PosStyles(
        fontType: fontType,
        align: PosAlign.left,
        bold: true,
        height: ThermalFontConfig.textSizeSmall,
      ),
    );

    // Convert amount to words
    final amountInWords =
        '${AmountHelper().convertNumberToWords(amount)} Only.';

    // Wrap long amount in words text
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

  List<int> buildCustomerBalance(
    Generator generator,
    double? oldBalance,
    double? currentBalance,
    double? paidAmount,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    // Only show if at least one value is non-null and non-zero
    if ((oldBalance == null || oldBalance == 0) &&
        (currentBalance == null || currentBalance == 0) &&
        (paidAmount == null || paidAmount == 0)) {
      return bytes;
    }

    // Old Balance
    if (oldBalance != null && oldBalance != 0) {
      bytes += generator.row([
        PosColumn(
            text: 'Old Bal:',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                height: ThermalFontConfig.textSizeSmall)),
        PosColumn(
            text: oldBalance.toStringAsFixed(2),
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                height: ThermalFontConfig.textSizeSmall)),
      ]);
    }

    // Paid Amount
    if (paidAmount != null && paidAmount != 0) {
      bytes += generator.row([
        PosColumn(
            text: 'Paid Amt:',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                height: ThermalFontConfig.textSizeSmall)),
        PosColumn(
            text: paidAmount.toStringAsFixed(2),
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                height: ThermalFontConfig.textSizeSmall)),
      ]);
    }

    // Current Balance
    if (currentBalance != null) {
      bytes += generator.row([
        PosColumn(
            text: 'Cur Bal:',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: ThermalFontConfig.textSizeSmall)),
        PosColumn(
            text: currentBalance.toStringAsFixed(2),
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: ThermalFontConfig.textSizeSmall)),
      ]);
    }

    bytes += generator.emptyLines(1);

    return bytes;
  }
}
