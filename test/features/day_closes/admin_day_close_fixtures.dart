import 'package:pos_machine/features/day_closes/domain/admin_day_close_list.dart';
import 'package:pos_machine/features/day_closes/domain/day_close_list.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'day_close_fixtures.dart';

const adminScope = AdminDayCloseScope(
    token: 'test',
    tenant: 'test',
    endpoint: 'https://example.test/list',
    executivesEndpoint: 'https://example.test/executives',
    storeId: 2,
    actorId: 10);
const allExecutives = [
  AdminExecutiveOption(516, 'Executive'),
  AdminExecutiveOption(911, 'Second Executive')
];

DayCloseListData adminPage(int page, AdminDayCloseQuery query,
    {int total = 3, int perPage = 2}) {
  final data = pageData(page, total: total, perPage: perPage);
  for (final row in data.rows) {
    row.closingPeriod = '2026-10-05 to 2026-10-07';
    row.salesExecutive = SalesExecutive(
        id: query.executiveId ?? (row.id!.isEven ? 911 : 516),
        name: row.id!.isEven ? 'Second Executive' : 'Executive',
        phone: '0012345678');
  }
  return data;
}

class FakeAdminSource implements AdminDayCloseSource {
  FakeAdminSource({this.scope = adminScope});
  @override
  final AdminDayCloseScope scope;
  Future<DayCloseListData> Function(int, AdminDayCloseQuery)? fetchPage;
  Future<List<AdminExecutiveOption>> Function()? lookup;
  final calls = <(int, String?, int?)>[];
  int lookupCalls = 0;
  @override
  Future<DayCloseListData> fetch(int page, AdminDayCloseQuery query) async {
    calls.add((page, query.date, query.executiveId));
    return fetchPage == null
        ? adminPage(page, query)
        : await fetchPage!(page, query);
  }

  @override
  Future<List<AdminExecutiveOption>> fetchExecutives() async {
    lookupCalls++;
    return lookup == null ? allExecutives : await lookup!();
  }
}
