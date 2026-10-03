import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import '../../../domain/models/expense.dart';
import 'expense_detail_items.dart';

Widget expenseDetailsCard({
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
                    child: expenseDetailItem(
                        'expense.reference_no'.tr, expense.referenceNumber),
                  ),
                  Expanded(
                    child: expenseDetailItemWithBadge(
                        'expense.label_entry_type'.tr,
                        'expense.entry_type_value'.tr,
                        Colors.orange.shade50,
                        Colors.orange),
                  ),
                  Expanded(
                    child: expenseDetailItem('expense.date'.tr, dateStr),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: expenseDetailItemWithBadge('expense.category'.tr,
                        displayCategory, Colors.blue.shade50, Colors.blue),
                  ),
                  Expanded(
                    child: expenseDetailItem(
                        'expense.label_description_vendor'.tr,
                        expense.description.isNotEmpty
                            ? expense.description
                            : "-"),
                  ),
                  Expanded(
                    child: expenseDetailItem('expense.amount'.tr,
                        "$currency ${expense.amount.toStringAsFixed(2)}"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: expenseDetailItemWithBadge(
                        'expense.payment_method'.tr,
                        displayPaymentMethod,
                        Colors.blue.shade50,
                        Colors.blue),
                  ),
                  Expanded(
                    child: expenseDetailItemWithBadge(
                        'expense.status'.tr,
                        UiCodeLabels.status(expense.status),
                        Colors.green.shade50,
                        Colors.green),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              expenseDetailItem(
                  'expense.label_notes_remarks'.tr,
                  expense.notes.isNotEmpty
                      ? expense.notes
                      : 'expense.no_remarks'.tr),
            ],
          ),
        ),
      ],
    ),
  );
}
