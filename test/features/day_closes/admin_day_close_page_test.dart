import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/sales/presentation/pages/admin_daily_sales_close_list_page.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/navigation/sales_navigation.dart';
import 'package:pos_machine/features/day_closes/domain/admin_day_close_list.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/features/day_closes/presentation/pages/admin_day_close_list_page.dart';
import 'package:pos_machine/features/day_closes/presentation/state/admin_day_close_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'admin_day_close_fixtures.dart';
import 'day_close_page_test.dart' show CloseSettings, CloseTranslations;
import '../../test_support/export_capture.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    final poppins = FontLoader('Poppins');
    for (final suffix in ['Regular', 'Medium', 'SemiBold']) {
      poppins.addFont(rootBundle.load('assets/fonts/Poppins-$suffix.ttf'));
    }
    await poppins.load();
    for (final entry
        in {'Arial': 'arial.ttf', 'Nirmala UI': 'Nirmala.ttc'}.entries) {
      final file = File('C:/Windows/Fonts/${entry.value}');
      if (await file.exists()) {
        final font = FontLoader(entry.key);
        font.addFont(file.readAsBytes().then(ByteData.sublistView));
        await font.load();
      }
    }
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final fonts = configFile.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final font = FontLoader(entry.key);
      font.addFont(File.fromUri(fonts.resolve(entry.value))
          .readAsBytes()
          .then(ByteData.sublistView));
      await font.load();
    }
  });
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => Get.reset());

  Future<void> mount(WidgetTester tester, FakeAdminSource source,
      {Size size = const Size(1440, 900),
      String locale = 'en',
      ExportController? export,
      VoidCallback? viewed}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => CloseSettings(),
        child: GetMaterialApp(
            locale: Locale(locale),
            translations: CloseTranslations(),
            theme: ThemeData(
                fontFamily: 'Poppins',
                fontFamilyFallback: const ['Nirmala UI', 'Arial']),
            home: Scaffold(
                body: RepaintBoundary(
                    key: const ValueKey('admin-preview'),
                    child: AdminDayCloseListPage(
                        readSource: () async => source,
                        exportController: export,
                        onView: (_, __) => viewed?.call()))))));
    await tester.pumpAndSettle();
  }

  AdminDayCloseController controller(WidgetTester tester) => tester
      .widgetList<ListenableBuilder>(find.byType(ListenableBuilder))
      .map((w) => w.listenable)
      .whereType<AdminDayCloseController>()
      .first;
  HeaderAction action(WidgetTester tester, Key key) => tester
      .widget<PageHeader>(find.byType(PageHeader))
      .actions
      .singleWhere((a) => a.key == key);

  for (final locale in ['en', 'ar', 'ml']) {
    for (final size in [
      const Size(1440, 900),
      const Size(850, 900),
      const Size(390, 812),
      const Size(390, 350)
    ]) {
      testWidgets('localized admin layout fits $locale $size', (tester) async {
        final source = FakeAdminSource()
          ..fetchPage = (p, q) async => adminPage(p, q, total: 10, perPage: 10);
        await mount(tester, source, locale: locale, size: size);
        expect(find.byType(PageHeader), findsOneWidget);
        expect(action(tester, AdminDayCloseListPage.exportKey).onPressed,
            isNotNull);
        expect(find.textContaining('daily_sales_close.'), findsNothing);
        expect(find.textContaining('{count}'), findsNothing);
        expect(find.textContaining('@count'), findsNothing);
        expect(find.text('Open Shift'), findsNothing);
        expect(find.text('Day Close'), findsNothing);
        if (size.width == 1440) {
          expect(
              find.byType(AppDataTable<DailySalesCloseData>), findsOneWidget);
          expect(find.byType(Scrollbar), findsWidgets);
          expect(find.text('2026-10-05 to 2026-10-07'), findsWidgets);
        }
        expect(tester.takeException(), isNull);
        if (size.width == 1440 || size.height == 812) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('admin-preview')));
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final path =
                '${Directory.systemTemp.path}/admin-day-close-previews';
            await Directory(path).create(recursive: true);
            await File('$path/$locale-${size.width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
  testWidgets(
      'executive search dismissal restores applied label; selection uses identity',
      (tester) async {
    final source = FakeAdminSource();
    await mount(tester, source);
    await tester.tap(find.byKey(const ValueKey('admin-day-close-executive')));
    await tester.pumpAndSettle();
    // Popup items handle the pointer in their parent rather than the Text.
    await tester.tapAt(tester.getCenter(find
        .descendant(
            of: find.byType(DropdownSearchPopup<AdminExecutiveOption>),
            matching: find.text('Second Executive'))
        .last));
    await tester.pumpAndSettle();
    expect(controller(tester).query.executiveId, 911);
    await tester.tap(find.byKey(const ValueKey('admin-day-close-executive')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'not selected');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1200, 100));
    await tester.pumpAndSettle();
    expect(controller(tester).query.executiveId, 911);
    final dropdown = tester.widget<DropdownSearch<AdminExecutiveOption>>(
        find.byKey(const ValueKey('admin-day-close-executive')));
    expect(dropdown.selectedItems.single.name, 'Second Executive');
    expect(find.text('not selected'), findsNothing);
  });
  testWidgets(
      'date picker -> executive -> page -> reset updates all controls and next export',
      (tester) async {
    final source = FakeAdminSource();
    final export = CapturingExport();
    await mount(tester, source, export: export);
    await tester.tap(find.byKey(const ValueKey('admin-day-close-date')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    expect(controller(tester).query.date, isNotNull);
    await tester.tap(find.byKey(const ValueKey('admin-day-close-executive')));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find
        .descendant(
            of: find.byType(DropdownSearchPopup<AdminExecutiveOption>),
            matching: find.text('Second Executive'))
        .last));
    await tester.pumpAndSettle();
    expect(controller(tester).query.executiveId, 911);
    tester
        .widget<AppPaginationBar>(find.byType(AppPaginationBar))
        .onPageChanged(2);
    await tester.pumpAndSettle();
    expect(controller(tester).data!.page, 2);
    await tester.tap(find.text('list.reset'.tr));
    await tester.pumpAndSettle();
    expect(controller(tester).query.date, isNull);
    expect(controller(tester).query.executiveId, isNull);
    expect(controller(tester).data!.page, 1);
    expect(
        tester
            .widget<DropdownSearch<AdminExecutiveOption>>(
                find.byKey(const ValueKey('admin-day-close-executive')))
            .selectedItems
            .single
            .id,
        0);
    expect(source.calls.last, (1, null, null));
    export.dispose();
  });
  testWidgets(
      'export uses captured filters on every page and preserves visible page',
      (tester) async {
    final source = FakeAdminSource();
    final export = CapturingExport();
    await mount(tester, source, export: export);
    await controller(tester).setQuery(
        const AdminDayCloseQuery(date: '2026-10-07', executiveId: 911));
    await controller(tester).load(page: 2);
    await tester.pumpAndSettle();
    await useTempExportDirectory(tester, 'admin-page-export-');
    action(tester, AdminDayCloseListPage.exportKey).onPressed!();
    await tester.pumpAndSettle();
    source.calls.clear();
    final file = await tester.runAsync(() => export.createFile!());
    expect(await tester.runAsync(() => file!.exists()), isTrue);
    expect(source.calls, [(1, '2026-10-07', 911), (2, '2026-10-07', 911)]);
    expect(controller(tester).data!.page, 2);
    export.dispose();
  });
  testWidgets(
      'changed filter cancels captured export before fetching another snapshot',
      (tester) async {
    final source = FakeAdminSource();
    final export = CapturingExport();
    await mount(tester, source, export: export);
    action(tester, AdminDayCloseListPage.exportKey).onPressed!();
    await tester.pumpAndSettle();
    await controller(tester)
        .setQuery(const AdminDayCloseQuery(executiveId: 911));
    await expectLater(export.createFile!(), throwsStateError);
    export.dispose();
  });
  testWidgets(
      'empty and backend failure are distinct; retry recovers; stale rows disable export',
      (tester) async {
    final source = FakeAdminSource()
      ..fetchPage = (p, q) async => adminPage(p, q, total: 0);
    await mount(tester, source);
    expect(find.text('daily_sales_close.no_closes_found'.tr), findsOneWidget);
    expect(action(tester, AdminDayCloseListPage.exportKey).onPressed, isNull);
    source.fetchPage = (_, __) async => throw StateError('HTTP 500');
    await controller(tester).load();
    await tester.pumpAndSettle();
    expect(find.text('daily_sales_close.list_load_error'.tr), findsOneWidget);
    source.fetchPage = null;
    await tester.tap(find.text('restaurant.retry'.tr));
    await tester.pumpAndSettle();
    expect(controller(tester).canExport, isTrue);
    source.fetchPage = (_, __) async => throw StateError('HTTP 500');
    await controller(tester).load(page: 2);
    await tester.pumpAndSettle();
    expect(find.text('daily_sales_close.list_load_failed'.tr), findsOneWidget);
    expect(action(tester, AdminDayCloseListPage.exportKey).onPressed, isNull);
  });
  testWidgets('short table fits rows; blue View calls original callback',
      (tester) async {
    final source = FakeAdminSource()
      ..fetchPage = (p, q) async => adminPage(p, q, total: 1);
    var views = 0;
    await mount(tester, source, viewed: () => views++);
    final table = find.byType(AppDataTable<DailySalesCloseData>);
    expect(tester.widget<AppDataTable<DailySalesCloseData>>(table).fitToContent,
        isTrue);
    expect(tester.getSize(table).height, lessThan(200));
    final scroll = tester
        .widget<AdminDayCloseListPage>(find.byType(AdminDayCloseListPage));
    expect(scroll.onView, isNotNull);
    final square = tester.widget<AppSquareIconButton>(find.ancestor(
        of: find.byTooltip('daily_sales_close.btn_view_details'.tr),
        matching: find.byType(AppSquareIconButton)));
    expect(square.foreground, AppColors.primary);
    square.onPressed!();
    expect(views, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'admin View retains selected row, detail route and admin return route',
      (tester) async {
    final source = FakeAdminSource();
    final sales = SalesProvider();
    final sidebar = Get.put(SideBarController());
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => CloseSettings()),
          ChangeNotifierProvider<SalesProvider>.value(value: sales),
        ],
        child: GetMaterialApp(
            locale: const Locale('en'),
            translations: CloseTranslations(),
            home: Scaffold(
                body: AdminDailySalesCloseListPage(
                    readSource: () async => source)))));
    await tester.pumpAndSettle();
    final row = controller(tester).data!.rows.first;
    final element = tester.element(find.byType(AdminDayCloseListPage));
    tester
        .widget<AdminDayCloseListPage>(find.byType(AdminDayCloseListPage))
        .onView(element, row);
    expect(sales.selectedDailySalesCloseData, same(row));
    expect(sales.returnIndex,
        SideBarController.adminDailySalesCloseListScreenIndex);
    expect(sidebar.index.value,
        SideBarController.dailySalesCloseDetailScreenIndex);
    SalesNavigation.returnFromDailyClose(sales.returnIndex);
    expect(sidebar.index.value,
        SideBarController.adminDailySalesCloseListScreenIndex);
    await tester.pumpWidget(const SizedBox.shrink());
    sales.dispose();
  });
}
