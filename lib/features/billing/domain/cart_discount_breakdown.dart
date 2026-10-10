import 'package:pos_machine/features/offers/domain/offer_money.dart';

/// Allocates an order discount over tax-inclusive lines using the backend's
/// rounding rule: proportional net totals, with the remainder on the last
/// line. Pass lines in submission order (including batch splits).
class CartDiscountBreakdown {
  CartDiscountBreakdown._();

  static List<DiscountedCartLine> calculate(
    List<({double total, double taxRate})> lines,
    double discount,
  ) {
    final subtotal =
        roundMoney(lines.fold<double>(0, (sum, l) => sum + l.total));
    final target = roundMoney(subtotal - discount.clamp(0, subtotal));
    var allocated = 0.0;
    return [
      for (var i = 0; i < lines.length; i++)
        (() {
          final line = lines[i];
          final remaining = roundMoney((target - allocated).clamp(0, target));
          final net = i == lines.length - 1
              ? remaining
              : roundMoney(subtotal > 0 ? target * line.total / subtotal : 0)
                  .clamp(0.0, remaining);
          allocated = roundMoney(allocated + net);
          final base = line.taxRate > 0
              ? roundMoney(net / (1 + line.taxRate / 100))
              : net;
          return DiscountedCartLine(
            discount: roundMoney(line.total - net),
            total: net,
            tax: roundMoney(net - base),
          );
        })(),
    ];
  }

  static List<DiscountedCartLine> grouped(
      List<({int index, double total, double taxRate})> lines,
      int count,
      double discount) {
    final amounts = calculate([
      for (final line in lines) (total: line.total, taxRate: line.taxRate),
    ], discount);
    final discounts = List<double>.filled(count, 0);
    final totals = List<double>.filled(count, 0);
    final taxes = List<double>.filled(count, 0);
    for (var i = 0; i < lines.length; i++) {
      final index = lines[i].index;
      discounts[index] += amounts[i].discount;
      totals[index] += amounts[i].total;
      taxes[index] += amounts[i].tax;
    }
    return [
      for (var i = 0; i < count; i++)
        DiscountedCartLine(
            discount: roundMoney(discounts[i]),
            total: roundMoney(totals[i]),
            tax: roundMoney(taxes[i])),
    ];
  }
}

class DiscountedCartLine {
  const DiscountedCartLine({
    required this.discount,
    required this.total,
    required this.tax,
  });

  final double discount;
  final double total;
  final double tax;
}
