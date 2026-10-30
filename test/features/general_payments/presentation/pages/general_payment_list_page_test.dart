import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/core/ui/ui.dart' show AppDialog;
import 'package:pos_machine/features/general_payments/data/general_payment_api.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';
import 'package:pos_machine/features/general_payments/presentation/navigation/general_payment_navigation.dart';
import 'package:pos_machine/features/general_payments/presentation/pages/general_payment_list_page.dart';
import 'package:pos_machine/features/general_payments/presentation/widgets/general_payment_results.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../../../test_support/app_settings_fakes.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../../../test_support/network_fakes.dart';
import '../../support/general_payment_fixtures.dart';

/// The list API, one page of [rows] per store.
class _Backend {
  final requests = <Uri>[];
  bool fail = false;
  Map<String, List<Map<String, dynamic>>> rows = {
    '2': [
      paymentJson(184, amount: 50),
      paymentJson(177,
          type: 'LOAN',
          date: '2026-09-04',
          amount: 2000,
          category: '8497',
          categoryLabel: 'Term Loan',
          debitId: 376,
          debit: 'Loan Account'),
      paymentJson(176,
          type: 'INCOME',
          date: '2026-09-04',
          amount: 2000,
          category: '8491',
          categoryLabel: 'Manufacturing Income',
          debitId: 12,
          debit: 'Bank Account',
          creditId: 375,
          credit: 'Direct Income Account'),
      paymentJson(30, type: 'ASSET', date: '2026-05-10', amount: 32800),
    ],
    '7': [
      paymentJson(5, amount: 70),
      // A repayment, saved as its own entry type.
      {
        ...paymentJson(9,
            type: 'LOAN_REPAY',
            amount: 300,
            category: '8495',
            categoryLabel: 'Bank Loan',
            debitId: 376,
            debit: 'Loan Account'),
        'entry_type_label': 'Loan Repayment',
      },
    ],
  };

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) async {
    requests.add(uri);
    if (fail) return http.Response('down', 500);
    return jsonResponse(apiPage(rows[uri.queryParameters['store_id']]!));
  }
}

/// Session whose store follows [_Stores].
class _Session extends FakeTenantSession {
  const _Session(this.stores);
  final _Stores stores;
  @override
  Future<int?> activeStoreId() async => stores.activeStore?.storeId;
}

class _Stores extends StoreSessionProvider {
  Store? active = Store(storeId: 2, storeName: 'Main Store');
  @override
  Store? get activeStore => active;
  void switchTo(Store store) {
    active = store;
    notifyListeners();
  }
}

