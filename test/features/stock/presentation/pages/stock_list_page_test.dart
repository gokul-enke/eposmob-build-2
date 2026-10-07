import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' show Excel;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import 'package:pos_machine/features/stock/presentation/pages/stock_list_page.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';

class TestStockProvider extends StockProvider {
  bool fails = false;
  @override
  Future<void> loadAllStocks(String token) async {
    if (fails) throw StateError('offline');
  }
}

class TestPurchaseProvider extends PurchaseProvider {
  @override
  Future<void> listAllStores(String token, String? name) async {}
}

class TestSettings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class TestCategories extends CategoryProvider {
  @override
  bool get isCategoriesLoaded => true;
  @override
  Future<void> ensureCategoriesLoaded() async {}
}

class TestRole extends RoleProvider {
  TestRole(this.allowed);
  final bool allowed;
  @override
  bool currentUserHasPermissionSync(String code) => allowed;
}

class StockTranslations extends Translations {
  StockTranslations([this.language = 'en']);
  final String language;
  @override
  Map<String, Map<String, String>> get keys {
    final result = <String, String>{};
    void flatten(Map<String, dynamic> map, String prefix) {
      map.forEach((key, value) {
        final path = prefix.isEmpty ? key : '$prefix.$key';
        if (value is Map<String, dynamic>) {
          flatten(value, path);
        } else {
          result[path] = value.toString();
        }
      });
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/$language.json').readAsStringSync())
            as Map<String, dynamic>,
        '');
    return {language == 'en' ? 'en_US' : language: result};
  }
}

