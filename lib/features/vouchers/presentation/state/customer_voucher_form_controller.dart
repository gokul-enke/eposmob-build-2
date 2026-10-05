import 'package:flutter/material.dart';
import 'package:pos_machine/models/master_data.dart';
import 'customer_voucher_form_item.dart';

class CustomerVoucherFormController extends ChangeNotifier {
  CustomerVoucherFormController(
      {required this.loadChoices, required this.loadPayments}) {}
  final Future<List<Map<String, dynamic>>?> Function() loadChoices;
  final Future<List<MasterDataValue>?> Function() loadPayments;
  bool _disposed = false;
  bool get alive => !_disposed;
  void update(VoidCallback change) {
    if (!alive) return;
    change();
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final values = await loadChoices();
      if (alive && values != null) update(() => customers = values);
    } catch (e) {
      debugPrint('Voucher choices failed: $e');
    }
    if (!alive) return;
    update(() => isLoadingPaymentMethods = true);
    try {
      final values = await loadPayments();
      if (!alive) return;
      update(() {
        paymentMethods = values ?? [];
        if (paymentMethods.isNotEmpty && selectedPaymentMethod == null) {
          selectedPaymentMethod = paymentMethods
                  .where((m) => m.value == 'CASH')
                  .firstOrNull
                  ?.value ??
              paymentMethods
                  .where((m) => m.value == 'COD')
                  .firstOrNull
                  ?.value ??
              paymentMethods.first.value;
        }
      });
    } catch (e) {
      debugPrint('Voucher payment methods failed: $e');
    } finally {
      if (alive) update(() => isLoadingPaymentMethods = false);
    }
  }

  // Form controllers
  final TextEditingController totalAmountController = TextEditingController();
  final TextEditingController customerSearchController =
      TextEditingController();

  // Date controllers - Default to today's date
  DateTime selectedVoucherDate = DateTime.now();
  DateTime selectedDueDate = DateTime.now();

  // Focus Nodes for keyboard navigation
  final FocusNode typeFocus = FocusNode();
  final FocusNode voucherDateFocus = FocusNode();
  final FocusNode dueDateFocus = FocusNode();
  final FocusNode statusFocus = FocusNode();
  final FocusNode paymentMethodFocus = FocusNode();
  final FocusNode customerFocus = FocusNode();

  // Dropdown selections - Default status is 'paid'
  String? selectedType;
  String? selectedStatus = 'paid';
  String? selectedPaymentMethod;
  int? selectedCustomerId;
  String? selectedCustomerName;

  // Items list
  List<CustomerVoucherFormItem> voucherItems = [CustomerVoucherFormItem()];

  // Options lists - Backend values and display names
  List<Map<String, String>> typeOptions = [
    {'value': 'order', 'display': 'Order'},
    {'value': 'discount', 'display': 'Discount'},
    {'value': 'sales_return', 'display': 'Sales Return'},
    {'value': 'other', 'display': 'Other'},
  ];
  List<Map<String, String>> statusOptions = [
    {'value': 'paid', 'display': 'Paid'},
    {'value': 'pending', 'display': 'Pending'},
    {'value': 'overdue', 'display': 'Overdue'},
  ];
  // Payment methods from API
  List<MasterDataValue> paymentMethods = [];
  bool isLoadingPaymentMethods = false;
  List<Map<String, dynamic>> customers = [];

  bool isLoading = false;

  void calculateTotal() {
    double total = 0;
    for (var item in voucherItems) {
      try {
        double unitAmount = double.tryParse(item.unitAmount) ?? 0;
        double quantity = double.tryParse(item.quantity) ?? 1;
        double tax = double.tryParse(item.tax) ?? 0;
        double itemTotal = (unitAmount * quantity) + tax;
        item.totalAmount = itemTotal.toStringAsFixed(2);
        total += itemTotal;
      } catch (e) {
        debugPrint("Error calculating total: $e");
      }
    }
    totalAmountController.text = total.toStringAsFixed(2);
  }

  int? getPaymentMethodId(String? paymentMethodValue) {
    if (paymentMethodValue == null || paymentMethods.isEmpty) return null;
    try {
      return paymentMethods.firstWhere((m) => m.value == paymentMethodValue).id;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    totalAmountController.dispose();
    customerSearchController.dispose();

    // Dispose focus nodes
    typeFocus.dispose();
    voucherDateFocus.dispose();
    dueDateFocus.dispose();
    statusFocus.dispose();
    paymentMethodFocus.dispose();
    customerFocus.dispose();

    // Dispose item focus nodes
    for (var item in voucherItems) {
      item.dispose();
    }

    _disposed = true;
    super.dispose();
  }
}
