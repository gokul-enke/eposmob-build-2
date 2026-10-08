import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

abstract final class CategoryNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openList() =>
      _sidebar.index.value = SideBarController.categoryListScreenIndex;
  static void openAdd() =>
      _sidebar.index.value = SideBarController.addCategoryScreenIndex;
  static void openEdit() =>
      _sidebar.index.value = SideBarController.editCategoryScreenIndex;
}
