import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

abstract final class VoucherNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openCustomerList() =>
      _sidebar.index.value = SideBarController.customerVoucherListScreenIndex;
  static void openCustomerCreate() =>
      _sidebar.index.value = SideBarController.createCustomerVoucherScreenIndex;
  static void openSupplierList({bool transactions = false}) =>
      _sidebar.index.value = transactions
          ? SideBarController.transactionSupplierVoucherListScreenIndex
          : SideBarController.supplierVoucherListScreenIndex;
  static void openSupplierCreate() =>
      _sidebar.index.value = _sidebar.index.value ==
              SideBarController.transactionSupplierVoucherListScreenIndex
          ? SideBarController.transactionCreateSupplierVoucherScreenIndex
          : SideBarController.createSupplierVoucherScreenIndex;
  static void backFromSupplierCreate() => openSupplierList(
      transactions: _sidebar.index.value ==
          SideBarController.transactionCreateSupplierVoucherScreenIndex);
}
