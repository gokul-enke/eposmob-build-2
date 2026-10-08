import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

/// Only the barcode list route; existing detail and print dialogs stay local.
abstract final class BarcodeNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openList() =>
      _sidebar.index.value = SideBarController.productBarcodeListScreenIndex;
}
