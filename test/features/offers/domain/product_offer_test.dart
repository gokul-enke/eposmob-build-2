import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/offers/domain/product_offer.dart';

void main() {
  group('ProductOfferLine.priceFor', () {
    test('percentage reduces the standard price', () {
      const line = ProductOfferLine(
        productId: 1,
        type: ProductOfferType.percentage,
        value: 10,
      );
      expect(line.priceFor(100), closeTo(90, 0.0001));
    });

    test('flat_amount subtracts the amount from the standard price', () {
      const line = ProductOfferLine(
        productId: 1,
        type: ProductOfferType.flatAmount,
        value: 15,
      );
      expect(line.priceFor(100), 85);
    });

    test('flat_amount larger than the price makes the item free', () {
      const line = ProductOfferLine(
        productId: 1,
        type: ProductOfferType.flatAmount,
        value: 120,
      );
      expect(line.priceFor(100), 0);
    });

    test('a zero or negative amount changes nothing', () {
      for (final value in [0.0, -5.0]) {
        final line = ProductOfferLine(
          productId: 1,
          type: ProductOfferType.flatAmount,
          value: value,
        );
        expect(line.priceFor(100), isNull, reason: 'value $value');
      }
    });

    test('rejects out-of-range percentages', () {
      for (final value in [0.0, -5.0, 101.0]) {
        final line = ProductOfferLine(
          productId: 1,
          type: ProductOfferType.percentage,
          value: value,
        );
        expect(line.priceFor(100), isNull, reason: 'value $value');
      }
    });

    test('100 percent makes the item free', () {
      const line = ProductOfferLine(
        productId: 1,
        type: ProductOfferType.percentage,
        value: 100,
      );
      expect(line.priceFor(50), 0);
    });

    test('non-finite values never produce a price or crash pricing', () {
      for (final type in ProductOfferType.values) {
        for (final value in [
          double.nan,
          double.infinity,
          double.negativeInfinity
        ]) {
          final line = ProductOfferLine(productId: 1, type: type, value: value);
          expect(line.priceFor(100), isNull);
          expect(
              ProductOfferLine.tryParse({
                'product_id': 1,
                'type': type.apiValue,
                'value': value.toString(),
              }),
              isNull);
        }
      }
    });
  });

  group('ProductOffer.tryParse', () {
    Map<String, dynamic> json() => {
          'id': 9,
          'version': 3,
          'name': 'Test Offer',
          'store_id': 1,
          'valid_from': '2026-10-01T00:00:00+05:30',
          'valid_until': '2026-11-01T00:00:00+05:30',
          'lines': [
            {
              'line_id': 501,
              'product_id': 123,
              'stock_id': null,
              'type': 'percentage',
              'value': 10,
            },
            {
              'line_id': 502,
              'product_id': '124',
              'stock_id': 88,
              'type': 'flat_amount',
              'value': '80.5',
            },
            {'product_id': 125, 'type': 'fixed_price', 'value': 1},
          ],
        };

    test(
        'parses the contract shape and drops unknown types such as fixed_price',
        () {
      final offer = ProductOffer.tryParse(json())!;
      expect(offer.id, 9);
      expect(offer.version, 3);
      expect(offer.validFrom, DateTime.utc(2026, 9, 30, 18, 30));
      expect(offer.validUntil, DateTime.utc(2026, 10, 31, 18, 30));
      expect(offer.lines, hasLength(2));
      expect(offer.lines[1].productId, 124);
      expect(offer.lines[1].stockId, 88);
      expect(offer.lines[1].type, ProductOfferType.flatAmount);
      expect(offer.lines[1].value, 80.5);
    });

    test('valid_until is exclusive and valid_from inclusive', () {
      final offer = ProductOffer.tryParse(json())!;
      expect(offer.isActiveAt(DateTime.utc(2026, 9, 30, 18, 30)), isTrue);
      expect(offer.isActiveAt(DateTime.utc(2026, 9, 30, 18, 29)), isFalse);
      expect(offer.isActiveAt(DateTime.utc(2026, 10, 31, 18, 29, 59)), isTrue);
      expect(offer.isActiveAt(DateTime.utc(2026, 10, 31, 18, 30)), isFalse);
    });

    test('rejects dates without a time zone offset', () {
      final raw = json()..['valid_from'] = '2026-10-01';
      expect(ProductOffer.tryParse(raw), isNull);
    });

    test('rejects an empty validity window', () {
      final raw = json()..['valid_until'] = '2026-10-01T00:00:00+05:30';
      expect(ProductOffer.tryParse(raw), isNull);
    });

    test('survives a toJson round trip', () {
      final offer = ProductOffer.tryParse(json())!;
      final copy = ProductOffer.tryParse(offer.toJson())!;
      expect(copy.validFrom, offer.validFrom);
      expect(copy.validUntil, offer.validUntil);
      expect(copy.lines.map((l) => l.toJson()),
          offer.lines.map((l) => l.toJson()));
    });
  });

  test('parses category lines with text ids and a distance', () {
    final offer = ProductOffer.tryParse({
      'id': 12,
      'version': 1,
      'store_id': null,
      'target_type': 'category',
      'category_id': 5,
      'enabled': true,
      'valid_from': '2026-10-01T00:00:00Z',
      'valid_until': '2026-11-01T00:00:00Z',
      'lines': [
        {
          'line_id': 'category-123',
          'category_distance': 1,
          'product_id': 7,
          'stock_id': null,
          'type': 'percentage',
          'value': 5,
        },
      ],
    })!;
    expect(offer.storeId, isNull);
    final line = offer.lines.single;
    expect(line.lineId, isNull);
    expect(line.categoryDistance, 1);
    expect(line.isCategoryLine, isTrue);
    expect(ProductOffer.tryParse(offer.toJson())!.lines.single.categoryDistance,
        1);
  });

  test('a full_snapshot response is flagged', () {
    final response = ProductOfferSyncResponse.fromJson({
      'success': true,
      'server_time': '2026-10-06T11:00:00Z',
      'full_snapshot': true,
      'offers': [],
      'removed_offer_ids': [],
    });
    expect(response.fullSnapshot, isTrue);
  });

  test('sync response parses offers, removed ids and server time', () {
    final response = ProductOfferSyncResponse.fromJson({
      'success': true,
      'server_time': '2026-10-06T11:00:00Z',
      'offers': [
        {
          'id': 9,
          'version': 1,
          'valid_from': '2026-10-01T00:00:00Z',
          'valid_until': '2026-11-01T00:00:00Z',
          'lines': [],
        },
        {'id': 'broken'},
      ],
      'removed_offer_ids': [7, '8'],
    });
    expect(response.offers.map((o) => o.id), [9]);
    expect(response.removedOfferIds, {7, 8});
    expect(response.serverTime, DateTime.utc(2026, 10, 6, 11));
  });
}
