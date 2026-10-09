import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/features/reports/presentation/pages/admin_executive_report_page.dart';
import 'package:pos_machine/features/reports/domain/report_date_range.dart';
import '../../test_support/export_capture.dart' show useTempExportDirectory;
import '../day_closes/day_close_page_test.dart'
    show CloseSettings, CloseTranslations, CaptureExport;
import 'admin_executive_contract_test.dart' show Source, scope, rows;

void main() {
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final suffix in ['Regular', 'Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Poppins-$suffix.ttf'));
    }
    await loader.load();
    final file = File('C:/Windows/Fonts/Nirmala.ttc');
    if (await file.exists()) {
      final fallback = FontLoader('Nirmala UI');
      fallback.addFont(file.readAsBytes().then(ByteData.sublistView));
      await fallback.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);
  Future<void> mount(WidgetTester t, Source source,
      {Size size = const Size(1440, 900),
      String lang = 'en',
      CaptureExport? export,
      void Function(dynamic, String)? view}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => CloseSettings(),
        child: GetMaterialApp(
            theme: ThemeData(
                fontFamily: 'Poppins',
                fontFamilyFallback: const ['Nirmala UI']),
            locale: Locale(lang),
            translations: CloseTranslations(),
            home: Scaffold(
                body: AdminExecutiveReportPage(
                    readSource: () async => source,
                    exportController: export,
                    onView: view ?? (_, __) {})))));
    await t.pumpAndSettle();
  }

  HeaderAction exportAction(WidgetTester t) => t
      .widget<PageHeader>(find.byType(PageHeader))
      .actions
      .singleWhere((a) => a.key == AdminExecutiveReportPage.exportKey);
  for (final lang in ['en', 'ar', 'ml']) {
    for (final size in [
      const Size(1440, 900),
      const Size(850, 900),
      const Size(390, 812),
      const Size(390, 350)
    ]) {
      testWidgets('shared layout $lang $size no overflow', (t) async {
        await mount(t, Source(scope, (_) async => rows()),
            size: size, lang: lang);
        expect(find.byType(PageHeader), findsOneWidget);
        expect(exportAction(t).onPressed, isNotNull);
        expect(t.takeException(), isNull);
        if (size.width >= 850) {
          final toggle =
              find.byKey(const ValueKey('admin-executive-filter-toggle'));
          await t.tap(toggle);
          await t.pumpAndSettle();
          expect(find.byKey(AdminExecutiveReportPage.fromKey).hitTestable(),
              findsNothing);
          await t.tap(toggle);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('name filter is local, Reset reloads and restores all results',
      (t) async {
    var calls = 0;
    final source = Source(scope, (_) async {
      calls++;
      return [...rows(), ...rows('Bob')];
    });
    await mount(t, source);
    await t.enterText(find.byKey(AdminExecutiveReportPage.nameKey), ' bob ');
    await t.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
    expect(calls, 1);
    final panel = t.widget<FilterPanel>(find.byType(FilterPanel));
    panel.onReset();
    await t.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(calls, 2);
    expect(
        t
            .widget<TextFormField>(find.byKey(AdminExecutiveReportPage.nameKey))
            .controller!
            .text,
        '');
  });
  testWidgets(
      'refresh failure retains rows but disables export and retry recovers',
      (t) async {
    var fail = false;
    await mount(
        t,
        Source(scope, (_) async {
          if (fail) throw StateError('offline');
          return rows();
        }));
    fail = true;
    t.widget<PageHeader>(find.byType(PageHeader)).actions.last.onPressed!();
    await t.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(exportAction(t).onPressed, isNull);
    expect(find.text('Retry'), findsOneWidget);
    fail = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(exportAction(t).onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('date cancellation leaves applied today query intact', (t) async {
    var calls = 0;
    await mount(
        t,
        Source(scope, (_) async {
          calls++;
          return rows();
        }));
    await t.tap(find.byKey(AdminExecutiveReportPage.fromKey));
    await t.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(exportAction(t).onPressed, isNotNull);
  });
  testWidgets('view keeps loaded date label and shared blue action', (t) async {
    String? label;
    await mount(t, Source(scope, (_) async => rows()),
        view: (_, l) => label = l);
    final button =
        find.widgetWithIcon(AppSquareIconButton, Icons.visibility_outlined);
    expect(t.widget<AppSquareIconButton>(button).foreground, AppColors.primary);
    t.widget<AppSquareIconButton>(button).onPressed!();
    expect(label, isNotNull);
    expect(label, contains('2026'));
  });
  testWidgets(
      'export factory cancels after name changes and exports all matching rows',
      (t) async {
    await useTempExportDirectory(t, 'admin-executive-widget-');
    final capture = CaptureExport();
    await mount(t, Source(scope, (_) async => [...rows(), ...rows('Bob')]),
        export: capture);
    await t.enterText(find.byKey(AdminExecutiveReportPage.nameKey), 'Bob');
    await t.pumpAndSettle();
    exportAction(t).onPressed!();
    await t.pumpAndSettle();
    expect(capture.factory, isNotNull);
    final file = await t.runAsync(() => capture.factory!());
    expect(file, isA<File>());
    await t.enterText(find.byKey(AdminExecutiveReportPage.nameKey), 'Alice');
    await t.pumpAndSettle();
    await t.runAsync(() => expectLater(capture.factory!(), throwsStateError));
  });
  testWidgets('selected date needs time confirmation and clear restores today',
      (t) async {
    final queries = <ReportDateRange>[];
    await mount(
        t,
        Source(scope, (r) async {
          queries.add(r);
          return rows();
        }));
    await t.tap(find.byKey(AdminExecutiveReportPage.fromKey));
    await t.pumpAndSettle();
    t
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 10, 1));
    await t.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(queries.length, 1);
    await t.tap(find.byKey(AdminExecutiveReportPage.fromKey));
    await t.pumpAndSettle();
    t
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 10, 1));
    await t.pumpAndSettle();
    await t.tap(find.text('OK').last);
    await t.pumpAndSettle();
    expect(queries.last.from!.day, 1);
    expect(queries.last.apiFrom, startsWith('2026-10-01 '));
    await t.tap(find.widgetWithIcon(IconButton, Icons.close));
    await t.pumpAndSettle();
    expect(queries.last.isEmpty, true);
    expect(queries.length, 3);
    expect(t.takeException(), isNull);
  });
}
