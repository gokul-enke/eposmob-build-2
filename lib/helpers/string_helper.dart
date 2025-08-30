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
}