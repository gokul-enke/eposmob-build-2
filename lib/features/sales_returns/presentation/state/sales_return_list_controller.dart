import 'package:flutter/foundation.dart';

import '../../domain/models/list_sales_return.dart';

class SalesReturnListController extends ChangeNotifier {
  SalesReturnListController({required this.fetch, required this.onError});
  final Future<SalesReturnResponse> Function(int page) fetch;
  final void Function(Object error) onError;
  List<SalesReturnOrder> salesReturnOrders = [];
  int salesReturnCurrentPage = 1;
  int salesReturnTotalPages = 1;
  int currentPage = 1;
  bool isLoading = true;
  String? loadError;
  bool _disposed = false;
  int _request = 0;

  Future<void> load({int? page}) async {
    if (_disposed) return;
    final request = ++_request;
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      final result = await fetch(page ?? currentPage);
      if (_disposed || request != _request) return;
      salesReturnOrders = result.data.data;
      salesReturnCurrentPage = result.data.currentPage;
      salesReturnTotalPages = result.data.lastPage;
      if (page != null) currentPage = page;
    } catch (error) {
      if (_disposed || request != _request) return;
      salesReturnOrders = [];
      loadError = error.toString().replaceFirst('Exception: ', '');
      onError(error);
    } finally {
      if (!_disposed && request == _request) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
