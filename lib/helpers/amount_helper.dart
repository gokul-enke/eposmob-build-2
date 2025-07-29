import 'package:intl/intl.dart';

class AmountHelper {
  static String formatAmount(dynamic amount) {
    // Check if the amount is a string and attempt to parse it
    if (amount is String) {
      // Try to parse the string to a double
      double? parsedAmount = double.tryParse(amount);
      if (parsedAmount != null) {
        amount = parsedAmount; // Update amount to the parsed double
      } else {
        return 'Invalid amount'; // Handle invalid string input
      }
    } else if (amount is! num) {
      return 'Invalid amount'; // Handle case where amount is not a number
    }

    // Now amount is guaranteed to be a num (int or double)
    final NumberFormat formatter = NumberFormat('#,##0.00');
    return formatter.format(amount);
  }

  // Add this utility function to convert numbers to words
  String convertNumberToWords(double number) {
    // Handle 0 case
    if (number == 0) return 'Zero';

    // Lists for words
    List<String> ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    List<String> tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];

    // Separate the whole and decimal parts
    int wholeNumber = number.toInt();
    int decimalPart = ((number - wholeNumber) * 100).round();

    String result = '';

    // Convert the whole part of number
    if (wholeNumber > 0) {
      // Crores (10 Million)
      if (wholeNumber >= 10000000) {
        result +=
            '${convertNumberToWords((wholeNumber ~/ 10000000).toDouble())} Crore ';
        wholeNumber %= 10000000;
      }

      // Lakhs (100 Thousand)
      if (wholeNumber >= 100000) {
        result +=
            '${convertNumberToWords((wholeNumber ~/ 100000).toDouble())} Lakh ';
        wholeNumber %= 100000;
      }

      // Thousands
      if (wholeNumber >= 1000) {
        result +=
            '${convertNumberToWords((wholeNumber ~/ 1000).toDouble())} Thousand ';
        wholeNumber %= 1000;
      }

      // Hundreds
      if (wholeNumber >= 100) {
        result += '${ones[wholeNumber ~/ 100]} Hundred ';
        wholeNumber %= 100;
      }

      // Tens and Ones
      if (wholeNumber > 0) {
        if (wholeNumber < 20) {
          result += ones[wholeNumber];
        } else {
          result += '${tens[wholeNumber ~/ 10]} ';
          if (wholeNumber % 10 > 0) {
            result += ones[wholeNumber % 10];
          }
        }
      }
    }

    // Handle decimal part if any
    if (decimalPart > 0) {
      result += ' and ';
      if (decimalPart < 20) {
        result += '${ones[decimalPart]} Paise';
      } else {
        result += '${tens[decimalPart ~/ 10]} ';
        if (decimalPart % 10 > 0) {
          result += '${ones[decimalPart % 10]} ';
        }
        result += 'Paise';
      }
    }

    return result.trim();
  }

  /// Rounds amount to nearest integer using standard rounding rules
  /// Example: 2.4 -> 2, 2.5 -> 3, 2.6 -> 3
  static double roundOffAmount(double amount) {
    return amount.roundToDouble();
  }

  /// Formats rounded amount
  static String formatRoundedAmount(double amount) {
    double rounded = roundOffAmount(amount);
    return rounded.toStringAsFixed(0); // No decimal places for rounded amounts
  }
}
