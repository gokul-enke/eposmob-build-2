import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/reports/presentation/navigation/report_navigation.dart';
import 'package:pos_machine/features/reports/presentation/pages/product_sales_report_page.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);
  test('Product Sales retains slot 40 and its page without registration', () {
    expect(Get.isRegistered<SideBarController>(), isFalse);
    ReportNavigation.openProductSalesReport();
    final sidebar = Get.find<SideBarController>();
    expect(SideBarController.productSalesReportScreenIndex, 40);
    expect(sidebar.index.value, 40);
    expect(sidebar.screens[40], isA<ProductSalesReportPage>());
  });
}
