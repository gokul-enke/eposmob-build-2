import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/billing_crash_guards.dart';
import 'package:pos_machine/models/customer_list.dart';

void main() {
  group('BillingCrashGuards.safePrice', () {
    test('returns fallback for null', () {
      expect(BillingCrashGuards.safePrice(null), 0.0);
      expect(BillingCrashGuards.safePrice(null, fallback: 9.99), 9.99);
    });

    test('returns fallback for negative and NaN', () {
      expect(BillingCrashGuards.safePrice(-1.0), 0.0);
      expect(BillingCrashGuards.safePrice(double.nan), 0.0);
    });

    test('returns valid price unchanged', () {
      expect(BillingCrashGuards.safePrice(12.5), 12.5);
      expect(BillingCrashGuards.safePrice(0.0), 0.0);
    });
  });

  group('BillingCrashGuards.safeMrp', () {
    test('delegates to safePrice', () {
      expect(BillingCrashGuards.safeMrp(null), 0.0);
      expect(BillingCrashGuards.safeMrp(99.0), 99.0);
    });
  });

  group('BillingCrashGuards.safeTaxRate', () {
    test('returns fallback for null, negative, and NaN', () {
      expect(BillingCrashGuards.safeTaxRate(null), 0.0);
      expect(BillingCrashGuards.safeTaxRate(-5), 0.0);
      expect(BillingCrashGuards.safeTaxRate(double.nan), 0.0);
    });

    test('allows zero and positive rates', () {
      expect(BillingCrashGuards.safeTaxRate(0), 0.0);
      expect(BillingCrashGuards.safeTaxRate(15), 15.0);
    });
  });

  group('BillingCrashGuards.lineTotal', () {
    test('multiplies safe unit price by quantity', () {
      expect(
        BillingCrashGuards.lineTotal(unitPrice: 10, quantity: 3),
        30.0,
      );
    });

    test('treats null price as zero', () {
      expect(
        BillingCrashGuards.lineTotal(unitPrice: null, quantity: 5),
        0.0,
      );
    });

    test('treats invalid quantity as zero', () {
      expect(
        BillingCrashGuards.lineTotal(unitPrice: 10, quantity: double.nan),
        0.0,
      );
      expect(
        BillingCrashGuards.lineTotal(unitPrice: 10, quantity: -2),
        0.0,
      );
    });
  });

  group('BillingCrashGuards.customerDisplayName', () {
    test('returns fallback when customer is null', () {
      expect(
        BillingCrashGuards.customerDisplayName(null),
        'Default B2C',
      );
    });

    test('returns trimmed name when present', () {
      final customer = CustomerListModelData(name: '  Alice  ');
      expect(BillingCrashGuards.customerDisplayName(customer), 'Alice');
    });

    test('returns fallback for blank name', () {
      final customer = CustomerListModelData(name: '   ');
      expect(
        BillingCrashGuards.customerDisplayName(customer, fallback: 'Guest'),
        'Guest',
      );
    });
  });

  group('BillingCrashGuards.customerDisplayPhone', () {
    test('returns null for missing phone', () {
      expect(BillingCrashGuards.customerDisplayPhone(null), isNull);
      expect(
        BillingCrashGuards.customerDisplayPhone(
          CustomerListModelData(phone: '  '),
        ),
        isNull,
      );
    });

    test('returns trimmed phone', () {
      expect(
        BillingCrashGuards.customerDisplayPhone(
          CustomerListModelData(phone: ' 5551234 '),
        ),
        '5551234',
      );
    });
  });

  group('BillingCrashGuards.hasDeliveryMethods', () {
    test('returns false for empty list', () {
      expect(BillingCrashGuards.hasDeliveryMethods([]), isFalse);
    });

    test('returns true when methods exist', () {
      expect(BillingCrashGuards.hasDeliveryMethods(['door']), isTrue);
    });
  });

  group('BillingCrashGuards.accessTokenOrNull', () {
    test('returns null for missing or blank token', () {
      expect(BillingCrashGuards.accessTokenOrNull(null), isNull);
      expect(BillingCrashGuards.accessTokenOrNull(''), isNull);
      expect(BillingCrashGuards.accessTokenOrNull('   '), isNull);
    });

    test('returns trimmed token', () {
      expect(
        BillingCrashGuards.accessTokenOrNull('  abc123  '),
        'abc123',
      );
    });
  });

  group('BillingCrashGuards.formatSafeAmount', () {
    test('formats safe price via AmountHelper', () {
      expect(BillingCrashGuards.formatSafeAmount(12.5), '12.50');
      expect(BillingCrashGuards.formatSafeAmount(null), '0.00');
    });
  });
}
