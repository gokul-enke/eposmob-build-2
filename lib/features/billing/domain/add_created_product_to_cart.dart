import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/domain/add_product_form_helpers.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:provider/provider.dart';

/// Routes a freshly created product through [ProductCartHelper] so mobile
/// create-and-add matches the standard add-to-cart path (stock modal, sale
/// units, reservations, wholesale/tax).
Future<void> addCreatedProductToCart({
  required BuildContext context,
  required GetProduct product,
  required String quantityText,
  required String sellingPriceText,
  int? customerId,
  String? customerName,
}) async {
  if (!context.mounted) return;

  final customerSelection =
      Provider.of<CustomerSelectionProvider>(context, listen: false);

  await ProductCartHelper.handleProductSelection(
    context: context,
    product: product,
    quantity: AddProductFormHelpers.parseAddToCartQuantity(quantityText),
    customPrice:
        AddProductFormHelpers.parseAddToCartSellingPrice(sellingPriceText),
    addToCartDirectly: true,
    customerId: customerId ?? customerSelection.selectedCustomerID,
    customerName: customerName ?? customerSelection.selectedCustomerName,
  );
}
