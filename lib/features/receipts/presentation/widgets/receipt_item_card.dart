part of 'receipt_create_dialog.dart';

class ReceiptItemCard {
  final TextEditingController itemTypeController = TextEditingController();
  final TextEditingController invoiceController = TextEditingController();
  final TextEditingController invoiceAmountController = TextEditingController();
  final TextEditingController balanceAmountController = TextEditingController();
  final TextEditingController paymentDateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final FocusNode itemTypeFocus = FocusNode();
  final FocusNode invoiceFocus = FocusNode();
  final FocusNode descriptionFocus = FocusNode();
  final FocusNode paymentDateFocus = FocusNode();
  final FocusNode amountFocus = FocusNode();

  String? selectedItemType;
  String? selectedInvoice;

  ReceiptItemCard({String defaultDescription = ""}) {
    invoiceAmountController.text = "0.00";
    balanceAmountController.text = "0.00";
    // Set default date as today in yyyy-MM-dd format
    paymentDateController.text = DateTime.now().toIso8601String().split('T')[0];
    amountController.text = "";
    descriptionController.text = defaultDescription;
    selectedItemType = "General Payment";

    // Select all text when description field gets focus
    descriptionFocus.addListener(() {
      if (descriptionFocus.hasFocus) {
        descriptionController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: descriptionController.text.length,
        );
      }
    });
  }

  ReceiptFormItem get snapshot => ReceiptFormItem(
        selectedItemType: selectedItemType,
        invoiceId: selectedInvoice,
        amount: amountController.text,
        paymentDate: paymentDateController.text,
        description: descriptionController.text,
      );

  void dispose() {
    itemTypeController.dispose();
    invoiceController.dispose();
    invoiceAmountController.dispose();
    balanceAmountController.dispose();
    paymentDateController.dispose();
    amountController.dispose();
    descriptionController.dispose();

    itemTypeFocus.dispose();
    invoiceFocus.dispose();
    descriptionFocus.dispose();
    paymentDateFocus.dispose();
    amountFocus.dispose();
  }
}
