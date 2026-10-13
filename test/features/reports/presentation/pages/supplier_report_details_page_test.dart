import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/reports/presentation/pages/supplier_report_details_page.dart';
import 'package:pos_machine/features/reports/presentation/widgets/report_error_bar.dart';
import 'package:pos_machine/features/reports/presentation/widgets/supplier_report/details/supplier_report_details_results.dart';
import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../fixtures/supplier_report_details_fixture.dart';

class DetailRepository extends SupplierRepository {
  bool fail = false;
  Completer<void>? exportGate;
  final calls =
      <({String? id, String? from, String? to, bool all, int? page})>[];
  @override
  Future<List<Supplier>?> fetchAll(String token, {String? name}) async => [
        Supplier.fromJson({
          'id': 7,
          'name': 'Supplier',
          'phone': '1234',
          'email': 'supplier@test.invalid',
          'address': 'Test address'
        })
      ];
  @override
  Future<Map<String, dynamic>> fetchTransactions(
    String token, {
    String? supplierName,
    String? supplierId,
    String? transactionType,
    String? fromDate,
    String? toDate,
    bool listAll = true,
    int? page,
  }) async {
    calls.add(
        (id: supplierId, from: fromDate, to: toDate, all: listAll, page: page));
    if (page != null && exportGate != null) await exportGate!.future;
    if (fail) throw StateError('network failure');
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return detailResponse(groups: [
      detailGroup(7, rows: [
        detailRow(71, date: date),
        detailRow(72,
            date: date, type: 'Debit', payment: 'CASH', amount: '45.50'),
      ])
    ]);
  }
}

class PrintNavigation extends NavigatorObserver {
  MaterialPageRoute<dynamic>? lastPrintRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is MaterialPageRoute<dynamic>) lastPrintRoute = route;
  }
}

class AllTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final result = <String, Map<String, String>>{};
    for (final lang in ['en', 'ar', 'ml']) {
      final flat = <String, String>{};
      void flatten(Map<String, dynamic> map, String prefix) {
        for (final entry in map.entries) {
          final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
          if (entry.value is Map<String, dynamic>) {
            flatten(entry.value as Map<String, dynamic>, key);
          } else {
            flat[key] = '${entry.value}';
          }
        }
      }

      flatten(
          jsonDecode(File('lib/resources/i18n/$lang.json').readAsStringSync())
              as Map<String, dynamic>,
          '');
      result[lang] = flat;
    }
    return result;
  }
}

Future<SupplierProvider> pumpDetails(
  WidgetTester tester,
  DetailRepository repo, {
  ExportController? export,
  String locale = 'en',
  String name = 'Supplier',
  NavigatorObserver? observer,
  double scale = 1,
}) async {
  final suppliers = SupplierProvider(repository: repo)
    ..setSelectedSupplierId('7')
    ..setSelectedSupplierName(name);
  addTearDown(suppliers.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>(
            create: (_) => AuthModel()..login('token', 1)),
        ChangeNotifierProvider<SupplierProvider>.value(value: suppliers),
      ],
      child: GetMaterialApp(
        translations: AllTranslations(),
        locale: Locale(locale),
        navigatorObservers: [if (observer != null) observer],
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SupplierTransactionDetailsScreen(exportController: export)),
      )));
  await tester.pumpAndSettle();
  return suppliers;
}

PageHeader header(WidgetTester tester) =>
    tester.widget<PageHeader>(find.byType(PageHeader));
