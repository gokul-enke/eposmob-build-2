import 'package:flutter/foundation.dart';

import 'offer_money.dart';

/// How a product offer changes the price of one base unit.
enum ProductOfferType {
  /// The standard price is reduced by `value` percent.
  percentage,

  /// `value` is subtracted from the standard price.
  flatAmount;

  /// Unknown types (for example a future fixed-price type) return null, and
  /// the line is skipped rather than priced with a guessed calculation.
  static ProductOfferType? tryParse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'percentage':
        return ProductOfferType.percentage;
      case 'flat_amount':
        return ProductOfferType.flatAmount;
      default:
        return null;
    }
  }

  String get apiValue => switch (this) {
        ProductOfferType.percentage => 'percentage',
        ProductOfferType.flatAmount => 'flat_amount',
      };
}

/// One rule inside an offer: a product (optionally one batch), or a product
/// reached through a category. Line overrides are already merged by the
/// backend, so [type] and [value] are final.
class ProductOfferLine {
  const ProductOfferLine({
    required this.productId,
    required this.type,
    required this.value,
    this.lineId,
    this.stockId,
    this.categoryDistance,
  });

  /// Numeric id of a product line. Category lines have text ids such as
  /// `category-123`, which are not kept.
  final int? lineId;
  final int productId;

  /// Set only for a batch-specific line.
  final int? stockId;

  /// 0 for the product's own category, 1 for its parent, and so on. Null for
  /// a line that targets the product directly.
  final int? categoryDistance;
  final ProductOfferType type;
  final double value;

  bool get isCategoryLine => categoryDistance != null;

  /// The offer price for a base unit whose standard price is
  /// [standardUnitPrice], rounded to 3 decimals, or null when this line would
  /// not lower the price.
  double? priceFor(double standardUnitPrice) {
    if (!standardUnitPrice.isFinite ||
        standardUnitPrice <= 0 ||
        !value.isFinite) {
      return null;
    }
    final double offerPrice;
    switch (type) {
      case ProductOfferType.percentage:
        if (value <= 0 || value > 100) return null;
        offerPrice = standardUnitPrice * (1 - value / 100);
      case ProductOfferType.flatAmount:
        if (value <= 0) return null;
        // An amount larger than the price makes the item free, never negative.
        offerPrice =
            value >= standardUnitPrice ? 0.0 : standardUnitPrice - value;
    }
    final rounded = roundOfferUnitPrice(offerPrice);
    if (rounded >= standardUnitPrice - 0.000001) return null;
    return rounded;
  }

  /// Parses one line, or returns null when a required field is missing.
  static ProductOfferLine? tryParse(Object? json) {
    if (json is! Map) return null;
    final productId = _parseInt(json['product_id']);
    final type = ProductOfferType.tryParse(json['type']);
    final value = _parseDouble(json['value']);
    if (productId == null || type == null || value == null) return null;
    return ProductOfferLine(
      lineId: _parseInt(json['line_id']),
      productId: productId,
      stockId: _parseInt(json['stock_id']),
      categoryDistance: _parseInt(json['category_distance']),
      type: type,
      value: value,
    );
  }

  Map<String, dynamic> toJson() => {
        'line_id': lineId,
        'product_id': productId,
        'stock_id': stockId,
        'category_distance': categoryDistance,
        'type': type.apiValue,
        'value': value,
      };
}

/// A product offer as delivered by `GET /api/v1/offers/pos-sync`.
class ProductOffer {
  const ProductOffer({
    required this.id,
    required this.version,
    required this.validFrom,
    required this.validUntil,
    required this.lines,
    this.name = '',
    this.storeId,
  });

  final int id;
  final int version;
  final String name;

  /// Null means the offer applies to every store.
  final int? storeId;

  /// Inclusive start, in UTC.
  final DateTime validFrom;

  /// Exclusive end, in UTC.
  final DateTime validUntil;
  final List<ProductOfferLine> lines;

  bool isActiveAt(DateTime at) {
    final utc = at.toUtc();
    return !utc.isBefore(validFrom) && utc.isBefore(validUntil);
  }

