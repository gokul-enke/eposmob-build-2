import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/supplier_report.dart';
import '../../export/supplier_transactions_report_export.dart';

List<TableColumnDef<SupplierTransactionSummary>> supplierReportColumns({
  required ValueChanged<SupplierTransactionSummary> onView,
}) =>
    [
      TableColumnDef(
        label: 'supplier_transaction_report.supplier_name_col'.tr,
        flex: 2,
        cellBuilder: (row, _) {
          final name = SupplierTransactionsReportExport.name(row);
          return TableCells.avatarName(
              name: name, avatar: AppAvatar(name: name, semanticLabel: name));
        },
      ),
      TableColumnDef(
          label: 'supplier_transaction_report.total_debit_col'.tr,
          cellBuilder: (row, _) =>
              TableCells.text(row.totalDebit.toStringAsFixed(2))),
      TableColumnDef(
          label: 'supplier_transaction_report.total_credit_col'.tr,
          cellBuilder: (row, _) =>
              TableCells.text(row.totalCredit.toStringAsFixed(2))),
      TableColumnDef(
          label: 'supplier_transaction_report.balance'.tr,
          cellBuilder: (row, _) => TableCells.amount(row.balance)),
      TableColumnDef(
          label: 'supplier_transaction_report.transactions'.tr,
          cellBuilder: (row, _) => TableCells.text('${row.transactionCount}')),
      TableColumnDef(
          label: 'supplier_transaction_report.action_col'.tr,
          cellBuilder: (row, _) => TableCells.action(
              label: 'list.view'.tr,
              icon: Icons.visibility_outlined,
              onPressed: () => onView(row))),
    ];
