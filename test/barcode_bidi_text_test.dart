import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/barcode_bidi_text.dart';

void main() {
  group('BarcodeBidiText', () {
    test('isolates English and Arabic product names with numeric suffixes', () {
      final text = BarcodeBidiText.englishThenArabic(
        'BAKING PAPER 12SHEETS / 4U',
        'ورق الخبز 12 ورقة / 4U',
      );

      expect(
        text,
        '\u2066BAKING PAPER 12SHEETS / 4U\u2069 / '
        '\u2067ورق الخبز 12 ورقة / 4U\u2069',
      );
      expect(
        BarcodeBidiText.directionForText(text),
        ui.TextDirection.ltr,
      );
    });

    test('uses RTL paragraph direction for Arabic-first mode', () {
      final text = BarcodeBidiText.arabicThenEnglish(
        'تونة سردين 155 جرام',
        'SARDINS TUNA 155G / 505 505',
      );

      expect(
        BarcodeBidiText.directionForText(text),
        ui.TextDirection.rtl,
      );
    });

    test('does not add controls when only one translation is available', () {
      expect(
        BarcodeBidiText.englishThenArabic('TOILET CLEANER 1L', ''),
        'TOILET CLEANER 1L',
      );
      expect(
        BarcodeBidiText.englishThenArabic('', 'منظف المراحيض 1 لتر'),
        'منظف المراحيض 1 لتر',
      );
      expect(
        BarcodeBidiText.directionForText('منظف المراحيض 1 لتر'),
        ui.TextDirection.rtl,
      );
    });
  });
}
