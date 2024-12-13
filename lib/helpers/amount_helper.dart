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
}

