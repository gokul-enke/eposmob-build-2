import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

import '../../domain/customer_report.dart';

/// Builds the Customer Transactions Report workbook (one row per customer,
/// amounts as numbers).
abstract final class CustomerTransactionsReportExport {
  static String _tr(String key) => 'customer_transaction_report.$key'.tr;

  static String customerName(CustomerReportRow row) =>
      row.name.isEmpty ? _tr('unknown_customer') : row.name;

  static Future<File> build(List<CustomerReportRow> rows) {
    return ListExcelExportService.export<CustomerReportRow>(
        items: rows,
        fileNamePrefix: 'customer-transactions-report',
        sheetName: 'Customer Transactions',
        columns: [
          ListExportColumn(
              label: _tr('customer_id'), value: (r, _) => r.id ?? ''),
          ListExportColumn(
              label: _tr('customer_name_col'),
              value: (r, _) => customerName(r)),
          ListExportColumn(
              label: _tr('total_debit_col'), value: (r, _) => r.debit),
          ListExportColumn(
              label: _tr('total_credit_col'), value: (r, _) => r.credit),
          ListExportColumn(label: _tr('balance'), value: (r, _) => r.balance),
          ListExportColumn(
              label: _tr('transactions'), value: (r, _) => r.count),
        ]);
  }
}
