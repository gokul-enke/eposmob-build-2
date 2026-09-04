import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:provider/provider.dart';

import '../../newcomponents/custom_round_button.dart';
import '../../newcomponents/custom_container_box.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/expense.dart';
import '../../providers/auth_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'expense_list_screen.dart'; // To access ExpenseViewController

class ViewExpenseScreen extends StatelessWidget {
  const ViewExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sideBarController = Get.find<SideBarController>();
    
    // Retrieve the selected reference from GetX controller
    final ExpenseViewController evc = Get.put(ExpenseViewController());
    final selectedRef = evc.selectedRef.value;

    final provider = Provider.of<ExpenseProvider>(context);
    final token = Provider.of<AuthModel>(context, listen: false).token;
    final currency = Provider.of<AppSettingsProvider>(context).appSettings?.currency ?? "";

    if (token != null &&
        provider.categoryOptions.isEmpty &&
        provider.debitAccountOptions.isEmpty &&
        provider.creditAccountOptions.isEmpty &&
        provider.paymentMethodOptions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ExpenseProvider>(context, listen: false)
            .fetchAccountOptions(accessToken: token);
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
            _buildHeader(expense.referenceNumber, sideBarController),
            const SizedBox(height: 25),
            
            // Details Card
            _buildDetailsCard(
              expense: expense,
              dateStr: dateStr,
              displayCategory: displayCategory,
              displayPaymentMethod: displayPaymentMethod,
              currency: currency,
            ),
            const SizedBox(height: 20),
            
            // Accounting double-entry card
            _buildAccountingCard(
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
                    sideBarController.index.value = 93; // Navigate back to ExpenseListScreen
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

  Widget _buildHeader(String refNumber, SideBarController sideBarController) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorManager.textColor),
          onPressed: () {
            sideBarController.index.value = 93; // Back to list
          },
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'expense.breadcrumb_view'.tr} $refNumber',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'expense.title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.20,
                    Colors.grey,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                Text(
                  refNumber,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.20,
                    Colors.grey,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                Text(
                  'expense.breadcrumb_view'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.20,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsCard({
    required Expense expense,
    required String dateStr,
    required String displayCategory,
    required String displayPaymentMethod,
    required String currency,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              'expense.expense_details'.tr,
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s14,
                0.1,
                ColorManager.textColor,
              ),
            ),
          ),
          // Content Grid
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailItem('expense.reference_no'.tr, expense.referenceNumber),
                    ),
                    Expanded(
                      child: _buildDetailItemWithBadge(
                        'expense.label_entry_type'.tr,
                        'expense.entry_type_value'.tr,
                        Colors.orange.shade50,
                        Colors.orange
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem('expense.date'.tr, dateStr),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailItemWithBadge(
                        'expense.category'.tr,
                        displayCategory,
                        Colors.blue.shade50,
                        Colors.blue
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem('expense.label_description_vendor'.tr, expense.description.isNotEmpty ? expense.description : "-"),
                    ),
                    Expanded(
                      child: _buildDetailItem('expense.amount'.tr, "$currency ${expense.amount.toStringAsFixed(2)}"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailItemWithBadge(
                        'expense.payment_method'.tr,
                        displayPaymentMethod,
                        Colors.blue.shade50,
                        Colors.blue
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItemWithBadge(
                        'expense.status'.tr,
                        UiCodeLabels.status(expense.status),
                        Colors.green.shade50,
                        Colors.green
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                _buildDetailItem('expense.label_notes_remarks'.tr, expense.notes.isNotEmpty ? expense.notes : 'expense.no_remarks'.tr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountingCard({
    required Expense expense,
    required String displayDebitAccount,
    required String displayCreditAccount,
    required String currency,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              'expense.accounting_title'.tr,
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s14,
                0.1,
                ColorManager.textColor,
              ),
            ),
          ),
          // Content Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'expense.label_debit_expense_ac'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s12,
                          0.1,
                          Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${'expense.label_debit_prefix'.tr}$displayDebitAccount',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s13,
                          0.1,
                          Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'expense.label_credit_cash_ac'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s12,
                          0.1,
                          Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${'expense.label_credit_prefix'.tr}$displayCreditAccount',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s13,
                          0.1,
                          Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'expense.label_transaction_amount'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s12,
                          0.1,
                          Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$currency ${expense.amount.toStringAsFixed(2)}",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s13,
                          0.1,
                          ColorManager.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s11,
            0.1,
            Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s13,
            0.1,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItemWithBadge(String label, String value, Color badgeBg, Color badgeText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s11,
            0.1,
            Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: badgeText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}


