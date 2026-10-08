import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

import '../../domain/supplier_report.dart';

abstract final class SupplierTransactionsReportExport {
  static String _tr(String key) => 'supplier_transaction_report.$key'.tr;
  static String name(SupplierTransactionSummary row) =>
      row.displayName?.trim().isNotEmpty == true
          ? row.displayName!
          : _tr('unknown');

  static Future<File> build(List<SupplierTransactionSummary> rows) =>
      ListExcelExportService.export<SupplierTransactionSummary>(
        items: rows,
        fileNamePrefix: 'supplier-transactions-report',
        sheetName: 'Supplier Transactions',
        columns: [
          ListExportColumn(
              label: _tr('supplier_id'), value: (row, _) => row.supplierId),
          ListExportColumn(
              label: _tr('supplier_name_col'), value: (row, _) => name(row)),
          ListExportColumn(
              label: _tr('total_debit_col'), value: (row, _) => row.totalDebit),
          ListExportColumn(
              label: _tr('total_credit_col'),
              value: (row, _) => row.totalCredit),
          ListExportColumn(
              label: _tr('balance'), value: (row, _) => row.balance),
          ListExportColumn(
              label: _tr('transactions'),
              value: (row, _) => row.transactionCount),
        ],
      );
}
