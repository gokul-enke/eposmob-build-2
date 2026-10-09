import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/sales_executive.dart';
import 'package:pos_machine/providers/admin_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/widgets/drawer_list_tile_expandable.dart';
import 'package:pos_machine/widgets/side_menu.dart';
import 'package:pos_machine/widgets/user_switcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MenuRoles extends RoleProvider {
  @override
  Future<void> fetchRoles(BuildContext context) async {}

  @override
  bool currentUserHasPermissionSync(String permission) => const {
        'menu.home.main.access',
        'menu.utility.user_switcher.access',
        'menu.catalog.category.access',
        'menu.catalog.product.list.access',
        'menu.catalog.product.stock.access',
      }.contains(permission);
}

class _MenuExecutives extends SalesExecutiveProvider {
  int fetchCount = 0;
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
  Future<void> fetchSalesExecutives(BuildContext context) async => fetchCount++;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceProvider.navigationSidebarExpandedKey: false,
    });
    Get.put(SideBarController()).index.value =
        SideBarController.productListScreenIndex;
  });

  tearDown(() => Get.delete<SideBarController>(force: true));

  testWidgets('real menu preserves selection, submenu and page focus on hover',
      (tester) async {
    final firstField = FocusNode();
    final secondField = FocusNode();
    addTearDown(firstField.dispose);
    addTearDown(secondField.dispose);
    const pageKey = ValueKey('real-menu-test-page');
    final sidebarKey = GlobalKey<CollapsibleSidebarState>();
    final executives = _MenuExecutives();
    addTearDown(executives.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(create: (_) => AuthModel()),
          ChangeNotifierProvider<RoleProvider>(create: (_) => _MenuRoles()),
          ChangeNotifierProvider<SalesExecutiveProvider>.value(
              value: executives),
          ChangeNotifierProvider<AdminSettingsProvider>(
              create: (_) => AdminSettingsProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CollapsibleSidebar(
              key: sidebarKey,
              sidebarContent: const SideMenu(),
              child: Column(
                key: pageKey,
                children: [
                  TextField(
                    key: const ValueKey('first-field'),
                    focusNode: firstField,
                  ),
                  TextField(focusNode: secondField),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pageRect = tester.getRect(find.byKey(pageKey));
    final groupState =
        tester.state(find.byType(DrawerListTileExpandableColumn));
    final userSwitcherState =
        tester.state(find.byType(UserSwitcher, skipOffstage: false));
    expect(executives.fetchCount, 1);
    await tester.enterText(find.byKey(const ValueKey('first-field')), 'Draft');
    expect(firstField.hasFocus, isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 500));
    await mouse.moveTo(const Offset(30, 200));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isExpanded, isTrue);
    expect(
        tester
            .widget<DrawerListTileExpandableColumn>(
                find.byType(DrawerListTileExpandableColumn))
            .selected,
        isTrue);
    expect(find.text('nav.stock'.tr), findsOneWidget);
    expect(find.text('nav.category'.tr), findsOneWidget);
    expect(tester.getRect(find.byKey(pageKey)), pageRect);
    expect(tester.state(find.byType(DrawerListTileExpandableColumn)),
        same(groupState));
    expect(tester.state(find.byType(UserSwitcher)), same(userSwitcherState));
    expect(firstField.hasFocus, isTrue);
    expect(find.text('Draft'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(secondField.hasFocus, isTrue);

    // Collapse the selected product submenu, then leave and preview again.
    await tester.tap(find.text('nav.product'.tr).first);
    await tester.pumpAndSettle();
    expect(find.text('nav.stock'.tr), findsNothing);
    expect(tester.state(find.byType(UserSwitcher)), same(userSwitcherState));
    expect(executives.fetchCount, 1);
    await mouse.moveTo(const Offset(500, 500));
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(30, 200));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(DrawerListTileExpandableColumn)),
        same(groupState));
    expect(find.text('nav.stock'.tr), findsNothing);
    expect(Get.find<SideBarController>().index.value,
        SideBarController.productListScreenIndex);

    await tester.tap(find.byKey(const ValueKey('navigation-sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isPinnedExpanded, isTrue);
    expect(tester.getRect(find.byKey(pageKey)).left, 200);
    await mouse.moveTo(const Offset(500, 500));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isExpanded, isTrue);
    expect(await SharedPreferenceProvider().getNavigationSidebarExpanded(),
        isTrue);

    // Navigate with the actual tile callback while the layout remains pinned.
    await tester.tap(find.text('nav.category'.tr));
    await tester.pumpAndSettle();
    expect(Get.find<SideBarController>().index.value,
        SideBarController.categoryListScreenIndex);
    expect(find.text('Draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
