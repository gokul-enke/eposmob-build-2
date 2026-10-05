import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

class PurchaseNavigation {
  PurchaseNavigation._();
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openLegacyList() =>
      openIndex(SideBarController.legacyPurchaseListIndex);
  static void openLegacyCreate() =>
      openIndex(SideBarController.legacyCreatePurchaseIndex);
  static void openLegacyVouchers() =>
      openIndex(SideBarController.legacyPurchaseVoucherListIndex);
  static void openLegacyVoucherDetails() =>
      openIndex(SideBarController.legacyPurchaseVoucherDetailsIndex);
  static void openList() => openIndex(SideBarController.purchaseOrderListIndex);
  static void openCreate() =>
      openIndex(SideBarController.createPurchaseOrderIndex);
  static void openDetails() =>
      openIndex(SideBarController.purchaseDetailsIndex);
  static void openIndex(int index) => _sidebar.index.value = index;
}