ListPageScaffold<SupplierTransaction> listing(WidgetTester tester) =>
    tester.widget<ListPageScaffold<SupplierTransaction>>(
        find.byType(ListPageScaffold<SupplierTransaction>));

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
    final root = configFile.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(File.fromUri(root.resolve(entry.value))
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(
        {'api_key': 'tenant', 'active_store_id': 2});
  });
  tearDown(Get.reset);

  for (final size in [
    const Size(375, 850),
    const Size(768, 900),
    const Size(1280, 900),
    const Size(1280, 550)
  ]) {
    for (final locale in ['en', 'ar', 'ml']) {
      testWidgets('shared View layout at $size in $locale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = DetailRepository();
        await pumpDetails(tester, repo,
            locale: locale,
            name: 'Supplier with a very long name for layout checking',
            scale: 1.3);
        expect(listing(tester).items.length, 2);
        expect(listing(tester).columns.length, 7);
        expect(find.byType(PageHeader), findsOneWidget);
        expect(find.byKey(SupplierTransactionDetailsScreen.backKey),
            findsOneWidget);
        expect(header(tester).actions[1].onPressed, isNotNull);
        if (size.width < 700) {
          expect(find.byType(SupplierReportDetailsCard), findsWidgets);
          await tapFilterToggle(tester,
              key: SupplierTransactionDetailsScreen.filterToggleKey);
          await tester.pumpAndSettle();
        }
        expect(find.byType(FilterPanel), findsOneWidget);
        expect(repo.calls.single.id, '7');
        expect(repo.calls.single.all, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'search, payment, type and Reset work with an empty shared supplier directory',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DetailRepository();
    final suppliers = await pumpDetails(tester, repo);
    expect(suppliers.supplierList, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'REF-72');
    await tester.pump();
    expect(listing(tester).items.single.id, 72);
    final dropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .toList();
    dropdowns[0].onChanged!('Debit');
    dropdowns[1].onChanged!('Cash');
    await tester.pump();
    expect(listing(tester).items.single.id, 72);
    expect(repo.calls.length, 1);
    tester.widget<FilterPanel>(find.byType(FilterPanel)).onReset();
    await tester.pumpAndSettle();
    expect(listing(tester).items.length, 2);
    expect(repo.calls.length, 2);
    expect(find.text('All'), findsNWidgets(2));
    expect(header(tester).actions[1].onPressed, isNotNull);
    await tapFilterToggle(tester);
    expect(listing(tester).showFilters, isFalse);
    expect(listing(tester).items.length, 2);
  });
  testWidgets(
      'date picker selection reloads with selected bounds; Cancel leaves data unchanged',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DetailRepository();
    await pumpDetails(tester, repo);
    await tester
        .tap(find.byKey(const ValueKey('supplier-report-details-from')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls.length, 1);
    await tester
        .tap(find.byKey(const ValueKey('supplier-report-details-from')));
    await tester.pumpAndSettle();
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    calendar.onDateChanged(DateTime(DateTime.now().year, 1, 1));
    await tester.pumpAndSettle();
    expect(repo.calls.last.from, '${DateTime.now().year}-01-01');
    expect(listing(tester).items.length, 2);
  });
  testWidgets(
      'failed refresh retains rows, blocks Export, Retry restores it and Back returns to report',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DetailRepository();
    await pumpDetails(tester, repo);
    repo.fail = true;
    header(tester).actions[2].onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(ReportErrorBar), findsOneWidget);
    expect(listing(tester).items.length, 2);
    expect(header(tester).actions[1].onPressed, isNull);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportErrorBar), findsNothing);
    expect(header(tester).actions[1].onPressed, isNotNull);
    await tester.tap(find.byKey(SupplierTransactionDetailsScreen.backKey));
    await tester.pump();
    expect(Get.find<SideBarController>().index.value,
        SideBarController.supplierTransactionsReportScreenIndex);
  });
  testWidgets(
      'shared export delivers numeric workbook, preserves rows and supplier selection',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await useTempExportDirectory(tester, 'supplier-details-');
    Excel? workbook;
    var delivered = 0;
    Object? failure;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      workbook = Excel.decodeBytes(await file.readAsBytes());
      delivered++;
    });
    addTearDown(export.dispose);
    final repo = DetailRepository();
    final suppliers = await pumpDetails(tester, repo, export: export);
    await tester.tap(find.byKey(SupplierTransactionDetailsScreen.exportKey));
    await tester.pump();
    expect(export.busy, isTrue);
    expect(header(tester).actions[1].onPressed, isNull);
    for (var i = 0; i < 120 && export.busy; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    failure = tester.takeException();
    expect(failure, isNull);
    expect(export.busy, isFalse);
    expect(delivered, 1);
    final rows = workbook!.tables.values.single.rows;
    expect(rows.length, 3);
    expect(rows[1][6]!.value, const DoubleCellValue(10.125));
    expect(rows[2][6]!.value, const DoubleCellValue(45.50));
    expect(rows[1][7]!.value, TextCellValue('SAR'));
    expect(listing(tester).items.length, 2);
    expect(suppliers.selectedSupplierId, '7');
    expect(suppliers.supplierList, isEmpty);
    expect(repo.calls.last.page, 1);
    expect(repo.calls.last.all, isTrue);
  });
  testWidgets('phone more menu exposes shared Export', (tester) async {
    tester.view.physicalSize = const Size(375, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final export = CapturingExport();
    addTearDown(export.dispose);
    await pumpDetails(tester, DetailRepository(), export: export);
    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(export.runs, 1);
  });
  testWidgets(
      'Print retains displayed rows, contact lookup, total and date bounds',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final observer = PrintNavigation();
    final repo = DetailRepository();
    final suppliers = await pumpDetails(tester, repo, observer: observer);
    await suppliers.fetchSuppliers(accessToken: 'token');
    await tester.pumpAndSettle();
    final print = header(tester).primaryActions.single as AppPrimaryButton;
    print.onPressed!();
    final printed = observer.lastPrintRoute!.builder(
            tester.element(find.byType(SupplierTransactionDetailsScreen)))
        as SupplierTransactionReportPrint;
    expect(printed.cartItems.map((row) => row.id), [71, 72]);
    expect(printed.formattedTotal, '55.63');
    expect(printed.savedTotal, '55.63');
    expect(printed.supplierName, 'Supplier');
    expect(printed.supplierPhone, '1234');
    expect(printed.supplierEmail, 'supplier@test.invalid');
    expect(printed.supplierAddress, 'Test address');
    expect(printed.fromDate, repo.calls.first.from);
    expect(printed.toDate, repo.calls.first.to);
    // Validate navigation input without opening a native printer or building its providers.
    await tester.pumpWidget(const SizedBox());
  });
}
