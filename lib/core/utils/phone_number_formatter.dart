import 'package:flutter/services.dart';

/// Formats digits as `123-456-7890…` while typing. Non-digits are dropped.
class PhoneNumberFormatter extends TextInputFormatter {
  const PhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String format(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 3) {
      digits = '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    if (digits.length > 7) {
      digits = '${digits.substring(0, 7)}-${digits.substring(7)}';
    }
    return digits;
  }

  /// Kept for callers of the old instance method.
  String formatPhoneNumber(String input) => format(input);
}
