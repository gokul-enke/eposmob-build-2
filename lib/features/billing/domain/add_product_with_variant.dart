import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';

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
}) async {
  ProductVariant? selectedVariant = ProductVariantSelection.tryResolveWithoutPicker(
    product,
    scannedBarcode: scannedBarcode,
  );

  if (selectedVariant == null &&
      product.hasVariants &&
      product.activeVariants.length == 1) {
    final onlyVariant = product.activeVariants.first;
    if (ProductVariantSelection.isOutOfStock(onlyVariant)) {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.variantOutOfStock(
            onlyVariant.formattedAttributes.isEmpty
                ? (onlyVariant.sku ?? 'This variant')
                : onlyVariant.formattedAttributes,
          ),
        );
      }
      return;
    }
  }

  if (selectedVariant == null && ProductVariantSelection.needsVariantPicker(product)) {
    selectedVariant = await showMobileVariantPickerSheet(
      context: context,
      product: product,
    );
    if (selectedVariant == null || !context.mounted) {
      return;
    }
  }

  if (selectedVariant != null &&
      ProductVariantSelection.isOutOfStock(selectedVariant)) {
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.variantOutOfStock(
          selectedVariant.formattedAttributes.isEmpty
              ? (selectedVariant.sku ?? 'This variant')
              : selectedVariant.formattedAttributes,
        ),
      );
    }
    return;
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
