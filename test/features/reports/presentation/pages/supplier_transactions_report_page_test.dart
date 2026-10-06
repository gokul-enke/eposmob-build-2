import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
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
  for (final width in [375.0, 1280.0, 1440.0]) {
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
        .widgetList<CalendarPickerTableCell>(
            find.byType(CalendarPickerTableCell))
        .toList();
    dates[0].onDateSelected(DateTime(2026, 9, 1));
    await tester.pumpAndSettle();
    dates = tester
        .widgetList<CalendarPickerTableCell>(
            find.byType(CalendarPickerTableCell))
        .toList();
    dates[1].onDateSelected(DateTime(2026, 10, 1));
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
    final pagination =
        tester.widget<PaginationControl>(find.byType(PaginationControl));
    pagination.onPageChanged(2);
    await tester.pumpAndSettle();
    expect(repo.calls.last.page, 2);
    expect(repo.calls.last.all, isFalse);
    await tester.tap(find.byIcon(Icons.visibility).first);
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
