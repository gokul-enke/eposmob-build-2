import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/billing/domain/coupon_calculation.dart';
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiscountData coupon([Map<String, dynamic> changes = const {}]) =>
    DiscountData.fromJson({
      'id': '10',
      'coupon_code': 'SAVE20',
      'coupon_name': 'Save twenty',
      'store_id': '2',
      'discount_type': 'percent',
      'discount_value': '20',
      'valid_from_date': '2026-10-01',
      'valid_to_date': '2026-10-31',
      ...changes,
    });

const lines = <CouponCartLine>[
  (productId: 1, categoryId: 3, total: 100, hasOffer: false),
  (productId: 2, categoryId: 4, total: 50, hasOffer: false),
  (productId: 3, categoryId: 3, total: 80, hasOffer: true),
];

CouponCalculation evaluate([Map<String, dynamic> changes = const {}]) =>
    CouponCalculation.evaluate(
        coupon: coupon(changes),
        lines: lines,
        now: DateTime(2026, 10, 10),
        storeId: 2,
        categoryParents: {3: 2, 2: 1, 4: null});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('nullable unlimited fields and numeric strings decode', () {
    final model = coupon({
      'store_id': null,
      'discount_coupon_limit_count': null,
      'discount_value': '12.5',
      'created_at': 'bad'
    });
    expect(model.storeId, isNull);
    expect(model.discountCouponLimitCount, 0);
    expect(model.discountValue, 12.5);
    expect(model.createdAt, isNull);
    expect(DiscountData.fromJson(model.toJson()).discountValue, 12.5);
  });
  for (final scenario in [
    (name: 'offers excluded', rules: <String, dynamic>{}, amount: 30.0),
    (name: 'product scope', rules: {'product_id': 2}, amount: 10.0),
    (name: 'category descendants', rules: {'category_id': 1}, amount: 20.0),
    (
      name: 'product precedence',
      rules: {'product_id': 2, 'category_id': 1},
      amount: 10.0
    ),
    (
      name: 'percentage cap',
      rules: {'discount_coupon_limit_amount': '12.340'},
      amount: 12.34
    ),
    (
      name: 'fixed capped by eligible subtotal',
      rules: {'discount_type': 'fixed', 'discount_value': 500},
      amount: 150.0
    ),
    (
      name: 'fixed cap',
      rules: {
        'discount_type': 'fixed',
        'discount_value': 100,
        'discount_coupon_limit_amount': 15
      },
      amount: 15.0
    ),
    (name: 'global store', rules: {'store_id': null}, amount: 30.0),
  ]) {
    test(scenario.name, () {
      final result = evaluate(scenario.rules);
      expect(result.error, isNull);
      expect(result.amount, scenario.amount);
    });
  }
  for (final scenario in [
    (name: 'wrong store', rules: <String, dynamic>{'store_id': 3}),
    (name: 'missing product', rules: {'product_id': 99}),
    (name: 'offered product only', rules: {'product_id': 3}),
    (name: 'unrelated category', rules: {'category_id': 99}),
    (name: 'minimum order', rules: {'discount_coupon_min_amount': 231}),
    (name: 'maximum order', rules: {'discount_coupon_max_amount': 229}),
    (name: 'exhausted uses', rules: {'remaining_uses': 0}),
    (
      name: 'usage count',
      rules: {'discount_coupon_limit_count': 3, 'usage_count': 3}
    ),
    (name: 'not started', rules: {'valid_from_date': '2026-10-11'}),
    (name: 'expired', rules: {'valid_to_date': '2026-10-09'}),
    (name: 'malformed date', rules: {'valid_from_date': 'bad'}),
    (name: 'invalid percentage', rules: {'discount_value': 101}),
  ]) {
    test(scenario.name, () {
      final result = evaluate(scenario.rules);
      expect(result.error, isNotNull);
      expect(result.amount, 0);
    });
  }
  test('missing date bounds still enforce minimum', () {
    expect(
        coupon({
          'valid_from_date': '',
          'valid_to_date': '',
          'discount_coupon_min_amount': 300
        }).checkValidity(230, DateTime(2026, 10, 10)),
        DiscountValidity.belowMin);
  });
  test('last validity day is inclusive in the configured calendar', () {
    final model = coupon({'valid_to_date': '2026-10-10'});
    expect(
        model.checkValidity(230, DateTime.utc(2026, 10, 10, 23, 59, 59, 999)),
        DiscountValidity.valid);
    expect(model.checkValidity(230, DateTime(2026, 10, 11)),
        DiscountValidity.expired);
  });
  test('numeric coupon code remains distinct from numeric id on both APIs', () {
    final payload = OrderSubmissionPayload(
        items: [], transactionNumber: '', couponId: '10', couponCode: '00123');
    for (final body in [payload.toApiJson(), payload.toUpdateApiJson()]) {
      expect(body['coupon_id'], 10);
      expect(body['coupon_code'], '00123');
    }
    expect(OrderSubmissionPayload.couponFields(null, code: '00123'),
        {'coupon_id': null, 'coupon_code': '00123'});
  });
  test(
      'document flags accept JSON strings and preserve explicit option overrides',
      () {
    final model = DocumentConfig.fromJson({
      'display_flags':
          jsonEncode({'showDiscount': '0', 'showCouponDetails': 1}),
      'display_configuration': jsonEncode({
        'showDiscount': {'visible': 'true', 'value': 'Custom discount'},
        'showOfferDetails': false,
      }),
    });
    final restored = DocumentConfig.fromJson(model.toJson());
    final options = restored.displayConfiguration!.options!;
    expect(options['showDiscount']!.visible, isTrue);
    expect(options['showDiscount']!.value, 'Custom discount');
    expect(options['showCouponDetails']!.visible, isTrue);
    expect(options['showOfferDetails']!.visible, isFalse);
  });
  test('coupon cache follows store, account and endpoint', () async {
    SharedPreferences.setMockInitialValues({
      'api_key': 'tenant-a',
      'access_token': 'account-a',
      'active_store_id': 2
    });
    final originalUrl = APPUrl.baseURL;
    addTearDown(() => APPUrl.baseURL = originalUrl);
    var calls = 0;
    final provider = DiscountProvider(client: MockClient((request) async {
      calls++;
      return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'data': [
                coupon({'store_id': request.url.queryParameters['store_id']})
                    .toJson(),
              ]
            }
          }),
          200);
    }));
    addTearDown(provider.dispose);
    await provider.fetchDiscounts();
    await provider.fetchDiscounts();
    expect(calls, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', 3);
    await provider.fetchDiscounts();
    expect(provider.discounts.single.storeId, 3);
    await prefs.setString('access_token', 'account-b');
    await provider.fetchDiscounts();
    APPUrl.updateBaseURL('https://another.example');
    await provider.fetchDiscounts();
    expect(calls, 4);
  });
  test('an earlier store response cannot overwrite the current list', () async {
    SharedPreferences.setMockInitialValues({
      'api_key': 'tenant-a',
      'access_token': 'account-a',
      'active_store_id': 2
    });
    final first = Completer<http.Response>();
    final started = Completer<void>();
    final provider = DiscountProvider(client: MockClient((request) async {
      if (request.url.queryParameters['store_id'] == '2') {
        started.complete();
        return first.future;
      }
      return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'data': [
                coupon({'store_id': 3}).toJson(),
              ]
            }
          }),
          200);
    }));
    addTearDown(provider.dispose);
    final pending = provider.fetchDiscounts();
    await started.future;
    await (await SharedPreferences.getInstance()).setInt('active_store_id', 3);
    await provider.fetchDiscounts();
    first.complete(http.Response(
        jsonEncode({
          'status': 'success',
          'data': {
            'data': [coupon().toJson()]
          }
        }),
        200));
    await pending;
    expect(provider.discounts.single.storeId, 3);
    expect(provider.isLoading, isFalse);
  });
}
