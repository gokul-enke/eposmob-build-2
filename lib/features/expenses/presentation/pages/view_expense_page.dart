import '../widgets/details/expense_details_card.dart';
import '../widgets/details/expense_accounting_card.dart';
import '../widgets/details/expense_details_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import '../navigation/expense_navigation.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import '../state/expense_view_controller.dart';

class ViewExpensePage extends StatefulWidget {
  const ViewExpensePage({super.key});
  @override
  State<ViewExpensePage> createState() => _ViewExpensePageState();
}

class _ViewExpensePageState extends State<ViewExpensePage> {
  late final ExpenseProvider _provider;
  late final AuthModel _auth;
  late final ExpenseViewController _selection;
  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseProvider>();
    _auth = context.read<AuthModel>();
    _selection = Get.put(ExpenseViewController());
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve the selected reference from GetX controller
    final ExpenseViewController evc = _selection;
    final selectedRef = evc.selectedRef.value;

    final provider = Provider.of<ExpenseProvider>(context);
    final token = _auth.token;
    final currency =
        Provider.of<AppSettingsProvider>(context).appSettings?.currency ?? "";

    if (token != null &&
        provider.categoryOptions.isEmpty &&
        provider.debitAccountOptions.isEmpty &&
        provider.creditAccountOptions.isEmpty &&
        provider.paymentMethodOptions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _provider.fetchAccountOptions(accessToken: token);
      });
    }

    final expense = provider.allFiltered.firstWhere(
      (e) => e.referenceNumber == selectedRef,
      orElse: () => Expense(
        referenceNumber: selectedRef.isNotEmpty ? selectedRef : 'EXP00000',
        paymentDate: DateTime.now(),
        category: 'N/A',
        categoryId: null,
        debitAccount: 'N/A',
        debitAccountId: null,
        creditAccount: 'N/A',
        creditAccountId: null,
        amount: 0.0,
        paymentMethod: 'N/A',
        paymentMethodId: null,
        description: 'N/A',
      ),
    );

    final String displayCategory = provider.resolveOptionLabel(
      provider.categoryOptions,
      expense.category,
      id: expense.categoryId,
    );

    final String displayPaymentMethod = provider.resolveOptionLabel(
      provider.paymentMethodOptions,
      expense.paymentMethod,
      id: expense.paymentMethodId,
    );

    final String displayDebitAccount = provider.resolveOptionLabel(
      provider.debitAccountOptions,
      expense.debitAccount,
      id: expense.debitAccountId,
    );

    final String displayCreditAccount = provider.resolveOptionLabel(
      provider.creditAccountOptions,
      expense.creditAccount,
      id: expense.creditAccountId,
    );

    // Formatted date string
    final dateStr = DateHelper.formatDate(expense.paymentDate);

    return SafeArea(
      child: CustomBoxShadowContainer(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        padding: const EdgeInsets.all(20),
        circleRadius: 22,
        offsetValue: const Offset(1, 1),
        blurRadius: 6,
        color: Colors.white,
        child: ListView(
          children: [
            expenseDetailsHeader(
                expense.referenceNumber, ExpenseNavigation.openList),
            const SizedBox(height: 25),

            // Details Card
            expenseDetailsCard(
              expense: expense,
              dateStr: dateStr,
              displayCategory: displayCategory,
              displayPaymentMethod: displayPaymentMethod,
              currency: currency,
            ),
            const SizedBox(height: 20),

            // Accounting double-entry card
            expenseAccountingCard(
              expense: expense,
              displayDebitAccount: displayDebitAccount,
              displayCreditAccount: displayCreditAccount,
              currency: currency,
            ),
            const SizedBox(height: 25),

            // Back button
            Row(
              children: [
                CustomRoundButtonAdvanced(
                  title: 'expense.back_to_list'.tr,
                  fct: () {
                    ExpenseNavigation
                        .openList(); // Navigate back to ExpenseListPage
                  },
                  width: 140,
                  height: 40,
                  fontSize: 12,
                  radius: 5,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
