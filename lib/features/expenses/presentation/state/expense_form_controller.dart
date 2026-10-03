import 'package:flutter/widgets.dart';
import '../../data/expense_payloads.dart';

class ExpenseFormController extends ChangeNotifier {
  ExpenseFormController({required this.referenceNo});
  String referenceNo;
  DateTime selectedDate = DateTime.now();
  Map<String, dynamic>? selectedCategory;
  final TextEditingController descriptionController = TextEditingController();
  Map<String, dynamic>? selectedDebitAccount;
  Map<String, dynamic>? selectedCreditAccount;
  final TextEditingController amountController = TextEditingController();
  Map<String, dynamic>? selectedPaymentMethod;
  final TextEditingController notesController = TextEditingController();
  List<String> _allowedPaymentMethods = [];
  bool isSubmitting = false;

  final FocusNode categoryFocus = FocusNode();
  final FocusNode dateFocus = FocusNode();
  final FocusNode debitAccountFocus = FocusNode();
  final FocusNode descriptionFocus = FocusNode();
  final FocusNode amountFocus = FocusNode();
  final FocusNode creditAccountFocus = FocusNode();
  final FocusNode paymentMethodFocus = FocusNode();
  final FocusNode notesFocus = FocusNode();
  final FocusNode createBtnFocus = FocusNode();
  final FocusNode createAnotherBtnFocus = FocusNode();
  final FocusNode cancelBtnFocus = FocusNode();

  bool _disposed = false;
  void update(VoidCallback mutation) {
    if (_disposed) return;
    mutation();
    notifyListeners();
  }

  List<Map<String, dynamic>> filteredPaymentMethods(
      List<Map<String, dynamic>> methods) {
    if (selectedCreditAccount == null || _allowedPaymentMethods.isEmpty) {
      return methods;
    }
    return methods
        .where((m) => _allowedPaymentMethods
            .any((a) => a.toUpperCase() == m['name']?.toString().toUpperCase()))
        .toList();
  }

  void selectCreditAccount(Map<String, dynamic>? value, List<String> allowed) {
    update(() {
      selectedCreditAccount = value;
      _allowedPaymentMethods = allowed;
      if (selectedPaymentMethod != null &&
          !allowed.any((m) =>
              m.toUpperCase() ==
              selectedPaymentMethod!['name']?.toString().toUpperCase())) {
        selectedPaymentMethod = null;
      }
    });
  }

  String? get selectionError {
    if (selectedCategory == null) return 'expense.error_no_category';
    if (selectedDebitAccount == null) return 'expense.error_no_debit';
    if (selectedCreditAccount == null) return 'expense.error_no_credit';
    if (selectedPaymentMethod == null) return 'expense.error_no_payment_method';
    if ((double.tryParse(amountController.text) ?? 0) <= 0) {
      return 'expense.error_amount_zero';
    }
    return null;
  }

  Future<Map<String, dynamic>?> submit(
      {required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
          create,
      required String Function() nextReference,
      bool createAnother = false}) async {
    if (_disposed || isSubmitting || selectionError != null) return null;
    final payload = expenseCreatePayload(
        date: selectedDate,
        category: selectedCategory!,
        debitAccount: selectedDebitAccount!,
        creditAccount: selectedCreditAccount!,
        paymentMethod: selectedPaymentMethod!,
        description: descriptionController.text,
        amount: double.parse(amountController.text),
        notes: notesController.text);
    update(() => isSubmitting = true);
    try {
      final result = await create(payload);
      if (_disposed) return null;
      if (result['status'] == 'success' && createAnother) {
        update(() {
          descriptionController.clear();
          amountController.clear();
          notesController.clear();
          selectedCategory = null;
          selectedDebitAccount = null;
          selectedCreditAccount = null;
          selectedPaymentMethod = null;
          selectedDate = DateTime.now();
          referenceNo = nextReference();
        });
      }
      return result;
    } finally {
      if (!_disposed) update(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    descriptionController.dispose();
    amountController.dispose();
    notesController.dispose();
    categoryFocus.dispose();
    dateFocus.dispose();
    debitAccountFocus.dispose();
    descriptionFocus.dispose();
    amountFocus.dispose();
    creditAccountFocus.dispose();
    paymentMethodFocus.dispose();
    notesFocus.dispose();
    createBtnFocus.dispose();
    createAnotherBtnFocus.dispose();
    cancelBtnFocus.dispose();
    super.dispose();
  }
}
