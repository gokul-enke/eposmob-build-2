import 'package:flutter/foundation.dart';
import '../../domain/models/list_sales_return_items.dart';

class SalesReturnDetailsController extends ChangeNotifier {
  SalesReturnDetailsController({required this.fetch});
  final Future<SalesReturnItemsResponse> Function(String number) fetch;
  List<SalesReturnCart> items = const [];
  bool loading = false;
  String? error;
  int _request = 0;
  bool _disposed = false;
  Future<void> load(String? number) async {
    if (_disposed || number == null || number.trim().isEmpty) return;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await fetch(number);
      if (_disposed || request != _request) return;
      items = List.of(response.data);
    } catch (failure) {
      if (_disposed || request != _request) return;
      error = failure.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
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
