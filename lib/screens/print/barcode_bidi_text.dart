import 'dart:ui' as ui;

import 'package:intl/intl.dart' show Bidi;

/// Keeps independently directed product-name segments stable inside a
/// bilingual barcode-label line.
class BarcodeBidiText {
  BarcodeBidiText._();

  static const String _leftToRightIsolate = '\u2066';
  static const String _rightToLeftIsolate = '\u2067';
  static const String _popDirectionalIsolate = '\u2069';

  /// Uses the first strong character, ignoring numbers and punctuation, to
  /// choose the paragraph direction.
  static ui.TextDirection directionForText(String text) {
    return Bidi.startsWithRtl(text)
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
  }

  static String _isolate(String text, ui.TextDirection direction) {
    final value = text.trim();
    if (value.isEmpty) return '';
    final opener = direction == ui.TextDirection.rtl
        ? _rightToLeftIsolate
        : _leftToRightIsolate;
    return '$opener$value$_popDirectionalIsolate';
  }

  static String _join({
    required String first,
    required ui.TextDirection firstDirection,
    required String second,
    required ui.TextDirection secondDirection,
  }) {
    final firstValue = first.trim();
    final secondValue = second.trim();
    if (firstValue.isEmpty) return secondValue;
    if (secondValue.isEmpty) return firstValue;
    return '${_isolate(firstValue, firstDirection)} / '
        '${_isolate(secondValue, secondDirection)}';
  }

  static String englishThenArabic(String english, String arabic) {
    return _join(
      first: english,
      firstDirection: ui.TextDirection.ltr,
      second: arabic,
      secondDirection: ui.TextDirection.rtl,
    );
  }

  static String arabicThenEnglish(String arabic, String english) {
    return _join(
      first: arabic,
      firstDirection: ui.TextDirection.rtl,
      second: english,
      secondDirection: ui.TextDirection.ltr,
    );
  }
}
