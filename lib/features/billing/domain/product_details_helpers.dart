import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';

/// Whether the current user may edit product details in billing context.
bool canEditProductDetails(
  BuildContext context, {
  required bool useBillingProductPermissions,
}) {
  final roleProvider = Provider.of<RoleProvider>(context, listen: false);
  if (useBillingProductPermissions) {
    return roleProvider
        .currentUserHasPermissionSync('billing.product.edit');
  }
  return roleProvider.currentUserHasPermissionSync('update_product') ||
      roleProvider
          .currentUserHasPermissionSync('menu.catalog.product.list.access');
}

String productDetailsValueToString(dynamic value) {
  if (value == null) return '';
  if (value is num) {
    return value.toString();
  }
  return value.toString();
}

/// Formats a numeric-like value by trimming trailing zeros (e.g. "10.000" -> "10").
String formatProductDetailsNumeric(dynamic value) {
  final text = productDetailsValueToString(value).trim();
  if (text.isEmpty) return '';
  final parsed = num.tryParse(text);
  if (parsed == null) return text;
  return parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
}

num? productAvailableQuantity(GetProduct product) {
  final stocks = product.stock;
  if (stocks == null) return null;
  if (stocks.isEmpty) return 0;

  num total = 0;
  var hasQuantity = false;
  for (final stock in stocks) {
    if (stock.quantity != null) {
      total += stock.quantity!;
      hasQuantity = true;
    }
  }
  return hasQuantity ? total : null;
}

bool isProductLowStock(num? quantity, int? reorderLevel) {
  if (quantity == null || reorderLevel == null) return false;
  return quantity <= reorderLevel;
}

String formatProductStockNumber(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}
