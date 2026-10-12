import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/order_submission_status.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// A cart line as `buildOrderItemsPayload` builds it: 2 x 90 under offer 9
/// (standard price 100, 18% tax included).
const _offerLine = <String, dynamic>{
  'product_id': 1,
  'quantity': 2,
  'price': 90.0,
  'mrp': 120.0,
  'stock_id': 88,
  'warranty_enabled': false,
  'offer_id': 9,
  'offer_version': 3,
  'standard_unit_price': 100.0,
  'tax_rate': 18.0,
  'tax_amount': 27.46,
  'total_price': 180.0,
  'item_discount_amount': 20.0,
  'discount_origin': 'offer',
  'offer_name': 'Test Offer',
  'offer_names': {'en': 'Test Offer'},
  'offer_discount_type': 'percentage',
  'offer_discount_value': '10.0',
};

const _identity = <String, String>{
  'client_sale_id': 'ab48eb7d-1495-4f8a-8815-3cf05200bca3',
  'receipt_number': '1-01-261006-0001',
  'issued_at': '2026-10-06T10:00:00Z',
  'pos_device_id': '2a5e060b-9c07-4b6b-a405-136a8344c327',
};

/// A printed sale; [identity] replaces receipt identity fields (null removes).
OrderSubmissionPayload _sale({
  Map<String, String?> identity = const {},
  String? orderId,
  String sourceType = 'executive',
  int? storeId = 1,
}) {
  String? field(String key) =>
      identity.containsKey(key) ? identity[key] : _identity[key];
  return OrderSubmissionPayload(
    items: const [_offerLine],
    transactionNumber: 'T-1',
    clientSaleId: field('client_sale_id'),
    receiptNumber: field('receipt_number'),
    issuedAt: field('issued_at'),
    posDeviceId: field('pos_device_id'),
    orderId: orderId,
    sourceType: sourceType,
    storeId: storeId,
  );
}

void _expectBody(Map<String, dynamic> body, {required bool completed}) {
  if (completed) {
    expect(body['pricing_mode'], OrderSubmissionPayload.completedSalePricingMode);
    expect(body['delivery_tax_amount'], 0);
  } else {
    expect(body.containsKey('pricing_mode'), isFalse);
    expect(body.containsKey('delivery_tax_amount'), isFalse);
  }
  final line = (body['items'] as List).single as Map;
  for (final key in OrderSubmissionPayload.completedSaleLineKeys) {
    expect(line.containsKey(key), completed, reason: key);
  }
  // The sold price and the offer reference are sent either way.
  expect(line['price'], 90);
  expect(line['offer_id'], 9);
  expect(line['offer_version'], 3);
}

LocalCartItem _offerItem({double price = 90, num quantity = 2}) {
  final batch = Stock(
    id: 88,
    productId: 1,
    storeId: 1,
    storeName: 'Main Store',
    quantity: 50,
    price: '100',
    mrp: '120',
    purchasePrice: '60',
    taxRate: '18',
    unit: 'PCS',
  );
  return LocalCartItem(
    product: GetProduct(
      productId: 1,
      productName: 'Chocobar',
      price: ProductPrice(price: '100'),
      mrp: '120',
      purchasePrice: '60',
      unit: 'PCS',
      stock: [batch],
    ),
    price: price,
    mrp: 120,
    taxRate: 18,
    quantity: quantity,
    selectedStock: batch,
    offerId: 9,
    offerVersion: 3,
    standardUnitPrice: 100,
  );
}

void main() {
  group('a completed sale', () {
    test('is a new executive sale with a store and a full receipt identity',
        () {
      final sale = _sale();
      expect(sale.isCompletedSale(), isTrue);
      _expectBody(sale.toApiJson(), completed: true);
    });

    test('may take its store from the fallback store id', () {
      final sale = _sale(storeId: null);
      expect(sale.isCompletedSale(fallbackStoreId: 3), isTrue);
      final body = sale.toApiJson(fallbackStoreId: 3);
      expect(body['store_id'], 3);
      _expectBody(body, completed: true);
    });
  });

  group('not a completed sale', () {
    final cases = <String, OrderSubmissionPayload>{
      'an existing order (order_id)': _sale(orderId: '55'),
      'a source other than executive': _sale(sourceType: 'admin_panel'),
      'no store id and no fallback': _sale(storeId: null),
      for (final key in _identity.keys) ...{
        'a missing $key': _sale(identity: {key: null}),
        'an empty $key': _sale(identity: {key: ''}),
        'a whitespace $key': _sale(identity: {key: '   '}),
      },
    };
    for (final entry in cases.entries) {
      test('${entry.key}: no snapshot and no pricing_mode', () {
        expect(entry.value.isCompletedSale(), isFalse);
        _expectBody(entry.value.toApiJson(), completed: false);
      });
    }
  });

  group('Finish saved order compares the sale lines', () {
    // OrderSubmissionCoordinator keeps the items of the body it sent. That
    // body has no receipt identity, so its lines carry no snapshot.
    List<dynamic> savedAttempt(List<LocalCartItem> cart) =>
        jsonDecode(jsonEncode(OrderSubmissionPayload(
          items: LocalProductProvider.buildOrderItemsPayloadFrom(cart),
          transactionNumber: 'T-1',
          storeId: 1,
        ).toApiJson()['items'])) as List;

    Iterable<Map<String, dynamic>> currentCart(List<LocalCartItem> cart) =>
        LocalProductProvider.buildOrderItemsPayloadFrom(cart).reversed;

    test('an unchanged offer cart matches its saved attempt', () {
      final saved = savedAttempt([_offerItem()]);
      final current = currentCart([_offerItem()]);
      // The cart always builds the snapshot the saved attempt never has.
      expect(jsonEncode(saved), isNot(jsonEncode(current.toList())));
      expect(comparableOrderItems(saved), comparableOrderItems(current));
    });

    test('an offer version re-stamped by a product sync still matches', () {
      final saved = savedAttempt([_offerItem()]);
      final resynced = _offerItem()..offerVersion = 4;
      expect(
        comparableOrderItems(saved),
        comparableOrderItems(currentCart([resynced])),
      );
    });

    test('a different price, quantity or line order still differs', () {
      final second = _offerItem()
        ..comment = 'second line'
        ..price = 50;
      final saved = savedAttempt([_offerItem(), second]);
      for (final cart in [
        [_offerItem(price: 85), second],
        [_offerItem(quantity: 3), second],
        [second, _offerItem()],
      ]) {
        expect(
          comparableOrderItems(saved),
          isNot(comparableOrderItems(currentCart(cart))),
        );
      }
      expect(
        comparableOrderItems(saved),
        comparableOrderItems(currentCart([_offerItem(), second])),
      );
    });
  });
}
