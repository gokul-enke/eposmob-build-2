import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

/// Mobile product-add entry that resolves variant selection before delegating to
/// [ProductCartHelper]. Desktop billing can reuse the domain helper later.
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
}) async {
  // Gate variant resolution behind the PRODUCT_VARIANT_ENABLED setting. When
  // disabled, the product is treated as a plain product (no variant resolution
  // or picker). Defaults to true (variants on) when the setting/provider is
  // unavailable so existing behavior is preserved. The gate lives here at the
  // orchestration layer so the pure domain helpers stay UI/provider-free.
  bool variantsOn = variantEnabled ??
      (Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.productVariantEnabled ??
          true);

  // Out-of-stock variants are NOT blocked here: the physical item may be in
  // front of the cashier. ProductCartHelper asks for an oversell confirmation
  // (only when stock management is enabled) instead of refusing the sale.
  ProductVariant? selectedVariant = variantsOn
      ? ProductVariantSelection.tryResolveWithoutPicker(
          product,
          scannedBarcode: scannedBarcode,
        )
      : null;

  if (variantsOn &&
      selectedVariant == null &&
      ProductVariantSelection.needsVariantPicker(product)) {
    selectedVariant = await showMobileVariantPickerSheet(
      context: context,
      product: product,
    );
    if (selectedVariant == null || !context.mounted) {
      return;
    }
  }

  final productPrice = ProductVariantSelection.productBasePrice(product);
  final resolvedPrice = selectedVariant == null
      ? customPrice
      : (customPrice ??
          ProductVariantSelection.resolveVariantPrice(
            variant: selectedVariant,
            productPrice: productPrice,
          ));
  final resolvedMrp = selectedVariant == null
      ? customMrp
      : (customMrp ??
          ProductVariantSelection.resolveVariantMrp(
            variant: selectedVariant,
            product: product,
            effectivePrice: resolvedPrice ?? productPrice,
          ));

  await ProductCartHelper.handleProductSelection(
    context: context,
    product: product,
    onSelected: onSelected,
    addToCartDirectly: addToCartDirectly,
    quantity: quantity,
    customPrice: resolvedPrice,
    customMrp: resolvedMrp,
    customerId: customerId,
    customerName: customerName,
    selectedSaleUnit: selectedSaleUnit,
    selectedVariant: selectedVariant,
  );
}
