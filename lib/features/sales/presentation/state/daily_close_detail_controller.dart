import 'package:flutter/widgets.dart';

import '../../domain/models/daily_sales_close.dart';

class DailyCloseDetailController extends ChangeNotifier {
  DailyCloseDetailController(
      {required this.data, required this.fetch, required this.onLoaded}) {
    orderNumberController.addListener(filterTransactions);
  }
  final Future<DailySalesCloseData?> Function(int) fetch;
  final ValueChanged<DailySalesCloseData> onLoaded;
  DailySalesCloseData? data;
  final orderNumberController = TextEditingController();
  String paymentTypeFilter = 'All';
  List<DailySalesTransaction> filteredTransactions = [];
  bool isLoading = true;
  bool _disposed = false;
  int _request = 0;
  void update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  Future<void> load() async {
    final request = ++_request;
    final id = data?.id;
    if (id == null) {
      update(() => isLoading = false);
      return;
    }
    try {
      final result = await fetch(id);
      if (_disposed || request != _request) return;
      if (result != null) {
        data = result;
        filteredTransactions = List.from(result.transactions ?? []);
        onLoaded(result);
      }
    } catch (_) {
    } finally {
      if (!_disposed && request == _request) update(() => isLoading = false);
    }
  }

  void filterTransactions() {
    if (data?.transactions == null) return;
    final query = orderNumberController.text.toLowerCase();
    update(() {
      filteredTransactions = data!.transactions!
          .where((tx) =>
              (query.isEmpty ||
                  (tx.orderNumber?.toLowerCase().contains(query) ?? false)) &&
              (paymentTypeFilter == 'All' ||
                  tx.paymentType?.toUpperCase() ==
                      paymentTypeFilter.toUpperCase()))
          .toList();
    });
  }

  void resetFilters() {
    update(() {
      orderNumberController.clear();
      paymentTypeFilter = 'All';
      filterTransactions();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    orderNumberController.dispose();
    super.dispose();
  }
}
