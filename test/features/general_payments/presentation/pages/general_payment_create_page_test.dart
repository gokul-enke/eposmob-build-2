import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/general_payments/data/general_payment_form_api.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';
import 'package:pos_machine/features/general_payments/presentation/navigation/general_payment_navigation.dart';
import 'package:pos_machine/features/general_payments/presentation/pages/general_payment_create_page.dart';
import 'package:pos_machine/features/general_payments/presentation/widgets/general_payment_form_actions.dart';
import 'package:pos_machine/features/general_payments/presentation/widgets/general_payment_form_sections.dart';
import 'package:pos_machine/models/company_accounts.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/company_account_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import '../../../../test_support/app_settings_fakes.dart';
import '../../../../test_support/app_translations.dart';
import '../../../../test_support/network_fakes.dart';

/// Company Accounts setup: cash goes with the Cash Account, card with the
/// Bank Account.
class _Companies extends CompanyAccountProvider {
  @override
  Future<dynamic> listCompanyAccounts(
      {required String accessToken,
      String? filterName,
      String? filterType,
      String? filterPaymentMethod,
      String? filterStatus,
      bool sortAscending = false,
      int page = 1,
      bool loadAll = false}) async {
    companyAccountsList = [
      CompanyAccountsData(name: 'Cash Account', paymentMethod: ['CASH']),
      CompanyAccountsData(name: 'Bank Account', paymentMethod: ['CARD']),
    ];
    return null;
  }
}

class _Master extends MasterDataProvider {
  final codes = <String>[];

  @override
  Future<MasterData?> fetchMasterData(String code) async {
    codes.add(code);
    final values = switch (code) {
      'EXPENSE_CATEGORY' => [
          MasterDataValue(
              id: 8192, value: 'TRANSPORT', description: 'Transportation')
        ],
      'INCOME_CATEGORY' => [
          MasterDataValue(
              id: 8491, value: 'MFG', description: 'Manufacturing Income')
        ],
      _ => <MasterDataValue>[],
    };
    return MasterData(status: 'success', message: '', data: values);
  }

  @override
  List<MasterDataValue>? get paymentMethods => null;

  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
          {bool forceRefresh = false}) async =>
      [
        MasterDataValue(
            id: 7973, value: 'CARD', description: 'Card', code: 'CARD'),
        MasterDataValue(
            id: 7974, value: 'CASH', description: 'Cash', code: 'CASH'),
      ];
}

/// account-options and create-general-payment as the live API answers.
class _Backend {
  final asked = <Map<String, String>>[];
  final saved = <Map<String, dynamic>>[];

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) async {
    asked.add(uri.queryParameters);
    final type = uri.queryParameters['entry_type']!;
    final loan = uri.queryParameters['loan_type'];
    const cashBank = [
      {'id': 11, 'name': 'Cash Account'},
      {'id': 12, 'name': 'Bank Account'},
    ];
    const loanAccount = [
      {'id': 376, 'name': 'Loan Account'}
    ];
    final (debit, credit) = switch (type) {
      'INCOME' => (
          cashBank,
          [
            {'id': 342, 'name': 'Indirect Income Account'}
          ]
        ),
      'LOAN' when loan == 'LOAN_REPAY' => (loanAccount, cashBank),
      'LOAN' => (cashBank, loanAccount),
      'ASSET' => (
          [
            {'id': 341, 'name': 'Fixed Asset Account'}
          ],
          cashBank
        ),
      _ => (
          [
            {'id': 20, 'name': 'Indirect Expense Account'}
          ],
          cashBank
        ),
    };
    return jsonResponse({
      'success': true,
      'data': {
        'entry_type': type,
        'loan_type': loan,
        'expense_accounts': debit,
        'payment_accounts': credit,
      }
    });
  }

  /// The server's refusal, when set (a 422 with field errors).
  String? refuse;

  Future<http.Response> post(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    saved.add(jsonDecode(body as String) as Map<String, dynamic>);
    if (refuse case final message?) {
      return jsonResponse({
        'message': 'The given data was invalid.',
        'errors': {
          'payment_date': [message]
        }
      }, 422);
    }
    return jsonResponse({
      'success': true,
      'data': {'reference_number': 'EXP00120'}
    }, 201);
  }
}

