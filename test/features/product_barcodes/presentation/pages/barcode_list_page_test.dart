import 'dart:io';
import 'dart:convert';
import 'package:pos_machine/resources/app_translations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/features/product_barcodes/presentation/pages/barcode_list_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_support/hive_test_teardown.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/product_barcodes/presentation/models/barcode_row.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/screens/product/widgets/confirm_barcode_print_modal.dart';
import 'package:pos_machine/screens/product/widgets/product_barcode_responsive.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:excel/excel.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../test_support/app_translations.dart';

class _FakeAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class _FakeCategoryProvider extends CategoryProvider {
  _FakeCategoryProvider() {
    categoryList = [
      Category(categoryId: 1, categoryName: 'Food'),
      Category(categoryId: 2, categoryName: 'Other')
    ];
  }
  @override
  bool get isCategoriesLoaded => true;

  @override
  Future<void> ensureCategoriesLoaded() async {}
}

class _FakeStockProvider extends StockProvider {
  @override
  Future<void> loadAllStocks(String accessToken) async {}
}

class _FakePurchaseProvider extends PurchaseProvider {
  @override
  Future<void> listAllStores(String accessToken, String? storeName) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    Get.testMode = true;
    hiveDir = await Directory.systemTemp.createTemp('product_filter_screens_');
    Hive.init(hiveDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveStringValueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveLocalCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveSavedOrderAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveProductAdapter());
    }

    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'api_key': 'test-api-key',
      'general_stock_enabled': true,
    });
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(() async {
    Get.reset();
    await awaitPendingHiveBoxWrites();
  });
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  Widget wrapScreen(
    Widget screen, {
    LocalProductProvider? localProductProvider,
    double? contentWidth,
    Locale locale = const Locale('en'),
  }) {
    final auth = AuthModel()..login('test-token', 1);
    final content = contentWidth == null
        ? screen
        : Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: contentWidth, child: screen),
          );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>.value(value: auth),
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => _FakeAppSettingsProvider(),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => _FakeCategoryProvider(),
        ),
        ChangeNotifierProvider<LocalProductProvider>.value(
          value: localProductProvider ?? LocalProductProvider(),
        ),
        ChangeNotifierProvider<StockProvider>(
          create: (_) => _FakeStockProvider(),
        ),
        ChangeNotifierProvider<PurchaseProvider>(
          create: (_) => _FakePurchaseProvider(),
        ),
        ChangeNotifierProvider<RoleProvider>(create: (_) => RoleProvider()),
      ],
      child: GetMaterialApp(
        translations: locale.languageCode == 'en'
            ? EnglishTranslations()
            : AppTranslations({
                locale.languageCode: {
                  for (final section in [
                    'product_barcode',
                    'pagination',
                    'general'
                  ])
                    for (final entry in (jsonDecode(
                            File('lib/resources/i18n/${locale.languageCode}.json')
                                .readAsStringSync())[section] as Map<String,
                            dynamic>)
                        .entries)
                      '$section.${entry.key}': entry.value.toString(),
                }
              }),
        locale: locale,
        home: Scaffold(body: content),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    LocalProductProvider? localProductProvider,
    double? contentWidth,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapScreen(
        screen,
        localProductProvider: localProductProvider,
        contentWidth: contentWidth,
        locale: locale,
      ),
    );
    await tester.pump();
  }

  List<GetProduct> catalogue({int count = 45}) => List.generate(
      count,
      (i) => GetProduct(
          productId: i + 1,
          productName: 'Product $i',
          barcode: '000${i.toString().padLeft(3, '0')}',
          categoryId: i.isEven ? 1 : 2,
          category: ProductCategory(name: i.isEven ? 'Food' : 'Other'),
          numberOfProductsAvailable: '1.250',
          price: ProductPrice(price: '6.000'),
          mrp: '8.000',
          sku: '00$i'));

  testWidgets(
      'filters apply existing provider logic, Reset cancels edit, page selection persists',
      (tester) async {
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(tester, const BarcodeListPage(),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('20 selected'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    expect(find.text(provider.allFilteredProducts[20].productName!),
        findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Product 4');
    await tester.pump(const Duration(milliseconds: 400));
    expect(provider.allFilteredProducts.length, 6);
    expect(find.text('20 selected'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'pending');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(provider.allFilteredProducts.length, 45);
    expect(find.text('20 selected'), findsNothing);
    await tester.tap(find.byType(DropdownSearch<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(provider.allFilteredProducts.length, 23);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'abandoned category search cannot change the displayed selection or filter',
      (tester) async {
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(tester, const BarcodeListPage(),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownSearch<int>));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Other');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
        tester
            .state<DropdownSearchState<int>>(find.byType(DropdownSearch<int>))
            .getSelectedItem,
        0);
    expect(provider.allFilteredProducts.length, 45);
    await tester.tap(find.byType(DropdownSearch<int>));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsWidgets);
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Export flushes pending filter, keeps selection, and delivers frozen all-page workbook',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('barcode-export-sequence-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final delivery = Completer<void>();
    File? delivered;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered = file;
      await delivery.future;
    });
    addTearDown(export.dispose);
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(
        tester, BarcodeListPage(exportController: export, exportDirectory: dir),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Product');
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.ios_share_rounded));
      for (var i = 0; i < 100 && delivered == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(export.busy, isTrue);
    expect(find.text('20 selected'), findsOneWidget);
    expect(delivered, isNotNull);
    final workbook = Excel.decodeBytes(delivered!.readAsBytesSync());
    final rows = workbook.tables.values.single.rows;
    expect(rows.length, 46);
    expect(rows[1][2]!.value, TextCellValue('000000'));
    expect(rows[1][4]!.value, const DoubleCellValue(1.25));
    expect(rows.last[1]!.value,
        TextCellValue(provider.allFilteredProducts.last.productName!));
    // Reset and catalogue mutations do not rewrite the workbook being delivered.
    await tester.tap(find.text('Reset'));
    await tester.pump();
    provider.initializeProducts(
        [GetProduct(productId: 99, productName: 'Changed', barcode: 'NEW')]);
    delivery.complete();
    await tester.pumpAndSettle();
    expect(export.busy, isFalse);
    expect(
        Excel.decodeBytes(delivered!.readAsBytesSync())
            .tables
            .values
            .single
            .rows
            .length,
        46);
    await tester.pumpWidget(const SizedBox());
    export.setStage('caller still owns export');
  });

  testWidgets(
      'View and print confirmation use unchanged sale-unit print product',
      (tester) async {
    final product = GetProduct(
        productId: 1,
        productName: 'Rice',
        barcode: 'BASE',
        price: ProductPrice(price: '6.000'),
        mrp: '8.000',
        saleUnits: [
          SaleUnit(id: 1, unitName: 'BOX', barcode: 'UNIT', price: 24)
        ]);
    final provider = LocalProductProvider()..initializeProducts([product]);
    await pumpScreen(tester, const BarcodeListPage(),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'UNIT');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Rice (BOX)'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.print_outlined));
    await tester.pumpAndSettle();
    final modal = tester.widget<ConfirmBarcodePrintModal>(
        find.byType(ConfirmBarcodePrintModal));
    expect(modal.selectedProducts.single.productName, 'Rice (BOX)');
    expect(modal.selectedProducts.single.barcode, 'UNIT');
    expect(modal.selectedProducts.single.price!.price, 24.0);
    Navigator.of(tester.element(find.byType(ConfirmBarcodePrintModal))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing-barcode single and bulk printing use the existing guard',
      (tester) async {
    final provider = LocalProductProvider()
      ..initializeProducts([GetProduct(productId: 1, productName: 'Missing')]);
    await pumpScreen(tester, const BarcodeListPage(),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.print_outlined));
    await tester.pumpAndSettle();
    expect(find.text("This product doesn't have a barcode."), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text("These products don't have a barcode."), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets(
      'populated shared layouts, selection and null-value labels at phone/tablet/desktop widths',
      (tester) async {
    for (final width in [375.0, 650.0, 768.0, 1280.0]) {
      final provider = LocalProductProvider()
        ..initializeProducts([
          GetProduct(productId: 1, productName: 'No values', barcode: '00001')
        ]);
      await pumpScreen(tester, const BarcodeListPage(),
          size: Size(width, 900), localProductProvider: provider);
      await tester.pumpAndSettle();
      expect(find.byType(ListPageScaffold<BarcodeRow>), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      if (width < 720) {
        expect(find.text('Qty'), findsOneWidget);
        expect(find.text('Price'), findsOneWidget);
        expect(find.text('SKU'), findsOneWidget);
      }
      expect(find.text('1 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'local edits with unchanged filter version update the visible barcode rows',
      (tester) async {
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(tester, const BarcodeListPage(),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    final version = provider.filteredProductsVersion;
    final rows = provider.allFilteredProducts.toList();
    rows[0] = rows[0]
        .copyWith(productName: 'Edited catalogue row', barcode: '000EDIT');
    provider.updateFilteredProducts(rows);
    await tester.pump();
    expect(provider.filteredProductsVersion, version);
    expect(find.text('Edited catalogue row'), findsOneWidget);
    expect(find.text('000EDIT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'catalogue sync hides rows and blocks captured print/export callbacks',
      (tester) async {
    var deliveries = 0;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      deliveries++;
    });
    addTearDown(export.dispose);
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(tester, BarcodeListPage(exportController: export),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    final printBulk = tester
        .widget<AppPrimaryButton>(find.byType(AppPrimaryButton))
        .onPressed!;
    final printSingle = tester
        .widget<AppSquareIconButton>(find
            .ancestor(
                of: find.byIcon(Icons.print_outlined).first,
                matching: find.byType(AppSquareIconButton))
            .first)
        .onPressed!;
    final exportRows = tester
        .widget<PageHeader>(find.byType(PageHeader))
        .actions
        .singleWhere((action) => action.icon == Icons.ios_share_rounded)
        .onPressed!;
    final version = provider.filteredProductsVersion;
    provider.isLoading = true;
    provider.updateFilteredProducts(provider.allFilteredProducts);
    await tester.pump();
    expect(provider.filteredProductsVersion, version);
    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.byIcon(Icons.print_outlined), findsNothing);
    expect(
        tester
            .widget<AppPrimaryButton>(find.byType(AppPrimaryButton))
            .onPressed,
        isNull);
    expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged, isNull);
    expect(
        tester
            .widget<PageHeader>(find.byType(PageHeader))
            .actions
            .singleWhere((action) => action.icon == Icons.ios_share_rounded)
            .onPressed,
        isNull);
    printSingle();
    printBulk();
    exportRows();
    await tester.pump();
    expect(find.byType(ConfirmBarcodePrintModal), findsNothing);
    expect(export.busy, isFalse);
    expect(deliveries, 0);
    provider.initializeProducts([
      GetProduct(productId: 100, productName: 'Synced product', barcode: 'NEW')
    ]);
    await tester.pump();
    expect(find.byType(AppLoadingView), findsOneWidget);
    provider.isLoading = false;
    provider.updateFilteredProducts(provider.allFilteredProducts);
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadingView), findsNothing);
    expect(find.text('Synced product'), findsOneWidget);
    expect(
        tester
            .widget<AppPrimaryButton>(find.byType(AppPrimaryButton))
            .onPressed,
        isNotNull);
    expect(find.text('20 selected'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.print_outlined));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ConfirmBarcodePrintModal), findsOneWidget);
    final modal = tester.widget<ConfirmBarcodePrintModal>(
        find.byType(ConfirmBarcodePrintModal));
    provider.isLoading = true;
    provider.updateFilteredProducts(provider.allFilteredProducts);
    Navigator.of(tester.element(find.byType(ConfirmBarcodePrintModal))).pop(
        BarcodePrintRequest(
            items: [BarcodePrintItem(product: modal.selectedProducts.single)],
            stickerSize: '50x25',
            stickersPerRow: 1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ConfirmBarcodePrintModal), findsNothing);
    expect(tester.widget<AppPrimaryButton>(find.byType(AppPrimaryButton)).busy,
        isFalse);
    provider.isLoading = false;
    provider.updateFilteredProducts(provider.allFilteredProducts);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'local replacement cannot bypass active category or product-name filters',
      (tester) async {
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(tester, const BarcodeListPage(),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownSearch<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    provider.updateFilteredProducts([
      ...provider.allFilteredProducts,
      GetProduct(
          productId: 100,
          categoryId: 2,
          productName: 'Wrong category',
          barcode: 'WRONG')
    ]);
    await tester.pump();
    expect(find.text('Wrong category'), findsNothing);
    expect(find.text('20 barcode rows on this page'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Product 0');
    await tester.pump(const Duration(milliseconds: 400));
    final rows = provider.allFilteredProducts.toList();
    rows[0] = rows[0].copyWith(productName: 'Renamed nonmatching row');
    provider.updateFilteredProducts(rows);
    await tester.pump();
    expect(find.text('No products found'), findsOneWidget);
    expect(find.text('Renamed nonmatching row'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Arabic and Malayalam selection, filters and mobile actions do not overflow',
      (tester) async {
    for (final language in ['ar', 'ml']) {
      final provider = LocalProductProvider()..initializeProducts(catalogue());
      await pumpScreen(tester, const BarcodeListPage(),
          size: const Size(375, 812),
          localProductProvider: provider,
          locale: Locale(language));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AppPrimaryButton), findsOneWidget);
      expect(find.byType(AppOutlinedButton), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets(
      'empty exports and delivery failure use shared feedback without changing selection',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('barcode-export-failure-');
    addTearDown(() => dir.deleteSync(recursive: true));
    var attempts = 0;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      attempts++;
      throw StateError('Save As failed');
    });
    addTearDown(export.dispose);
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(
        tester, BarcodeListPage(exportController: export, exportDirectory: dir),
        size: const Size(1280, 900), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.ios_share_rounded));
      for (var i = 0; i < 100 && (attempts == 0 || export.busy); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(export.busy, isFalse);
    expect(attempts, 1);
    expect(find.text('Unable to export the list. Please try again.'),
        findsOneWidget);
    expect(find.text('20 selected'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'No match');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pump();
    expect(attempts, 1);
    expect(export.busy, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'phone detail dialog retains the original responsive chips and scrollable contents',
      (tester) async {
    final provider = LocalProductProvider()..initializeProducts(catalogue());
    await pumpScreen(tester, const BarcodeListPage(),
        size: const Size(375, 812), localProductProvider: provider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductBarcodeInfoChip), findsWidgets);
    expect(find.text('Stock Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('barcode preview capture', (tester) async {
    final poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    await poppins.load();
    final roboto = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf'
    ]) {
      roboto.addFont(Future.value(ByteData.sublistView(File(
              '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/$name')
          .readAsBytesSync())));
    }
    await roboto.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/materialicons-regular.otf')
          .readAsBytesSync())));
    await icons.load();
    for (final width in [375.0, 768.0, 1280.0]) {
      final provider = LocalProductProvider()..initializeProducts(catalogue());
      final key = GlobalKey();
      await pumpScreen(
          tester, RepaintBoundary(key: key, child: const BarcodeListPage()),
          size: Size(width, 900), localProductProvider: provider);
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir =
            Directory('${Directory.systemTemp.path}/barcode-list-previews');
        await dir.create(recursive: true);
        await File('${dir.path}/after-${width.toInt()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: Platform.environment['BARCODE_LIST_PREVIEW'] != '1');
}
