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
};

bool allowsDecimalQuantityUnit(String? unit) {
  final normalizedUnit = unit?.trim().toUpperCase();
  return decimalQuantityUnits.contains(normalizedUnit);
}

List<TextInputFormatter> quantityInputFormattersForUnit(String? unit) {
  if (allowsDecimalQuantityUnit(unit)) {
    return [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
    ];
  }

  return [FilteringTextInputFormatter.digitsOnly];
}
