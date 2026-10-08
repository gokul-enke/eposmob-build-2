import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

/// The one place that knows how the report screens are reached in the
/// sidebar shell.
abstract final class ReportNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());

  static void openStockReport() =>
      _sidebar.index.value = SideBarController.stockReportScreenIndex;

  /// The selected customer's transactions (read from `CustomerProvider`).
  static void openCustomerTransactionDetails() => _sidebar.index.value =
      SideBarController.customerTransactionDetailsScreenIndex;
  static void openSupplierTransactionsReport() => _sidebar.index.value =
      SideBarController.supplierTransactionsReportScreenIndex;
  static void openSupplierTransactionDetails() => _sidebar.index.value =
      SideBarController.supplierTransactionDetailsScreenIndex;
}
