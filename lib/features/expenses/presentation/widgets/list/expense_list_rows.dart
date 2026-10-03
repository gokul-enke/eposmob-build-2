import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import '../../../domain/models/expense.dart';
import 'expense_list_status_pill.dart';

class ExpenseListRows {
  const ExpenseListRows({required this.onCopy, required this.onView});
  final void Function(Expense) onCopy;
  final void Function(Expense) onView;

  /// Blank values show as a dash, as in the other list columns.
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;

  Widget _copyButton(Expense expense) => IconButton(
        icon: const Icon(Icons.copy_outlined, size: 16),
        tooltip: 'expense.copied_to_clipboard'.tr,
        onPressed: () => onCopy(expense),
      );

  Widget _referenceCell(Expense expense) => Row(children: [
        Expanded(child: TableCells.text(_orDash(expense.referenceNumber))),
        _copyButton(expense),
      ]);

  String _amount(Expense expense, String currency) =>
      '$currency ${expense.amount.toStringAsFixed(2)}';

  Widget card(Expense expense, String currency) => AppListCard(
        leading: const AppIconTile(
            icon: Icons.payments_outlined,
            size: 42,
            iconSize: 20,
            background: AppColors.softBlue,
            foreground: AppColors.primary),
        title: _orDash(expense.category),
        subtitle: DateHelper.formatDate(expense.paymentDate),
        trailing: ExpenseListStatusPill(status: expense.status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                  icon: Icons.payments_outlined,
                  label: 'expense.amount'.tr,
                  value: _amount(expense, currency)),
              AppMetric(
                  icon: Icons.event_outlined,
                  label: 'expense.col_payment_date'.tr,
                  value: DateHelper.formatDate(expense.paymentDate)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
                icon: Icons.tag,
                label: 'expense.col_reference_number'.tr,
                value: _orDash(expense.referenceNumber),
                trailing: _copyButton(expense)),
            InfoRow(
                icon: Icons.account_balance_outlined,
                label: 'expense.col_debit_ac'.tr,
                value: _orDash(expense.debitAccount)),
            InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'expense.col_credit_ac'.tr,
                value: _orDash(expense.creditAccount)),
          ],
        ),
        actionLabel: 'list.view'.tr,
        actionIcon: Icons.visibility_outlined,
        onAction: () => onView(expense),
      );

  List<TableColumnDef<Expense>> columns(String currency) => [
        TableColumnDef(
            label: 'expense.col_reference_number'.tr,
            flex: 1.5,
            cellBuilder: (e, _) => _referenceCell(e)),
        TableColumnDef(
            label: 'expense.col_payment_date'.tr,
            cellBuilder: (e, _) =>
                TableCells.text(_orDash(DateHelper.formatDate(e.paymentDate)))),
        TableColumnDef(
            label: 'expense.category'.tr,
            flex: 1.4,
            cellBuilder: (e, _) => TableCells.text(_orDash(e.category))),
        TableColumnDef(
            label: 'expense.col_debit_ac'.tr,
            flex: 1.4,
            cellBuilder: (e, _) => TableCells.text(_orDash(e.debitAccount))),
        TableColumnDef(
            label: 'expense.col_credit_ac'.tr,
            flex: 1.4,
            cellBuilder: (e, _) => TableCells.text(_orDash(e.creditAccount))),
        TableColumnDef(
            label: 'expense.amount'.tr,
            flex: 1.1,
            cellBuilder: (e, _) => TableCells.text(_amount(e, currency))),
        TableColumnDef(
            label: 'expense.status'.tr,
            cellBuilder: (e, _) =>
                TableCells.widget(ExpenseListStatusPill(status: e.status))),
        TableColumnDef(
            label: 'expense.breadcrumb_view'.tr,
            cellBuilder: (e, _) => TableCells.action(
                label: 'list.view'.tr,
                icon: Icons.visibility_outlined,
                onPressed: () => onView(e))),
      ];
}
