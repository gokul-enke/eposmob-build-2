import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/company_account_provider.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_view_controller.dart';
import '../../../test_support/app_settings_fakes.dart';
import '../../../test_support/app_translations.dart';
import 'expense_fixtures.dart';

class ExpenseMasterDataFake extends MasterDataProvider {
  @override
  Future<MasterData?> fetchMasterData(String code) async => null;
  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
          {bool forceRefresh = false}) async =>
      null;
}

Future<ExpenseProvider> mountExpensePage(
    WidgetTester tester, Widget page, Size size,
    {MasterDataProvider? master,
    ExpenseProvider? expenses,
    Key? captureKey}) async {
  useSurfaceSize(tester, size);
  Get.testMode = true;
  Get.put(SideBarController());
  final p = expenses ?? ExpenseProvider();
  p.addExpense(Expense.fromJson({...row(1), 'reference_number': 'EXP00001'}));
  p.categoryOptions = [
    {'id': '1', 'name': 'Rent'}
  ];
  p.debitAccountOptions = [
    {'id': 2, 'name': 'Office'}
  ];
  p.creditAccountOptions = [
    {'id': 3, 'name': 'Cash'}
  ];
  p.paymentMethodOptions = [
    {'id': '4', 'name': 'Cash'}
  ];
  Get.put(ExpenseViewController()).selectedRef.value = 'EXP00001';
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ExpenseProvider>.value(value: p),
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) =>
                FakeAppSettingsProvider(testAppSettings(currency: 'SAR'))),
        ChangeNotifierProvider<MasterDataProvider>(
            create: (_) => master ?? ExpenseMasterDataFake()),
        ChangeNotifierProvider(create: (_) => CompanyAccountProvider()),
      ],
      child: GetMaterialApp(
          translations: EnglishTranslations(),
          locale: const Locale('en'),
          home:
              Scaffold(body: RepaintBoundary(key: captureKey, child: page)))));
  await tester.pumpAndSettle();
  return p;
}
