import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/api_translations.dart';
import 'package:pos_machine/models/list_unit.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/resources/api_locale.dart';
import 'package:pos_machine/resources/localization_service.dart';

/// Guards the client half of the localized-reference-data contract in
/// `TRANSLATION_AGREED_SCOPE.md`.
///
/// The failure these pin down is quiet by nature: every one of these paths
/// degrades to "show the server-resolved English text" rather than throwing, so
/// a regression looks like a cosmetic bug on one screen rather than a broken
/// feature. The payloads below are taken verbatim from the live demo tenant on
/// 2026-09-04 (captured in `TRANSLATION_BACKEND_STATUS.md`).
void main() {
  /// Runs [body] with the app locale switched, then restores English.
  Future<void> withLocale(String code, Future<void> Function() body) async {
    await LocalizationService.updateLocale(Locale(code));
    try {
      await body();
    } finally {
      await LocalizationService.updateLocale(const Locale('en'));
    }
  }

  group('ApiTranslations.parse — shape tolerance', () {
    test('the contract map shape', () {
      expect(
        ApiTranslations.parse({'en': 'Cash', 'ar': 'نقدي'}),
        {'en': 'Cash', 'ar': 'نقدي'},
      );
    });

    test('the empty array PHP emits for an empty associative array', () {
      // This is what every untranslated record looks like today.
      expect(ApiTranslations.parse(<dynamic>[]), isEmpty);
    });

    test('null and unexpected scalars', () {
      expect(ApiTranslations.parse(null), isEmpty);
      expect(ApiTranslations.parse('nonsense'), isEmpty);
      expect(ApiTranslations.parse(42), isEmpty);
    });

    test('the live EAV row shape', () {
      final parsed = ApiTranslations.parse([
        {
          'entity_type': 'delivery_method',
          'locale': 'ar',
          'key': 'name',
          'value': 'التوصيل بالسيارة',
          'language': {'id': 4, 'code': 'ar', 'type': 'rtl'},
        }
      ]);

      expect(parsed, {'ar': 'التوصيل بالسيارة'});
    });

    test('honours field priority when a locale has several columns', () {
      // Master data translates `description`; a row set may also carry `name`.
      final parsed = ApiTranslations.parse(
        [
          {'locale': 'ar', 'key': 'name', 'value': 'الاسم'},
          {'locale': 'ar', 'key': 'description', 'value': 'الوصف'},
        ],
        fields: const ['description', 'label', 'name'],
      );

      expect(parsed, {'ar': 'الوصف'},
          reason: 'description outranks name for master data');
    });

    test('normalizes underscored and region-qualified locales', () {
      // The language table stores `en_ar`; master-data meta reports `en-ar`.
      final parsed = ApiTranslations.parse({'ar_SA': 'نقدي'});
      expect(parsed['ar-sa'], 'نقدي');
      expect(parsed['ar'], 'نقدي', reason: 'lookups are by base language');
    });
  });

  group('ApiTranslations.resolve', () {
    const translations = {'en': 'Cash', 'ar': 'نقدي', 'ml': 'പണം'};

    test('picks the active language', () async {
      expect(ApiTranslations.resolve(translations, fallback: 'Cash'), 'Cash');
      await withLocale('ar', () async {
        expect(ApiTranslations.resolve(translations, fallback: 'Cash'), 'نقدي');
      });
      await withLocale('ml', () async {
        expect(ApiTranslations.resolve(translations, fallback: 'Cash'), 'പണം');
      });
    });

    test('falls back to the server-resolved text, not to English', () async {
      // The server already applied the tenant's own fallback chain to produce
      // the fallback, so it outranks our English entry.
      await withLocale('ar', () async {
        expect(
          ApiTranslations.resolve(const {'en': 'Cash'}, fallback: 'Efectivo'),
          'Efectivo',
        );
      });
    });

    test('uses English only when the fallback is empty', () async {
      await withLocale('ar', () async {
        expect(
          ApiTranslations.resolve(const {'en': 'Cash'}, fallback: '   '),
          'Cash',
        );
      });
    });

    test('never returns blank when there is nothing to resolve', () {
      expect(ApiTranslations.resolve(const {}, fallback: 'CASH'), 'CASH');
    });
  });

  group('MasterDataValue', () {
    // Verbatim from GET /master-data-values?code=PAYMENT_METHOD, which is what
    // the backend returns today: additive code/label present, translations
    // still an empty array.
    const liveRow = {
      'id': 7973,
      'master_data_id': 16,
      'value': 'CARD',
      'description': 'card',
      'code': 'CARD',
      'label': 'card',
      'translations': <dynamic>[],
    };

    test('parses the live payload unchanged', () {
      final parsed = MasterDataValue.fromJson(Map<String, dynamic>.from(liveRow));

      expect(parsed.id, 7973);
      expect(parsed.value, 'CARD');
      expect(parsed.description, 'card');
      expect(parsed.code, 'CARD');
      expect(parsed.translations, isEmpty);
      expect(parsed.label, 'card', reason: 'falls back to the server text');
    });

    test('tolerates a string id without dropping the row', () {
      expect(MasterDataValue.fromJson({'id': '7973', 'value': 'CARD'}).id, 7973);
      expect(MasterDataValue.fromJson({'value': 'CARD'}).id, 0);
    });

    test('relabels from translations once the backend seeds them', () async {
      final parsed = MasterDataValue.fromJson({
        'id': 7974,
        'value': 'CASH',
        'description': 'cash',
        'translations': {'en': 'Cash', 'ar': 'نقدي'},
      });

      expect(parsed.label, 'Cash');
      await withLocale('ar', () async {
        expect(parsed.label, 'نقدي',
            reason: 'no refetch — this is what makes offline switching work');
      });
      expect(parsed.value, 'CASH',
          reason: 'the machine value must never follow the locale');
    });

    test('reads master-data translations from the description column', () {
      final parsed = MasterDataValue.fromJson({
        'id': 1,
        'value': 'CASH',
        'description': 'cash',
        'translations': [
          {'locale': 'ar', 'key': 'description', 'value': 'نقدي'},
        ],
      });

      expect(parsed.translations, {'ar': 'نقدي'});
    });

    test('label falls back to the machine value when description is blank', () {
      final parsed = MasterDataValue.fromJson({'id': 1, 'value': 'CASH'});
      expect(parsed.label, 'CASH');
    });

    test('stableCode prefers code and falls back to value', () {
      expect(
        MasterDataValue.fromJson({'value': 'A', 'code': 'B'}).stableCode,
        'B',
      );
      expect(MasterDataValue.fromJson({'value': 'A'}).stableCode, 'A');
    });

    test('cache round trip preserves translations', () {
      final original = MasterDataValue.fromJson({
        'id': 1,
        'value': 'CASH',
        'description': 'cash',
        'code': 'CASH',
        'translations': {'en': 'Cash', 'ar': 'نقدي'},
      });

      final restored = MasterDataValue.fromJson(original.toJson());

      expect(restored.translations, original.translations);
      expect(restored.code, 'CASH');
      expect(restored.value, 'CASH');
    });
  });

  group('PaymentMethod', () {
    test('resolves its label against the active locale', () async {
      final method = PaymentMethod.fromJson({
        'id': 7974,
        'value': 'CASH',
        'description': 'cash',
        'translations': {'en': 'Cash', 'ar': 'نقدي'},
      });

      expect(method.code, 'CASH');
      // An explicit translation for the active language outranks the server's
      // pre-resolved text, which incidentally fixes the lowercase master-data
      // labels ("cash") the admin has not tidied up yet.
      expect(method.label, 'Cash');
      expect(method.rawLabel, 'cash');
      await withLocale('ar', () async {
        expect(method.label, 'نقدي');
      });
    });

    test('caches the server text, never the locale-resolved one', () async {
      final method = PaymentMethod.fromJson({
        'id': 1,
        'value': 'CASH',
        'description': 'cash',
        'translations': {'en': 'Cash', 'ar': 'نقدي'},
      });

      // The bug this prevents: caching while Arabic would otherwise bake نقدي
      // in as the raw label, and an English session reading that cache back
      // would show Arabic for any method with no `en` translation.
      late Map<String, dynamic> cached;
      await withLocale('ar', () async {
        cached = method.toJson();
      });

      expect(cached['label'], 'cash');
      expect(cached['description'], 'cash');
      expect(cached['translations'], {'en': 'Cash', 'ar': 'نقدي'});

      final restored = PaymentMethod.fromJson(cached);
      expect(restored.rawLabel, 'cash');
      expect(restored.label, 'Cash');
      await withLocale('ar', () async {
        expect(restored.label, 'نقدي');
      });
    });

    test('a method with no en translation survives an Arabic cache write',
        () async {
      final method = PaymentMethod.fromJson({
        'id': 2,
        'value': 'CHEQUE',
        'description': 'Cheque',
        'translations': {'ar': 'شيك'},
      });

      late Map<String, dynamic> cached;
      await withLocale('ar', () async {
        cached = method.toJson();
      });

      expect(PaymentMethod.fromJson(cached).label, 'Cheque',
          reason: 'English must not inherit the Arabic label from the cache');
    });

    test('carries translations across MasterDataValue conversion', () async {
      final value = MasterDataValue.fromJson({
        'id': 1,
        'value': 'CASH',
        'description': 'cash',
        'translations': {'ar': 'نقدي'},
      });

      final method = PaymentMethod.fromMasterDataValue(value);
      await withLocale('ar', () async {
        expect(method.label, 'نقدي');
      });
    });

    test('an untranslated method still behaves exactly as before', () async {
      final method = PaymentMethod.fromJson({
        'id': 10160,
        'value': 'UPI',
        'description': 'UPI',
        'translations': <dynamic>[],
      });

      expect(method.label, 'UPI');
      await withLocale('ar', () async {
        expect(method.label, 'UPI');
      });
    });
  });

  group('UnitsResponse', () {
    // Verbatim from GET /product/list-units — `data` only, no `labels` yet.
    const liveBody = {
      'status': 'success',
      'message': 'Units found',
      'data': {'1989': 'KG', '6953': 'PCS'},
    };

    test('parses the live payload and falls back to machine values', () {
      final parsed = UnitsResponse.fromJson(Map<String, dynamic>.from(liveBody));

      expect(parsed.unitList, {'1989': 'KG', '6953': 'PCS'});
      expect(parsed.labels, isEmpty);
      expect(parsed.displayFor('6953'), 'PCS');
      expect(parsed.displayList, {'1989': 'KG', '6953': 'PCS'});
    });

    test('uses labels once the backend ships them, per entry', () {
      final parsed = UnitsResponse.fromJson({
        'status': 'success',
        'message': 'Units found',
        'data': {'1989': 'KG', '6953': 'PCS'},
        'labels': {'6953': 'قطعة'},
      });

      expect(parsed.unitList['6953'], 'PCS',
          reason: 'data stays the machine value — stored units match on it');
      expect(parsed.displayFor('6953'), 'قطعة');
      expect(parsed.displayFor('1989'), 'KG',
          reason: 'a unit with no label falls back rather than going blank');
    });

    test('survives a missing or array-shaped labels field', () {
      for (final labels in [null, <dynamic>[], 'nonsense']) {
        final parsed = UnitsResponse.fromJson({
          'status': 'success',
          'message': '',
          'data': {'1': 'KG'},
          'labels': labels,
        });
        expect(parsed.labels, isEmpty, reason: 'labels=$labels');
        expect(parsed.displayFor('1'), 'KG');
      }
    });
  });

  group('ApiLocale', () {
    test('supported languages track the app bundles, with no second list', () {
      // These drifting apart is what made a Malayalam session silently request
      // English reference data.
      expect(
        ApiLocale.supported,
        LocalizationService.supportedLocales.map((l) => l.languageCode).toSet(),
      );
      expect(ApiLocale.supported, contains('ml'));
    });

    test('current follows the app locale and clamps the unknown', () async {
      expect(ApiLocale.current, 'en');
      await withLocale('ar', () async {
        expect(ApiLocale.current, 'ar');
      });
      await withLocale('ml', () async {
        expect(ApiLocale.current, 'ml');
      });
    });

    test('master data now carries the locale', () {
      final url = ApiLocale.build(
        'https://example.com/api/v1/master-data-values',
        {'code': 'PAYMENT_METHOD', 'store_id': '2'},
      );

      expect(url.queryParameters['locale'], 'en');
      expect(url.queryParameters['code'], 'PAYMENT_METHOD');
      expect(url.queryParameters['store_id'], '2');
    });

    test('list-units still withholds it until labels ship', () {
      final url = ApiLocale.build('https://example.com/api/v1/product/list-units');

      expect(url.queryParameters.containsKey('locale'), isFalse);
      expect(ApiLocale.isLocalized(url), isFalse);
      expect(
        ApiLocale.headers(apiKey: 'k', localized: false)
            .containsKey('Accept-Language'),
        isFalse,
        reason: 'the header must not localize what the query param left alone',
      );
    });

    test('cache suffix separates languages', () async {
      expect(ApiLocale.cacheSuffix(), '_en');
      await withLocale('ar', () async {
        expect(ApiLocale.cacheSuffix(), '_ar');
      });
    });
  });
}
