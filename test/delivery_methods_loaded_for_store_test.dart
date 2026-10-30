import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/resources/api_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String cacheKey(int store) =>
      'delivery_methods_cache_$store${ApiLocale.cacheSuffix()}';
  final takeaway = jsonEncode([
    DeliveryMethod(id: '11', name: 'Store Takeaway', code: 'STORE_TAKEAWAY')
        .toJson()
  ]);

  test('a failed load after a store switch is not taken for "no methods"',
      () async {
    // Store 1 loads from its cache; store 2 has no cache and no API key, so
    // its load fails to an empty list.
    SharedPreferences.setMockInitialValues(
        {'active_store_id': 1, cacheKey(1): takeaway});
    final provider = DeliveryMethodsProvider();
    expect(provider.loadedForStore, isFalse);
    await provider.fetchDeliveryMethods();
    expect((provider.hasMethods, provider.loadedForStore), (true, true));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_store_id', 2);
    await provider.fetchDeliveryMethods(forceRefresh: true);
    expect(provider.hasMethods, isFalse);
    expect(provider.loadedForStore, isFalse,
        reason: "store 1's success must not vouch for store 2");

    await prefs.setString(cacheKey(2), takeaway);
    await provider.fetchDeliveryMethods();
    expect((provider.hasMethods, provider.loadedForStore), (true, true));
  });
}
