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
import 'package:pos_machine/features/stock/presentation/pages/stock_list_page.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';

class TestStockProvider extends StockProvider {
  @override
  Future<void> loadAllStocks(String token) async {}
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
  @override
  bool currentUserHasPermissionSync(String code) => true;
}

class StockTranslations extends Translations {
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
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>,
        '');
    return {'en_US': result};
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
      {int count = 3}) async {
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
          ChangeNotifierProvider<RoleProvider>(create: (_) => TestRole()),
        ],
        child: GetMaterialApp(
            translations: StockTranslations(),
            locale: const Locale('en', 'US'),
            home: const Scaffold(
                body: RepaintBoundary(
                    key: ValueKey('preview'), child: StockListPage())))));
    await tester.pumpAndSettle();
    return provider;
  }

  for (final width in [375.0, 1280.0, 1440.0]) {
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
    await tester.pump();
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
