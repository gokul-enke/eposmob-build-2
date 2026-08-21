import 'package:pos_machine/models/get_product.dart';

bool purchaseOrderPurchaseUnitsMatch(
  SaleUnit? left,
  String? leftConversionRate,
  SaleUnit? right,
  String? rightConversionRate,
) {
  if (left == null || right == null) {
    return left == null && right == null;
  }

  if (_normaliseRate(leftConversionRate ?? left.conversionRate) !=
      _normaliseRate(rightConversionRate ?? right.conversionRate)) {
    return false;
  }

  final leftIdentity = _saleUnitIdentity(left);
  final rightIdentity = _saleUnitIdentity(right);
  if (leftIdentity == null || rightIdentity == null) {
    return identical(left, right);
  }
  return leftIdentity == rightIdentity;
}

String? _saleUnitIdentity(SaleUnit unit) {
  if (unit.id != null) return 'id:${unit.id}';
  if (unit.unitId != null) return 'unit:${unit.unitId}';

  final barcode = unit.barcode?.trim();
  if (barcode != null && barcode.isNotEmpty) return 'barcode:$barcode';

  final name = unit.unitName?.trim().toLowerCase();
  if (name != null && name.isNotEmpty) return 'name:$name';
  return null;
}

String? _normaliseRate(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  return parsed == null ? trimmed : parsed.toString();
}