/// Lets a toast's timer run out.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String field, String option) async {
  await tester.tap(find.byKey(ValueKey('general-payment-$field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    Get.testMode = true;
  });
  setUp(() => SharedPreferences.setMockInitialValues({'api_key': 'tenant'}));
  tearDown(Get.reset);

  // Tall enough that the whole form is on screen.
  Future<(_Backend, _Master)> mount(WidgetTester tester,
      {Size size = const Size(1440, 1800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = _Backend(), master = _Master();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('token', 1)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) =>
                  FakeAppSettingsProvider(testAppSettings(currency: 'SAR'))),
          ChangeNotifierProvider<MasterDataProvider>.value(value: master),
          ChangeNotifierProvider<CompanyAccountProvider>(
              create: (_) => _Companies()),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home: Scaffold(
                body: GeneralPaymentCreatePage(
                    api: GeneralPaymentFormApi(
                        accountsEndpoint: () =>
                            'https://x.test/account-options',
                        createEndpoint: () => 'https://x.test/create',
                        get: backend.get,
                        post: backend.post,
                        session: const FakeTenantSession(storeId: 2)))))));
    await tester.pumpAndSettle();
    return (backend, master);
  }

  testWidgets('opens on the type and reference the list asked for',
      (tester) async {
    GeneralPaymentNavigation.openCreate(
        type: GeneralPaymentType.income,
        nextReferences: const {'INC': 'INC00008'});
    final (backend, master) = await mount(tester);
    expect(backend.asked.single, {'entry_type': 'INCOME'});
    expect(master.codes, ['INCOME_CATEGORY']);
    expect(find.text('INC00008'), findsOneWidget);
    // Required fields carry a " *".
    for (final label in [
      'Received date *',
      'Income category *',
      'Received in (Debit) *',
      'Income account (Credit) *',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Indirect Income Account'), findsWidgets,
        reason: 'the only income account is chosen');
    expect(GeneralPaymentNavigation.takeCreateRequest(), isNull,
        reason: 'taken once');
  });

  testWidgets('loans ask which way and repaying swaps the accounts',
      (tester) async {
    final (backend, _) = await mount(tester);
    expect(find.text('Expense account (Debit) *'), findsOneWidget);
    await tester.tap(find.text('Loan'));
    await tester.pumpAndSettle();
    expect(backend.asked.last, {'entry_type': 'LOAN', 'loan_type': 'LOAN_IN'});
    expect(find.text('Disbursement date *'), findsOneWidget);
    expect(find.text('Lender / Bank name'), findsOneWidget);
    expect(find.text('Loan account (Credit) *'), findsOneWidget);
    await tester.tap(find.text('Loan repayment'));
    await tester.pumpAndSettle();
    expect(
        backend.asked.last, {'entry_type': 'LOAN', 'loan_type': 'LOAN_REPAY'});
    expect(find.text('Loan account (Debit) *'), findsOneWidget);
    expect(find.text('Paid from (Credit) *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing choice is named before anything is sent',
      (tester) async {
    final (backend, _) = await mount(tester);
    await tester.tap(find.byKey(GeneralPaymentFormActions.createKey));
    await tester.pump();
    expect(find.text('Please choose a category.'), findsOneWidget);
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(backend.saved, isEmpty);
    await _settleToast(tester);
  });

  testWidgets('an expense is saved with its journal and returns to the list',
      (tester) async {
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    // The form starts on the day it opens; around midnight either day fits.
    final opened = day(DateTime.now());
    final (backend, _) = await mount(tester);
    final sidebar = Get.put(SideBarController())..index.value = 105;
    await _choose(tester, 'category', 'Transportation');
    await _choose(tester, 'credit', 'Bank Account');
    await _choose(tester, 'method', 'Card');
    await tester.enterText(
        find.byKey(GeneralPaymentFormSections.amountKey), '2000');
    await tester.pumpAndSettle();
    final journal = find.byKey(const ValueKey('general-payment-journal'));
    expect(
        find.descendant(
            of: journal, matching: find.text('Indirect Expense Account')),
        findsOneWidget);
    expect(find.descendant(of: journal, matching: find.text('SAR 2,000.00')),
        findsNWidgets(2));
    await tester.tap(find.byKey(GeneralPaymentFormActions.createKey));
    await tester.pumpAndSettle();
    final saved = backend.saved.single;
    expect([opened, day(DateTime.now())], contains(saved['payment_date']));
    expect(saved, {
      'entry_type': 'EXPENSE',
      'payment_date': saved['payment_date'],
      'category': '8192',
      'description': '',
      'amount': 2000.0,
      'payment_method': '7973',
      'expense_account_id': 20,
      'payment_account_id': 12,
      'status': 'SUCC',
      'notes': '',
      'store_id': 2,
    });
    expect(find.text('EXP00120 saved.'), findsOneWidget);
    expect(
        sidebar.index.value, SideBarController.generalPaymentListScreenIndex);
    await _settleToast(tester);
  });

  testWidgets('create & add another stays for the next entry', (tester) async {
    final (backend, _) = await mount(tester);
    final sidebar = Get.put(SideBarController())..index.value = 105;
    await _choose(tester, 'category', 'Transportation');
    await _choose(tester, 'credit', 'Cash Account');
    await _choose(tester, 'method', 'Cash');
    await tester.enterText(
        find.byKey(GeneralPaymentFormSections.amountKey), '50');
    await tester.tap(find.byKey(GeneralPaymentFormActions.createAnotherKey));
    await tester.pumpAndSettle();
    expect(backend.saved, hasLength(1));
    expect(sidebar.index.value, 105, reason: 'stays on New Entry');
    expect(find.text('EXP00121'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(GeneralPaymentFormSections.amountKey))
            .controller!
            .text,
        isEmpty);
    await _settleToast(tester);
  });

  testWidgets('a refused save shows why and keeps the entry', (tester) async {
    final (backend, _) = await mount(tester);
    backend.refuse = 'The payment date is in a closed period.';
    final sidebar = Get.put(SideBarController())..index.value = 105;
    await _choose(tester, 'category', 'Transportation');
    await _choose(tester, 'credit', 'Cash Account');
    await _choose(tester, 'method', 'Cash');
    await tester.enterText(
        find.byKey(GeneralPaymentFormSections.amountKey), '75');
    await tester.tap(find.byKey(GeneralPaymentFormActions.createKey));
    await tester.pumpAndSettle();
    expect(
        find.text('The payment date is in a closed period.'), findsOneWidget);
    expect(sidebar.index.value, 105, reason: 'stays to fix it');
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(GeneralPaymentFormSections.amountKey))
            .controller!
            .text,
        '75');
    await _settleToast(tester);
  });

  testWidgets('Enter on the amount does not save', (tester) async {
    final (backend, _) = await mount(tester);
    await _choose(tester, 'category', 'Transportation');
    await _choose(tester, 'credit', 'Cash Account');
    await _choose(tester, 'method', 'Cash');
    await tester.enterText(
        find.byKey(GeneralPaymentFormSections.amountKey), '75');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(backend.saved, isEmpty);
  });

  for (final size in [const Size(375, 812), const Size(768, 1024)]) {
    testWidgets('fits $size', (tester) async {
      await mount(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.byKey(GeneralPaymentFormActions.createKey), findsOneWidget);
      expect(find.byKey(const ValueKey('general-payment-journal')),
          findsOneWidget);
    });
  }
}
