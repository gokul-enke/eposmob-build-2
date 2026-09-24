import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/delivery_method_display.dart';
import 'package:pos_machine/helpers/payment_method_display.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/delivery_method_registry.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/models/payment_method_registry.dart';
import 'package:pos_machine/resources/localization_service.dart';

/// Guards the order-details page's two remaining untranslated fields.
///
/// The order-details payload carries `payment_method: ["CARD"]` — a stable
/// machine code that must stay a code, since `payments` reuses it as a map key
/// — and `delivery_method_name: "Dine In"`, which the backend resolves to the
/// store's default language and ships without `translations`. Both used to be
/// rendered raw. These tests pin the two different resolution paths, including
/// the cold-registry fallbacks, because every failure mode here is silent: the
/// page just shows English.
void main() {
  /// Switches both locale sources: `.tr` reads [Get.locale] while
  /// [ApiTranslations.resolve] reads [LocalizationService.locale], and a label
  /// that crosses both would otherwise be tested under a split locale.
  Future<void> withLocale(String code, Future<void> Function() body) async {
    await LocalizationService.updateLocale(Locale(code));
    Get.locale = Locale(code);
    try {
      await body();
    } finally {
      await LocalizationService.updateLocale(const Locale('en'));
      Get.locale = const Locale('en');
    }
  }

  tearDown(() {
    PaymentMethodRegistry.clear();
    DeliveryMethodRegistry.clear();
  });

  group('PaymentMethodDisplay', () {
    test('falls back to bundled strings when the registry is cold', () async {
      // A deep link into order details before payment methods have loaded.
      expect(PaymentMethodDisplay.labelFor('CARD'), 'Card');

      await withLocale('ar', () async {
        expect(PaymentMethodDisplay.labelFor('CARD'), 'بطاقة');
      });
      await withLocale('ml', () async {
        expect(PaymentMethodDisplay.labelFor('CARD'), 'കാർഡ്');
      });
    });

    test('prefers a backend translation over the bundled string', () async {
      PaymentMethodRegistry.update([
        PaymentMethod.fromJson({
          'id': '3200',
          'value': 'CARD',
          'description': 'Card',
          'translations': {'en': 'Card Machine', 'ar': 'جهاز البطاقة'},
        }),
      ]);

      // A tenant may have renamed the method; their wording should survive
      // translation rather than being overwritten by our bundled string.
      expect(PaymentMethodDisplay.labelFor('CARD'), 'Card Machine');
      await withLocale('ar', () async {
        expect(PaymentMethodDisplay.labelFor('CARD'), 'جهاز البطاقة');
      });
    });

    test('ignores a known method whose label is just the code', () async {
      // What an untranslated backend returns: `description` empty, so
      // PaymentMethod falls back to the code. Showing `CARD` is the bug.
      PaymentMethodRegistry.update([
        PaymentMethod.fromJson({'id': '3200', 'value': 'CARD'}),
      ]);

      await withLocale('ar', () async {
        expect(PaymentMethodDisplay.labelFor('CARD'), 'بطاقة');
      });
    });

    test('resolves a tenant code the app has no bundled string for', () {
      PaymentMethodRegistry.update([
        PaymentMethod.fromJson({
          'id': '3299',
          'value': 'LOYALTY_POINTS',
          'description': 'Loyalty Points',
        }),
      ]);

      expect(PaymentMethodDisplay.labelFor('LOYALTY_POINTS'), 'Loyalty Points');
    });

    test('passes an entirely unknown code through unchanged', () {
      // Better a raw code than a blank row.
      expect(PaymentMethodDisplay.labelFor('SOMETHING_NEW'), 'SOMETHING_NEW');
      expect(PaymentMethodDisplay.labelFor(null), '');
      expect(PaymentMethodDisplay.labelFor('   '), '');
    });

    test('localizes each code of a split order separately', () async {
      // OrderDetailsModelDataPaymentDetails joins the API's array into one
      // string, so "CASH, CARD" has to be split before lookup.
      expect(PaymentMethodDisplay.labelForCodeList('CASH, CARD'), 'Cash, Card');

      await withLocale('ar', () async {
        expect(PaymentMethodDisplay.labelForCodeList('CASH, CARD'), 'نقد, بطاقة');
      });
    });
  });

  group('DeliveryMethodDisplay.labelForIdOrName', () {
    /// The live payload for order 3386: a tenant method whose name matches no
    /// DeliveryKind token, so only the backend translation can localize it.
    List<DeliveryMethod> dineInOnly() => [
          DeliveryMethod.fromMap({
            'id': '199',
            'name': 'Dine In',
            'code': 'DINE_IN',
            'translations': {'en': 'Dine In', 'ar': 'تناول الطعام بالمطعم'},
          }),
        ];

    test('resolves through the id, not the server-resolved name', () async {
      DeliveryMethodRegistry.update(dineInOnly());

      await withLocale('ar', () async {
        expect(
          DeliveryMethodDisplay.labelForIdOrName('199', 'Dine In'),
          'تناول الطعام بالمطعم',
        );
      });
    });

    test('falls back to the name when the registry is cold', () async {
      // Deep link before store bootstrap. Echoing the id back at the user
      // would be worse than showing untranslated words.
      await withLocale('ar', () async {
        expect(DeliveryMethodDisplay.labelForIdOrName('199', 'Dine In'),
            'Dine In');
      });
    });

    test('recovers through the name when the id no longer matches', () async {
      // Re-seeded reference data changes ids but usually keeps names, so the
      // name pass still localizes an order saved against the old id.
      DeliveryMethodRegistry.update(dineInOnly());

      await withLocale('ar', () async {
        expect(
          DeliveryMethodDisplay.labelForIdOrName('404', 'Dine In'),
          'تناول الطعام بالمطعم',
        );
      });
    });

    test('shows the raw name when nothing resolves it', () async {
      DeliveryMethodRegistry.update(dineInOnly());

      await withLocale('ar', () async {
        expect(DeliveryMethodDisplay.labelForIdOrName('404', 'Banquet Hall'),
            'Banquet Hall');
      });
    });

    test('still uses the bundled string for a known kind', () async {
      // No id on the order, name only — the pre-existing labelFor path.
      await withLocale('ar', () async {
        expect(DeliveryMethodDisplay.labelForIdOrName(null, 'Car Delivery'),
            'توصيل بالسيارة');
        expect(DeliveryMethodDisplay.labelForIdOrName('', 'Car Delivery'),
            'توصيل بالسيارة');
      });
    });
  });
}
