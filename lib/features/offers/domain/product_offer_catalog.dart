import 'product_offer.dart';

/// The offers cached for one store, plus the `POS_OFFERS` switch and the
/// device-to-server clock offset measured at the last sync.
///
/// Immutable: every sync produces a new catalog.
class ProductOfferCatalog {
  ProductOfferCatalog({
    this.enabled = false,
    Map<int, ProductOffer> offers = const <int, ProductOffer>{},
    this.storeId,
    this.lastSyncedAt,
    this.clockOffset = Duration.zero,
  }) : offers = Map.unmodifiable(offers);

  static final empty = ProductOfferCatalog();

  /// Mirrors the `POS_OFFERS` app setting. Missing means false.
  final bool enabled;
  final Map<int, ProductOffer> offers;
  final int? storeId;

  /// Server time of the last successful offer sync. Null until the first
  /// sync; used as `since` for the next delta sync.
  final DateTime? lastSyncedAt;

  /// `server_time - device time` at the last sync. Added to the device clock
  /// when checking offer validity, so a device whose clock is wrong still
  /// starts and ends offers on time.
  final Duration clockOffset;

  late final Map<int, List<(ProductOffer, ProductOfferLine)>> _byProduct =
      _indexByProduct(offers.values);

  static Map<int, List<(ProductOffer, ProductOfferLine)>> _indexByProduct(
    Iterable<ProductOffer> offers,
  ) {
    final index = <int, List<(ProductOffer, ProductOfferLine)>>{};
    for (final offer in offers) {
      for (final line in offer.lines) {
        (index[line.productId] ??= []).add((offer, line));
      }
    }
    return index;
  }

  /// Device time corrected by [clockOffset].
  DateTime trustedNow(DateTime deviceNow) => deviceNow.toUtc().add(clockOffset);

  /// Offer lines for [productId] whose offer is active at [at].
  Iterable<(ProductOffer, ProductOfferLine)> activeLinesFor(
    int productId,
    DateTime at,
  ) {
    final candidates = _byProduct[productId];
    if (candidates == null) return const [];
    return candidates.where((entry) => entry.$1.isActiveAt(at));
  }

  ProductOfferCatalog copyWith({
    bool? enabled,
    Map<int, ProductOffer>? offers,
    int? storeId,
    DateTime? lastSyncedAt,
    Duration? clockOffset,
  }) {
    return ProductOfferCatalog(
      enabled: enabled ?? this.enabled,
      offers: offers ?? this.offers,
      storeId: storeId ?? this.storeId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      clockOffset: clockOffset ?? this.clockOffset,
    );
  }

  /// Applies a sync response. A full sync ([since] was not sent) replaces
  /// every offer; a delta sync upserts the returned offers and drops
  /// `removed_offer_ids`.
  ProductOfferCatalog applySync(
    ProductOfferSyncResponse response, {
    required bool fullSync,
    required DateTime deviceNow,
  }) {
    // The backend can answer a delta request with a full snapshot; its offers
    // then replace the whole cache.
    final replaceAll = fullSync || response.fullSnapshot;
    final merged =
        replaceAll ? <int, ProductOffer>{} : Map<int, ProductOffer>.of(offers);
    for (final id in response.removedOfferIds) {
      merged.remove(id);
    }
    for (final offer in response.offers) {
      merged[offer.id] = offer;
    }

    final serverTime = response.serverTime;
    final offset = serverTime == null
        ? clockOffset
        : serverTime.difference(deviceNow.toUtc());

    // Offers that ended before the server time can never apply again.
    final now = serverTime ?? deviceNow.toUtc().add(offset);
    merged.removeWhere((_, offer) => !offer.validUntil.isAfter(now));

    return ProductOfferCatalog(
      enabled: enabled,
      offers: merged,
      storeId: storeId,
      lastSyncedAt: serverTime ?? deviceNow.toUtc().add(offset),
      clockOffset: offset,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'store_id': storeId,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'clock_offset_ms': clockOffset.inMilliseconds,
        'offers': offers.values.map((offer) => offer.toJson()).toList(),
      };

  factory ProductOfferCatalog.fromJson(Map<String, dynamic> json) {
    final rawOffers = json['offers'];
    final offers = <int, ProductOffer>{};
    if (rawOffers is List) {
      for (final raw in rawOffers) {
        final offer = ProductOffer.tryParse(raw);
        if (offer != null) offers[offer.id] = offer;
      }
    }
    final offsetMs = json['clock_offset_ms'];
    return ProductOfferCatalog(
      enabled: json['enabled'] == true,
      storeId: json['store_id'] is int ? json['store_id'] as int : null,
      lastSyncedAt:
          DateTime.tryParse(json['last_synced_at']?.toString() ?? '')?.toUtc(),
      clockOffset: Duration(milliseconds: offsetMs is int ? offsetMs : 0),
      offers: offers,
    );
  }
}
