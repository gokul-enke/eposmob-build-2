import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:pos_machine/features/reports/presentation/widgets/supplier_report/supplier_report_filters.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:excel/excel.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/reports/domain/supplier_report.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/reports/presentation/pages/supplier_transactions_report_page.dart';
import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import '../../../../test_support/app_translations.dart';

List<Supplier> directory() => [
      Supplier.fromJson({'id': 7, 'name': 'First supplier'}),
      Supplier.fromJson({'id': 8, 'name': 'Second supplier'})
    ];
Map<String, dynamic> response(int page) => {
      'data': {
        'current_page': page,
        'last_page': 2,
        'data': [
          {
            'supplier_id': 7,
            'supplier_name': 'First supplier',
            'total_debit': '125.25',
            'total_credit': 50,
            'balance': -75.25,
            'transactions': [{}, {}]
          },
          {
            'supplier_id': 8,
            'supplier_name': 'Second supplier',
            'total_debit': 10,
            'total_credit': '20.50',
            'balance': 10.5,
            'transactions': [{}]
          },
        ]
      }
    };

class TestSupplierRepository extends SupplierRepository {
  final calls =
      <({String? id, String? from, String? to, int page, bool all})>[];
  @override
  Future<List<Supplier>?> fetchAll(String token, {String? name}) async =>
      directory();
  @override
  Future<Map<String, dynamic>> fetchTransactions(String token,
      {String? supplierName,
      String? supplierId,
      String? transactionType,
      String? fromDate,
      String? toDate,
      bool listAll = true,
      int? page}) async {
    calls.add((
      id: supplierId,
      from: fromDate,
      to: toDate,
      page: page ?? 1,
      all: listAll
    ));
    return response(page ?? 1);
  }
}

class TestSupplierProvider extends SupplierProvider {
  TestSupplierProvider(TestSupplierRepository repo) : super(repository: repo);
  @override
  List<Supplier>? get allSuppliers => directory();
  @override
  Future<List<Supplier>?> fetchSuppliers(
          {required String accessToken, String? supplierName}) async =>
      directory();
}

class ExportSupplierRepository extends TestSupplierRepository {
  bool fail = false;
  @override
  Future<Map<String, dynamic>> fetchTransactions(String token,
      {String? supplierName,
      String? supplierId,
      String? transactionType,
      String? fromDate,
      String? toDate,
      bool listAll = true,
      int? page}) async {
    calls.add((
      id: supplierId,
      from: fromDate,
      to: toDate,
      page: page ?? 1,
      all: listAll
    ));
    if (fail) throw StateError('network');
    final current = page ?? 1;
    final result = response(current);
    final data = result['data'] as Map;
    if (current == 2) {
      data['data'] = [
        {
          'supplier_id': 9,
          'supplier_name': 'Third supplier',
          'total_debit': 90,
          'total_credit': 40,
          'balance': -50,
          'transactions': [{}],
        }
      ];
    }
    data['total'] = 3;
    data['per_page'] = 2;
    return result;
  }
}

class DeferredExportRepository extends ExportSupplierRepository {
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> fetchTransactions(String token,
      {String? supplierName,
      String? supplierId,
      String? transactionType,
      String? fromDate,
      String? toDate,
      bool listAll = true,
      int? page}) async {
    final pending = gate;
    if (pending != null) await pending.future;
    return super.fetchTransactions(token,
        supplierName: supplierName,
        supplierId: supplierId,
        transactionType: transactionType,
        fromDate: fromDate,
        toDate: toDate,
        listAll: listAll,
        page: page);
  }
}

class ReportRouteObserver extends NavigatorObserver {
  final popped = <Route<dynamic>>[];
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
  }
}

class DirectoryFailureRepository extends TestSupplierRepository {
  bool failDirectory = true;
  int directoryCalls = 0;
  @override
  Future<List<Supplier>?> fetchAll(String token, {String? name}) async {
    directoryCalls++;
    if (failDirectory) throw StateError('directory');
    return directory();
  }
}

class FilterFailureRepository extends TestSupplierRepository {
  bool fail = false;
  @override
  Future<Map<String, dynamic>> fetchTransactions(String token,
      {String? supplierName,
      String? supplierId,
      String? transactionType,
      String? fromDate,
      String? toDate,
      bool listAll = true,
      int? page}) async {
    final result = await super.fetchTransactions(token,
        supplierName: supplierName,
        supplierId: supplierId,
        transactionType: transactionType,
        fromDate: fromDate,
        toDate: toDate,
        listAll: listAll,
        page: page);
    if (fail) throw StateError('network');
    result['data']['last_page'] = 3;
    return result;
  }
}

