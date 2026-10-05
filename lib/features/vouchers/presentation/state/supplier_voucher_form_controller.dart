import 'package:flutter/material.dart';
import 'package:pos_machine/models/master_data.dart';
import 'supplier_voucher_form_item.dart';

class SupplierVoucherFormController extends ChangeNotifier {
  SupplierVoucherFormController(
      {required this.loadChoices, required this.loadPayments}) {
    for (final item in voucherItems) {
      addItemListeners(item);
    }
  }
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
      if (alive && values != null) update(() => suppliers = values);
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
  final TextEditingController netTotalController = TextEditingController();
  final TextEditingController totalTaxController = TextEditingController();
  final TextEditingController totalAmountController = TextEditingController();

  // Date controllers
  DateTime selectedVoucherDate = DateTime.now();
  DateTime selectedDueDate = DateTime.now(); // Changed to today's date

  // Focus Nodes for keyboard navigation
  final FocusNode typeFocus = FocusNode();
  final FocusNode voucherDateFocus = FocusNode();
  final FocusNode dueDateFocus = FocusNode();
  final FocusNode statusFocus = FocusNode();
  final FocusNode paymentMethodFocus = FocusNode();
  final FocusNode supplierFocus = FocusNode();

  // Dropdown selections
  String? selectedType;
  String? selectedStatus = 'paid'; // Default to 'paid'
  String? selectedPaymentMethod;
  int? selectedSupplierId;
  String? selectedSupplierName;

  // Items list
  List<SupplierVoucherFormItem> voucherItems = [SupplierVoucherFormItem()];

  // Options lists - Backend values and display names
  List<Map<String, String>> typeOptions = [
    {'value': 'order', 'display': 'Order'},
    {'value': 'discount', 'display': 'Discount'},
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
  List<Map<String, dynamic>> suppliers = [];

  bool isLoading = false;

  void calculateTotal() {
    double netTotal = 0;
    double totalTax = 0;
    double total = 0;
    for (var item in voucherItems) {
      try {
        double unitAmount =
            double.tryParse(item.unitAmountController.text) ?? 0;
        double quantity = double.tryParse(item.quantityController.text) ?? 1;
        double taxRate = double.tryParse(item.taxController.text) ?? 0;
        double itemNetTotal = unitAmount * quantity;
        double itemTax = itemNetTotal * (taxRate / 100);
        double itemTotal = itemNetTotal + itemTax;
        item.totalController.text = itemTotal.toStringAsFixed(2);
        netTotal += itemNetTotal;
        totalTax += itemTax;
        total += itemTotal;
      } catch (e) {
        debugPrint("Error calculating total: $e");
      }
    }
    netTotalController.text = netTotal.toStringAsFixed(2);
    totalTaxController.text = totalTax.toStringAsFixed(2);
    totalAmountController.text = total.toStringAsFixed(2);

    // Trigger rebuild to update summary text fields
    if (alive) {
      update(() {});
    }
  }

  int? getPaymentMethodId(String? paymentMethodValue) {
    if (paymentMethodValue == null || paymentMethods.isEmpty) return null;
    try {
      return paymentMethods.firstWhere((m) => m.value == paymentMethodValue).id;
    } catch (e) {
      return null;
    }
  }

  void addItemListeners(SupplierVoucherFormItem item) {
    item.unitAmountController.addListener(calculateTotal);
    item.taxController.addListener(calculateTotal);
    item.quantityController.addListener(calculateTotal);
  }

  @override
  void dispose() {
    netTotalController.dispose();
    totalTaxController.dispose();
    totalAmountController.dispose();
    typeFocus.dispose();
    voucherDateFocus.dispose();
    dueDateFocus.dispose();
    statusFocus.dispose();
    paymentMethodFocus.dispose();
    supplierFocus.dispose();

    // Dispose all voucher items
    for (var item in voucherItems) {
      item.unitAmountController.removeListener(calculateTotal);
      item.taxController.removeListener(calculateTotal);
      item.quantityController.removeListener(calculateTotal);
      item.dispose();
    }

    _disposed = true;
    super.dispose();
  }
}
