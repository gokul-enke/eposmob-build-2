import 'package:pos_machine/models/order_details.dart';

/// Shared refund total and unit prices for the entry point and all layouts.
class ReturnPrintAmounts {
  const ReturnPrintAmounts._();

  static double? money(String? source) {
    final value = double.tryParse(source?.replaceAll(',', '').trim() ?? '');
    return value != null && value.isFinite ? value : null;
  }

  static double total(OrderReturns? returns, List<dynamic> cartItems) {
    final supplied = money(returns?.returnTotalAmount);
    if (supplied != null) return supplied;
    return (returns?.returnItems ?? const <OrderReturnItem>[]).fold<double>(
        0,
        (sum, item) =>
            sum + (item.quantity ?? 0) * itemRate(item, cartItems, returns).$1);
  }

  static (double, double) itemRate(OrderReturnItem item,
      List<dynamic> cartItems, OrderReturns? orderReturns) {
    final explicitRate = money(item.unitPrice);
    if (explicitRate != null) {
      return (explicitRate, money(item.mrp) ?? explicitRate);
    }
    for (final cartItem in cartItems) {
      var name = '';
      double? rate;
      var mrp = 0.0;
      int? cartId;
      int? variantId;
      if (cartItem is Map) {
        cartId = int.tryParse(cartItem['id']?.toString() ?? '');
        variantId =
            int.tryParse(cartItem['product_variant_id']?.toString() ?? '');
        name = (cartItem['product_name'] ?? cartItem['productName'] ?? '')
            .toString();
        rate = money(
            (cartItem['unit_price'] ?? cartItem['unitPrice'])?.toString());
        mrp = money(cartItem['mrp']?.toString()) ?? 0.0;
      } else {
        try {
          cartId = int.tryParse(cartItem.id?.toString() ?? '');
          variantId = int.tryParse(cartItem.productVariantId?.toString() ?? '');
          name = cartItem.productName?.toString() ?? '';
          rate = money(cartItem.unitPrice?.toString());
          mrp = money(cartItem.mrp?.toString()) ?? 0.0;
        } catch (_) {}
      }
      final matches = item.cartItemId != null && cartId != null
          ? item.cartItemId == cartId
          : name == item.productName &&
              (item.productVariantId == null ||
                  item.productVariantId == variantId);
      if (matches && rate != null) return (rate, mrp);
    }
    final returns = orderReturns;
    final total = money(returns?.returnTotalAmount) ?? 0.0;
    num quantity = 0;
    for (final returned in returns?.returnItems ?? const <OrderReturnItem>[]) {
      quantity += returned.quantity ?? 0;
    }
    final average = quantity > 0 ? total / quantity : 0.0;
    return (average, average);
  }
}
