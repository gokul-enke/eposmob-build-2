import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
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


/// Delivery stand-in: records the exported file instead of opening Save As
/// or the share sheet.
class _Delivery {
  final files = <File>[];
  final shareTexts = <String?>[];

  Future<void> call(BuildContext context, File file,
      {required String mimeType,
      String? shareText,
      Rect? shareOrigin,
      ValueChanged<String>? onStage}) async {
    files.add(file);
    shareTexts.add(shareText);
  }
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  Future<_Provider> mount(WidgetTester tester, Size size,
      {ExportController? export}) async {
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
            home: Scaffold(body: TransactionScreen(export: export)))));
    await tester.pumpAndSettle();
    return provider;
  }

  /// Taps a header action, opening the "more" menu first on narrow headers.
  Future<void> tapHeaderAction(
      WidgetTester tester, Key key, String menuLabel) async {
    if (find.byKey(key).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(key));
    } else {
      await tester.tap(find.byKey(PageHeader.moreActionsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(menuLabel).last);
    }
    await tester.pumpAndSettle();
  }

  AppSquareIconButton headerButton(WidgetTester tester, Key key) =>
      tester.widget<AppSquareIconButton>(find.byKey(key));

  testWidgets('desktop retains columns, reference copy and details action',
      (tester) async {
    await mount(tester, const Size(1440, 900));
    expect(headerButton(tester, TransactionScreen.exportKey).tooltip,
        'Export');
    expect(headerButton(tester, TransactionScreen.exportKey).onPressed,
        isNotNull);
    expect(find.byKey(TransactionScreen.refreshKey), findsOneWidget);
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

  testWidgets('typing in Search is debounced and Enter searches at once',
      (tester) async {
    final provider = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField).first, 'INV');
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.exportFetches, 0);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(provider.exportFetches, 1);
    await tester.pump(const Duration(milliseconds: 500));
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
    await tester.tap(find.byKey(TransactionScreen.filterToggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(TransactionScreen.filtersKey), findsNothing);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(provider.requests.last, {
      'supplierId': '7',
      'transactionType': 'Invoice',
      'type': null,
      'page': 2,
      'perPage': 50
    });
    await tester.tap(find.byKey(TransactionScreen.filterToggleKey));
    await tester.pumpAndSettle();
    expect(find.text('Test Supplier'), findsWidgets);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(provider.requests.last['supplierId'], isNull);
    expect(provider.requests.last['transactionType'], isNull);
    expect(provider.requests.last['page'], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export fetches with the applied filters and hands over a file',
      (tester) async {
    final delivery = _Delivery();
    final export = ExportController(deliver: delivery.call);
    final provider =
        await mount(tester, const Size(1440, 900), export: export);
    await tester.enterText(find.byType(TextField).first, 'INV-TEST');
    await tester.pumpAndSettle();
    final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('supplier-tx-export-test-')))!;
    addTearDown(() => directory.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.runAsync(() async {
      headerButton(tester, TransactionScreen.exportKey).onPressed!();
      // The file is written on a real isolate; wait for the export to end.
      for (var i = 0; i < 200 && export.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    expect(delivery.files, hasLength(1));
    expect(delivery.shareTexts, ['Supplier Transactions']);
    expect(provider.exportSearch, 'INV-TEST');
    expect(provider.exportStatus, isNull);
    expect(export.busy, isFalse);
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
      // Narrow headers fold Filters, Export and Refresh into one menu.
      expect(find.byKey(PageHeader.moreActionsKey),
          size.width < PageHeader.collapseActionsBelow
              ? findsOneWidget
              : findsNothing);
      final layout = tester.widget<ListPageScaffold<TransactionModel>>(
          find.byType(ListPageScaffold<TransactionModel>));
      expect(layout.minTableWidth, 1200);
      expect(find.textContaining('INR 250.00'), findsOneWidget);
      expect(find.byType(AppDataTable<TransactionModel>),
          size.width >= 700 ? findsOneWidget : findsNothing);
      if (size.width < 700) {
        expect(find.byKey(TransactionScreen.filtersKey), findsNothing);
        await tapHeaderAction(
            tester, TransactionScreen.filterToggleKey, 'Filters');
      }
      expect(find.byKey(TransactionScreen.filtersKey), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'desktop keeps its table below 1200 pixels and scrolls to actions',
      (tester) async {
    await mount(tester, const Size(1100, 900));
    expect(find.byType(AppDataTable<TransactionModel>), findsOneWidget);
    expect(find.text('Transaction Type'), findsOneWidget);
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
