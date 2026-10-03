import '../../support/expense_fixtures.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_view_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/features/expenses/presentation/pages/expense_list_page.dart';

/// Records the file factory the screen hands to the export instead of
/// creating and delivering the file, so tests can run it directly.
class _CapturingExport extends ExportController {
  Future<File> Function()? createFile;

  @override
  Future<bool> run(BuildContext context,
      {required Future<File> Function() createFile,
      String mimeType = FileExportService.xlsxMimeType,
      String? shareText,
      Rect? shareOrigin}) async {
    this.createFile = createFile;
    return true;
  }
}

class TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final values = <String, String>{};
    void flatten(Map<String, dynamic> data, String prefix) {
      for (final entry in data.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value, key);
        } else {
          values[key] = entry.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': values};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting());
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 7});
    Get.testMode = true;
  });
  tearDown(() => Get.reset());

  Future<ExpenseProvider> mount(WidgetTester tester, Size size,
      {ExportController? export}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put(SideBarController());
    final p = ExpenseProvider();
    p.categoryOptions = [
      {'name': 'Rent'}
    ];
    p.debitAccountOptions = [
      {'name': 'Office'}
    ];
    for (var i = 1; i <= 25; i++) {
      p.addExpense(Expense.fromJson(row(i)));
    }
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ExpenseProvider>.value(value: p),
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider(create: (_) => MasterDataProvider()),
        ],
        child: GetMaterialApp(
            translations: TestTranslations(),
            locale: const Locale('en'),
            home: Scaffold(body: ExpenseListPage(export: export)))));
    await tester.pumpAndSettle();
    return p;
  }

  HeaderAction exportAction(WidgetTester tester) => tester
      .widget<PageHeader>(find.byType(PageHeader))
      .actions
      .singleWhere((a) => a.key == ExpenseListPage.exportKey);

  void mockDocumentsDirectory(WidgetTester tester, Directory dir) {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
  }

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(390, 800),
    const Size(375, 300)
  ]) {
    testWidgets('expense layout fits $size and keeps export and actions',
        (tester) async {
      await mount(tester, size);
      final export = exportAction(tester);
      expect(export.label, 'expense.export_tooltip'.tr);
      expect(export.label, isNot('expense.export_tooltip'));
      expect(export.onPressed, isNotNull);
      // A header button on wide screens, an entry of the "more" menu on
      // phones.
      final collapsed =
          find.byKey(PageHeader.moreActionsKey).evaluate().isNotEmpty;
      expect(find.byKey(ExpenseListPage.exportKey),
          collapsed ? findsNothing : findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('export shows the translated progress label while busy',
      (tester) async {
    final delivered = Completer<void>();
    File? file;
    final export = ExportController(deliver: (context, f,
        {required mimeType, shareText, shareOrigin, onStage}) {
      file = f;
      return delivered.future;
    });
    addTearDown(export.dispose);
    final dir = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('expense-export-')))!;
    addTearDown(() => dir.delete(recursive: true));
    mockDocumentsDirectory(tester, dir);
    await mount(tester, const Size(1440, 900), export: export);
    await tester.tap(find.byKey(ExpenseListPage.exportKey));
    await tester.pump();
    expect(exportAction(tester).busy, isTrue);
    expect(
        exportAction(tester).label, 'supplier_transactions.export_creating'.tr);
    expect(exportAction(tester).label,
        isNot('supplier_transactions.export_creating'));
    // Let the real file write finish, then complete delivery.
    for (var i = 0; i < 100 && file == null; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(file, isNotNull);
    delivered.complete();
    await tester.pump();
    await tester.pump();
    expect(exportAction(tester).busy, isFalse);
    expect(exportAction(tester).label, 'expense.export_tooltip'.tr);
  });
  testWidgets(
      'export includes all filtered pages and flushes pending search without API',
      (tester) async {
    final capture = _CapturingExport();
    addTearDown(capture.dispose);
    final p = await mount(tester, const Size(1440, 900), export: capture);
    p.setPage(2);
    await tester.pump();
    final dir = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('expense-export-')))!;
    addTearDown(() => dir.delete(recursive: true));
    mockDocumentsDirectory(tester, dir);
    Future<File?> export() async {
      await tester.tap(find.byKey(ExpenseListPage.exportKey));
      return tester.runAsync(capture.createFile!);
    }

    var file = await export();
    var rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 26);
    expect(p.currentPage, 2);
    expect(rows[1][0]!.value, isA<TextCellValue>());
    expect(rows[1][5]!.value, const DoubleCellValue(126.125));
    await tester.enterText(find.byType(TextField), '00025');
    await tester.pump(const Duration(milliseconds: 100));
    file = await export();
    rows = Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 2);
    expect(rows[1][0]!.value, TextCellValue('00025'));
    expect(p.filterReference, '00025');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed refresh retains rows and disables export until retry succeeds',
      (tester) async {
    final p = await mount(tester, const Size(1440, 900));
    await load(p, (_) => http.Response('failed', 500));
    await tester.pumpAndSettle();
    expect(p.allFiltered.length, 25);
    expect(exportAction(tester).onPressed, isNull);
    expect(find.text('Retry'), findsOneWidget);
    await load(
        p,
        (_) => response({
              'data': [row(1)]
            }));
    await tester.pumpAndSettle();
    expect(exportAction(tester).onPressed, isNotNull);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('copy writes the reference and restores success feedback',
      (tester) async {
    await mount(tester, const Size(1440, 900));
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byIcon(Icons.copy_outlined).first);
    await tester.pump();
    expect(copied, '00025');
    expect(find.text('Reference number copied to clipboard'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Reference number copied to clipboard'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('create and view routes retain their references', (tester) async {
    await mount(tester, const Size(1440, 900));
    await tester.tap(find.text('New Entry'));
    expect(Get.find<SideBarController>().index.value, 94);
    await tester.tap(find
        .descendant(
            of: find.byType(AppOutlinedButton), matching: find.text('View'))
        .first);
    expect(Get.find<SideBarController>().index.value, 95);
    expect(Get.find<ExpenseViewController>().selectedRef.value, '00025');
  });
  testWidgets('filter toggle hides and restores the filter panel',
      (tester) async {
    await mount(tester, const Size(1440, 900));
    expect(find.byKey(ExpenseListPage.filtersKey), findsOneWidget);
    await tester.tap(find.byKey(ExpenseListPage.filterToggleKey));
    await tester.pump();
    expect(find.byKey(ExpenseListPage.filtersKey), findsNothing);
    await tester.tap(find.byKey(ExpenseListPage.filterToggleKey));
    await tester.pump();
    expect(find.byKey(ExpenseListPage.filtersKey), findsOneWidget);
  });
}
