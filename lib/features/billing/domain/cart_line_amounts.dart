import 'package:pos_machine/features/offers/domain/offer_money.dart';

/// Money for one backend order line. Prices include tax.
class CartLineAmounts {
  const CartLineAmounts({required this.total, required this.tax});

  factory CartLineAmounts.calculate({
    required double price,
    required num quantity,
    required double taxRate,
  }) {
    final total = roundMoney(price * quantity);
    return CartLineAmounts(
      total: total,
      tax: taxRate > 0 ? roundMoney(total * taxRate / (100 + taxRate)) : 0,
    );
  }

  factory CartLineAmounts.sum(Iterable<CartLineAmounts> lines) {
    var total = 0.0;
    var tax = 0.0;
    for (final line in lines) {
      total += line.total;
      tax += line.tax;
    }
    return CartLineAmounts(total: roundMoney(total), tax: roundMoney(tax));
  }

  final double total;
  final double tax;
}
