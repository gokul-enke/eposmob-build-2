import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/offers/domain/offer_money.dart';
import 'package:pos_machine/features/offers/domain/product_offer.dart';
import 'package:pos_machine/features/offers/domain/product_offer_pricing.dart';

import '../support/offer_fixtures.dart';

ProductOfferPrice? resolve(
  List<ProductOffer> offers, {
  DateTime? at,
  List<int> stockIds = const [],
  double standard = 100,
}) {
  return resolveProductOfferPrice(
    catalog: offerCatalog(offers),
    productId: 1,
    standardUnitPrice: standard,
    at: at ?? offerTestNow,
    stockIds: stockIds,
  );
}

void main() {
  group('selection order (one winner, no stacking)', () {
    test('a product rule beats a category rule, even at a lower price', () {
      final winner = resolve([
        productOffer(
          id: 1,
          lines: [offerLine(productId: 1, lineId: 10, value: 5)],
        ),
        productOffer(
          id: 2,
          lines: [offerLine(productId: 1, categoryDistance: 0, value: 50)],
        ),
      ])!;
      expect(winner.offerId, 1);
      expect(winner.price, closeTo(95, 0.0001));
    });

    test('a store-specific offer beats a company-wide one', () {
      final winner = resolve([
        productOffer(
          id: 1,
          companyWide: true,
          lines: [offerLine(productId: 1, lineId: 99, value: 50)],
        ),
        productOffer(
          id: 2,
          lines: [offerLine(productId: 1, lineId: 10, value: 5)],
        ),
      ])!;
      expect(winner.offerId, 2);
    });

    test('an offer for another store never applies', () {
      expect(
        resolve([
          productOffer(
            storeId: 2,
            lines: [offerLine(productId: 1, lineId: 10)],
          ),
        ]),
        isNull,
      );
    });

    test('a batch rule beats a product-wide rule, then the highest line id',
        () {
      final winner = resolve([
        productOffer(
          id: 1,
          lines: [offerLine(productId: 1, lineId: 900, value: 50)],
        ),
        productOffer(
          id: 2,
          lines: [offerLine(productId: 1, lineId: 10, stockId: 88, value: 5)],
        ),
        productOffer(
          id: 3,
          lines: [offerLine(productId: 1, lineId: 20, stockId: 88, value: 8)],
        ),
      ], stockIds: [
        88
      ])!;
      expect(winner.offerId, 3);

      final productWide = resolve([
        productOffer(
          id: 1,
          lines: [offerLine(productId: 1, lineId: 10, value: 5)],
        ),
        productOffer(
          id: 2,
          lines: [offerLine(productId: 1, lineId: 20, value: 8)],
        ),
      ])!;
      expect(productWide.offerId, 2);
    });

    test('the nearest category wins, then the highest offer id', () {
      final winner = resolve([
        productOffer(
          id: 1,
          lines: [offerLine(productId: 1, categoryDistance: 2, value: 50)],
        ),
        productOffer(
          id: 2,
          lines: [offerLine(productId: 1, categoryDistance: 0, value: 5)],
        ),
        productOffer(
          id: 3,
          lines: [offerLine(productId: 1, categoryDistance: 0, value: 7)],
        ),
      ])!;
      expect(winner.offerId, 3);
    });

    test('a company-wide product rule beats a store-specific category rule',
        () {
      final winner = resolve([
        productOffer(
          id: 1,
          lines: [offerLine(productId: 1, categoryDistance: 0, value: 50)],
        ),
        productOffer(
          id: 2,
          companyWide: true,
          lines: [offerLine(productId: 1, lineId: 10, value: 5)],
        ),
      ])!;
      expect(winner.offerId, 2);
      expect(winner.price, closeTo(95, 0.0001));
    });

    test('a store-specific product-wide rule beats a company-wide batch rule',
        () {
      final winner = resolve([
        productOffer(
          id: 1,
          companyWide: true,
          lines: [
            offerLine(productId: 1, lineId: 900, stockId: 88, value: 50),
          ],
        ),
        productOffer(
          id: 2,
          lines: [offerLine(productId: 1, lineId: 10, value: 5)],
        ),
      ], stockIds: [
        88
      ])!;
      expect(winner.offerId, 2);
    });

    test('among category rules a store-specific one beats a nearer one', () {
      final winner = resolve([
        productOffer(
          id: 3,
          companyWide: true,
          lines: [offerLine(productId: 1, categoryDistance: 0, value: 50)],
        ),
        productOffer(
          id: 1,
          lines: [offerLine(productId: 1, categoryDistance: 2, value: 5)],
        ),
      ])!;
      expect(winner.offerId, 1);
    });

    test('the highest line id wins over the highest offer id', () {
      final winner = resolve([
        productOffer(
          id: 5,
          lines: [offerLine(productId: 1, lineId: 10, value: 50)],
        ),
        productOffer(
          id: 3,
          lines: [offerLine(productId: 1, lineId: 20, value: 5)],
        ),
      ])!;
      expect(winner.offerId, 3);
    });

    test('the winner is used even when it does not lower the price', () {
      // The product rule is a no-op for a ₹10 product (flat ₹20 off still
      // lowers it, so use a zero value). The category rule must not be tried.
      final winner = resolve([
        productOffer(
          id: 1,
          lines: [
            offerLine(
              productId: 1,
              lineId: 10,
              type: ProductOfferType.flatAmount,
              value: 0,
            ),
          ],
        ),
        productOffer(
          id: 2,
          lines: [offerLine(productId: 1, categoryDistance: 0, value: 50)],
        ),
      ]);
      expect(winner, isNull);
    });
  });

  group('category fallback when the product offer ends first', () {
    final offers = [
      productOffer(
        id: 1,
        validUntil: DateTime.utc(2026, 10, 8),
        lines: [offerLine(productId: 1, lineId: 10, value: 20)],
      ),
      productOffer(
        id: 2,
        validUntil: DateTime.utc(2026, 10, 15),
        lines: [offerLine(productId: 1, categoryDistance: 0, value: 10)],
      ),
    ];

    test('7 Oct: the product offer applies', () {
      final winner = resolve(offers, at: DateTime.utc(2026, 10, 7, 12))!;
      expect(winner.offerId, 1);
      expect(winner.price, closeTo(80, 0.0001));
    });

    test('9 Oct, still offline: the category offer applies', () {
      final winner = resolve(offers, at: DateTime.utc(2026, 10, 9, 12))!;
      expect(winner.offerId, 2);
      expect(winner.price, closeTo(90, 0.0001));
    });

    test('16 Oct: no offer', () {
      expect(resolve(offers, at: DateTime.utc(2026, 10, 16)), isNull);
    });
  });

  group('rounding', () {
    test('half-way values round up, never to even', () {
      expect(roundHalfUp(89.9945, 3), 89.995);
      expect(roundHalfUp(78.125, 2), 78.13);
      expect(roundHalfUp(0.285, 2), 0.29);
      expect(roundHalfUp(2.5, 0), 3);
    });

    test('a percentage offer price is rounded to 3 decimals', () {
      // 19.99 - 15% = 16.9915
      final winner = resolve(
        [
          productOffer(
            lines: [offerLine(productId: 1, lineId: 1, value: 15)],
          ),
        ],
        standard: 19.99,
      )!;
      expect(winner.price, 16.992);
    });

    test('flat amount is exact and clamps at zero', () {
      final flat = resolve([
        productOffer(
          lines: [
            offerLine(
              productId: 1,
              lineId: 1,
              type: ProductOfferType.flatAmount,
              value: 15.5,
            ),
          ],
        ),
      ])!;
      expect(flat.price, 84.5);

      final free = resolve([
        productOffer(
          lines: [
            offerLine(
              productId: 1,
              lineId: 1,
              type: ProductOfferType.flatAmount,
              value: 500,
            ),
          ],
        ),
      ])!;
      expect(free.price, 0);
    });
  });
}
