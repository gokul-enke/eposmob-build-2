import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/vouchers/presentation/navigation/voucher_navigation.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);
  test(
      'customer and supplier routes retain existing slots and create/back aliases',
      () {
    VoucherNavigation.openCustomerList();
    final sidebar = Get.find<SideBarController>();
    expect(sidebar.index.value, 70);
    VoucherNavigation.openCustomerCreate();
    expect(sidebar.index.value, 71);
    VoucherNavigation.openSupplierList();
    expect(sidebar.index.value, 72);
    VoucherNavigation.openSupplierCreate();
    expect(sidebar.index.value, 73);
    VoucherNavigation.backFromSupplierCreate();
    expect(sidebar.index.value, 72);
    VoucherNavigation.openSupplierList(transactions: true);
    expect(sidebar.index.value, 75);
    VoucherNavigation.openSupplierCreate();
    expect(sidebar.index.value, 76);
    VoucherNavigation.backFromSupplierCreate();
    expect(sidebar.index.value, 75);
  });
}
