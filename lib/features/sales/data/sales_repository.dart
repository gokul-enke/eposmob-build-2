import 'daily_close_api.dart';
import 'sales_actions_api.dart';
import 'sales_orders_api.dart';

/// Sales has no independent Hive cache: local order ownership stays in billing/sync.
class SalesRepository {
  SalesRepository(
      {SalesOrdersApi? orders,
      SalesActionsApi? actions,
      DailyCloseApi? closing})
      : orders = orders ?? SalesOrdersApi(),
        actions = actions ?? SalesActionsApi(),
        closing = closing ?? DailyCloseApi();
  final SalesOrdersApi orders;
  final SalesActionsApi actions;
  final DailyCloseApi closing;
}
