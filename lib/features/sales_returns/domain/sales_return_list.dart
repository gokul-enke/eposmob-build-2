import 'package:pos_machine/models/list_sales_return.dart';

/// Authentication and store scope frozen for a listing or export request.
class SalesReturnListScope {
  const SalesReturnListScope(
      {required this.token,
      required this.tenant,
      required this.endpoint,
      this.storeId});
  final String token, tenant, endpoint;
  final int? storeId;
  bool sameAs(SalesReturnListScope other) =>
      token == other.token &&
      tenant == other.tenant &&
      endpoint == other.endpoint &&
      storeId == other.storeId;
}

class SalesReturnListData {
  const SalesReturnListData(
      {required this.rows,
      required this.page,
      required this.pages,
      required this.perPage,
      required this.total,
      this.completeForExport = true});
  final List<SalesReturnOrder> rows;
  final int page, pages, perPage, total;
  final bool completeForExport;
}

abstract class SalesReturnListSource {
  SalesReturnListScope get scope;
  Future<SalesReturnListData> fetch(int page);
}

num salesReturnQuantity(SalesReturnOrder order) =>
    order.items.fold<num>(0, (sum, item) => sum + item.quantity);
