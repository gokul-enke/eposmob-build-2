import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/providers/admin_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/widgets/side_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Roles extends RoleProvider {
  _Roles(this.permissions);
  final Set<String> permissions;

  @override
  Future<void> fetchRoles(BuildContext context) async {}

  @override
  bool currentUserHasPermissionSync(String permission) =>
      permissions.contains(permission);
}

class _Executives extends SalesExecutiveProvider {
  final _executive = SalesExecutive(
    id: 1,
    name: 'Asha',
    email: 'asha@example.test',
    phone: '',
    phoneVerified: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  @override
  List<SalesExecutive> get salesExecutives => [_executive];

  @override
  SalesExecutive? getCurrentUser(BuildContext context) => _executive;

  @override
  Future<void> fetchSalesExecutives(BuildContext context) async {}
}

void main() {
  tearDown(() => Get.delete<SideBarController>(force: true));

  /// Clicks the desktop Reports header as [role] with [permissions] and
  /// returns the sidebar slot it opened.
  Future<int> openReports(WidgetTester tester,
      {String role = 'manager', Set<String> permissions = const {}}) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceProvider.navigationSidebarExpandedKey: true,
      'userRole': role,
    });
    final sidebar = Get.put(SideBarController())
      ..index.value = SideBarController.productListScreenIndex;
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>(create: (_) => AuthModel()),
        ChangeNotifierProvider<RoleProvider>(
            create: (_) => _Roles(permissions)),
        ChangeNotifierProvider<SalesExecutiveProvider>(
            create: (_) => _Executives()),
        ChangeNotifierProvider<AdminSettingsProvider>(
            create: (_) => AdminSettingsProvider()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: CollapsibleSidebar(
              sidebarContent: SideMenu(), child: SizedBox.expand()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final header = find.text('nav.reports'.tr);
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    final index = sidebar.index.value;
    await tester.pumpWidget(const SizedBox.shrink());
    return index;
  }

  testWidgets('a role with one report opens that report from the header',
      (tester) async {
    expect(
        await openReports(tester,
            permissions: {'menu.reports.sales_report.access'}),
        SideBarController.salesReportScreenIndex);
    expect(
        await openReports(tester,
            permissions: {'menu.reports.discount_sales.access'}),
        SideBarController.discountSaleReportScreenIndex);
    expect(
        await openReports(tester, permissions: {'menu.reports.stock.access'}),
        SideBarController.stockReportScreenIndex);
  });

  testWidgets('sales executive reports and company admins keep their page',
      (tester) async {
    expect(
        await openReports(tester, permissions: {
          'menu.reports.sales_executive.access',
          'menu.reports.sales_report.access'
        }),
        SideBarController.mySalesReportScreenIndex);
    expect(await openReports(tester, role: 'company_admin'), 85);
  });
}
