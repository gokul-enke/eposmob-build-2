import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import '../../../domain/models/expense.dart';

Widget expenseAccountingCard({
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
