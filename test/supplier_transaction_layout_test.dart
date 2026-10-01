import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/core/ui/list_page/list_page_scaffold.dart';
import 'package:pos_machine/models/transaction_model.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/screens/transactions/supplier_transactions/supplier_transactions.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final flat = <String, String>{};
    void flatten(Map<String, dynamic> data, String prefix) {
      for (final entry in data.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value, key);
        } else {
          flat[key] = entry.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': flat};
  }
}

TransactionModel _transaction() => TransactionModel.withIndex(
    TransactionModel.fromJson({
      'id': 1,
      'supplier_id': 7,
      'date': '2026-10-01',
      'type': 'Credit',
      'transaction_type': 'Invoice',
      'payment_mode': 'CASH',
      'amount': '250.00',
      'currency': 'INR',
      'reference': 'INV-TEST-001',
      'status': 'SUCCESS',
      'user_id': 1,
      'created_at': '',
      'updated_at': '',
      'supplier': {
        'id': 7,
        'user_id': 1,
        'balance': '250.00',
        'created_at': '',
        'updated_at': '',
        'user': {
          'id': 1,
          'name': 'Test Supplier',
          'email': '',
          'phone': '',
          'phone_verified': 0,
          'company_id': 1,
          'created_at': '',
          'updated_at': ''
        }
      }
    }),
    0);

class _Provider extends TransactionProvider {
  final requests = <Map<String, Object?>>[];
  int page = 1;
  @override
  List<TransactionModel> get listTransactionModelDataList => [_transaction()];
  @override
  int get transactionCurrentPage => page;
  @override
  int get transactionTotalPages => 2;
  @override
  List<String> getSupplierOptions() => ['Test Supplier'];
  @override
  int? lookupSupplierIdByName(String name) =>
      name == 'Test Supplier' ? 7 : null;
  String? exportSearch;
  String? exportStatus;
  int exportFetches = 0;
  @override
  Future<List<TransactionModel>> fetchTransactionsForExport(
      {String? supplierId,
      String? transactionType,
      String? type,
      String? search,
      String? status,
      String? supplierName,
      void Function(int, int)? onProgress}) async {
    exportFetches++;
    exportSearch = search;
    exportStatus = status;
    return [_transaction()]
        .where((tx) =>
            (search == null ||
                tx.reference.toLowerCase().contains(search.toLowerCase()) ||
                tx.supplier.user.name
                    .toLowerCase()
                    .contains(search.toLowerCase())) &&
            (status == null || tx.status == status))
        .toList();
  }

  @override
  Future<void> fetchTransactionsFromServerV2(
      {String? supplierId,
      String? transactionType,
      String? type,
      String? dateFrom,
      String? dateTo,
      int? perPage,
      int? page}) async {
    requests.add({
      'supplierId': supplierId,
      'transactionType': transactionType,
      'type': type,
      'page': page,
      'perPage': perPage
    });
    this.page = page ?? 1;
    notifyListeners();
  }
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  Future<_Provider> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _Provider();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider<TransactionProvider>.value(value: provider),
        ],
        child: GetMaterialApp(
            translations: _Translations(),
            locale: const Locale('en'),
            home: const Scaffold(body: TransactionScreen()))));
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets('desktop retains columns, reference copy and details action',
      (tester) async {
    await mount(tester, const Size(1440, 900));
    expect(find.text('Export'), findsOneWidget);
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        isTrue);
    expect(find.textContaining('INR 250.00'), findsOneWidget);
    expect(find.text('INV-TEST-001'), findsOneWidget);
    expect(find.byTooltip('Copy reference'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search and Status filter the list through the same export fetch',
      (tester) async {
    final provider = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).first, 'INV-TEST');
    await tester.pumpAndSettle();
    expect(find.text('INV-TEST-001'), findsOneWidget);
    expect(find.text('INV-TEST-001'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>).last)
            .initialValue,
        'SUCCESS');
    expect(find.text('INV-TEST-001'), findsOneWidget);
    expect(provider.exportFetches, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supplier and type filters survive hiding and pagination',
      (tester) async {
    final provider = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).at(1), 'Test Supplier');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invoice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterToggleButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(provider.requests.last, {
      'supplierId': '7',
      'transactionType': 'Invoice',
      'type': null,
      'page': 2,
      'perPage': 50
    });
    await tester.tap(find.byType(FilterToggleButton));
    await tester.pumpAndSettle();
    expect(find.text('Test Supplier'), findsWidgets);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(provider.requests.last['supplierId'], isNull);
    expect(provider.requests.last['transactionType'], isNull);
    expect(provider.requests.last['page'], 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(390, 800),
    const Size(800, 900),
    const Size(375, 300)
  ]) {
    testWidgets('responsive table or cards and expanded filters at $size',
        (tester) async {
      await mount(tester, size);
      expect(
          tester
              .widget<ExportShareButton>(find.byType(ExportShareButton))
              .compact,
          isTrue);
      final layout = tester.widget<ListPageScaffold<TransactionModel>>(
          find.byType(ListPageScaffold<TransactionModel>));
      expect(layout.tableMinWidth, 1200);
      expect(find.textContaining('INR 250.00'), findsOneWidget);
      expect(find.text('TRANSACTION TYPE'),
          size.width >= 700 ? findsOneWidget : findsNothing);
      if (size.width < 700) {
        await tester.tap(find.byType(FilterToggleButton));
        await tester.pumpAndSettle();
      }
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'desktop keeps its table below 1200 pixels and scrolls to actions',
      (tester) async {
    await mount(tester, const Size(1100, 900));
    expect(find.text('TRANSACTION TYPE'), findsOneWidget);
    final horizontal = find.byWidgetPredicate((widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal);
    expect(horizontal, findsOneWidget);
    await tester.drag(horizontal, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
