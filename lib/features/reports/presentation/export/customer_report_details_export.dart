import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

import '../../domain/customer_report_details_query.dart';

abstract final class CustomerReportDetailsExport {
  static String _tr(String key) => 'customer_transaction_report.$key'.tr;

  static Future<File> build(
          List<ListTransaction> rows, CustomerReportDetailsQuery query) =>
      ListExcelExportService.export<ListTransaction>(
        items: rows,
        fileNamePrefix: 'customer-transaction-details',
        sheetName: 'Customer Transaction Details',
        columns: [
          ListExportColumn(
              label: _tr('customer_id'),
              value: (row, _) => row.customerId ?? query.customerId),
          ListExportColumn(
              label: _tr('customer_name_col'),
              value: (row, _) => row.customerName ?? query.customerName),
          ListExportColumn(
              label: _tr('sl_no_col'), value: (_, index) => index + 1),
          ListExportColumn(
              label: _tr('order_number_col'),
              value: (row, _) => row.orderNumber ?? _tr('na')),
          ListExportColumn(
              label: _tr('transaction_type_label'),
              value: (row, _) => row.transactionType ?? _tr('na')),
          ListExportColumn(
              label: _tr('amount_col'),
              value: (row, _) =>
                  ListExcelExportService.numericValue(row.amount)),
          ListExportColumn(
              label: _tr('type_label'),
              value: (row, _) => row.type ?? _tr('na')),
          ListExportColumn(
              label: _tr('transaction_date_col'),
              value: (row, _) => row.date ?? _tr('na')),
          ListExportColumn(
              label: _tr('status_label'),
              value: (row, _) => row.status ?? _tr('na')),
          ListExportColumn(
              label: _tr('from_date'), value: (_, __) => query.from),
          ListExportColumn(label: _tr('to_date'), value: (_, __) => query.to),
        ],
      );
}
