import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'day_close_list.dart';

class AdminDayCloseScope {
  const AdminDayCloseScope(
      {required this.token,
      required this.tenant,
      required this.endpoint,
      required this.executivesEndpoint,
      required this.storeId,
      required this.actorId});
  final String token, tenant, endpoint, executivesEndpoint;
  final int storeId, actorId;
  bool sameAs(AdminDayCloseScope other) =>
      token == other.token &&
      tenant == other.tenant &&
      endpoint == other.endpoint &&
      executivesEndpoint == other.executivesEndpoint &&
      storeId == other.storeId &&
      actorId == other.actorId;
}

class AdminExecutiveOption {
  const AdminExecutiveOption(this.id, this.name);
  final int id;
  final String name;
}

class AdminDayCloseQuery {
  const AdminDayCloseQuery({this.date, this.executiveId});
  final String? date;
  final int? executiveId;
  bool sameAs(AdminDayCloseQuery other) =>
      date == other.date && executiveId == other.executiveId;
}

abstract class AdminDayCloseSource {
  AdminDayCloseScope get scope;
  Future<DayCloseListData> fetch(int page, AdminDayCloseQuery query);
  Future<List<AdminExecutiveOption>> fetchExecutives();
}

bool adminDayCloseRowInScope(DailySalesCloseData row, AdminDayCloseScope scope,
        AdminDayCloseQuery query) =>
    (row.id ?? 0) > 0 &&
    row.store?.id == scope.storeId &&
    (row.salesExecutive?.id ?? 0) > 0 &&
    (query.executiveId == null || row.salesExecutive?.id == query.executiveId);

bool completeAdminDayCloseRow(DailySalesCloseData row, AdminDayCloseScope scope,
        AdminDayCloseQuery query) =>
    adminDayCloseRowInScope(row, scope, query) &&
    (row.businessDate == null ||
        row.businessDate!.isEmpty ||
        validDayCloseDate(row.businessDate)) &&
    (row.totalOrders ?? -1) >= 0 &&
    [row.totalSales, row.totalOnline, row.totalCash, row.totalCredit]
        .every((value) => dayCloseNumber(value) != null);
