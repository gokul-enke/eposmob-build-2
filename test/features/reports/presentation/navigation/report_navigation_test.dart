import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/reports/presentation/navigation/report_navigation.dart';
import 'package:pos_machine/features/reports/presentation/pages/stock_report_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);
  test('Stock Report uses named slot 98 and reuses the shell controller', () {
    final sidebar = Get.put(SideBarController());
    expect(sidebar.screens[SideBarController.stockReportScreenIndex],
        isA<StockReportPage>());
    sidebar.index.value = 0;
    ReportNavigation.openStockReport();
    expect(Get.find<SideBarController>(), same(sidebar));
    expect(sidebar.index.value, 98);
  });
}
