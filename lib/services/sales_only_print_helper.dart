import 'package:pos_machine/models/order_details.dart';

/// Removes returned quantities from the original sale while preserving the
/// original per-unit price and tax values for the remaining quantities.
List<OrderDetailsModelDataCartItem> buildSalesOnlyCartItems(
    List<OrderDetailsModelDataCartItem> cartItems,
    List<OrderReturnItem> returnItems,
    {List<OrderReturnItem>? completedReturnCartItems}) {
  // Prefer the server's cart-line snapshot only when it reconciles with the
  // returned quantities being printed and references actual sold lines.
  final snapshot = completedReturnCartItems;
  final cartById = {
    for (final item in cartItems)
      if (item.id != null) item.id!: item
  };
  final snapshotQuantity = snapshot?.fold<double>(
          0, (sum, item) => sum + (item.quantity ?? 0).toDouble()) ??
      0;
  final summaryQuantity = returnItems.fold<double>(
      0, (sum, item) => sum + (item.quantity ?? 0).toDouble());
  final snapshotValid = snapshot != null &&
      snapshot.isNotEmpty &&
      snapshotQuantity.isFinite &&
      summaryQuantity.isFinite &&
      (snapshotQuantity - summaryQuantity).abs() < 0.000001 &&
      snapshot.map((item) => item.cartItemId).toSet().length ==
          snapshot.length &&
      snapshot.every((item) {
        final sold = cartById[item.cartItemId];
        final quantity = item.quantity ?? 0;
        return sold != null &&
            quantity.isFinite &&
            quantity > 0 &&
            quantity <= (sold.quantity ?? 0);
      });
  final remainingReturns = <String, num>{};
  for (final returnItem in snapshotValid ? snapshot! : returnItems) {
    final productName = returnItem.productName?.trim().toLowerCase() ?? '';
    final quantity = returnItem.quantity ?? 0;
    if (!quantity.isFinite || quantity <= 0) continue;
    final cartId = returnItem.cartItemId;
    final key = cartId != null && cartId > 0
        ? 'id:$cartId'
        : returnItem.productVariantId != null
            ? 'variant:${returnItem.productVariantId}:$productName'
            : 'name:$productName';
    if (productName.isEmpty && (cartId == null || cartId <= 0)) continue;
    remainingReturns[key] = (remainingReturns[key] ?? 0) + quantity;
  }
  final adjustedItems = <OrderDetailsModelDataCartItem>[];

  for (final item in cartItems) {
    final productName = item.productName?.trim().toLowerCase() ?? '';
    final originalQty = item.quantity?.toDouble() ?? 0;
    if (!originalQty.isFinite || originalQty <= 0) continue;
    var deductQty = 0.0;
    for (final key in [
      if (item.id != null) 'id:${item.id}',
      if (item.productVariantId != null)
        'variant:${item.productVariantId}:$productName',
      'name:$productName',
    ]) {
      final returnedQty = remainingReturns[key] ?? 0;
      final deduction =
          returnedQty.clamp(0, originalQty - deductQty).toDouble();
      deductQty += deduction;
      remainingReturns[key] = returnedQty - deduction;
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
