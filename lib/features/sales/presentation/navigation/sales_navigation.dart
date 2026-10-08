import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

/// Keeps Sales sidebar mutations in one adapter without changing screen slots.
class SalesNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openOrders({bool online = false}) => _sidebar.index.value = online
      ? SideBarController.onlineSalesScreenIndex
      : SideBarController.salesScreenIndex;
  static void openDetails() =>
      _sidebar.index.value = SideBarController.salesOrderDetailsScreenIndex;
  static void openConfirmed() =>
      _sidebar.index.value = SideBarController.confirmedOrdersScreenIndex;
  static void openDailyCloseList({bool admin = false}) =>
      _sidebar.index.value = admin
          ? SideBarController.adminDailySalesCloseListScreenIndex
          : SideBarController.dailySalesCloseListScreenIndex;
  static void openDailyCloseDetails() =>
      _sidebar.index.value = SideBarController.dailySalesCloseDetailScreenIndex;
  static void returnFromDailyClose(int index) => _sidebar.index.value = index;
}
