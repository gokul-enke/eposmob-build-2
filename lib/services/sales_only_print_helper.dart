import 'package:pos_machine/models/order_details.dart';

/// Removes returned quantities from the original sale while preserving the
/// original per-unit price and tax values for the remaining quantities.
List<OrderDetailsModelDataCartItem> buildSalesOnlyCartItems(
  List<OrderDetailsModelDataCartItem> cartItems,
  List<OrderReturnItem> returnItems,
) {
  final returnQtyByProduct = <String, int>{};
  for (final returnItem in returnItems) {
    final productName = returnItem.productName?.trim().toLowerCase() ?? '';
    if (productName.isEmpty) continue;
    returnQtyByProduct[productName] =
        (returnQtyByProduct[productName] ?? 0) + (returnItem.quantity ?? 0);
  }

  final remainingReturns = Map<String, int>.from(returnQtyByProduct);
  final adjustedItems = <OrderDetailsModelDataCartItem>[];

  for (final item in cartItems) {
    final productName = item.productName?.trim().toLowerCase() ?? '';
    final originalQty = item.quantity?.toDouble() ?? 0;
    if (originalQty <= 0) continue;

    final returnedQty = remainingReturns[productName] ?? 0;
    final deductQty = returnedQty.clamp(0, originalQty.toInt());
    if (deductQty > 0) {
      remainingReturns[productName] = returnedQty - deductQty;
    }

    final newQty = originalQty - deductQty;
    if (newQty <= 0) continue;

    final unitPrice = double.tryParse(item.unitPrice ?? '0') ?? 0;
    final originalTax = double.tryParse(item.taxAmount ?? '0') ?? 0;
    final taxPerUnit = originalQty > 0 ? originalTax / originalQty : 0;

    adjustedItems.add(
      item.copyWith(
        quantity: newQty,
        totalPrice: (unitPrice * newQty).toStringAsFixed(2),
        taxAmount: (taxPerUnit * newQty).toStringAsFixed(2),
      ),
    );
  }

  return adjustedItems;
}
