import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';

void main() {
  group('BalanceFilter.fromLegacy', () {
    test('maps every legacy string to its filter', () {
      for (final filter in BalanceFilter.values) {
        expect(BalanceFilter.fromLegacy(filter.legacyValue), filter);
      }
    });

    test('treats null, empty and unknown values as all', () {
      expect(BalanceFilter.fromLegacy(null), BalanceFilter.all);
      expect(BalanceFilter.fromLegacy(''), BalanceFilter.all);
      expect(BalanceFilter.fromLegacy('Positive'), BalanceFilter.all);
    });
  });

  group('BalanceFilter.matches', () {
    test('all accepts every balance including a missing one', () {
      expect(BalanceFilter.all.matches(null), isTrue);
      expect(BalanceFilter.all.matches(-5), isTrue);
    });

    test('positive, negative and zero split on the sign', () {
      expect(BalanceFilter.positive.matches(0.01), isTrue);
      expect(BalanceFilter.positive.matches(0), isFalse);
      expect(BalanceFilter.negative.matches(-0.01), isTrue);
      expect(BalanceFilter.negative.matches(0), isFalse);
      expect(BalanceFilter.zero.matches(0), isTrue);
      expect(BalanceFilter.zero.matches(1), isFalse);
    });

    test('a missing balance only passes all', () {
      expect(BalanceFilter.positive.matches(null), isFalse);
      expect(BalanceFilter.negative.matches(null), isFalse);
      expect(BalanceFilter.zero.matches(null), isFalse);
    });
  });
}
