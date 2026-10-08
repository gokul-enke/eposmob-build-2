import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/sales/data/sales_list_repository.dart';
import 'package:pos_machine/features/sales/domain/sales_list_query.dart';
import 'package:pos_machine/features/sales/presentation/pages/sales_list_page.dart';
import 'package:pos_machine/features/sales/presentation/widgets/sales_list_filters.dart';
import 'package:pos_machine/features/sales/presentation/export/sales_list_excel.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_translations.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:pos_machine/features/sales/presentation/widgets/actions/cancel_order_modal.dart';

class ActionSalesProvider extends SalesProvider {
  String? cancelledId;
  @override
  Future<void> cancelOrder(
      {required String accessToken,
      required String orderId,
      String? paymentMethod,
      String? refundAmount,
      bool? deliveryChargeRefundable}) async {
    cancelledId = orderId;
    expect(paymentMethod, isNull);
    expect(refundAmount, isNull);
  }
}

class PageSource implements SalesListSource {
  final queries = <SalesListQuery>[];
  final pages = <int>[];
  SalesListQuery? exported;
  bool fail = false;
  bool unpaidCod = false;
  Object? exportFailure;
  @override
  Future<SalesListPageData> fetch(
      String token, SalesListQuery query, int page) async {
    queries.add(query);
    pages.add(page);
    if (fail) throw StateError('offline');
    return SalesListPageData(rows: [
      ListOrderModelData(
          id: page,
          orderNumber: 'ORD-000$page',
          receiptNumber: '00000$page',
          orderDate: DateTime(2026, 10, 8),
          grantTotal: '10.25',
          status: query.status == 'all' ? 'confirmed' : query.status,
          paymentStatus: unpaidCod ? 'pending' : 'paid',
          paymentMethods: unpaidCod ? ['COD'] : ['CASH'],
          customerName: 'Customer')
    ], current: page, last: 3, from: (page - 1) * 10 + 1, perPage: 10);
  }

