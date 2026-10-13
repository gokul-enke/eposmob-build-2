/// Immutable receipt metadata. These fields describe stored discounts; they
/// never reprice a line or apply a coupon. See docs/receipt-discount-api-contract.md.
class ItemDiscountDetails {
  const ItemDiscountDetails({
    this.itemDiscountAmount,
    this.discountOrigin,
    this.offerId,
    this.offerVersion,
    this.offerName,
    this.offerNames = const {},
    this.offerDiscountType,
    this.offerDiscountValue,
    this.orderDiscountAllocations = const [],
  });

  final String? itemDiscountAmount;
  final String? discountOrigin;
  final int? offerId;
  final int? offerVersion;
  final String? offerName;
  final Map<String, String> offerNames;
  final String? offerDiscountType;
  final String? offerDiscountValue;
  final List<OrderDiscountAllocation> orderDiscountAllocations;

  bool get isManual => discountOrigin == 'manual';
  bool get isOffer =>
      discountOrigin == 'offer' || (discountOrigin == null && offerId != null);

  factory ItemDiscountDetails.fromJson(Map<dynamic, dynamic> json) =>
      ItemDiscountDetails(
        itemDiscountAmount: _money(json['item_discount_amount']),
        discountOrigin: _text(json['discount_origin'])?.toLowerCase(),
        offerId: int.tryParse(json['offer_id']?.toString() ?? ''),
        offerVersion: int.tryParse(json['offer_version']?.toString() ?? ''),
        offerName: _text(json['offer_name']),
        offerNames: _names(json['offer_names']),
        offerDiscountType: _text(json['offer_discount_type'])?.toLowerCase(),
        offerDiscountValue: _money(json['offer_discount_value']),
        orderDiscountAllocations: List.unmodifiable([
          if (json['order_discount_allocations'] is List)
            for (final raw in json['order_discount_allocations'])
              if (raw is Map)
                if (OrderDiscountAllocation.tryParse(raw) case final value?)
                  value,
        ]),
      );

  Map<String, dynamic> toJson() => {
        if (itemDiscountAmount != null)
          'item_discount_amount': itemDiscountAmount,
        if (discountOrigin != null) 'discount_origin': discountOrigin,
        if (offerId != null) 'offer_id': offerId,
        if (offerVersion != null) 'offer_version': offerVersion,
        if (offerName != null) 'offer_name': offerName,
        if (offerNames.isNotEmpty) 'offer_names': offerNames,
        if (offerDiscountType != null) 'offer_discount_type': offerDiscountType,
        if (offerDiscountValue != null)
          'offer_discount_value': offerDiscountValue,
        if (orderDiscountAllocations.isNotEmpty)
          'order_discount_allocations':
              orderDiscountAllocations.map((value) => value.toJson()).toList(),
      };

  /// Only amounts scale for a partial receipt. The original offer rule does
  /// not change. Return APIs must supply exact stored return allocations.
  ItemDiscountDetails scaled(double factor) => ItemDiscountDetails(
        itemDiscountAmount: itemDiscountAmount == null
            ? null
            : (double.parse(itemDiscountAmount!) * factor).toStringAsFixed(2),
        discountOrigin: discountOrigin,
        offerId: offerId,
        offerVersion: offerVersion,
        offerName: offerName,
        offerNames: offerNames,
        offerDiscountType: offerDiscountType,
        offerDiscountValue: offerDiscountValue,
        orderDiscountAllocations: List.unmodifiable([
          for (final value in orderDiscountAllocations) value.scaled(factor),
        ]),
      );
}

/// One source's share of the order discount on this line. The sum must equal
/// line_discount. Amount is already inside that total, never an extra deduction.
class OrderDiscountAllocation {
  const OrderDiscountAllocation({
    required this.source,
    required this.amount,
    this.code,
    this.name,
    this.names = const {},
  });

  final String source;
  final double amount;
  final String? code;
  final String? name;
  final Map<String, String> names;

  static OrderDiscountAllocation? tryParse(Map<dynamic, dynamic> json) {
    final source = _text(json['source'])?.toLowerCase();
    final amount = double.tryParse(_money(json['amount']) ?? '');
    if (source == null || amount == null) return null;
    return OrderDiscountAllocation(
      source: source,
      amount: amount,
      code: _text(json['code']),
      name: _text(json['name']),
      names: _names(json['names']),
    );
  }

  OrderDiscountAllocation scaled(double factor) => OrderDiscountAllocation(
        source: source,
        amount: double.parse((amount * factor).toStringAsFixed(2)),
        code: code,
        name: name,
        names: names,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'amount': amount.toStringAsFixed(2),
        if (code != null) 'code': code,
        if (name != null) 'name': name,
        if (names.isNotEmpty) 'names': names,
      };
}

String? _text(dynamic raw) {
  if (raw is! String && raw is! num) return null;
  final value = raw.toString().replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  return value.isEmpty || value.toLowerCase() == 'null' ? null : value;
}

String? _money(dynamic raw) {
  final value = _text(raw)?.replaceAll(',', '');
  final parsed = double.tryParse(value ?? '');
  return parsed == null || !parsed.isFinite || parsed < 0 ? null : value;
}

Map<String, String> _names(dynamic raw) => Map.unmodifiable({
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String)
            if (_text(entry.value) case final value?)
              entry.key as String: value,
    });