  /// Parses one offer, or returns null when it cannot be applied safely
  /// (missing id or dates, or an empty validity window). Invalid lines are
  /// dropped; the rest of the offer is kept.
  static ProductOffer? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _parseInt(json['id']);
    final validFrom = _parseDate(json['valid_from']);
    final validUntil = _parseDate(json['valid_until']);
    if (id == null || validFrom == null || validUntil == null) return null;
    if (!validUntil.isAfter(validFrom)) return null;

    final rawLines = json['lines'];
    final lines = <ProductOfferLine>[
      if (rawLines is List)
        for (final raw in rawLines)
          if (ProductOfferLine.tryParse(raw) case final line?) line,
    ];

    return ProductOffer(
      id: id,
      version: _parseInt(json['version']) ?? 0,
      name: json['name']?.toString() ?? '',
      storeId: _parseInt(json['store_id']),
      validFrom: validFrom,
      validUntil: validUntil,
      lines: List.unmodifiable(lines),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'name': name,
        'store_id': storeId,
        'valid_from': validFrom.toIso8601String(),
        'valid_until': validUntil.toIso8601String(),
        'lines': lines.map((line) => line.toJson()).toList(),
      };
}

/// The body of `GET /api/v1/offers/pos-sync`.
class ProductOfferSyncResponse {
  const ProductOfferSyncResponse({
    required this.offers,
    this.removedOfferIds = const <int>{},
    this.serverTime,
    this.receivedAt,
    this.fullSnapshot = false,
  });

  final List<ProductOffer> offers;

  /// Offers to drop. Applied after [offers], so an id in both is removed.
  final Set<int> removedOfferIds;
  final DateTime? serverTime;

  /// Device-clock midpoint of the request carrying [serverTime]. Null when
  /// the response was not received over the network. Used for clock correction.
  final DateTime? receivedAt;

  /// The backend sent every offer of the store (`full_snapshot: true`), so
  /// the local cache must be replaced, not merged.
  final bool fullSnapshot;

  factory ProductOfferSyncResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      throw const FormatException('Offer sync response reported failure.');
    }
    final rawOffers = json['offers'];
    final rawRemoved = json['removed_offer_ids'];
    final offers = <ProductOffer>[];
    final removed = <int>{
      if (rawRemoved is List)
        for (final raw in rawRemoved)
          if (_parseInt(raw) case final id?) id,
    };
    var dropped = 0;
    if (rawOffers is List) {
      for (final raw in rawOffers) {
        final id = raw is Map ? _parseInt(raw['id']) : null;
        // Disabled offers should arrive in removed_offer_ids; this is a
        // safeguard for a backend that returns them with `enabled: false`.
        if (raw is Map && _isDisabled(raw['enabled'])) {
          if (id != null) removed.add(id);
          continue;
        }
        final offer = ProductOffer.tryParse(raw);
        if (offer != null) {
          offers.add(offer);
          continue;
        }
        dropped++;
        // An unreadable new version must not leave the older cached version
        // of the same offer applying.
        if (id != null) removed.add(id);
      }
    }
    if (dropped > 0) {
      debugPrint('Product offers: dropped $dropped unreadable offer(s).');
    }
    return ProductOfferSyncResponse(
      serverTime: _parseDate(json['server_time']),
      fullSnapshot: json['full_snapshot'] == true,
      offers: offers,
      removedOfferIds: removed,
    );
  }
}

bool _isDisabled(Object? value) {
  if (value is bool) return !value;
  if (value is num) return value == 0;
  final text = value?.toString().trim().toLowerCase();
  return text == 'false' || text == '0';
}

int? _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _parseDouble(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().trim() ?? '');
  return parsed != null && parsed.isFinite ? parsed : null;
}

/// Offer times must carry an offset (or `Z`). A bare date or a local time
/// is ambiguous across store time zones and is rejected.
DateTime? _parseDate(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final hasOffset = text.endsWith('Z') ||
      text.endsWith('z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
  if (!hasOffset) return null;
  return DateTime.tryParse(text)?.toUtc();
}