ListStockModelData row(int index) => ListStockModelData(
    stockId: index + 1,
    productName: 'Stock item $index',
    categoryName: 'Produce',
    storeName: 'Main',
    barCode: '12345$index',
    retailPrice: '10.00',
    mrp: '12.00',
    purchaseRate: '7.00',
    qty: 2,
    unit: 'PC',
    rack: 'A',
    orderDate: '2026-10-01',
    stockStatus: 'Low Stock');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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
          .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'test-key'});
  });
  tearDown(() {
    Get.reset();
  });
  Future<TestStockProvider> mount(WidgetTester tester, double width,
      {int count = 3,
      String language = 'en',
      ExportController? export,
      bool costPermission = true}) async {
    tester.view.physicalSize = Size(width, width == 375 ? 812 : 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = TestStockProvider()
      ..applyRealtimeStocks(List.generate(count, row));
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('token', 1)),
          ChangeNotifierProvider<StockProvider>.value(value: provider),
          ChangeNotifierProvider<PurchaseProvider>(
              create: (_) => TestPurchaseProvider()),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => TestSettings()),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => TestCategories()),
          ChangeNotifierProvider<RoleProvider>(
              create: (_) => TestRole(costPermission)),
        ],
        child: GetMaterialApp(
            translations: StockTranslations(language),
            locale:
                language == 'en' ? const Locale('en', 'US') : Locale(language),
            home: Scaffold(
                body: RepaintBoundary(
                    key: const ValueKey('preview'),
                    child: StockListPage(exportController: export))))));
    await tester.pumpAndSettle();
    return provider;
  }

  for (final allowed in [false, true]) {
    testWidgets(
        'export freezes all pages and respects cost permission $allowed',
        (tester) async {
      await useTempExportDirectory(tester, 'stock-page-export-');
      final export = CapturingExport();
      addTearDown(export.dispose);
      final provider = await mount(tester, 1440,
          count: 45, export: export, costPermission: allowed);
      provider.goToStockPage(2);
      await tester.pump();
      final table = tester.widget<AppDataTable<ListStockModelData>>(
          find.byType(AppDataTable<ListStockModelData>));
      expect(table.columns.any((c) => c.label == 'Purchase Price'), allowed);
      expect(table.horizontalController, isNotNull);
      await tester.tap(find.byKey(StockListPage.exportKey));
      await tester.pump();
      expect(export.runs, 1);
      expect(provider.stockCurrentPage, 2);
      provider.applyRealtimeStocks([row(99)]);
      final file = await tester.runAsync(export.createFile!);
      final book =
          Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single;
      expect(book.rows, hasLength(46));
      expect(
          book.rows.first.any((c) => c?.value.toString() == 'Purchase Price'),
          allowed);
      expect(book.rows.last.first?.value.toString(), '45');
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      // A caller-owned export controller remains usable after leaving the page.
      export.setStage('still owned by caller');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'pending text is flushed before Export, not before an old Next page',
      (tester) async {
    await useTempExportDirectory(tester, 'stock-pending-export-');
    final export = CapturingExport();
    addTearDown(export.dispose);
    final provider = await mount(tester, 1440, count: 45, export: export);
    final next = find.byIcon(Icons.chevron_right_rounded);
    await tester.enterText(find.byType(TextField).first, 'Stock item 2');
    await tester.tap(next);
    await tester.pump();
    expect(provider.stockCurrentPage, 1);
    expect(provider.stockFilterName, 'Stock item 2');
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Stock item 44');
    await tester.tap(find.byKey(StockListPage.exportKey));
    await tester.pump();
    final file = await tester.runAsync(export.createFile!);
    final book =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single;
    expect(book.rows, hasLength(2));
    expect(book.rows[1][1]?.value.toString(), 'Stock item 44');
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  testWidgets('undone text edits preserve the Export page and allow Next',
      (tester) async {
    final export = CapturingExport();
    addTearDown(export.dispose);
    final provider = await mount(tester, 1440, count: 65, export: export);
    provider.goToStockPage(2);
    await tester.pump();
    final input = find.byType(TextField).first;
    await tester.enterText(input, 'Stock');
    await tester.enterText(input, '');
    await tester.tap(find.byKey(StockListPage.exportKey));
    await tester.pump();
    expect(export.runs, 1);
    expect(provider.stockCurrentPage, 2);
    await tester.pump(const Duration(milliseconds: 350));
    expect(provider.stockCurrentPage, 2);
    await tester.enterText(input, 'Stock');
    await tester.enterText(input, '');
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    expect(provider.stockCurrentPage, 3);
    await tester.pump(const Duration(milliseconds: 350));
    expect(provider.stockCurrentPage, 3);
    // The normal timer also ignores edits undone without another action.
    await tester.enterText(input, 'Stock');
    await tester.enterText(input, '');
    await tester.pump(const Duration(milliseconds: 350));
    expect(provider.stockCurrentPage, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    expect(tester.takeException(), isNull);
  });
  for (final language in ['en', 'ar', 'ml']) {
    testWidgets('missing mobile retail price uses the $language fallback',
        (tester) async {
      final provider = await mount(tester, 375, language: language);
      provider.applyRealtimeStocks([
        ListStockModelData(stockId: 1, productName: 'Missing price', qty: 0),
      ]);
      await tester.pumpAndSettle();
      final retail = tester
          .widgetList<AppMetric>(find.byType(AppMetric))
          .singleWhere((metric) => metric.label == 'stock.retail_price'.tr);
      expect(retail.value, 'stock.na'.tr);
      expect(retail.value, isNot('null'));
      expect(retail.value, isNot('stock.na'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  }
  testWidgets(
      'store popup search can be abandoned without changing the filter; Reset clears it',
      (tester) async {
    final provider = await mount(tester, 1440);
    final picker = find.byKey(const ValueKey('stock-picker-All Stores'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main').last);
    await tester.pumpAndSettle();
    expect(provider.stockFilterStore, 'Main');
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final search = find.byType(TextField).last;
    await tester.enterText(search, 'does not exist');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(provider.stockFilterStore, 'Main');
    expect(tester.state<DropdownSearchState<String>>(picker).getSelectedItem,
        'Main');
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(provider.stockFilterStore, isNull);
    expect(tester.state<DropdownSearchState<String>>(picker).getSelectedItem,
        'All Stores');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  testWidgets(
      'failed refresh retains rows but blocks export until a successful retry',
      (tester) async {
    final export = CapturingExport();
    addTearDown(export.dispose);
    final provider = await mount(tester, 1440, export: export);
    await tester.enterText(find.byType(TextField).first, 'Stock item 1');
    await tester.pump(const Duration(milliseconds: 300));
    provider.fails = true;
    await tester.tap(find.byKey(StockListPage.refreshKey));
    await tester.pumpAndSettle();
    expect(find.text('Stock item 1'), findsNWidgets(2));
    var button =
        tester.widget<AppSquareIconButton>(find.byKey(StockListPage.exportKey));
    expect(button.onPressed, isNull);
    provider.fails = false;
    await tester.tap(find.byKey(StockListPage.refreshKey));
    await tester.pumpAndSettle();
    expect(provider.stockFilterName, 'Stock item 1');
    button =
        tester.widget<AppSquareIconButton>(find.byKey(StockListPage.exportKey));
    expect(button.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  testWidgets('phone shared action menu exposes Export and filters',
      (tester) async {
    final provider = await mount(tester, 375);
    expect(find.byKey(StockListPage.exportKey), findsNothing);
    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    expect(find.text('Export to Excel'), findsOneWidget);
    await tester.tapAt(const Offset(10, 150));
    await tester.pumpAndSettle();
    await tapFilterToggle(tester, key: StockListPage.filterToggleKey);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  testWidgets(
      'closing a searchable popup with Back then leaving disposes its inputs',
      (tester) async {
    final provider = await mount(tester, 1440);
    await tester.tap(find.byKey(const ValueKey('stock-picker-All Stores')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'typed');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    provider.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'horizontal scrolling exposes stock actions; clipboard preserves zeroes',
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
    final provider = await mount(tester, 1280);
    provider.applyRealtimeStocks([row(0).copyWith(barCode: '0000123')]);
    await tester.pump();
    await tester.tap(find.byTooltip('Copy barcode'));
    await tester.pumpAndSettle();
    expect(copied, '0000123');
    final table = tester.widget<AppDataTable<ListStockModelData>>(
        find.byType(AppDataTable<ListStockModelData>));
    table.horizontalController!
        .jumpTo(table.horizontalController!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('View')).dx, lessThan(1280));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Adjust Stock'), findsOneWidget);
    expect(find.text('Move Stock'), findsOneWidget);
    expect(find.text('Withdraw Stock'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(provider.stockCurrentPage, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    expect(tester.takeException(), isNull);
  });
  for (final language in ['ar', 'ml']) {
    for (final width in [375.0, 1280.0]) {
      testWidgets('localized stock layout $language at $width stays usable',
          (tester) async {
        final provider = await mount(tester, width, language: language);
        expect(tester.takeException(), isNull);
        final header = tester.widget<PageHeader>(find.byType(PageHeader));
        expect(header.title, isNot('stock.title'));
        expect(header.actions[1].label, isNot('stock.list_export'));
        if (language == 'ar') {
          expect(Directionality.of(tester.element(find.byType(PageHeader))),
              TextDirection.rtl);
        }
        await tapFilterToggle(tester, key: StockListPage.filterToggleKey);
        if (width == 375) {
          await tester.tap(find.byType(ExpansionTile));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
      });
    }
  }
  for (final width in [375.0, 768.0, 1280.0, 1440.0]) {
    testWidgets('populated stock list retains layout and actions at $width',
        (tester) async {
      final provider = await mount(tester, width);
      expect(find.text('Stock item 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final tag = Platform.environment['STOCK_CAPTURE_TAG'];
      if (tag != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')));
          final bitmap = await boundary.toImage(pixelRatio: 1);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final folder =
              Directory('${Directory.systemTemp.path}/stock-list-previews')
                ..createSync(recursive: true);
          File('${folder.path}/$tag-${width.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      provider.dispose();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'search, reset, page and realtime update keep existing provider semantics',
      (tester) async {
    final provider = await mount(tester, 1440, count: 25);
    expect(provider.stockTotalPages, 2);
    await tester.enterText(find.byType(TextField).first, 'Stock item 24');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stock item 24'), findsNWidgets(2));
    expect(provider.stockTotalPages, 1);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(provider.stockTotalPages, 2);
    provider.goToStockPage(2);
    await tester.pump();
    expect(find.text('Stock item 24'), findsOneWidget);
    provider.applyRealtimeStocks([row(99)]);
    await tester.pump();
    expect(find.text('Stock item 99'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}
