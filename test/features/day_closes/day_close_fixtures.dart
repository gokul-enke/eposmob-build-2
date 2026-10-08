import 'package:pos_machine/features/day_closes/domain/day_close_list.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/features/sales/domain/models/day_close_pending_status.dart';

const fixtureScope = DayCloseListScope(
    token: 'test',
    tenant: 'test',
    endpoint: 'https://example.test/list',
    pendingEndpoint: 'https://example.test/pending',
    storeId: 2,
    userId: 516);
const scope = fixtureScope;
DailySalesCloseData closeRow(int id) => DailySalesCloseData(
    id: id,
    salesExecutive:
        SalesExecutive(id: 516, name: 'Executive', phone: '0012345678'),
    store: Store(id: 2, name: 'Store'),
    businessDate: '2026-10-07',
    totalOrders: 12,
    totalSales: '256.00',
    totalOnline: '183.00',
    totalCash: '2.00',
    totalCredit: '71.00',
    status: 'closed');
DayCloseListData pageData(int page, {int total = 3, int perPage = 2}) {
  final start = (page - 1) * perPage;
  return DayCloseListData(
      rows: [
        for (var i = start; i < total && i < start + perPage; i++)
          closeRow(i + 1)
      ],
      page: page,
      pages: total == 0 ? 1 : (total / perPage).ceil(),
      perPage: perPage,
      total: total);
}

DayClosePendingStatus pendingStatus(
        {bool canOpen = true, OpenDraftModel? draft}) =>
    DayClosePendingStatus(
        pendingDayClose: false,
        canOpenShift: canOpen,
        requiresConfirmation: false,
        businessDate: '',
        message: '',
        confirmationMessage: '',
        openDraft: draft);

class FakeDayCloseSource implements DayCloseListSource {
  FakeDayCloseSource({this.scope = fixtureScope});
  @override
  final DayCloseListScope scope;
  Future<DayCloseListData> Function(int, String?)? fetchPage;
  Future<DayClosePendingStatus> Function()? pendingResponse;
  final calls = <(int, String?)>[];
  int pendingCalls = 0;
  @override
  Future<DayCloseListData> fetch(int page, {String? date}) async {
    calls.add((page, date));
    return fetchPage == null ? pageData(page) : await fetchPage!(page, date);
  }

  @override
  Future<DayClosePendingStatus> fetchPending() async {
    pendingCalls++;
    return pendingResponse == null ? pendingStatus() : await pendingResponse!();
  }
}
