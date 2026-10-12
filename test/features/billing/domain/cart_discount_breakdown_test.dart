import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/cart_discount_breakdown.dart';
import 'package:pos_machine/features/offers/domain/offer_money.dart';

void main() {
  test('rounding drift never gives the last line a negative discount', () {
    // Each proportional share (0.144) rounds down to 0.14, which would leave
    // 0.18 for the last 0.15 line.
    final lines = [
      for (var i = 0; i < 10; i++) (total: 0.15, taxRate: 15.0),
    ];
    final result = CartDiscountBreakdown.calculate(lines, 0.06);

    for (final line in result) {
      expect(line.discount, greaterThanOrEqualTo(0));
      expect(line.total, lessThanOrEqualTo(0.15));
    }
    expect(
        roundMoney(result.fold<double>(0, (sum, line) => sum + line.total)),
        1.44);
    expect(
        roundMoney(result.fold<double>(0, (sum, line) => sum + line.discount)),
        0.06);
  });

  test('keeps the remainder on the last line when it fits', () {
    final result = CartDiscountBreakdown.calculate(
        [(total: 10.0, taxRate: 0.0), (total: 20.0, taxRate: 0.0)], 10);

    expect(result.map((line) => line.total), [6.67, 13.33]);
    expect(result.map((line) => line.discount), [3.33, 6.67]);
  });
}
