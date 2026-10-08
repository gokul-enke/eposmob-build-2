import 'dart:math' as math;

/// Rounds [value] to [places] decimals, halves away from zero (the same
/// rule the backend's `round()` uses): 89.9945 -> 89.995 at 3 places and
/// 78.125 -> 78.13 at 2 places.
///
/// Binary floating point stores many half-way values slightly below the half
/// (89.9945 * 1000 = 89994.49999999999), so the scaled value is first snapped
/// to six extra decimals to absorb that noise.
double roundHalfUp(double value, int places) {
  final factor = math.pow(10, places).toDouble();
  final snapped = ((value * factor) * 1e6).roundToDouble() / 1e6;
  return snapped.roundToDouble() / factor;
}

/// Offer unit price: 3 decimals.
double roundOfferUnitPrice(double value) => roundHalfUp(value, 3);

/// Line total, tax and other order amounts: 2 decimals.
double roundMoney(double value) => roundHalfUp(value, 2);
