import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/day_closes/presentation/pages/day_close_list_page.dart';
import 'package:pos_machine/features/day_closes/presentation/state/day_close_list_controller.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'day_close_fixtures.dart';
import '../../test_support/export_capture.dart';

class CloseTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final lang in ['en', 'ar', 'ml'])
          lang: flatten(jsonDecode(
              File('lib/resources/i18n/$lang.json').readAsStringSync()))
      };
  Map<String, String> flatten(Map<String, dynamic> json, [String prefix = '']) {
    final result = <String, String>{};
    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(flatten(entry.value, key));
      } else {
        result[key] = entry.value.toString();
      }
    }
    return result;
  }
}

class CloseSettings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class CaptureExport extends ExportController {
  Future<File> Function()? factory;
  @override
  Future<bool> run(BuildContext context,
      {required Future<File> Function() createFile,
      String mimeType = FileExportService.xlsxMimeType,
      String? shareText,
      Rect? shareOrigin}) async {
    factory = createFile;
    return true;
  }
}

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
        final loader = FontLoader(entry.key);
        loader.addFont(file.readAsBytes().then(ByteData.sublistView));
        await loader.load();
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
      final loader = FontLoader(entry.key);
      loader.addFont(File.fromUri(fonts.resolve(entry.value))
          .readAsBytes()
          .then(ByteData.sublistView));
      await loader.load();
    }
  });
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => Get.reset());
  Future<void> mount(WidgetTester tester, FakeDayCloseSource source,
      {Size size = const Size(1440, 900),
      String locale = 'en',
      ExportController? export,
      void Function(DailySalesCloseData)? view,
      VoidCallback? opened,
      void Function(VoidCallback, OpenDraftModel?)? closed}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => CloseSettings(),
        child: GetMaterialApp(
            theme: ThemeData(
                fontFamily: 'Poppins',
                fontFamilyFallback: const ['Nirmala UI', 'Arial']),
            locale: Locale(locale),
            translations: CloseTranslations(),
            home: Scaffold(
                body: RepaintBoundary(
                    key: const ValueKey('preview'),
                    child: DayCloseListPage(
                        readSource: () async => source,
                        exportController: export,
                        onView: (_, row) => view?.call(row),
                        onOpenShift: (_, success) => opened?.call(),
                        onDayClose: (_, success, draft) =>
                            closed?.call(success, draft)))))));
    await tester.pumpAndSettle();
  }

  HeaderAction action(WidgetTester tester, Key key) => tester
      .widget<PageHeader>(find.byType(PageHeader))
      .actions
      .singleWhere((a) => a.key == key);
  DayCloseListController controller(WidgetTester tester) => tester
      .widgetList<ListenableBuilder>(find.byType(ListenableBuilder))
      .map((w) => w.listenable)
      .whereType<DayCloseListController>()
      .first;

  for (final size in [
    const Size(1440, 900),
    const Size(850, 900),
    const Size(390, 812),
    const Size(390, 350)
  ]) {
    testWidgets('shared layout and controls fit $size', (tester) async {
      final source = FakeDayCloseSource()
        ..fetchPage = (p, _) async => pageData(p, total: 1);
      await mount(tester, source, size: size);
      expect(find.byType(PageHeader), findsOneWidget);
      expect(
          find.byKey(const ValueKey('day-close-open-shift')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-close-submit')), findsOneWidget);
      expect(action(tester, DayCloseListPage.exportKey).onPressed, isNotNull);
      final view = tester.widget<AppSquareIconButton>(
          find.widgetWithIcon(AppSquareIconButton, Icons.visibility_outlined));
      expect(view.foreground, AppColors.primary);
      if (size.width >= 850) {
        final table = tester.widget<AppDataTable<DailySalesCloseData>>(
            find.byType(AppDataTable<DailySalesCloseData>));
        expect(table.fitToContent, isTrue);
        expect(table.minWidth, 1720);
        expect(table.horizontalController, isNotNull);
        final toggle = find.byKey(const ValueKey('day-close-filter-toggle'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('day-close-date')).hitTestable(),
            findsNothing);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('day-close-date')).hitTestable(),
            findsOneWidget);
      } else {
        expect(find.byType(CollapsibleFilterTile), findsOneWidget);
        await tester.tap(find.byKey(PageHeader.moreActionsKey));
        await tester.pumpAndSettle();
        expect(find.text('Export'), findsOneWidget);
        await tester.tap(find.text('Filters').last);
        await tester.pumpAndSettle();
        expect(find.byType(CollapsibleFilterTile).hitTestable(), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('date selection reset pagination and genuine empty result',
      (tester) async {
    final source = FakeDayCloseSource();
    await mount(tester, source);
    await controller(tester).load(page: 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(source.calls.last, (1, null));
    source.fetchPage =
        (p, date) async => date == null ? pageData(p) : pageData(p, total: 0);
    await tester.tap(find.byKey(const ValueKey('day-close-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7').last);
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final selected =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-07';
    expect(source.calls.last, (1, selected));
    expect(find.text('No Daily Sales Closes Found'), findsOneWidget);
    expect(action(tester, DayCloseListPage.exportKey).onPressed, isNull);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(controller(tester).data!.rows.length, 2);
    expect(controller(tester).date, isNull);
  });
  testWidgets(
      'existing callbacks get the selected full row and open draft; success reloads page 1',
      (tester) async {
    final draft = OpenDraftModel(id: 81, shiftName: 'Morning');
    final source = FakeDayCloseSource()
      ..pendingResponse = () async => pendingStatus(draft: draft);
    DailySalesCloseData? selected;
    OpenDraftModel? passedDraft;
    VoidCallback? success;
    var opens = 0;
    await mount(tester, source,
        view: (row) => selected = row,
        opened: () => opens++,
        closed: (callback, open) {
          success = callback;
          passedDraft = open;
        });
    await tester.tap(find.byKey(const ValueKey('day-close-open-shift')));
    expect(opens, 1);
    await tester.tap(find.byKey(const ValueKey('day-close-submit')));
    expect(passedDraft, same(draft));
    await controller(tester).load(page: 2);
    await tester.pumpAndSettle();
    success!();
    await tester.pumpAndSettle();
    expect(source.calls.last, (1, null));
    final table = tester.widget<AppDataTable<DailySalesCloseData>>(
        find.byType(AppDataTable<DailySalesCloseData>));
    table.horizontalController!
        .jumpTo(table.horizontalController!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find
        .widgetWithIcon(AppSquareIconButton, Icons.visibility_outlined)
        .first);
    expect(selected, same(controller(tester).data!.rows.first));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed shift status keeps valid rows/export and disables both mutation buttons until retry',
      (tester) async {
    final source = FakeDayCloseSource()
      ..pendingResponse = () async => throw StateError('offline');
    await mount(tester, source);
    expect(controller(tester).data!.total, 3);
    expect(action(tester, DayCloseListPage.exportKey).onPressed, isNotNull);
    expect(
        tester
            .widget<AppPrimaryButton>(
                find.byKey(const ValueKey('day-close-submit')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<AppOutlinedButton>(
                find.byKey(const ValueKey('day-close-open-shift')))
            .onPressed,
        isNull);
    source.pendingResponse = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(source.calls.length, 1);
    expect(
        tester
            .widget<AppPrimaryButton>(
                find.byKey(const ValueKey('day-close-submit')))
            .onPressed,
        isNotNull);
  });
  testWidgets(
      'filter change while export awaits a source cannot deliver a stale file',
      (tester) async {
    final source = FakeDayCloseSource(), export = CaptureExport();
    await mount(tester, source, export: export);
    action(tester, DayCloseListPage.exportKey).onPressed!();
    await tester.pump();
    await controller(tester).setDate('2026-10-07');
    await tester.pumpAndSettle();
    await expectLater(export.factory!(), throwsStateError);
    expect(source.calls.length, 2);
    export.dispose();
  });
  testWidgets(
      'real export delivers all pages once and preserves the visible page',
      (tester) async {
    await useTempExportDirectory(tester, 'day-close-export-');
    final source = FakeDayCloseSource();
    final delivered = Completer<File>();
    final finishDelivery = Completer<void>();
    var deliveries = 0;
    String? deliveredMime;
    Rect? deliveredOrigin;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) {
      deliveredMime = mimeType;
      deliveredOrigin = shareOrigin;
      deliveries++;
      delivered.complete(file);
      return finishDelivery.future;
    });
    addTearDown(export.dispose);
    await mount(tester, source, export: export);
    await controller(tester).load(page: 2);
    await tester.pumpAndSettle();
    action(tester, DayCloseListPage.exportKey).onPressed!();
    await tester.pump();
    expect(export.busy, isTrue);
    action(tester, DayCloseListPage.exportKey).onPressed!();
    // Pump native callbacks while the encoder and file work finish in real time.
    for (var i = 0; i < 300 && !delivered.isCompleted; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(delivered.isCompleted, isTrue);
    final file = await delivered.future;
    final workbook = await tester
        .runAsync(() async => Excel.decodeBytes(await file.readAsBytes()));
    expect(workbook!.tables['Daily Sales Closes']!.rows.length, 4);
    expect(source.calls, [(1, null), (2, null), (1, null), (2, null)]);
    expect(controller(tester).data!.page, 2);
    expect(deliveries, 1);
    expect(deliveredMime, FileExportService.xlsxMimeType);
    expect(deliveredOrigin, isNotNull);
    finishDelivery.complete();
    await tester.pumpAndSettle();
    expect(export.busy, isFalse);
  });
  for (final locale in ['en', 'ar', 'ml']) {
    testWidgets('localized $locale desktop and mobile render without overflow',
        (tester) async {
      for (final size in [const Size(1440, 900), const Size(390, 812)]) {
        final source = FakeDayCloseSource()
          ..fetchPage = (p, _) async => pageData(p, total: 8, perPage: 20);
        await mount(tester, source, locale: locale, size: size);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('daily_sales_close.'), findsNothing);
        if (Platform.environment['DAY_CLOSE_PREVIEWS']
            case final String folder) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('preview')));
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(folder).create(recursive: true);
            await File('$folder/$locale-${size.width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    });
  }
}
