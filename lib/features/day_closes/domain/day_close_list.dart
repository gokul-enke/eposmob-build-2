import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';

class DayCloseListScope {
  const DayCloseListScope(
      {required this.token,
      required this.tenant,
      required this.endpoint,
      required this.pendingEndpoint,
      required this.storeId,
      required this.userId});
  final String token, tenant, endpoint, pendingEndpoint;
  final int storeId, userId;
  bool sameAs(DayCloseListScope other) =>
      token == other.token &&
      tenant == other.tenant &&
      endpoint == other.endpoint &&
      pendingEndpoint == other.pendingEndpoint &&
      storeId == other.storeId &&
      userId == other.userId;
}

class DayCloseListData {
  const DayCloseListData(
      {required this.rows,
      required this.page,
      required this.pages,
      required this.perPage,
      required this.total});
  final List<DailySalesCloseData> rows;
  final int page, pages, perPage, total;
}

abstract class DayCloseListSource {
  DayCloseListScope get scope;
  Future<DayCloseListData> fetch(int page, {String? date});
  Future<DayClosePendingStatus> fetchPending();
}

double? dayCloseNumber(String? value) {
  final number = double.tryParse(value ?? '');
  return number != null && number.isFinite ? number : null;
}

bool validDayCloseDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
}

bool completeDayCloseRow(DailySalesCloseData row, DayCloseListScope scope) =>
    (row.id ?? 0) > 0 &&
    row.store?.id == scope.storeId &&
    row.salesExecutive?.id == scope.userId &&
    (row.businessDate == null ||
        row.businessDate!.isEmpty ||
        validDayCloseDate(row.businessDate)) &&
    (row.totalOrders ?? -1) >= 0 &&
    [row.totalSales, row.totalOnline, row.totalCash, row.totalCredit]
        .every((value) => dayCloseNumber(value) != null) &&
    row.status?.trim().isNotEmpty == true;
