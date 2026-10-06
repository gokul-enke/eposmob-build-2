import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/offers/domain/product_offer.dart';
import 'package:pos_machine/features/offers/domain/product_offer_pricing.dart';

import '../support/offer_fixtures.dart';

void main() {
  test('applies an active product offer', () {
    final catalog = offerCatalog([
      productOffer(version: 3, lines: [offerLine(productId: 1)]),
    ]);
    final price = resolveProductOfferPrice(
      catalog: catalog,
      productId: 1,
      standardUnitPrice: 100,
      at: offerTestNow,
    )!;
    expect(price.price, closeTo(90, 0.0001));
    expect(price.standardPrice, 100);
    expect(price.offerId, 9);
    expect(price.offerVersion, 3);
  });

  test('nothing applies while POS_OFFERS is off', () {
    final catalog = offerCatalog(
      [
        productOffer(lines: [offerLine(productId: 1)])
      ],
      enabled: false,
    );
    expect(
      resolveProductOfferPrice(
        catalog: catalog,
        productId: 1,
        standardUnitPrice: 100,
        at: offerTestNow,
      ),
      isNull,
    );
  });

  test('ignores offers outside their validity window', () {
    final catalog = offerCatalog([
      productOffer(
        validFrom: DateTime.utc(2026, 10, 7),
        lines: [offerLine(productId: 1)],
      ),
      productOffer(
        id: 10,
        validUntil: DateTime.utc(2026, 10, 6, 12),
        lines: [offerLine(productId: 1)],
      ),
    ]);
    expect(
      resolveProductOfferPrice(
        catalog: catalog,
        productId: 1,
        standardUnitPrice: 100,
        at: offerTestNow,
      ),
      isNull,
    );
  });

  test('sale units (pack/case) never get an offer', () {
    final catalog = offerCatalog([
      productOffer(lines: [offerLine(productId: 1)]),
    ]);
    expect(
      resolveProductOfferPrice(
        catalog: catalog,
        productId: 1,
        standardUnitPrice: 100,
        at: offerTestNow,
        isBaseUnit: false,
      ),
      isNull,
    );
  });

  test('wholesale price wins over an offer', () {
    final catalog = offerCatalog([
      productOffer(lines: [offerLine(productId: 1)]),
    ]);
    expect(
      resolveProductOfferPrice(
        catalog: catalog,
        productId: 1,
        standardUnitPrice: 80,
        at: offerTestNow,
        usesWholesalePrice: true,
      ),
      isNull,
    );
  });

  group('batch-specific lines', () {
    final catalog = offerCatalog([
      productOffer(lines: [offerLine(productId: 1, value: 10)]),
      productOffer(
        id: 10,
        lines: [
          offerLine(
            productId: 1,
            stockId: 88,
            type: ProductOfferType.flatAmount,
            value: 5,
          ),
        ],
      ),
    ]);

    test('beat a product-wide line for that batch, even at a higher price', () {
      final price = resolveProductOfferPrice(
        catalog: catalog,
        productId: 1,
        standardUnitPrice: 100,
        at: offerTestNow,
        stockIds: [88],
      )!;
      expect(price.offerId, 10);
      expect(price.price, 95);
    });

    test('do not apply to other batches', () {
      final price = resolveProductOfferPrice(
        catalog: catalog,
        productId: 1,
        standardUnitPrice: 100,
        at: offerTestNow,
        stockIds: [77],
      )!;
      expect(price.offerId, 9);
    });

    test('do not apply when the line spans several batches', () {
      final price = resolveProductOfferPrice(
        catalog: catalog,
        productId: 1,
        standardUnitPrice: 100,
        at: offerTestNow,
        stockIds: [88, 77],
      )!;
      expect(price.offerId, 9);
    });
  });

  test('other products are untouched', () {
    final catalog = offerCatalog([
      productOffer(lines: [offerLine(productId: 1)]),
    ]);
    expect(
      resolveProductOfferPrice(
        catalog: catalog,
        productId: 2,
        standardUnitPrice: 100,
        at: offerTestNow,
      ),
      isNull,
    );
  });
}
