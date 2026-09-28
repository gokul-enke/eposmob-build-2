import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/models/order_details.dart';

SalesReturnCart? matchingLoadedSalesReturnItem(
  SalesReturnItem summaryItem,
  Iterable<SalesReturnCart> loadedItems,
) {
  for (final loadedItem in loadedItems) {
    if (loadedItem.cartItemId > 0 &&
        (loadedItem.cartItemId == summaryItem.cartItemId ||
            loadedItem.cartItemId == summaryItem.cartItem.id)) {
      return loadedItem;
    }
  }
  return null;
}

String salesReturnItemDisplayName(
  SalesReturnItem summaryItem,
  Iterable<SalesReturnCart> loadedItems,
) {
  final summaryName = summaryItem.cartItem.displayName.trim();
  if (summaryName.isNotEmpty && summaryName != 'Unknown Product') {
    return summaryName;
  }

  final loadedName = matchingLoadedSalesReturnItem(summaryItem, loadedItems)
      ?.productName
      .trim();
  return loadedName?.isNotEmpty == true ? loadedName! : 'Unknown Product';
}

String salesReturnItemUnitPrice(
  SalesReturnItem summaryItem,
  Iterable<SalesReturnCart> loadedItems,
) {
  double? amount(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '').trim());
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }

  // The return item's `price` can be its line total (e.g. 60 for 12 x 5).
  // Prefer the original cart's explicit unit price when it is available.
  final cartPrice = summaryItem.cartItem.unitPrice.trim();
  if (summaryItem.cartItem.hasUnitPrice &&
      amount(cartPrice) != null) {
    return cartPrice.replaceAll(',', '');
  }
  final loadedItem = matchingLoadedSalesReturnItem(summaryItem, loadedItems);
  final loadedPrice = loadedItem?.unitPrice.trim();
  if (loadedItem?.hasUnitPrice == true &&
      amount(loadedPrice ?? '') != null) {
    return loadedPrice!.replaceAll(',', '');
  }
  final lineAmount = amount(summaryItem.price);
  final quantity = summaryItem.quantity.toDouble();
  if (lineAmount == null || !quantity.isFinite || quantity <= 0) return '';
  // This is the returned line's value, not the original sale's full quantity.
  // Preserve precision here; monetary formatting belongs to the renderer.
  return (lineAmount / quantity).toString();
}

String salesReturnItemReason(
  SalesReturnItem summaryItem,
  Iterable<SalesReturnCart> loadedItems,
) {
  final summaryReason = summaryItem.reason.trim();
  if (summaryReason.isNotEmpty) return summaryReason;

  return matchingLoadedSalesReturnItem(summaryItem, loadedItems)
          ?.reason
          ?.trim() ??
      '';
}

List<OrderReturnItem> buildTransactionReturnPrintItems(
  Iterable<SalesReturnItem> summaryItems,
  Iterable<SalesReturnCart> loadedItems,
) {
  return summaryItems.map((summaryItem) {
    final loadedItem = matchingLoadedSalesReturnItem(summaryItem, loadedItems);
    return OrderReturnItem(
      cartItemId: summaryItem.cartItemId,
      hsnCode: summaryItem.cartItem.product?.hsnCode,
      taxRate: summaryItem.cartItem.hasTaxRate ? summaryItem.cartItem.taxRate : null,
      unitPrice: salesReturnItemUnitPrice(summaryItem, loadedItems),
      mrp: summaryItem.cartItem.mrp ?? summaryItem.cartItem.product?.mrp,
      id: summaryItem.id,
      productName: salesReturnItemDisplayName(summaryItem, loadedItems),
      quantity: summaryItem.quantity,
      reason: salesReturnItemReason(summaryItem, loadedItems),
      productVariantId: loadedItem?.productVariantId,
      variantAttributes: loadedItem?.variantAttributes,
    );
  }).toList();
}
