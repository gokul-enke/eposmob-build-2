import 'dart:convert';
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
import 'package:pos_machine/features/sales_returns/presentation/pages/sales_return_list_page.dart';
import 'package:pos_machine/features/sales_returns/presentation/widgets/sales_return_list_rows.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'support.dart';

class ReturnTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final locale in ['en', 'ar', 'ml'])
          locale: flatten(jsonDecode(
              File('lib/resources/i18n/$locale.json').readAsStringSync()))
      };
  Map<String, String> flatten(Map<String, dynamic> json, [String prefix = '']) {
    final result = <String, String>{};
    for (final e in json.entries) {
      final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
      if (e.value is Map<String, dynamic>) {
        result.addAll(flatten(e.value, key));
      } else {
        result[key] = e.value.toString();
      }
    }
    return result;
  }
}

class ReturnSettings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class CapturingReturnExport extends ExportController {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    final poppins = FontLoader('Poppins');
    for (final suffix in ['Regular', 'Medium', 'SemiBold']) {
      poppins.addFont(rootBundle.load('assets/fonts/Poppins-$suffix.ttf'));
    }
    await poppins.load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final fontRoot = configFile.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(File.fromUri(fontRoot.resolve(entry.value))
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

  Future<void> mount(WidgetTester tester, ReturnSource source,
      {Size size = const Size(1440, 900),
      String locale = 'en',
      ExportController? export}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => ReturnSettings(),
        child: GetMaterialApp(
            locale: Locale(locale),
            translations: ReturnTranslations(),
            home: Scaffold(
                body: RepaintBoundary(
                    key: const ValueKey('preview'),
                    child: SalesReturnListPage(
                        readSource: () async => source,
                        exportController: export))))));
    await tester.pumpAndSettle();
  }

  HeaderAction action(WidgetTester tester, Key key) => tester
      .widget<PageHeader>(find.byType(PageHeader))
      .actions
      .singleWhere((a) => a.key == key);

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(375, 812),
    const Size(375, 300)
  ]) {
    testWidgets('shared list fits $size with export and row actions',
        (tester) async {
      await mount(tester, ReturnSource((_) async => returnData([returnRow(1)])),
          size: size);
      expect(find.text('000123'), findsOneWidget);
      expect(
          action(tester, SalesReturnListPage.exportKey).onPressed, isNotNull);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.print_outlined), findsOneWidget);
      expect(find.text('1.25'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      if (size.width == 800) {
        final table = tester.widget<AppDataTable>(
            find.byWidgetPredicate((w) => w is AppDataTable));
        expect(table.horizontalController!.position.maxScrollExtent,
            greaterThan(0));
      }
      if (Platform.environment['RETURN_CAPTURE'] != null && size.height > 300) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')));
          final picture = await boundary.toImage();
          final bytes =
              await picture.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/sales-return-previews');
          await dir.create(recursive: true);
          await File('${dir.path}/list-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
    });
  }
  for (final locale in ['ar', 'ml']) {
    testWidgets('localized list fits $locale without missing labels',
        (tester) async {
      await mount(tester, ReturnSource((_) async => returnData([returnRow(1)])),
          locale: locale, size: const Size(800, 900));
      expect(tester.takeException(), isNull);
      expect(find.text('sales_return.title'), findsNothing);
      expect(action(tester, SalesReturnListPage.exportKey).label,
          isNot('sales_return.list_export'));
    });
  }
  testWidgets(
      'failed pagination retains rows, blocks export, and Retry requests the failed page',
      (tester) async {
    var fail = true;
    final source = ReturnSource((p) async {
      if (p == 2 && fail) throw StateError('offline');
      return returnData([
        returnRow(p)..['order'] = {'order_number': 'ORD-$p'}
      ], page: p, perPage: 1, total: 2);
    });
    await mount(tester, source);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('ORD-1'), findsOneWidget);
    expect(action(tester, SalesReturnListPage.exportKey).onPressed, isNull);
    expect(
        tester.widget<AppPaginationBar>(find.byType(AppPaginationBar)).enabled,
        isFalse);
    fail = false;
    await tester.tap(find.text('restaurant.retry'.tr));
    await tester.pumpAndSettle();
    expect(find.text('ORD-2'), findsOneWidget);
    expect(source.calls, [1, 2, 2]);
    expect(action(tester, SalesReturnListPage.exportKey).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('initial failure offers Retry; empty success disables export',
      (tester) async {
    var fail = true;
    final source = ReturnSource((_) async {
      if (fail) throw StateError('offline');
      return returnData([]);
    });
    await mount(tester, source);
    expect(find.text('sales_return.err_load'.tr), findsOneWidget);
    fail = false;
    await tester.tap(find.text('restaurant.retry'.tr));
    await tester.pumpAndSettle();
    expect(find.text('sales_return.no_returns_found'.tr), findsOneWidget);
    expect(action(tester, SalesReturnListPage.exportKey).onPressed, isNull);
  });
  testWidgets('mobile shared header exposes Export in its action menu',
      (tester) async {
    await mount(tester, ReturnSource((_) async => returnData([returnRow(1)])),
        size: const Size(375, 812));
    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    expect(find.text('sales_return.list_export'.tr), findsOneWidget);
  });
  testWidgets('copy preserves receipt number including leading zeroes',
      (tester) async {
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
    await mount(tester, ReturnSource((_) async => returnData([returnRow(1)])));
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();
    expect(copied, '000123');
  });
  testWidgets(
      'Export builds all pages with typed cells and leaves the visible page unchanged',
      (tester) async {
    final source = ReturnSource((p) async => returnData([
          returnRow(p)
            ..['order'] = {'order_number': 'ORD-$p', 'receipt_number': '000$p'}
        ], page: p, perPage: 1, total: 2));
    final export = CapturingReturnExport();
    addTearDown(export.dispose);
    await mount(tester, source, export: export);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    action(tester, SalesReturnListPage.exportKey).onPressed!();
    await tester.pump();
    final dir = Directory.systemTemp.createTempSync('sales-return-test-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final file = await tester.runAsync(() => export.factory!());
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 3);
    expect(rows[1][0]!.value, isA<TextCellValue>());
    expect(rows[1][2]!.value.toString(), '0001');
    expect(rows[1][3]!.value, const DoubleCellValue(1.25));
    expect(rows[1][4]!.value, const DoubleCellValue(12.5));
    expect(source.calls, [1, 2, 1, 2]);
    expect(find.text('0002'), findsOneWidget);
    expect(
        tester
            .widget<AppPaginationBar>(find.byType(AppPaginationBar))
            .currentPage,
        2);
  });
  testWidgets('row actions pass the same transaction to existing handlers',
      (tester) async {
    final row = returnData([returnRow(1)]).rows.single;
    Object? viewed, printed;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: salesReturnListActions(row,
                onView: (r) => viewed = r, onPrint: (r) => printed = r))));
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.tap(find.byIcon(Icons.print_outlined));
    expect(viewed, same(row));
    expect(printed, same(row));
  });
}
