import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';

String _tr(String key) => 'supplier_transaction_report.$key'.tr;
String _amount(SupplierTransaction row) =>
    '${row.currency} ${double.tryParse(row.amount)?.toStringAsFixed(2) ?? row.amount}';
AppBadge _type(String type) => AppBadge(
    label: type,
    tone: type.toLowerCase() == 'credit'
        ? AppBadgeTone.success
        : AppBadgeTone.danger);
AppBadge _status(String status) {
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

List<TableColumnDef<SupplierTransaction>> supplierReportDetailsColumns() => [
      TableColumnDef(
          label: _tr('date_col'),
          cellBuilder: (row, _) => TableCells.text(row.date)),
      TableColumnDef(
          label: _tr('reference_col'),
          flex: 1.4,
          cellBuilder: (row, _) => TableCells.text(row.reference)),
      TableColumnDef(
          label: _tr('type_label'),
          cellBuilder: (row, _) => TableCells.widget(_type(row.type))),
      TableColumnDef(
          label: _tr('transaction_type_label'),
          flex: 1.2,
          cellBuilder: (row, _) => TableCells.text(row.transactionType)),
      TableColumnDef(
          label: _tr('amount_col'),
          cellBuilder: (row, _) => TableCells.text(_amount(row))),
      TableColumnDef(
          label: _tr('payment_method_label'),
          flex: 1.2,
          cellBuilder: (row, _) => TableCells.text(row.paymentMethod)),
      TableColumnDef(
          label: _tr('status_col'),
          cellBuilder: (row, _) => TableCells.widget(_status(row.status))),
    ];

class SupplierReportDetailsCard extends StatelessWidget {
  const SupplierReportDetailsCard({super.key, required this.row});
  final SupplierTransaction row;
  @override
  Widget build(BuildContext context) => AppListCard(
        title: row.reference.isEmpty ? '-' : row.reference,
        subtitle: '${row.date} · ${row.transactionType}',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [_type(row.type), _status(row.status)]),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(
              icon: Icons.payments_outlined,
              label: _tr('amount_col'),
              value: _amount(row)),
          InfoRow(
              icon: Icons.credit_card_outlined,
              label: _tr('payment_method_label'),
              value: row.paymentMethod),
        ]),
      );
}
