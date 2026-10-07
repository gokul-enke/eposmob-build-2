import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

/// The one place that knows how the report screens are reached in the
/// sidebar shell.
abstract final class ReportNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());

  static void openConsumedStocksReport() =>
      _sidebar.index.value = SideBarController.consumedStocksReportScreenIndex;

  /// The selected customer's transactions (read from `CustomerProvider`).
  static void openCustomerTransactionDetails() => _sidebar.index.value =
      SideBarController.customerTransactionDetailsScreenIndex;
}