Finder _total(GeneralPaymentType type, String value) => find.descendant(
    of: find.byKey(ValueKey('general-payments-total-${type.name}')),
    matching: find.text(value));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    Get.testMode = true;
  });
  setUp(() => SharedPreferences.setMockInitialValues({'api_key': 'tenant'}));
  tearDown(Get.reset);

  Future<(_Backend, CapturingExport, _Stores)> mount(WidgetTester tester,
      {Size size = const Size(1440, 900), bool fail = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = _Backend()..fail = fail;
    final capture = CapturingExport(), stores = _Stores();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('token', 1)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) =>
                  FakeAppSettingsProvider(testAppSettings(currency: 'SAR'))),
          ChangeNotifierProvider<StoreSessionProvider>.value(value: stores),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(
                body: GeneralPaymentListPage(
                    export: capture,
                    api: GeneralPaymentApi(
                        endpoint: () =>
                            'https://x.test/api/v1/general-payment/list-general-payments',
                        get: backend.get,
                        session: _Session(stores)))))));
    await tester.pumpAndSettle();
    return (backend, capture, stores);
  }

  testWidgets('lists every entry type with the four totals', (tester) async {
    final (backend, _, _) = await mount(tester);
    expect(backend.requests.single.queryParameters,
        {'store_id': '2', 'per_page': '100'});
    expect(find.text('General Payments'), findsOneWidget);
    for (final ref in ['EXP00184', 'LON00177', 'INC00176', 'AST00030']) {
      expect(find.text(ref), findsOneWidget);
    }
    expect(find.text('Loan Account'), findsOneWidget);
    expect(_total(GeneralPaymentType.expense, 'SAR 50.00'), findsOneWidget);
    expect(_total(GeneralPaymentType.asset, 'SAR 32,800.00'), findsOneWidget);
    expect(_total(GeneralPaymentType.income, 'SAR 2,000.00'), findsOneWidget);
    expect(_total(GeneralPaymentType.loan, 'SAR 2,000.00'), findsOneWidget);
    expect(find.text('4 entries'), findsOneWidget);
  });

  testWidgets('the entry type filter narrows the table and the totals',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<GeneralPaymentType?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    expect(find.text('INC00176'), findsOneWidget);
    expect(find.text('EXP00184'), findsNothing);
    expect(_total(GeneralPaymentType.expense, 'SAR 0.00'), findsOneWidget);
    expect(_total(GeneralPaymentType.income, 'SAR 2,000.00'), findsOneWidget);
    expect(find.text('1 of 4 entries'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('EXP00184'), findsOneWidget);
  });

  testWidgets('export holds the filtered entries and says how', (tester) async {
    final (_, capture, _) = await mount(tester);
    await useTempExportDirectory(tester, 'general-payments-');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Reference Number'), 'lon');
    await tester.pumpAndSettle();
    expect(find.text('EXP00184'), findsNothing);
    await tester.tap(find.byKey(GeneralPaymentListPage.exportKey));
    await tester.pumpAndSettle();
    expect(capture.runs, 1);
    final file = (await tester.runAsync(capture.createFile!))!;
    final sheet =
        Excel.decodeBytes(await tester.runAsync(file.readAsBytes) as List<int>)
            .tables['General Payments']!;
    expect(sheet.maxRows, 2);
    expect([
      for (final c in sheet.rows[0]) c?.value.toString()
    ], [
      'Reference number',
      'Entry type',
      'Payment date',
      'Category',
      'Debit A/c',
      'Credit A/c',
      'Amount (SAR)',
      'Payment method',
      'Status',
      'Description',
      'Notes',
      'Created by',
      'Applied filters',
    ]);
    final row = sheet.rows[1];
    expect(row[0]?.value.toString(), 'LON00177');
    expect(row[1]?.value.toString(), 'Loan');
    expect(row[2]?.value.toString(), '2026-09-04');
    expect(row[6]?.value, isNot(isA<TextCellValue>()), reason: 'numeric');
    expect(num.parse(row[6]!.value.toString()), 2000);
    expect(row[8]?.value.toString(), 'Success');
    expect(row[12]?.value.toString(), 'Reference Number: lon');
  });

  testWidgets('a failed load says so and Retry recovers', (tester) async {
    final (backend, capture, _) = await mount(tester, fail: true);
    expect(
        find.text(
            'Could not load general payments. Check the connection and try again.'),
        findsOneWidget);
    await tester.tap(find.byKey(GeneralPaymentListPage.exportKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(capture.runs, 0, reason: 'Export is disabled');
    backend.fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('EXP00184'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
  });

  testWidgets('a store switch shows the new store\'s entries', (tester) async {
    final (backend, _, stores) = await mount(tester);
    stores.switchTo(Store(storeId: 7, storeName: 'Second'));
    await tester.pumpAndSettle();
    expect(backend.requests.last.queryParameters['store_id'], '7');
    expect(find.text('EXP00005'), findsOneWidget);
    expect(find.text('EXP00184'), findsNothing);
    expect(_total(GeneralPaymentType.expense, 'SAR 70.00'), findsOneWidget);
  });

  testWidgets('View shows the entry with its journal over the list',
      (tester) async {
    await mount(tester);
    // Rows: EXP00184, LON00177, INC00176, AST00030.
    await tester.tap(find.byIcon(Icons.visibility_outlined).at(1));
    await tester.pumpAndSettle();
    final dialog = find.byType(AppDialog);
    expect(dialog, findsOneWidget);
    Finder inDialog(String text) =>
        find.descendant(of: dialog, matching: find.text(text));
    expect(inDialog('LON00177'), findsOneWidget);
    expect(inDialog('Term Loan'), findsOneWidget);
    expect(inDialog('Admin'), findsOneWidget);
    final journal =
        find.byKey(const ValueKey('general-payment-details-journal'));
    expect(find.descendant(of: journal, matching: find.text('Loan Account')),
        findsOneWidget);
    expect(find.descendant(of: journal, matching: find.text('Cash Account')),
        findsOneWidget);
    expect(find.descendant(of: journal, matching: find.text('SAR 2,000.00')),
        findsNWidgets(2));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.text('LON00177'), findsOneWidget, reason: 'list unchanged');
  });

  testWidgets('on phones a card opens the same details', (tester) async {
    await mount(tester, size: const Size(375, 812));
    // The first card; the others may be below the fold.
    await tester.tap(find.text('EXP00184'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AppDialog), matching: find.text('Transportation')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New Entry opens on the filtered type with next references',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<GeneralPaymentType?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Entry'));
    await tester.pumpAndSettle();
    expect(Get.find<SideBarController>().index.value,
        SideBarController.generalPaymentCreateScreenIndex);
    final request = GeneralPaymentNavigation.takeCreateRequest()!;
    expect(request.type, GeneralPaymentType.income);
    expect(request.nextReferences, {
      'EXP': 'EXP00185',
      'AST': 'AST00031',
      'INC': 'INC00177',
      'LON': 'LON00178',
    });
  });

  testWidgets('a store switch drops a category the new store does not use',
      (tester) async {
    final (_, _, stores) = await mount(tester);
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Term Loan').last);
    await tester.pumpAndSettle();
    expect(find.text('LON00177'), findsOneWidget);
    expect(find.text('EXP00184'), findsNothing);
    // Store 7 has no Term Loan: its entries show instead of nothing.
    stores.switchTo(Store(storeId: 7, storeName: 'Second'));
    await tester.pumpAndSettle();
    expect(find.text('EXP00005'), findsOneWidget);
    expect(find.text('No entries match these filters'), findsNothing);
  });

  testWidgets('a loan repayment reads as one and counts in Total Loan',
      (tester) async {
    final (_, _, stores) = await mount(tester);
    stores.switchTo(Store(storeId: 7, storeName: 'Second'));
    await tester.pumpAndSettle();
    expect(find.text('LRP00009'), findsOneWidget);
    expect(find.text('Loan repayment'), findsOneWidget);
    expect(_total(GeneralPaymentType.loan, 'SAR 300.00'), findsOneWidget);
    // A tap on the reference opens View too.
    await tester.tap(find.text('LRP00009'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AppDialog), matching: find.text('Loan Account')),
        findsOneWidget);
  });

  testWidgets('phones show cards and start with the filters hidden',
      (tester) async {
    await mount(tester, size: const Size(375, 812));
    expect(tester.takeException(), isNull);
    expect(find.byType(GeneralPaymentCard), findsWidgets);
    expect(_total(GeneralPaymentType.asset, 'SAR 32,800.00'), findsOneWidget);
    expect(find.text('Tap to filter entries'), findsNothing);
    await tapFilterToggle(tester, key: GeneralPaymentListPage.filterToggleKey);
    await tester.pumpAndSettle();
    expect(find.text('Tap to filter entries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
