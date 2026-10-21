/// Parsed form values retain the original empty/invalid-number defaults.
class InvoiceFormItem {
  const InvoiceFormItem({
    required this.name,
    required this.unitAmount,
    required this.taxPercent,
    required this.quantity,
    required this.totalAmount,
  });

  factory InvoiceFormItem.fromText({
    required String name,
    required String unitAmount,
    required String taxPercent,
    required String quantity,
    required String totalAmount,
  }) =>
      InvoiceFormItem(
        name: name,
        unitAmount: double.tryParse(unitAmount) ?? 0.0,
        taxPercent: double.tryParse(taxPercent) ?? 0.0,
        quantity: double.tryParse(quantity) ?? 1.0,
        totalAmount: double.tryParse(totalAmount) ?? 0.0,
      );

  final String name;
  final double unitAmount;
  final double taxPercent;
  final double quantity;
  final double totalAmount;

  Map<String, dynamic> toJson() => {
        'item_name': name,
        'unit_amount': unitAmount,
        'tax': taxPercent,
        'quantity': quantity,
        'total_amount': totalAmount,
      };
}

class InvoiceFormTotals {
  const InvoiceFormTotals(this.net, this.tax, this.discount);

  factory InvoiceFormTotals.calculate(
    Iterable<InvoiceFormItem> items, {
    required double flatDiscount,
    required double percentageDiscount,
  }) {
    double net = 0;
    double tax = 0;
    for (final item in items) {
      final subtotal = item.unitAmount * item.quantity;
      net += subtotal;
      tax += subtotal * (item.taxPercent / 100);
    }
    final discount = percentageDiscount > 0
        ? (net + tax) * (percentageDiscount / 100)
        : flatDiscount;
    return InvoiceFormTotals(net, tax, discount);
  }

  final double net;
  final double tax;
  final double discount;
  double get payable => net + tax - discount;
}
