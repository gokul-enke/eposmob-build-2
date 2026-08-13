import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/models/order_details.dart';

SalesReturnCart? matchingLoadedSalesReturnItem(
  SalesReturnItem summaryItem,
  Iterable<SalesReturnCart> loadedItems,
) {
  for (final loadedItem in loadedItems) {
    if (loadedItem.cartItemId == summaryItem.cartItemId ||
        loadedItem.cartItemId == summaryItem.cartItem.id) {
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
  final summaryPrice = summaryItem.price.trim();
  final parsedSummaryPrice = double.tryParse(summaryPrice);
  if (summaryPrice.isNotEmpty &&
      (parsedSummaryPrice == null || parsedSummaryPrice > 0)) {
    return summaryPrice;
  }

  final loadedPrice =
      matchingLoadedSalesReturnItem(summaryItem, loadedItems)?.unitPrice.trim();
  return loadedPrice?.isNotEmpty == true ? loadedPrice! : summaryPrice;
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
      id: summaryItem.id,
      productName: salesReturnItemDisplayName(summaryItem, loadedItems),
      quantity: summaryItem.quantity,
      reason: salesReturnItemReason(summaryItem, loadedItems),
      productVariantId: loadedItem?.productVariantId,
      variantAttributes: loadedItem?.variantAttributes,
    );
  }).toList();
}
