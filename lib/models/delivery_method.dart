import 'package:pos_machine/resources/localization_service.dart';

/// Canonical behaviour class for a delivery method.
///
/// The billing flow must never branch on a delivery method's *display name*:
/// once the backend starts returning localized names (`توصيل بالسيارة` instead
/// of `Car Delivery`) every `name ==` comparison silently stops matching, which
/// disables car-number validation and address capture without any error.
///
/// [DeliveryKind] is resolved from stable data — capability flags first, then
/// `code`, then the English entry of the `translations` map, and only as a last
/// resort the raw name. See [DeliveryMethod.kind].
enum DeliveryKind {
  storeTakeaway,
  carDelivery,
  doorDelivery,
  thirdPartyLogistics,

  /// A tenant-defined method we have no special behaviour for. Treated as a
  /// plain counter pickup unless the backend sends capability flags.
  other,
}

/// Normalizes a code/name for comparison: uppercase, and every run of
/// non-alphanumeric characters collapsed to a single `_`.
///
/// This makes `car-delivery`, `CAR_DELIVERY`, `Car Delivery` and `car delivery`
/// all resolve to `CAR_DELIVERY`, so we tolerate whatever casing/separator
/// convention the backend seeds without another round trip.
String _normalizeToken(String raw) {
  final upper = raw.trim().toUpperCase();
  final collapsed = upper.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
  return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Known tokens per kind. Covers both the historical English display names and
/// the hyphenated/underscored code conventions the backend may seed.
const Map<DeliveryKind, Set<String>> _kindTokens = {
  DeliveryKind.storeTakeaway: {
    'STORE_TAKEAWAY',
    'STORE_TAKE_AWAY',
    'TAKEAWAY',
    'TAKE_AWAY',
    'PICKUP',
    'STORE_PICKUP',
    'SELF_PICKUP',
  },
  DeliveryKind.carDelivery: {
    'CAR_DELIVERY',
    'CAR',
    'CURBSIDE',
    'CURBSIDE_PICKUP',
    'DRIVE_THROUGH',
  },
  DeliveryKind.doorDelivery: {
    'DOOR_DELIVERY',
    'HOME_DELIVERY',
    'DOOR',
    'DELIVERY',
    'STANDARD_DELIVERY',
  },
  DeliveryKind.thirdPartyLogistics: {
    'THIRD_PARTY_LOGISTICS',
    'THIRD_PARTY',
    'THIRDPARTY',
    '3PL',
    'LOGISTICS',
  },
};

DeliveryKind _kindFromToken(String? raw) {
  if (raw == null || raw.trim().isEmpty) return DeliveryKind.other;
  final token = _normalizeToken(raw);
  if (token.isEmpty) return DeliveryKind.other;
  for (final entry in _kindTokens.entries) {
    if (entry.value.contains(token)) return entry.key;
  }
  return DeliveryKind.other;
}

class DeliveryMethod {
  final String id;

  /// Display name as returned by the API for the requested locale. May be
  /// localized — never branch on this, use [kind].
  final String name;

  /// Stable machine code. Not translated. Preferred input for [kind].
  final String? code;

  /// Per-language display names keyed by base language code (`en`, `ar`).
  /// Lets the UI switch language from cache with no refetch.
  final Map<String, String> translations;

  /// Backend capability flags. Null means "backend has not shipped them yet",
  /// which is different from `false` — see [requiresCarNumber].
  final bool? requiresCarNumberFlag;
  final bool? requiresAddressFlag;

  final String? iconKey;
  final int sortOrder;
  final bool enabled;

  final List<DeliveryPrice>? _prices;

  List<DeliveryPrice> get prices => _prices ?? const [];

  DeliveryMethod({
    required this.id,
    required this.name,
    this.code,
    this.translations = const {},
    this.requiresCarNumberFlag,
    this.requiresAddressFlag,
    this.iconKey,
    this.sortOrder = 0,
    this.enabled = true,
    List<DeliveryPrice>? prices,
  }) : _prices = prices;

  /// Canonical behaviour class, resolved from the most stable signal available.
  ///
  /// Resolution order:
  /// 1. `code` — stable and never translated.
  /// 2. The English entry of [translations] — stable even when `name` is Arabic.
  /// 3. `name` — correct only while the backend returns English.
  ///
  /// Capability flags are deliberately *not* used here: they answer "what does
  /// this method need?" rather than "which method is this?". They are consulted
  /// separately by [requiresCarNumber] / [requiresAddress].
  DeliveryKind get kind {
    final fromCode = _kindFromToken(code);
    if (fromCode != DeliveryKind.other) return fromCode;

    final english = translations['en'];
    if (english != null) {
      final fromEnglish = _kindFromToken(english);
      if (fromEnglish != DeliveryKind.other) return fromEnglish;
    }

    return _kindFromToken(name);
  }

  /// Whether this method needs a car/vehicle number before checkout.
  ///
  /// Prefers the backend flag when present so a tenant can add a new
  /// curbside-style method without an app release; falls back to [kind] while
  /// the flag is unavailable.
  bool get requiresCarNumber =>
      requiresCarNumberFlag ?? (kind == DeliveryKind.carDelivery);

  /// Whether this method needs a delivery address before checkout.
  bool get requiresAddress =>
      requiresAddressFlag ?? (kind == DeliveryKind.doorDelivery);

  /// Display label for the active app locale, resolved from [translations] with
  /// a fallback to the server-resolved [name]. Resolving at render time means a
  /// language switch needs no refetch and works offline.
  String get label {
    final code = LocalizationService.locale.languageCode.toLowerCase();
    final exact = translations[code];
    if (exact != null && exact.trim().isNotEmpty) return exact.trim();

    final english = translations['en'];
    if (english != null && english.trim().isNotEmpty && name.trim().isEmpty) {
      return english.trim();
    }

    return name;
  }

  // Get the base price (first price in the list)
  double? get basePrice {
    if (prices.isEmpty) return null;
    return prices.first.price;
  }

  // Get all unique prices as a formatted string
  String get pricesDisplay {
    if (prices.isEmpty) return 'Free';
    final priceList = prices.map((p) => p.price.toString()).toList();
    return priceList.join(', ');
  }

  /// Legacy positional factory retained for the `{id: name}` map shape some
  /// older responses use.
  factory DeliveryMethod.fromJson(
    String id,
    String name,
  ) {
    return DeliveryMethod(
      id: id,
      name: name,
    );
  }

  /// Parses both the API payload and the SharedPreferences cache entry, so the
  /// two can never drift apart.
  ///
  /// Every new field is optional with a safe default: an older backend that
  /// sends only `id`/`name`/`code` parses exactly as before.
  factory DeliveryMethod.fromMap(Map<String, dynamic> json) {
    final prices = <DeliveryPrice>[];
    final rawPrices = json['prices'];
    if (rawPrices is List) {
      for (final priceItem in rawPrices) {
        if (priceItem is Map<String, dynamic>) {
          try {
            prices.add(DeliveryPrice.fromJson(priceItem));
          } catch (_) {
            // Skip malformed price rows rather than dropping the method.
          }
        }
      }
    }

    return DeliveryMethod(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['label']?.toString() ?? '',
      code: _nonEmpty(json['code']?.toString()),
      translations: parseTranslations(json['translations']),
      requiresCarNumberFlag: _parseNullableBool(json['requires_car_number']),
      requiresAddressFlag: _parseNullableBool(json['requires_address']),
      iconKey: _nonEmpty(json['icon_key']?.toString()),
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      enabled: _parseStatus(json['status']),
      prices: prices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'translations': translations,
      'requires_car_number': requiresCarNumberFlag,
      'requires_address': requiresAddressFlag,
      'icon_key': iconKey,
      'sort_order': sortOrder,
      'status': enabled ? 'Y' : 'N',
      'prices': prices.map((price) => price.toJson()).toList(),
    };
  }

  /// Reads the `translations` field defensively.
  ///
  /// The backend currently emits `[]` (PHP's empty associative array) rather
  /// than `{}` when a record has no translations, so both shapes must parse.
  /// Keys are lowercased; a region-qualified key (`ar-sa`) additionally
  /// populates its base language (`ar`) when that is not already present, since
  /// the client looks up by base language only.
  static Map<String, String> parseTranslations(dynamic raw) {
    if (raw is! Map) return const {};

    final result = <String, String>{};
    raw.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      final normalizedKey = key.toString().trim().toLowerCase();
      if (normalizedKey.isEmpty) return;
      result[normalizedKey] = text;
    });

    // Backfill base languages from region-qualified keys (`ar-sa` -> `ar`).
    for (final entry in result.entries.toList()) {
      final dashIndex = entry.key.indexOf('-');
      if (dashIndex > 0) {
        final base = entry.key.substring(0, dashIndex);
        result.putIfAbsent(base, () => entry.value);
      }
    }

    return result;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Returns null when the key is absent, so "backend has not shipped this
  /// flag" stays distinguishable from an explicit `false`.
  static bool? _parseNullableBool(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      if (v.isEmpty) return null;
      if (v == 'true' || v == '1' || v == 'y' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'n' || v == 'no') return false;
    }
    return null;
  }

  /// Lenient `status` parsing — the backend uses `Y`/`N` but the truthy set was
  /// never confirmed, so booleans and 1/0 are accepted too. Absent means enabled.
  static bool _parseStatus(dynamic raw) => _parseNullableBool(raw) ?? true;

  @override
  String toString() =>
      'DeliveryMethod(id: $id, code: $code, name: $name, kind: ${kind.name})';
}

class DeliveryPrice {
  final String id;
  final String deliveryMethodId;
  final double price;
  final String? createdAt;
  final String? updatedAt;

  DeliveryPrice({
    required this.id,
    required this.deliveryMethodId,
    required this.price,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryPrice.fromJson(Map<String, dynamic> json) {
    return DeliveryPrice(
      id: json['id']?.toString() ?? '',
      deliveryMethodId: json['delivery_method_id']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_method_id': deliveryMethodId,
      'price': price,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
