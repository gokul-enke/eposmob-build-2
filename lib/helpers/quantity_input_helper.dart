import 'package:flutter/services.dart';

const Set<String> decimalQuantityUnits = {
  'KG',
  'KGS',
  'G',
  'GM',
  'GMS',
  'GRAM',
  'GRAMS',
  'LT',
  'LTR',
  'L',
  'ML',
  'CRT',
  'CTN',
  'CARTON',
  'CARTOON',
  // Pack and set units configured with fractional quantities.
  'DOZEN',
  'DZN',
  'BOX 10 DZ',
  'BX 10 D',
  'BOX 20 DZ',
  'SET4',
  'SET5',
  'SET6',
  'SET10',
  'BUNDLE',
};

bool allowsDecimalQuantityUnit(String? unit) {
  final normalizedUnit = unit?.trim().toUpperCase();
  return decimalQuantityUnits.contains(normalizedUnit);
}

/// Normalizes a quantity for a given unit. For non-decimal units (anything
/// not in [decimalQuantityUnits]) the value is floored to a whole number so
/// PCS/PC-style products never carry a fractional quantity. Decimal-capable
/// units (KG, LTR, ...) pass through unchanged.
num normalizeQuantityForUnit(num value, String? unit) {
  if (allowsDecimalQuantityUnit(unit)) {
    return value;
  }
  return value.floor();
}

List<TextInputFormatter> quantityInputFormattersForUnit(String? unit) {
  if (allowsDecimalQuantityUnit(unit)) {
    return [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
    ];
  }

  return [FilteringTextInputFormatter.digitsOnly];
}