  @override
  Future<List<ListOrderModelData>> snapshot(String token, SalesListQuery query,
      {void Function(int, int)? progress}) async {
    exported = query;
    if (exportFailure != null) throw exportFailure!;
    progress?.call(1, 3);
    return [
      ListOrderModelData(
          id: 1,
          orderNumber: 'ORD-001',
          receiptNumber: '00001',
          grantTotal: '10.25')
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    await LocalizationService.init();
    await initializeDateFormatting();
    if (const bool.fromEnvironment('SALES_PREVIEW')) {
      final font = FontLoader('SalesPreview')
        ..addFont(File('C:/Windows/Fonts/segoeui.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(File(
                'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await icons.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(WidgetTester tester, PageSource source,
      {double width = 1280,
      bool isOnlineSales = false,
      ValueNotifier<bool>? mode,
      String locale = 'en',
      AuthModel? auth,
      SalesProvider? sales,
      ExportController? exporter,
      Future<File> Function(List<ListOrderModelData>)? create}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>.value(value: auth ?? AuthModel()),
          ChangeNotifierProvider<SalesProvider>.value(
              value: sales ?? SalesProvider()),
          ChangeNotifierProvider(create: (_) => StoreSessionProvider()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ],
        child: GetMaterialApp(
            translations: AppTranslations(LocalizationService.translations),
            locale: Locale(locale),
            theme: ThemeData(
                fontFamily: const bool.fromEnvironment('SALES_PREVIEW')
                    ? 'SalesPreview'
                    : null),
            home: Scaffold(
                body: RepaintBoundary(
                    key: const ValueKey('sales-preview'),
                    child: mode == null
                        ? SalesListPage(
                            isOnlineSales: isOnlineSales,
                            source: source,
                            exportController: exporter,
                            createWorkbook: create)
                        : ValueListenableBuilder<bool>(
                            valueListenable: mode,
                            builder: (_, online, __) => SalesListPage(
                                isOnlineSales: online,
                                source: source,
                                exportController: exporter,
                                createWorkbook: create)))))));
    await tester.pumpAndSettle();
  }

  for (final locale in ['en', 'ar', 'ml']) {
    for (final width in [390.0, 768.0, 1280.0]) {
      for (final online in [false, true]) {
        testWidgets(
            'shared layout at $width in $locale online=$online has no overflow',
            (tester) async {
          final source = PageSource();
          await mount(tester, source,
              width: width, locale: locale, isOnlineSales: online);
          expect(find.byType(ListPageScaffold<ListOrderModelData>),
              findsOneWidget);
          expect(source.pages, [1]);
          expect(source.queries.single.isOnlineSales, online);
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('SALES_PREVIEW') &&
              locale == 'en' &&
              !online) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('sales-preview')));
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File('build/sales-list-${width.toInt()}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (width < 700) {
            expect(find.byType(AppListCard), findsOneWidget);
          } else {
            expect(find.text('#ORD-0001'), findsWidgets);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
  for (final locale in ['en', 'ar', 'ml']) {
    for (final online in [false, true]) {
      testWidgets('Delivered filter keeps raw status in $locale online=$online',
          (tester) async {
        final source = PageSource();
        final dir = Directory.systemTemp.createTempSync('delivered-sales-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/test.xlsx')
          ..writeAsStringSync('fixture');
        var deliveries = 0;
        final exporter = ExportController(deliver: (context, file,
            {required mimeType, shareText, shareOrigin, onStage}) async {
          deliveries++;
        });
        addTearDown(exporter.dispose);
        await mount(tester, source,
            locale: locale,
            isOnlineSales: online,
            exporter: exporter,
            create: (_) async => file);
        final label = 'sales.status_delivered'.tr;
        expect(label, isNot('sales.status_delivered'));
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(source.queries.last.status, 'delivered');
        expect(source.pages.last, 1);
        expect(find.text(label), findsWidgets);
        await tester.tap(find.byKey(SalesListPage.refreshKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('pagination.next_page'.tr));
        await tester.pumpAndSettle();
        expect(source.pages.last, 2);
        await tester.tap(find.byKey(SalesListPage.exportKey));
        await tester.pumpAndSettle();
        expect(deliveries, 1);
        expect(source.exported!.status, 'delivered');
        expect(source.exported!.isOnlineSales, online);
        expect(
            source.queries.skip(1).every(
                (q) => q.status == 'delivered' && q.isOnlineSales == online),
            true);
        await tester.tap(find.text('general.reset'.tr));
        await tester.pumpAndSettle();
        expect(source.queries.last.status, 'all');
        expect(source.queries.last.isOnlineSales, online);
        expect(source.pages.last, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
      'pending text exports the new filters; refresh/realtime preserve filters',
      (tester) async {
    final source = PageSource(), sales = SalesProvider();
    var delivered = 0;
    final dir = Directory.systemTemp.createTempSync('sales-page-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.xlsx')..writeAsStringSync('fixture');
    final exporter = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered++;
    });
    addTearDown(exporter.dispose);
    await mount(tester, source,
        sales: sales, exporter: exporter, create: (rows) async => file);
    final phone = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Phone');
    await tester.enterText(phone, '00123');
    await tester.pump();
    await tester.tap(find.byKey(SalesListPage.exportKey));
    await tester.pumpAndSettle();
    expect(source.exported?.phone, '00123');
    expect(delivered, 1);
    await sales.refreshOrdersForRealtime(accessToken: 'token', storeId: 7);
    await tester.pumpAndSettle();
    expect(source.queries.last.phone, '00123');
    await tester.tap(find.byKey(SalesListPage.refreshKey));
    await tester.pumpAndSettle();
    expect(source.queries.last.phone, '00123');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Online Orders shares Export and keeps its scope after mutations',
      (tester) async {
    final source = PageSource()..unpaidCod = true;
    final sales = ActionSalesProvider();
    final dir = Directory.systemTemp.createTempSync('online-sales-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.xlsx')..writeAsStringSync('fixture');
    var delivered = 0;
    final exporter = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered++;
    });
    addTearDown(exporter.dispose);
    await mount(tester, source,
        sales: sales,
        isOnlineSales: true,
        exporter: exporter,
        create: (_) async => file);
    expect(find.text('Online Orders List'), findsOneWidget);
    expect(sales.isOnlineSalesNavigation, true);
    await tester.tap(find.byKey(SalesListPage.exportKey));
    await tester.pumpAndSettle();
    expect(delivered, 1);
    expect(source.exported!.isOnlineSales, true);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    final modal =
        tester.widget<CancelOrderModal>(find.byType(CancelOrderModal));
    await modal.onConfirm(null, null, false);
    await tester.pumpAndSettle();
    expect(sales.cancelledId, '1');
    expect(source.queries, hasLength(2));
    expect(source.queries.every((q) => q.isOnlineSales), true);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'failed filtering retains rows with Retry and disables export/pagination',
      (tester) async {
    final source = PageSource();
    await mount(tester, source);
    source.fail = true;
    final phone = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Phone');
    await tester.enterText(phone, '00123');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('#ORD-0001'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
        tester
            .widget<AppSquareIconButton>(find.byKey(SalesListPage.exportKey))
            .onPressed,
        isNull);
    source.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(source.pages.last, 1);
    expect(source.queries.last.phone, '00123');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('store/auth change during encoding prevents file delivery',
      (tester) async {
    final source = PageSource(), auth = AuthModel()..login('first', 1);
    var delivered = 0;
    final encoding = Completer<File>();
    final exporter = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered++;
    });
    addTearDown(exporter.dispose);
    final dir = Directory.systemTemp.createTempSync('sales-context-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.xlsx')..writeAsStringSync('fixture');
    await mount(tester, source,
        auth: auth, exporter: exporter, create: (_) => encoding.future);
    await tester.tap(find.byKey(SalesListPage.exportKey));
    await tester.pump();
    auth.login('second', 2);
    await tester.pump();
    auth.login('first', 1);
    await tester.pump();
    encoding.complete(file);
    await tester.pumpAndSettle();
    expect(delivered, 0);
    expect(source.queries, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('failed export names the server page without saving partial rows',
      (tester) async {
    final source = PageSource()
      ..exportFailure = const SalesListExportPageException(
          252, HttpException('Invalid sales response on page 252: HTTP 500'));
    var encoded = 0, delivered = 0;
    final exporter = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered++;
    });
    addTearDown(exporter.dispose);
    await mount(tester, source, exporter: exporter, create: (_) async {
      encoded++;
      throw StateError('Partial workbook must not be encoded');
    });
    await tester.tap(find.byKey(SalesListPage.exportKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('page 252 could not be loaded'), findsOneWidget);
    expect(find.text('#ORD-0001'), findsOneWidget);
    expect(encoded, 0);
    expect(delivered, 0);
    expect(exporter.busy, false);
    expect(source.queries, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('switching shared list mode invalidates export and old inputs',
      (tester) async {
    final source = PageSource(), sales = SalesProvider();
    final mode = ValueNotifier(false);
    addTearDown(mode.dispose);
    final encoding = Completer<File>();
    var delivered = 0;
    final exporter = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered++;
    });
    addTearDown(exporter.dispose);
    final dir = Directory.systemTemp.createTempSync('sales-mode-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test.xlsx')..writeAsStringSync('fixture');
    await mount(tester, source,
        sales: sales,
        mode: mode,
        exporter: exporter,
        create: (_) => encoding.future);
    final phone = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Phone');
    await tester.enterText(phone, '00123');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SalesListPage.exportKey));
    await tester.pump();
    mode.value = true;
    await tester.pump();
    expect(source.queries.last.isOnlineSales, true);
    expect(source.queries.last.phone, isEmpty);
    expect(sales.isOnlineSalesNavigation, true);
    mode.value = false;
    await tester.pump();
    encoding.complete(file);
    await tester.pumpAndSettle();
    expect(delivered, 0);
    expect(source.queries.last.isOnlineSales, false);
    expect(sales.isOnlineSalesNavigation, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'cancel action retains COD arguments and refreshes the applied list',
      (tester) async {
    final source = PageSource()..unpaidCod = true;
    final sales = ActionSalesProvider();
    await mount(tester, source, sales: sales);
    final phone = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Phone');
    await tester.enterText(phone, '00123');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    final modal =
        tester.widget<CancelOrderModal>(find.byType(CancelOrderModal));
    expect(modal.isUnpaidCod, true);
    expect(modal.initialRefundAmount, '10.25');
    await modal.onConfirm(null, null, false);
    await tester.pumpAndSettle();
    expect(sales.cancelledId, '1');
    expect(source.queries.last.phone, '00123');
    expect(source.queries, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('date picker retains From day when time is cancelled',
      (tester) async {
    DateTime? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SalesDateFilter(
                label: 'From',
                value: DateTime(2026, 10, 8),
                includeTime: true,
                onChanged: (date) => selected = date))));
    await tester.tap(find.text('2026-10-08 00:00:00'));
    await tester.pumpAndSettle();
    // Existing date dialog auto-dismisses on selecting a day.
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 10, 9));
  });
  test('workbook keeps receipt identifiers as text and amount as number',
      () async {
    final dir = await Directory.systemTemp.createTemp('sales-excel-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = await exportSalesListExcel([
      ListOrderModelData(
          id: 1,
          orderNumber: 'ORD-001',
          receiptNumber: '00001',
          grantTotal: '100.25')
    ], outputDirectory: dir);
    final rows =
        Excel.decodeBytes(await file.readAsBytes()).tables.values.single.rows;
    expect(rows[1][1]!.value, TextCellValue('ORD-001'));
    expect(rows[1][2]!.value, TextCellValue('00001'));
    expect(rows[1][6]!.value, const DoubleCellValue(100.25));
  });
  test('online workbook uses the online list title and file prefix', () async {
    final dir = await Directory.systemTemp.createTemp('online-excel-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = await exportSalesListExcel([
      ListOrderModelData(id: 1, orderNumber: 'ORD-001', grantTotal: '100.25')
    ], outputDirectory: dir, isOnlineSales: true);
    final workbook = Excel.decodeBytes(await file.readAsBytes());
    expect(workbook.tables.keys.single, 'Online Orders List');
    expect(file.uri.pathSegments.last, startsWith('online-orders'));
  });
}
