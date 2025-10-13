// lib/utils/string_helper.dart

class StringHelper {
  static String formatPropCode(String code) {
    return code
        .toLowerCase()
        .split('_')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1)
            : '')
        .join(' ');
  }

  /// Masks a string by showing only the last 4 characters and replacing the rest with asterisks
  /// Example: "1234567890" becomes "******7890"
  static String maskStringShowLast4(String value) {
    if (value.isEmpty) return value;
    if (value.length <= 4) return value;
    
    int visibleChars = 4;
    int maskedLength = value.length - visibleChars;
    String masked = '*' * maskedLength;
    String visible = value.substring(value.length - visibleChars);
    
    return masked + visible;
  }
}