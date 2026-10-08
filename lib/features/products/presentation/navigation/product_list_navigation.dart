import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

/// Only the list route belongs to this refactor. Inner routes stay unchanged.
abstract final class ProductListNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openList() =>
      _sidebar.index.value = SideBarController.productListScreenIndex;
}
