import 'general_payment_type.dart';
import 'models/general_payment.dart';

/// The amount of each entry type (the four totals above the list).
class GeneralPaymentTotals {
  const GeneralPaymentTotals._(this._byType);

  static const zero = GeneralPaymentTotals._({});

  /// Sums [rows] per entry type; rows of an unknown type count nowhere.
  factory GeneralPaymentTotals.of(Iterable<GeneralPayment> rows) {
    final sums = <GeneralPaymentType, double>{};
    for (final row in rows) {
      final type = row.type;
      if (type != null) sums[type] = (sums[type] ?? 0) + row.amount;
    }
    return GeneralPaymentTotals._(Map.unmodifiable(sums));
  }

  final Map<GeneralPaymentType, double> _byType;

  double operator [](GeneralPaymentType type) => _byType[type] ?? 0;
}
