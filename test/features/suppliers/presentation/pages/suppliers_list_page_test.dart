import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/suppliers/presentation/pages/suppliers_list_page.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../../support/supplier_fixtures.dart';

void main() {
  late FakeSupplierRepository repository;
  late SupplierProvider provider;
  late SideBarController sidebar;

  setUp(() {
    repository = FakeSupplierRepository(numberedSuppliers(28));
    provider = SupplierProvider(repository: repository);
    sidebar = Get.put(SideBarController());
    sidebar.index.value = SideBarController.suppliersScreenIndex;
  });

  tearDown(() => Get.delete<SideBarController>(force: true));

  Future<void> pumpPage(
    WidgetTester tester,
    Size size, {
    ExportController? export,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>.value(
            value: AuthModel()..login('token', 1),
          ),
          ChangeNotifierProvider<SupplierProvider>.value(value: provider),
        ],
        child: GetMaterialApp(
          home: Scaffold(body: SuppliersListPage(export: export)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  final filters = find.byKey(const ValueKey('supplier-list-filters'));

  testWidgets('desktop: table, pagination and the header actions in order',
      (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    expect(find.text('Supplier 1'), findsOneWidget);
    expect(find.text('20 suppliers on this page'), findsOneWidget);
    expect(filters, findsOneWidget);
    final xs = [
      SuppliersListPage.filterToggleKey,
      SuppliersListPage.exportKey,
      SuppliersListPage.refreshKey,
    ].map((key) => tester.getCenter(find.byKey(key)).dx).toList();
    expect(xs, orderedEquals([...xs]..sort()));
    expect(find.text('Add New Supplier'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Supplier 21'), findsOneWidget);
  });

  testWidgets('desktop: hiding filters keeps the input and its pending search',
      (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    await tester.enterText(field('Name'), 'Supplier 2');
    await tester.tap(find.byKey(SuppliersListPage.filterToggleKey));
    await tester.pump();
    expect(filters.hitTestable(), findsNothing);
    expect(find.byType(AppBadgeDot), findsOneWidget);

    // The debounced search still runs while the panel is hidden.
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.filter.name, 'Supplier 2');

    await tester.tap(find.byKey(SuppliersListPage.filterToggleKey));
    await tester.pumpAndSettle();
    final name = tester.widget<TextFormField>(field('Name'));
    expect(name.controller!.text, 'Supplier 2');
  });

  testWidgets('phone: filters start hidden, toggle from the menu, no overflow',
      (tester) async {
    await pumpPage(tester, const Size(360, 640));

    expect(filters.hitTestable(), findsNothing);
    expect(find.text('Add New'), findsOneWidget);
    expect(find.byKey(PageHeader.moreActionsKey), findsOneWidget);

    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Filters'));
    await tester.pumpAndSettle();
    expect(filters.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh reloads and re-applies every visible filter',
      (tester) async {
    await pumpPage(tester, const Size(1280, 800));
    await tester.enterText(field('Email'), 'supplier1');
    await tester.enterText(field('Phone'), '555');
    // Still pending: refresh must apply what is typed, not wait for it.
    await tester.tap(find.byKey(SuppliersListPage.refreshKey));
    await tester.pumpAndSettle();

    expect(repository.fetches, 2);
    expect(provider.filter.email, 'supplier1');
    expect(provider.filter.phone, '555');
  });

  testWidgets(
      'export applies pending filters in place, exports every match and '
      'makes no API call', (tester) async {
    File? delivered;
    final export = ExportController(
      deliver: (context, file,
          {required mimeType, shareText, shareOrigin, onStage}) async {
        delivered = file;
      },
    );
    final dir = Directory.systemTemp.createTempSync('supplier-export-');
    addTearDown(() => dir.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await pumpPage(tester, const Size(1440, 900), export: export);
    provider.goToPage(2);
    await tester.pump();
    await tester.enterText(field('Name'), 'Supplier');
    await tester.enterText(field('Email'), '@test.com');
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.filter.name, isEmpty);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(SuppliersListPage.exportKey));
      for (var i = 0; i < 50 && delivered == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    final rows = Excel.decodeBytes(delivered!.readAsBytesSync())
        .tables
        .values
        .single
        .rows;
    expect(rows.length, 29);
    expect(provider.filter.email, '@test.com');
    expect(provider.currentPage, 2);
    expect(repository.fetches, 1);

    // The cancelled debounce must not reset the page later.
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.currentPage, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed export shows the error message', (tester) async {
    final export = ExportController(
      deliver: (context, file,
              {required mimeType, shareText, shareOrigin, onStage}) async =>
          throw StateError('disk full'),
    );
    final dir = Directory.systemTemp.createTempSync('supplier-export-');
    addTearDown(() => dir.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await pumpPage(tester, const Size(1280, 800), export: export);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(SuppliersListPage.exportKey));
      for (var i = 0; i < 50 && export.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('Could not export suppliers'), findsOneWidget);
    await tester.pump(AppToastType.error.duration);
  });

  testWidgets('View and row tap open the profile', (tester) async {
    await pumpPage(tester, const Size(1280, 800));
    await tester.tap(find.text('View').first);
    expect(provider.selectedSupplier!.id, 1);
    expect(sidebar.index.value, SideBarController.supplierProfileScreenIndex);

    await tester.tap(find.text('Supplier 3'));
    expect(provider.selectedSupplier!.id, 3);
  });

  testWidgets('empty results show the empty state', (tester) async {
    repository.suppliers = [];
    await pumpPage(tester, const Size(1280, 800));
    expect(find.text('No suppliers found'), findsOneWidget);
  });
}
