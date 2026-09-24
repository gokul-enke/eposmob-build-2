import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/sync_log.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  late List<String> printed;
  late DebugPrintCallback original;

  setUp(() {
    printed = [];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() => debugPrint = original);

  test('quiet hides routine lines but keeps sync lines and problems', () async {
    final capture = debugPrint;
    await SyncLog.quiet(() async {
      debugPrint('📦 [Hive] Box products now has 4855 entries');
      debugPrint('🔧 AuthModel: token getter called, exists: true');
      SyncLog.line('Products ✓ 120 ms');
      debugPrint('❌ [API] Error fetching all products from API: timeout');
      debugPrint('⚠️ Failed to refresh settings during sync');
    });

    expect(printed, [
      '[Sync] Products ✓ 120 ms',
      '❌ [API] Error fetching all products from API: timeout',
      '⚠️ Failed to refresh settings during sync',
      '[Sync] 2 routine log line(s) hidden',
    ]);
    // Normal logging is back afterwards.
    expect(debugPrint, same(capture));
  });

  test('quiet restores logging even when the sync throws', () async {
    final capture = debugPrint;
    await expectLater(
      SyncLog.quiet<void>(() async => throw Exception('boom')),
      throwsException,
    );
    expect(debugPrint, same(capture));
  });

  test('products prints full details of each synced product', () {
    // The "Test" product from a delta sync (SKU on store 32's stock row).
    final product = GetProduct.fromJson({
      'product_id': 38887,
      'product_name': 'Test',
      'barcode': '111000452',
      'unit': 'KG',
      'mrp': '100.000',
      'purchase_price': '100.000',
      'category': {'name': 'Chicken Buckets'},
      'price': {'base_price': '100.000', 'total_price': '100.000'},
      'taxes': [
        {'name': 'CGST 26', 'rate': '9'},
        {'name': 'SGST2026', 'rate': '9'},
      ],
      'names': {'en': 'Test', 'ar': 'امتحان'},
      'stock': [
        {
          'store_id': 32,
          'store_name': 'funzcart2',
          'quantity': '10.000',
          'price': '100.000',
          'sku': '4226',
        },
      ],
    });

    SyncLog.products(ProductFetchSummary(
      delta: true,
      products: [product],
      addedIds: {38887},
      deletedIds: const {},
      total: 4856,
      elapsed: const Duration(milliseconds: 850),
    ));

    expect(printed.first,
        '[Sync] Products (delta): 1 received · 1 new · 0 updated · 0 deleted · catalog 4856 · 850 ms');
    final details = printed[1];
    expect(details, contains('NEW #38887 Test'));
    expect(details,
        contains('barcode 111000452 · unit KG · category Chicken Buckets'));
    expect(details, contains('price 100.000 (total 100.000)'));
    expect(details, contains('tax CGST 26 9%, SGST2026 9%'));
    expect(details, contains('ar: امتحان'));
    expect(
        details,
        contains(
            'stock store 32 funzcart2 · qty 10 · price 100.000 · SKU 4226'));
  });

  test('a large full sync lists only the first products', () {
    final products = [
      for (var i = 0; i < 25; i++) GetProduct(productId: i, productName: 'P$i'),
    ];
    SyncLog.products(ProductFetchSummary(
      delta: false,
      products: products,
      addedIds: const {},
      deletedIds: const {},
      total: 25,
      elapsed: Duration.zero,
    ));

    expect(printed.where((l) => l.contains('SYNCED #')).length,
        SyncLog.maxDetailedProducts);
    expect(printed.last, '[Sync]   … and 5 more product(s) not listed');
  });

  test('request logs a pasteable URL, readable params and masked secrets', () {
    final url = Uri.parse('https://api.example.com/api/v1/products').replace(
      queryParameters: {
        'page': '1',
        'store_id': '32',
        'updated_at_range': '2026-09-24 08:20:00,2026-09-24 08:26:41',
      },
    );
    SyncLog.request('GET', url, headers: {
      'Authorization': 'Bearer secret-access-token',
      'X-Tenant': 'tenant-api-key-123',
      'Accept-Language': 'en',
    });

    expect(printed[0], '[API] → GET $url');
    expect(printed[1],
        '[API]   params page=1 · store_id=32 · updated_at_range=2026-09-24 08:20:00,2026-09-24 08:26:41');
    expect(printed[2], contains('Authorization: Bearer secr•••• (19 chars)'));
    expect(printed[2], contains('X-Tenant: tena•••• (18 chars)'));
    expect(printed[2], contains('Accept-Language: en'));
    expect(printed.join('\n'), isNot(contains('secret-access-token')));
    expect(printed.join('\n'), isNot(contains('tenant-api-key-123')));
    expect(printed[3], '[API]   body (none)');
  });

  test('quiet keeps API request and response lines', () async {
    await SyncLog.quiet(() async {
      SyncLog.response(200, 'page 1 · 0 product(s)');
      debugPrint('📦 [API] Batch completed in 120ms');
    });
    expect(printed.first, '[API] ← 200 page 1 · 0 product(s)');
    expect(printed.last, '[Sync] 1 routine log line(s) hidden');
  });
}
