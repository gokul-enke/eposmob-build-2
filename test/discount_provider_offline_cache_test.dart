import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The coupon modal refreshes the list after the cache expires. A failed
/// refresh (offline or server error) must keep the coupons already loaded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final coupon = {
    'id': 7,
    'coupon_code': 'SAVE10',
    'discount_category_id': 1,
    'coupon_name': 'Save 10',
    'discount_type': 'percent',
    'valid_from_date': '',
    'valid_to_date': '',
    'discount_coupon_limit_count': 0,
    'discount_value': 10,
    'company_id': 1,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'tenant', 'access_token': 'token', 'active_store_id': 1});
  });

  Future<DiscountProvider> loaded(Future<http.Response> Function() refresh) async {
    var calls = 0;
    final provider = DiscountProvider(
      client: MockClient((_) async {
        if (calls++ == 0) {
          return http.Response(
              jsonEncode({
                'status': 'success',
                'data': {
                  'data': [coupon]
                },
              }),
              200);
        }
        return refresh();
      }),
    );
    await provider.fetchDiscounts();
    expect(provider.discounts, hasLength(1));
    return provider;
  }

  test('offline refresh keeps the downloaded coupons', () async {
    final provider =
        await loaded(() => throw const SocketException('offline'));
    await provider.fetchDiscounts(forceRefresh: true);
    expect(provider.discounts.single.couponCode, 'SAVE10');
    expect(provider.hasError, isTrue);
  });

  test('server error refresh keeps the downloaded coupons', () async {
    final provider = await loaded(() async => http.Response('down', 503));
    await provider.fetchDiscounts(forceRefresh: true);
    expect(provider.discounts.single.couponCode, 'SAVE10');
    expect(provider.hasError, isTrue);
  });
}
