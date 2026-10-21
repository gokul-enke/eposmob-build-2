part of 'invoice_create_dialog.dart';

class InvoiceItemCard {
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController unitAmountController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController totalController = TextEditingController();

  final FocusNode itemNameFocus = FocusNode();
  final FocusNode unitAmountFocus = FocusNode();
  final FocusNode taxFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();
  final FocusNode totalFocus = FocusNode();

  InvoiceItemCard() {
    unitAmountController.text = "0";
    taxController.text = "0";
    quantityController.text = "1";
    totalController.text = "0";

    // Auto-calculate total when values change
    unitAmountController.addListener(_calculateTotal);
    taxController.addListener(_calculateTotal);
    quantityController.addListener(_calculateTotal);
  }

  InvoiceFormItem get snapshot => InvoiceFormItem.fromText(
        name: itemNameController.text,
        unitAmount: unitAmountController.text,
        taxPercent: taxController.text,
        quantity: quantityController.text,
        totalAmount: totalController.text,
      );

  void _calculateTotal() {
    final unitAmount = double.tryParse(unitAmountController.text) ?? 0;
    final taxPercent = double.tryParse(taxController.text) ?? 0;
    final quantity = double.tryParse(quantityController.text) ?? 1;
    // Calculate tax as percentage of unit amount
    final taxAmount = unitAmount * (taxPercent / 100);
    final total = (unitAmount + taxAmount) * quantity;
    totalController.text = total.toStringAsFixed(2);
  }

  void dispose() {
    unitAmountController.removeListener(_calculateTotal);
    taxController.removeListener(_calculateTotal);
    quantityController.removeListener(_calculateTotal);

    itemNameController.dispose();
    unitAmountController.dispose();
    taxController.dispose();
    quantityController.dispose();
    totalController.dispose();

    itemNameFocus.dispose();
    unitAmountFocus.dispose();
    taxFocus.dispose();
    quantityFocus.dispose();
    totalFocus.dispose();
  }
}
