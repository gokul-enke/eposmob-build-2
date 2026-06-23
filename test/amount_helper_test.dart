/// Phase-0 characterization tests for [AmountHelper].
///
/// These pin the *current* behaviour of money formatting, number-to-words,
/// and round-off so the upcoming responsive / feature-first refactor (which
/// will relocate this helper into `core/`) cannot silently change output.
///
/// Characterization rule: assertions describe what the code does TODAY, even
/// where the behaviour is quirky (e.g. a pure-decimal amount renders without a
/// main currency unit and leads with "and ..."). If the refactor intends to
/// change any of these, the change must be deliberate and the expectation
/// updated in the same commit.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/amount_helper.dart';

void main() {
  group('AmountHelper.formatAmount', () {
    test('formats a double with thousands separators and 2 decimals', () {
      expect(AmountHelper.formatAmount(1234.5), '1,234.50');
      expect(AmountHelper.formatAmount(1000000), '1,000,000.00');
      expect(AmountHelper.formatAmount(0), '0.00');
      expect(AmountHelper.formatAmount(-5.5), '-5.50');
    });

    test('parses numeric strings before formatting', () {
      expect(AmountHelper.formatAmount('12.5'), '12.50');
      expect(AmountHelper.formatAmount('1234.567'), '1,234.57');
    });

    test('returns "Invalid amount" for non-numeric input', () {
      expect(AmountHelper.formatAmount('abc'), 'Invalid amount');
      expect(AmountHelper.formatAmount(null), 'Invalid amount');
      expect(AmountHelper.formatAmount(['x']), 'Invalid amount');
    });
  });

  group('AmountHelper.roundOffAmount (ties away from zero)', () {
    test('rounds to nearest integer as a double', () {
      expect(AmountHelper.roundOffAmount(2.4), 2.0);
      expect(AmountHelper.roundOffAmount(2.6), 3.0);
    });

    test('rounds halves away from zero', () {
      expect(AmountHelper.roundOffAmount(0.5), 1.0);
      expect(AmountHelper.roundOffAmount(2.5), 3.0);
      expect(AmountHelper.roundOffAmount(-2.5), -3.0);
    });
  });

  group('AmountHelper.formatRoundedAmount', () {
    test('rounds then renders with no decimals', () {
      expect(AmountHelper.formatRoundedAmount(2.6), '3');
      expect(AmountHelper.formatRoundedAmount(199.5), '200');
      expect(AmountHelper.formatRoundedAmount(0.4), '0');
    });
  });

  group('AmountHelper.convertNumberToWords — English / INR', () {
    final helper = AmountHelper();

    test('zero renders with plural main unit', () {
      expect(helper.convertNumberToWords(0), 'Zero Rupees');
    });

    test('singular vs plural main unit', () {
      expect(helper.convertNumberToWords(1), 'One Rupee');
      expect(helper.convertNumberToWords(2), 'Two Rupees');
    });

    test('hundreds with paise fraction', () {
      expect(
        helper.convertNumberToWords(123.45),
        'One Hundred Twenty Three Rupees and Forty Five Paise',
      );
    });

    test('exact hundred', () {
      expect(helper.convertNumberToWords(100), 'One Hundred Rupees');
    });

    test('Indian lakh grouping', () {
      expect(helper.convertNumberToWords(100000), 'One Lakh Rupees');
    });

    test('pure-decimal amount has no main unit and leads with "and"', () {
      // Quirk pinned on purpose: wholeNumber == 0 means the main unit is
      // never appended, so the string starts at the fractional part.
      expect(helper.convertNumberToWords(0.5), 'and Fifty Paise');
    });

    test('rounding guard: x.999 rolls the cents into the next rupee', () {
      expect(helper.convertNumberToWords(1.999), 'Two Rupees');
    });
  });

  group('AmountHelper.convertNumberToWords — currency / language variants', () {
    final helper = AmountHelper();

    test('SAR uses Riyal/Riyals and international grouping', () {
      expect(helper.convertNumberToWords(1, currency: 'SAR'), 'One Riyal');
      expect(helper.convertNumberToWords(2, currency: 'SAR'), 'Two Riyals');
      expect(
        helper.convertNumberToWords(100000, currency: 'SAR'),
        'One Hundred Thousand Riyals',
      );
    });

    test('Arabic zero renders with Arabic currency word', () {
      expect(helper.convertNumberToWords(0, language: 'ar'), 'صفر روبية');
    });
  });
}
