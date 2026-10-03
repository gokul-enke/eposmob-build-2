import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

abstract final class VoucherNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());
  static void openCustomerList() =>
      _sidebar.index.value = SideBarController.customerVoucherListIndex;
  static void openCustomerCreate() =>
      _sidebar.index.value = SideBarController.createCustomerVoucherIndex;
  static void openSupplierList({bool transactions = false}) =>
      _sidebar.index.value = transactions
          ? SideBarController.transactionSupplierVoucherListIndex
          : SideBarController.supplierVoucherListIndex;
  static void openSupplierCreate() =>
      _sidebar.index.value = _sidebar.index.value ==
              SideBarController.transactionSupplierVoucherListIndex
          ? SideBarController.transactionCreateSupplierVoucherIndex
          : SideBarController.createSupplierVoucherIndex;
  static void backFromSupplierCreate() => openSupplierList(
      transactions: _sidebar.index.value ==
          SideBarController.transactionCreateSupplierVoucherIndex);
}
