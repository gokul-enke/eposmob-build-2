import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';

/// Thin passthrough kept for existing call sites. Variant resolution (picker,
/// barcode match, pricing precedence, out-of-stock confirmation) now lives
/// centrally in [ProductCartHelper.handleProductSelection] — the same place
/// stock-selection and zero-price modals are handled — so every add-to-cart
/// entry point gets variant support without needing this wrapper.
Future<void> addProductWithVariantResolution({
  required BuildContext context,
  required GetProduct product,
  String? scannedBarcode,
  Function(GetProduct, Stock?)? onSelected,
  bool addToCartDirectly = true,
  num? quantity,
  double? customPrice,
  double? customMrp,
  int? customerId,
  String? customerName,
  SaleUnit? selectedSaleUnit,
  bool? variantEnabled,
  VoidCallback? onAdded,
}) {
  return ProductCartHelper.handleProductSelection(
    context: context,
    product: product,
    scannedBarcode: scannedBarcode,
    onSelected: onSelected,
    addToCartDirectly: addToCartDirectly,
    quantity: quantity,
    customPrice: customPrice,
    customMrp: customMrp,
    customerId: customerId,
    customerName: customerName,
    selectedSaleUnit: selectedSaleUnit,
    variantEnabled: variantEnabled,
    onAdded: onAdded,
  );
}
