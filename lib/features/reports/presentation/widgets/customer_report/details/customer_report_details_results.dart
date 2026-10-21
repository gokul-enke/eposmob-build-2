import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_transaction.dart';

String _tr(String key) => 'customer_transaction_report.$key'.tr;
String _value(String? value) => value ?? _tr('na');

AppBadge _typeBadge(String? value) => AppBadge(
      label: _value(value),
      tone: value?.toLowerCase() == 'credit'
          ? AppBadgeTone.success
          : AppBadgeTone.danger,
    );

AppBadge _statusBadge(String? value) {
  final status = _value(value);
  final (label, tone) = switch (status.toUpperCase()) {
    'SUCC' || 'SUCCESS' || 'COMPLETED' => (
        _tr('success_label'),
        AppBadgeTone.success
      ),
    'INIT' || 'INITIATED' || 'PENDING' => (
        _tr('pending_label'),
        AppBadgeTone.warning
      ),
    'FAIL' || 'FAILED' || 'CANCELLED' => (
        _tr('failed_label'),
        AppBadgeTone.danger
      ),
    _ => (status.isEmpty ? _tr('na') : status, AppBadgeTone.neutral),
  };
  return AppBadge(label: label, tone: tone);
}

/// Same seven columns and unrounded source values in the shared table.
List<TableColumnDef<ListTransaction>> customerReportDetailsColumns() => [
      TableColumnDef(
        label: _tr('sl_no_col'),
        flex: .6,
        cellBuilder: (_, number) => TableCells.number(number),
      ),
      TableColumnDef(
        label: _tr('order_number_col'),
        flex: 1.5,
        cellBuilder: (tx, _) => TableCells.text(_value(tx.orderNumber)),
      ),
      TableColumnDef(
        label: _tr('transaction_type_label'),
        flex: 1.5,
        cellBuilder: (tx, _) => TableCells.text(_value(tx.transactionType)),
      ),
      TableColumnDef(
        label: _tr('amount_col'),
        cellBuilder: (tx, _) => TableCells.text(tx.amount ?? '0.00'),
      ),
      TableColumnDef(
        label: _tr('type_label'),
        cellBuilder: (tx, _) => TableCells.widget(_typeBadge(tx.type)),
      ),
      TableColumnDef(
        label: _tr('transaction_date_col'),
        flex: 1.5,
        cellBuilder: (tx, _) => TableCells.text(_value(tx.date)),
      ),
      TableColumnDef(
        label: _tr('status_label'),
        cellBuilder: (tx, _) => TableCells.widget(_statusBadge(tx.status)),
      ),
    ];

/// Read-only narrow-layout card with the same transaction fields as the table.
class CustomerReportDetailsCard extends StatelessWidget {
  const CustomerReportDetailsCard({
    super.key,
    required this.transaction,
    required this.number,
  });

  final ListTransaction transaction;
  final int number;

  @override
  Widget build(BuildContext context) => AppListCard(
        title: '#$number  ${_value(transaction.orderNumber)}',
        subtitle: _value(transaction.date),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              _typeBadge(transaction.type),
              _statusBadge(transaction.status),
            ]),
            InfoRow(
              icon: Icons.receipt_long_outlined,
              label: _tr('transaction_type_label'),
              value: _value(transaction.transactionType),
            ),
            InfoRow(
              icon: Icons.payments_outlined,
              label: _tr('amount_col'),
              value: transaction.amount ?? '0.00',
            ),
          ],
        ),
      );
}
