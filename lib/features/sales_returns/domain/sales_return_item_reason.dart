import 'models/list_sales_return.dart';
import 'models/list_sales_return_items.dart';

String? resolveSalesReturnItemReason(
  SalesReturnCart loadedItem,
  Iterable<SalesReturnItem> summaryItems,
) {
  final endpointReason = loadedItem.reason?.trim();
  if (endpointReason != null && endpointReason.isNotEmpty) {
    return endpointReason;
  }

  for (final summaryItem in summaryItems) {
    final matchesCartItem = summaryItem.cartItemId == loadedItem.cartItemId ||
        summaryItem.cartItem.id == loadedItem.cartItemId;
    final summaryReason = summaryItem.reason.trim();
    if (matchesCartItem && summaryReason.isNotEmpty) {
      return summaryReason;
    }
  }

  return null;
}