Future<TestSupplierProvider> pumpReport(
    WidgetTester tester, TestSupplierRepository repo,
    {ExportController? export, NavigatorObserver? observer}) async {
  final provider = TestSupplierProvider(repo)..setSelectedSupplierId('99');
  addTearDown(provider.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>(
            create: (_) => AuthModel()..login('test', 1)),
        ChangeNotifierProvider<SupplierProvider>.value(value: provider),
      ],
      child: GetMaterialApp(
          builder: (_, child) => RepaintBoundary(
              key: const ValueKey('supplier-report-test-app'), child: child!),
          navigatorObservers: [if (observer != null) observer],
          translations: EnglishTranslations(),
          locale: const Locale('en'),
          home: Scaffold(
              body:
                  SupplierTransactionsReportPage(exportController: export)))));
  await tester.pumpAndSettle();
  return provider;
}

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
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
  });
  tearDown(Get.reset);
  for (final width in [375.0, 1280.0]) {
    testWidgets(
        'directory outage at $width leaves report usable and retries only filter options',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DirectoryFailureRepository();
      await pumpReport(tester, repo);
      expect(find.text('First supplier'), findsOneWidget);
      expect(
          find.text(
              'Could not load supplier filter options. Use Retry to load them.'),
          findsOneWidget);
      expect(
          tester
              .widget<PageHeader>(find.byType(PageHeader))
              .actions[1]
              .onPressed,
          isNotNull);
      final list = tester.widget<ListPageScaffold<SupplierTransactionSummary>>(
          find.byType(ListPageScaffold<SupplierTransactionSummary>));
      expect(list.isLoading, isFalse);
      expect(list.pagination!.enabled, isTrue);
      final reportRequests = repo.calls.length;
      repo.failDirectory = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.directoryCalls, 2);
      expect(repo.calls.length, reportRequests);
      expect(
          find.text(
              'Could not load supplier filter options. Use Retry to load them.'),
          findsNothing);
      expect(find.text('First supplier'), findsOneWidget);
      if (width < 700) {
        await tapFilterToggle(tester);
      }
      await tester.tap(find.byType(DropdownSearch<SupplierReportOption>));
      await tester.pumpAndSettle();
      expect(find.text('Second supplier'), findsWidgets);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'failed filter on page 2 at $width disables arrows until Retry loads page 1',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FilterFailureRepository();
      await pumpReport(tester, repo);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
      await tester.pumpAndSettle();
      expect(repo.calls.last.page, 2);
      if (width < 700) await tapFilterToggle(tester);
      repo.fail = true;
      await tester.tap(find.byType(DropdownSearch<SupplierReportOption>));
      await tester.pumpAndSettle();
      await tester.tap(find
          .ancestor(
              of: find.text('Second supplier').last,
              matching: find.byType(InkResponse))
          .first);
      await tester.pumpAndSettle();
      expect(repo.calls.last.page, 1);
      expect(repo.calls.last.id, '8');
      expect(find.text('First supplier'), findsOneWidget);
      expect(find.text('Page 2 of 3'), findsOneWidget);
      final arrows = tester.widgetList<AppSquareIconButton>(find.descendant(
          of: find.byType(AppPaginationBar),
          matching: find.byType(AppSquareIconButton)));
      expect(arrows, hasLength(2));
      expect(arrows.every((button) => button.onPressed == null), isTrue);
      final list = tester.widget<ListPageScaffold<SupplierTransactionSummary>>(
          find.byType(ListPageScaffold<SupplierTransactionSummary>));
      final requests = repo.calls.length;
      list.pagination!.onPageChanged(3);
      await tester.pumpAndSettle();
      expect(repo.calls.length, requests);
      repo.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.page, 1);
      expect(repo.calls.last.id, '8');
      expect(find.text('Page 1 of 3'), findsOneWidget);
      // The earlier error toast briefly overlays the phone's bottom controls.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
      await tester.pumpAndSettle();
      expect(repo.calls.last.page, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [375.0, 768.0, 1280.0]) {
    testWidgets(
        'real supplier popup selection/search/clear/Reset at $width keeps report route',
        (tester) async {
      final captureDirectory =
          Platform.environment['REPORT_POPUP_CAPTURE_DIRECTORY'];
      final previousShadows = debugDisableShadows;
      if (captureDirectory != null) {
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = previousShadows);
      }
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final routes = ReportRouteObserver();
      final repo = TestSupplierRepository();
      await pumpReport(tester, repo, observer: routes);
      if (width < 700) {
        tester
            .widget<PageHeader>(find.byType(PageHeader))
            .actions
            .first
            .onPressed!();
        await tester.pumpAndSettle();
      }
      final picker = find.byType(DropdownSearch<SupplierReportOption>);
      final originalState =
          tester.state<DropdownSearchState<SupplierReportOption>>(picker);
      Future<void> selectSecond({bool search = false}) async {
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(find.byType(SupplierTransactionsReportPage), findsOneWidget);
        final option = find.text('Second supplier').last;
        final material = tester
            .widgetList<Material>(
                find.ancestor(of: option, matching: find.byType(Material)))
            .firstWhere((widget) => widget.type == MaterialType.card);
        expect(material.color, AppColors.surface);
        expect(material.surfaceTintColor, AppColors.surface);
        expect(tester.widget<Text>(option).style!.fontSize,
            AppTextStyles.input.fontSize);
        if (captureDirectory != null && width == 1280 && search) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('supplier-report-test-app')));
            final bitmap = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await bitmap.toByteData(format: ui.ImageByteFormat.png);
            await File('$captureDirectory/supplier-report-popup.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            bitmap.dispose();
          });
        }
        if (search) {
          await tester.enterText(find.byType(TextField).last, 'Second');
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }
        await tester.tap(find
            .ancestor(
                of: find.text('Second supplier').last,
                matching: find.byType(InkResponse))
            .first);
        await tester.pumpAndSettle();
        expect(repo.calls.last.id, '8');
        expect(tester.state<DropdownSearchState<SupplierReportOption>>(picker),
            same(originalState));
        expect(originalState.getSelectedItem!.id, '8');
        expect(find.byType(SupplierTransactionsReportPage), findsOneWidget);
        expect(routes.popped.every((route) => route is PopupRoute), isTrue);
      }

      await selectSecond(search: true);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(
          tester.widget<Text>(find.text('Second supplier').last).style!.color,
          AppColors.primary);
      expect(
          tester
              .widget<Ink>(find
                  .ancestor(
                      of: find.text('Second supplier').last,
                      matching: find.byType(Ink))
                  .first)
              .decoration,
          isA<BoxDecoration>().having(
              (value) => value.color, 'selected colour', AppColors.softBlue));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester
          .tap(find.descendant(of: picker, matching: find.byIcon(Icons.clear)));
      await tester.pumpAndSettle();
      expect(repo.calls.last.id, isNull);
      expect(originalState.getSelectedItem, isNull);
      await selectSecond();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.id, isNull);
      expect(originalState.getSelectedItem, isNull);
      expect(find.text('All suppliers'), findsOneWidget);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      // Dismiss the menu through its modal barrier, without selecting a filter.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(routes.popped, hasLength(4));
      expect(routes.popped.every((route) => route is PopupRoute), isTrue);
      expect(find.byType(SupplierTransactionsReportPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDisableShadows = previousShadows;
    });
  }
  for (final change in ['store', 'tenant', 'logout']) {
    testWidgets(
        '$change change during Export blocks delivery and releases busy',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var deliveries = 0;
      final export = ExportController(deliver: (_, __,
          {required mimeType, shareText, shareOrigin, onStage}) async {
        deliveries++;
      });
      addTearDown(export.dispose);
      final repo = DeferredExportRepository();
      await pumpReport(tester, repo, export: export);
      final gate = Completer<void>();
      repo.gate = gate;
      await tester.tap(find.byKey(SupplierTransactionsReportPage.exportKey));
      // Allow async scope reads to finish and the HTTP request to wait on gate.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(export.busy, isTrue);
      final prefs = await SharedPreferences.getInstance();
      if (change == 'store') {
        await prefs.setInt('active_store_id', 2);
      } else if (change == 'tenant') {
        await prefs.setString('api_key', 'another-tenant');
      } else {
        tester
            .element(find.byType(SupplierTransactionsReportPage))
            .read<AuthModel>()
            .logout();
      }
      repo.gate = null;
      gate.complete();
      await tester.pumpAndSettle();
      expect(export.busy, isFalse);
      expect(deliveries, 0);
      expect(repo.calls, hasLength(2));
      expect(find.text('First supplier'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
  testWidgets('tablet scrollbar reveals View and opens the same supplier',
      (tester) async {
    tester.view.physicalSize = const Size(768, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await pumpReport(tester, TestSupplierRepository());
    final list = tester.widget<ListPageScaffold<SupplierTransactionSummary>>(
        find.byType(ListPageScaffold<SupplierTransactionSummary>));
    expect(find.byType(Scrollbar), findsWidgets);
    list.tableScrollController!
        .jumpTo(list.tableScrollController!.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(provider.selectedSupplierId, '7');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
      'changing supplier during Export cancels delivery and releases busy state',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var deliveries = 0;
    final export = ExportController(deliver: (_, __,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      deliveries++;
    });
    addTearDown(export.dispose);
    final repo = DeferredExportRepository();
    await pumpReport(tester, repo, export: export);
    final gate = Completer<void>();
    repo.gate = gate;
    await tester.tap(find.byKey(SupplierTransactionsReportPage.exportKey));
    await tester.pump();
    expect(export.busy, isTrue);
    expect(tester.widget<PageHeader>(find.byType(PageHeader)).actions[1].busy,
        isTrue);
    repo.gate = null;
    tester
            .widget<DropdownSearch<SupplierReportOption>>(
                find.byType(DropdownSearch<SupplierReportOption>))
            .onChanged!(
        const SupplierReportOption(id: '8', name: 'Second supplier'));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(export.busy, isFalse);
    expect(deliveries, 0);
    expect(
        tester
            .widget<DropdownSearch<SupplierReportOption>>(
                find.byType(DropdownSearch<SupplierReportOption>))
            .selectedItems
            .single
            .id,
        '8');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('exports every filtered summary page as numeric workbook cells',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await useTempExportDirectory(tester, 'supplier-report-export-');
    final export = CapturingExport();
    addTearDown(export.dispose);
    final repo = ExportSupplierRepository();
    final provider = await pumpReport(tester, repo, export: export);
    tester
            .widget<DropdownSearch<SupplierReportOption>>(
                find.byType(DropdownSearch<SupplierReportOption>))
            .onChanged!(
        const SupplierReportOption(id: '7', name: 'First supplier'));
    await tester.pumpAndSettle();
    tester
        .widget<SupplierReportDateField>(
            find.byKey(const ValueKey('supplier-report-from')))
        .onChanged(DateTime(2026, 9, 1));
    await tester.pumpAndSettle();
    tester
        .widget<SupplierReportDateField>(
            find.byKey(const ValueKey('supplier-report-to')))
        .onChanged(DateTime(2026, 10, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SupplierTransactionsReportPage.exportKey));
    await tester.pump();
    expect(export.runs, 1);
    final file = (await tester.runAsync(export.createFile!))!;
    final workbook = Excel.decodeBytes(file.readAsBytesSync());
    final rows = workbook.tables['Supplier Transactions']!.rows;
    expect(rows.length, 4);
    expect(rows[1][2]!.value, const DoubleCellValue(125.25));
    expect(rows[1][4]!.value, const DoubleCellValue(-75.25));
    expect(rows[3][1]!.value, TextCellValue('Third supplier'));
    expect(repo.calls.skip(repo.calls.length - 2).map((call) => call.page),
        [1, 2]);
    for (final call in repo.calls.skip(repo.calls.length - 2)) {
      expect(call.id, '7');
      expect(call.from, '2026-09-01');
      expect(call.to, '2026-10-01');
      expect(call.all, isFalse);
    }
    final list = tester.widget<ListPageScaffold<SupplierTransactionSummary>>(
        find.byType(ListPageScaffold<SupplierTransactionSummary>));
    expect(list.pagination!.currentPage, 1);
    expect(list.items.length, 2);
    expect(provider.selectedSupplierId, '99');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Injected export remains owned by the caller after the page closes.
    var notified = false;
    export.addListener(() => notified = true);
    export.setStage('still available');
    expect(notified, isTrue);
  });
  testWidgets('failed refresh retains rows, shows Retry and disables export',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ExportSupplierRepository();
    await pumpReport(tester, repo);
    repo.fail = true;
    await tester.tap(find.byKey(SupplierTransactionsReportPage.refreshKey));
    await tester.pumpAndSettle();
    expect(find.text('First supplier'), findsOneWidget);
    final header = tester.widget<PageHeader>(find.byType(PageHeader));
    expect(header.actions[1].onPressed, isNull);
    expect(find.text('Retry'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<PageHeader>(find.byType(PageHeader)).actions[1].onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('phone menu exposes filters and date picker stays date-only',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = TestSupplierRepository();
    final provider = await pumpReport(tester, repo);
    expect(find.byType(AppListCard), findsWidgets);
    expect(find.byKey(const ValueKey('supplier-transactions-report-filters')),
        findsNothing);
    await tapFilterToggle(tester);
    await tester.tap(find.byKey(const ValueKey('supplier-report-from')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 15));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(repo.calls.last.from, '2026-09-15');
    await tapFilterToggle(tester);
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(provider.selectedSupplierId, '7');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  for (final width in [375.0, 768.0, 1280.0, 1440.0]) {
    testWidgets('populated supplier report layout at $width', (tester) async {
      tester.view.physicalSize = Size(width, width == 375 ? 812 : 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestSupplierRepository();
      final provider = TestSupplierProvider(repo);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthModel>(
                create: (_) => AuthModel()..login('test', 1)),
            ChangeNotifierProvider<SupplierProvider>.value(value: provider),
          ],
          child: GetMaterialApp(
              translations: EnglishTranslations(),
              locale: const Locale('en'),
              home: const Scaffold(
                  body: RepaintBoundary(
                      key: ValueKey('preview'),
                      child: SupplierTransactionsReportPage())))));
      await tester.pumpAndSettle();
      expect(find.text('First supplier'), findsOneWidget);
      expect(find.text('Second supplier'), findsOneWidget);
      expect(repo.calls.single.all, isFalse);
      expect(tester.takeException(), isNull);
      final tag = Platform.environment['SUPPLIER_REPORT_CAPTURE_TAG'];
      if (tag != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')));
          final bitmap = await boundary.toImage(pixelRatio: 1);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final folder =
              Directory('${Directory.systemTemp.path}/supplier-report-previews')
                ..createSync(recursive: true);
          File('${folder.path}/$tag-${width.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      provider.dispose();
    });
  }
  testWidgets(
      'supplier/date -> Reset -> paging preserves queries and visible dates; View sets only details selection',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = TestSupplierRepository();
    final provider = TestSupplierProvider(repo)..setSelectedSupplierId('99');
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<SupplierProvider>.value(value: provider),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: const Scaffold(body: SupplierTransactionsReportPage()))));
    await tester.pumpAndSettle();
    expect(repo.calls.single.id, isNull);
    expect(provider.selectedSupplierId, '99');
    final dropdown = tester.widget<DropdownSearch<SupplierReportOption>>(
        find.byType(DropdownSearch<SupplierReportOption>));
    dropdown.onChanged!(
        const SupplierReportOption(id: '7', name: 'First supplier'));
    await tester.pumpAndSettle();
    var dates = tester
        .widgetList<SupplierReportDateField>(
            find.byType(SupplierReportDateField))
        .toList();
    dates[0].onChanged(DateTime(2026, 9, 1));
    await tester.pumpAndSettle();
    dates = tester
        .widgetList<SupplierReportDateField>(
            find.byType(SupplierReportDateField))
        .toList();
    dates[1].onChanged(DateTime(2026, 10, 1));
    await tester.pumpAndSettle();
    expect(repo.calls.last.id, '7');
    expect(repo.calls.last.from, '2026-09-01');
    expect(repo.calls.last.to, '2026-10-01');
    expect(find.text('Sep 01, 2026'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Sep 01, 2026'), findsNothing);
    expect(find.text('Oct 01, 2026'), findsNothing);
    expect(repo.calls.last.id, isNull);
    expect(repo.calls.last.from, isNull);
    expect(repo.calls.last.to, isNull);
    expect(repo.calls.last.page, 1);
    final pagination = tester
        .widget<ListPageScaffold<SupplierTransactionSummary>>(
            find.byType(ListPageScaffold<SupplierTransactionSummary>))
        .pagination!;
    pagination.onPageChanged(2);
    await tester.pumpAndSettle();
    expect(repo.calls.last.page, 2);
    expect(repo.calls.last.all, isFalse);
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(provider.selectedSupplierId, '7');
    expect(provider.selectedSupplierName, 'First supplier');
    expect(Get.find<SideBarController>().index.value,
        SideBarController.supplierTransactionDetailsScreenIndex);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    provider.dispose();
    expect(tester.takeException(), isNull);
  });
}
