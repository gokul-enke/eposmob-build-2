import 'package:pos_machine/models/order_details.dart';

/// Returns the unit that was selected for the sale line.
///
/// A product can have a base unit (for example, PC) and a different sale
/// unit (for example, BOX). Printing must display the sale unit when it is
/// present, just like the order-details screen does.
String getPrintUnit(dynamic item) {
  dynamic saleUnit;
  dynamic productUnit;

  if (item is Map) {
    saleUnit = item['sale_unit_name'] ??
        item['saleUnitName'] ??
        item['product_sale_unit_name'] ??
        item['productSaleUnitName'];

    if (!_hasText(saleUnit)) {
      saleUnit = _nestedUnitName(item['product_sale_unit']) ??
          _nestedUnitName(item['sale_unit']);
    }

    if (_hasText(saleUnit)) {
      return saleUnit.toString().trim();
    }

    productUnit = item['product_unit'] ?? item['productUnit'] ?? item['unit'];
  } else if (item is OrderDetailsModelDataCartItem) {
    saleUnit = item.saleUnitName;
    if (_hasText(saleUnit)) {
      return saleUnit!.trim();
    }

    productUnit = item.productUnit;
  } else {
    // Keep this helper safe for any legacy print item type.
    try {
      saleUnit = item.saleUnitName;
    } catch (_) {}
    if (_hasText(saleUnit)) {
      return saleUnit.toString().trim();
    }

    try {
      productUnit = item.productUnit;
    } catch (_) {}
  }

  return productUnit?.toString().trim() ?? '';
}

bool _hasText(dynamic value) =>
    value != null && value.toString().trim().isNotEmpty;

dynamic _nestedUnitName(dynamic value) {
  if (value is! Map) return null;
  return value['unit_name'] ?? value['unitName'] ?? value['name'];
}
