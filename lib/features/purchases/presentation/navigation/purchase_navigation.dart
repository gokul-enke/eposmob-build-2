import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

class PurchaseNavigation {
  PurchaseNavigation._();
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openLegacyList() =>
      openIndex(SideBarController.legacyPurchaseListScreenIndex);
  static void openLegacyCreate() =>
      openIndex(SideBarController.legacyCreatePurchaseScreenIndex);
  static void openLegacyVouchers() =>
      openIndex(SideBarController.legacyPurchaseVoucherListScreenIndex);
  static void openLegacyVoucherDetails() =>
      openIndex(SideBarController.legacyPurchaseVoucherDetailsScreenIndex);
  static void openList() =>
      openIndex(SideBarController.purchaseOrderListScreenIndex);
  static void openCreate() =>
      openIndex(SideBarController.createPurchaseOrderScreenIndex);
  static void openDetails() =>
      openIndex(SideBarController.purchaseDetailsScreenIndex);
  static void openIndex(int index) => _sidebar.index.value = index;
}
