import 'package:flutter/material.dart';
import 'package:pos_machine/core/responsive/breakpoints.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_product_details_sheet.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';

/// Opens product details using a mobile bottom sheet below the mobile breakpoint,
/// or the existing desktop dialog at tablet/desktop widths.
void showProductDetails(
  BuildContext context, {
  GetProduct? product,
  String? barcode,
  double? unitPrice,
  double? mrp,
  num? quantity,
  Stock? selectedStock,
  bool isCompact = true,
  String currency = '',
  VoidCallback? onAdd,
  bool useBillingProductPermissions = false,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (Breakpoints.isMobileWidth(width)) {
    showMobileProductDetailsSheet(
      context: context,
      product: product,
      barcode: barcode,
      unitPrice: unitPrice,
      mrp: mrp,
      quantity: quantity,
      selectedStock: selectedStock,
      currency: currency,
      onAdd: onAdd,
      useBillingProductPermissions: useBillingProductPermissions,
    );
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return ProductDetailsDialog(
        product: product,
        barcode: barcode,
        unitPrice: unitPrice,
        mrp: mrp,
        quantity: quantity,
        selectedStock: selectedStock,
        isCompact: isCompact,
        currency: currency,
        onAdd: onAdd,
        useBillingProductPermissions: useBillingProductPermissions,
      );
    },
  );
}
