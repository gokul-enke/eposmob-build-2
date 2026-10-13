import 'package:pos_machine/features/offers/domain/offer_money.dart';
import 'package:pos_machine/models/discount_list_model.dart';

typedef CouponCartLine = ({
  int? productId,
  int? categoryId,
  double total,
  bool hasOffer,
});

/// Mirrors the downloaded coupon rules. Usage is checked only when the API
/// supplies a used/remaining count; global redemption still requires the server.
class CouponCalculation {
  const CouponCalculation(this.amount, this.error);

  final double amount;
  final String? error;
  bool get isValid => error == null;

  static CouponCalculation evaluate({
    required DiscountData coupon,
    required List<CouponCartLine> lines,
    required DateTime now,
    int? storeId,
    Map<int, int?> categoryParents = const {},
    double? subtotal,
  }) {
    CouponCalculation invalid(String message) => CouponCalculation(0, message);
    final cartTotal = roundMoney(
        subtotal ?? lines.fold<double>(0, (sum, line) => sum + line.total));
    if (cartTotal <= 0) return invalid('Add items before applying a coupon.');
    if (coupon.storeId != null &&
        storeId != null &&
        coupon.storeId != storeId) {
      return invalid('This coupon belongs to another store.');
    }
    final validity = coupon.checkValidity(cartTotal, now);
    if (validity != DiscountValidity.valid) {
      return invalid(switch (validity) {
        DiscountValidity.belowMin =>
          'Coupon minimum order amount is ${coupon.discountCouponMinAmount}.',
        DiscountValidity.aboveMax =>
          'Coupon maximum order amount is ${coupon.discountCouponMaxAmount}.',
        DiscountValidity.expired => 'Coupon has expired',
        DiscountValidity.notStarted => 'This coupon is not active yet.',
        _ => 'This coupon has invalid validity dates.',
      });
    }
    if ((coupon.remainingUses != null && coupon.remainingUses! <= 0) ||
        (coupon.discountCouponLimitCount > 0 &&
            coupon.usageCount != null &&
            coupon.usageCount! >= coupon.discountCouponLimitCount)) {
      return invalid('This coupon has reached its usage limit.');
    }
    bool matchesCategory(int? id) {
      final visited = <int>{};
      while (id != null && visited.add(id)) {
        if (id == coupon.categoryId) return true;
        id = categoryParents[id];
      }
      return false;
    }

    final eligible = roundMoney(lines.fold<double>(0, (sum, line) {
      if (line.hasOffer || line.total <= 0) return sum;
      if (coupon.productId != null && line.productId != coupon.productId) {
        return sum;
      }
      // Product selection takes precedence over category, as on the backend.
      if (coupon.productId == null &&
          coupon.categoryId != null &&
          !matchesCategory(line.categoryId)) {
        return sum;
      }
      return sum + line.total;
    }));
    if (eligible <= 0) {
      return invalid(
          'No eligible items for this coupon. Items with offers are excluded.');
    }
    final value = coupon.discountValue.toDouble();
    if (!value.isFinite || value <= 0) return invalid('Invalid coupon value.');
    final type = coupon.discountType.toLowerCase();
    double amount;
    if (type == 'percent' || type == 'percentage') {
      if (value > 100) return invalid('Invalid coupon percentage.');
      amount = eligible * value / 100;
    } else if (type == 'fixed') {
      amount = value;
    } else {
      return invalid('Unsupported coupon type.');
    }
    final cap = coupon.discountCouponLimitAmount;
    if (cap.isFinite && cap > 0 && amount > cap) amount = cap;
    return CouponCalculation(
        roundMoney(
            amount.clamp(0.0, eligible).clamp(0.0, cartTotal).toDouble()),
        null);
  }
}
