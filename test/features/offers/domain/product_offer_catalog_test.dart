import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/offers/domain/product_offer.dart';
import 'package:pos_machine/features/offers/domain/product_offer_catalog.dart';

import '../support/offer_fixtures.dart';

void main() {
  final base = offerCatalog([
    productOffer(id: 7, lines: [offerLine(productId: 1)]),
    productOffer(id: 8, lines: [offerLine(productId: 2)]),
  ]);

  test('a delta sync upserts offers and drops removed ids', () {
    final next = base.applySync(
      ProductOfferSyncResponse(
        serverTime: offerTestNow,
        offers: [
          productOffer(id: 8, version: 2, lines: [offerLine(productId: 3)]),
        ],
        removedOfferIds: {7},
      ),
      fullSync: false,
      deviceNow: offerTestNow,
    );
    expect(next.offers.keys, [8]);
    expect(next.offers[8]!.version, 2);
    expect(next.activeLinesFor(2, offerTestNow), isEmpty);
    expect(next.activeLinesFor(3, offerTestNow), hasLength(1));
    expect(next.lastSyncedAt, offerTestNow);
    expect(next.enabled, isTrue);
  });

  test('an id both returned and removed is removed', () {
    final next = base.applySync(
      ProductOfferSyncResponse(
        serverTime: offerTestNow,
        offers: [
          productOffer(id: 8, version: 2, lines: [offerLine(productId: 2)]),
        ],
        removedOfferIds: {8},
      ),
      fullSync: false,
      deviceNow: offerTestNow,
    );
    expect(next.offers.keys, [7]);
    expect(next.activeLinesFor(2, offerTestNow), isEmpty);
  });

  test('an unreadable new version evicts the cached offer', () {
    final next = base.applySync(
      ProductOfferSyncResponse.fromJson({
        'success': true,
        'server_time': '2026-10-06T12:00:00Z',
        'offers': [
          {
            'id': 8,
            'version': 2,
            'valid_from': '2026-10-01T00:00:00Z',
            'valid_until': null,
            'lines': [
              {'product_id': 2, 'type': 'percentage', 'value': 50},
            ],
          },
        ],
      }),
      fullSync: false,
      deviceNow: offerTestNow,
    );
    expect(next.offers.keys, [7]);
    expect(next.activeLinesFor(2, offerTestNow), isEmpty);
  });

  test('a full sync replaces every offer', () {
    final next = base.applySync(
      ProductOfferSyncResponse(
        serverTime: offerTestNow,
        offers: [
          productOffer(id: 9, lines: [offerLine(productId: 4)])
        ],
      ),
      fullSync: true,
      deviceNow: offerTestNow,
    );
    expect(next.offers.keys, [9]);
  });

  test('a delta request answered with a full snapshot replaces the cache', () {
    final next = base.applySync(
      ProductOfferSyncResponse(
        serverTime: offerTestNow,
        fullSnapshot: true,
        offers: [
          productOffer(id: 9, lines: [offerLine(productId: 4)])
        ],
      ),
      fullSync: false,
      deviceNow: offerTestNow,
    );
    expect(next.offers.keys, [9]);
  });

  test('drops offers that ended before the server time', () {
    final next = base.applySync(
      ProductOfferSyncResponse(
        serverTime: offerTestNow,
        offers: [
          productOffer(
            id: 9,
            validUntil: offerTestNow,
            lines: [offerLine(productId: 4)],
          ),
        ],
      ),
      fullSync: false,
      deviceNow: offerTestNow,
    );
    expect(next.offers.containsKey(9), isFalse);
  });

  test('measures the device clock offset from server_time', () {
    final deviceNow = offerTestNow.subtract(const Duration(hours: 2));
    final next = base.applySync(
      ProductOfferSyncResponse(serverTime: offerTestNow, offers: const []),
      fullSync: false,
      deviceNow: deviceNow,
    );
    expect(next.clockOffset, const Duration(hours: 2));
    expect(next.trustedNow(deviceNow), offerTestNow);
  });

  test('survives a JSON round trip (offline cache)', () {
    final synced = base.applySync(
      ProductOfferSyncResponse(serverTime: offerTestNow, offers: const []),
      fullSync: false,
      deviceNow: offerTestNow.subtract(const Duration(minutes: 5)),
    );
    final copy = ProductOfferCatalog.fromJson(synced.toJson());
    expect(copy.enabled, isTrue);
    expect(copy.storeId, 1);
    expect(copy.lastSyncedAt, offerTestNow);
    expect(copy.clockOffset, const Duration(minutes: 5));
    expect(copy.offers.keys, unorderedEquals([7, 8]));
    expect(copy.activeLinesFor(1, offerTestNow), hasLength(1));
  });
}
