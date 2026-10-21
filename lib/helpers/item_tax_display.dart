import 'package:pos_machine/models/document_configurations.dart';

/// Resolves a displayed row amount without modifying accounting amounts.
class ItemTaxDisplay {
  ItemTaxDisplay._();

  static double amount({
    required ItemTaxDisplayMode mode,
    dynamic rowTax,
    dynamic unitTax,
    dynamic quantity,
  }) {
    final rowAmount = _number(rowTax) ?? 0;
    if (mode == ItemTaxDisplayMode.rowTotal) return rowAmount;

    // Explicit API zero is a valid unit amount. Older sales/quotation data
    // lacks unit tax, so divide the original row amount only for display.
    final unitAmount = _number(unitTax);
    if (unitAmount != null) return unitAmount;
    final count = _number(quantity) ?? 0;
    if (count <= 0) return 0;
    final derived = rowAmount / count;
    return derived.isFinite ? derived : 0;
  }

  static double? _number(dynamic value) {
    final result =
        double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '');
    return result != null && result.isFinite ? result : null;
  }
}
