import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

class SalesReturnNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openList() =>
      _sidebar.index.value = SideBarController.salesReturnListScreenIndex;
  static void openCreate() =>
      _sidebar.index.value = SideBarController.createSalesReturnScreenIndex;
}
