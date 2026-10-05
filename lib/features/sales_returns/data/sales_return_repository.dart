import '../domain/models/list_sales_return.dart';
import '../domain/models/list_sales_return_items.dart';
import 'sales_return_api.dart';

/// One-off snapshots never mutate the shared return provider.
class SalesReturnRepository {
  SalesReturnRepository({SalesReturnApi? api}) : api = api ?? SalesReturnApi();
  final SalesReturnApi api;

  Future<SalesReturnResponse> fetchPage(String token, {int? page}) async {
    final request = await api.prepare(token, includeStore: true);
    return api.list(request, page: page);
  }

  Future<SalesReturnItemsResponse> fetchItems(String token,
      {required String orderId, int? page}) async {
    final request = await api.prepare(token, includeStore: true);
    return api.items(request, orderId: orderId, page: page);
  }
}
