import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/models/get_store.dart';

import '../../data/sales_action_response.dart';
import '../../domain/sales_order_query.dart';

class SalesListController extends ChangeNotifier {
  SalesListController(
      {required this.fetch,
      required this.activeStore,
      required this.onError,
      this.isOnlineSales = false});
  final Future<void> Function(SalesOrderQuery) fetch;
  final String? Function() activeStore;
  final ValueChanged<String> onError;
  bool isOnlineSales;
  bool initLoading = false;
  bool lastRequestFailed = false;
  bool _disposed = false;
  int _request = 0;
  Timer? _debounce;
  String? selectedStatus;
  GetStoreModelData? storeSelected;
  DateTime? selectedBusinessDate;
  Key businessCalendarPickerKey = UniqueKey();
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  bool get hasActiveFilters =>
      orderNumberController.text.isNotEmpty ||
      customerNameController.text.isNotEmpty ||
      amountController.text.isNotEmpty ||
      emailController.text.isNotEmpty ||
      phoneController.text.isNotEmpty ||
      storeController.text.isNotEmpty ||
      (selectedStatus != null && selectedStatus != 'all') ||
      fromDateController.text.isNotEmpty ||
      toDateController.text.isNotEmpty ||
      selectedBusinessDate != null;

  void update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void onFilterTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!_disposed) searchOrders(1);
    });
  }

  Future<void> loadInitData() => _load(
      SalesOrderQuery(
          filterStore: activeStore(),
          filterOnlineSales: isOnlineSales ? true : null),
      reportError: false);
  Future<void> searchOrders(int page) => _load(SalesOrderQuery(
      orderNumber: orderNumberController.text.isEmpty
          ? null
          : orderNumberController.text.trim().toUpperCase(),
      filterName: customerNameController.text.isEmpty
          ? null
          : customerNameController.text.trim(),
      filterPrice:
          amountController.text.isEmpty ? null : amountController.text.trim(),
      filterEmail:
          emailController.text.isEmpty ? null : emailController.text.trim(),
      filterPhone:
          phoneController.text.isEmpty ? null : phoneController.text.trim(),
      from: fromDateController.text.isEmpty ? null : fromDateController.text,
      until: toDateController.text.isEmpty ? null : toDateController.text,
      businessDate: selectedBusinessDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(selectedBusinessDate!),
      filterStore: activeStore(),
      filterStatus: selectedStatus == null || selectedStatus == 'all'
          ? null
          : selectedStatus!.trim(),
      page: page,
      filterOnlineSales: isOnlineSales ? true : null));
  Future<void> _load(SalesOrderQuery query, {bool reportError = true}) async {
    if (_disposed) return;
    final request = ++_request;
    update(() => initLoading = true);
    var failed = false;
    try {
      await fetch(query);
    } catch (error) {
      failed = true;
      if (!_disposed && request == _request && reportError)
        onError(SalesActionResponse.apiErrorMessage(error,
            fallback: 'sales.orders_load_failed'.tr));
    } finally {
      if (!_disposed && request == _request)
        update(() {
          initLoading = false;
          lastRequestFailed = failed;
        });
    }
  }

  Future<void> resetSearch() {
    _debounce?.cancel();
    update(() {
      orderNumberController.clear();
      customerNameController.clear();
      amountController.clear();
      emailController.clear();
      phoneController.clear();
      storeController.clear();
      statusController.clear();
      fromDateController.clear();
      toDateController.clear();
      storeSelected = null;
      selectedStatus = null;
      selectedBusinessDate = null;
      businessCalendarPickerKey = UniqueKey();
    });
    return searchOrders(1);
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _debounce?.cancel();
    orderNumberController.dispose();
    customerNameController.dispose();
    dateController.dispose();
    amountController.dispose();
    emailController.dispose();
    phoneController.dispose();
    storeController.dispose();
    storeSearchController.dispose();
    statusController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
  }
}
