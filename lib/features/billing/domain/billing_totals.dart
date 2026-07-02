import 'package:pos_machine/helpers/amount_helper.dart';

/// Shared billing total math used by both the desktop billing page and the
/// mobile billing flow so their checkout numbers stay identical.
class BillingTotals {
  BillingTotals._();

  /// The order total used for payment validation, change/balance calculation
  /// and payment autofill.
  ///
  /// Mirrors desktop `BillingPage._getEffectiveOrderTotal()`: the net (base)
  /// total is round-off adjusted first (only when `priceRoundOff` is enabled),
  /// then the delivery charge is added on top.
  static double effectiveOrderTotal({
    required double baseTotal,
    required double deliveryCharge,
    required bool priceRoundOff,
  }) {
    final roundedOrBaseTotal =
        priceRoundOff ? AmountHelper.roundOffAmount(baseTotal) : baseTotal;
    return roundedOrBaseTotal + deliveryCharge;
  }
}
