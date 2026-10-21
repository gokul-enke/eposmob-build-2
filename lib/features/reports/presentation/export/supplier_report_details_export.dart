import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/supplier_report_details_query.dart';

abstract final class SupplierReportDetailsExport {
  static String _tr(String key) => 'supplier_transaction_report.$key'.tr;
  static Future<File> build(
          List<SupplierTransaction> rows, SupplierReportDetailsQuery query) =>
      ListExcelExportService.export<SupplierTransaction>(
        items: rows,
        fileNamePrefix: 'supplier-transaction-details',
        sheetName: 'Supplier Transaction Details',
        columns: [
          ListExportColumn(
              label: _tr('supplier_id'), value: (_, __) => query.supplier.id),
          ListExportColumn(
              label: _tr('supplier_name_col'),
              value: (_, __) => query.supplier.name),
          ListExportColumn(label: _tr('date_col'), value: (row, _) => row.date),
          ListExportColumn(
              label: _tr('reference_col'), value: (row, _) => row.reference),
          ListExportColumn(
              label: _tr('type_label'), value: (row, _) => row.type),
          ListExportColumn(
              label: _tr('transaction_type_label'),
              value: (row, _) => row.transactionType),
          ListExportColumn(
              label: _tr('amount_col'),
              value: (row, _) => double.parse(row.amount)),
          ListExportColumn(
              label: 'supplier_transactions.currency'.tr,
              value: (row, _) => row.currency),
          ListExportColumn(
              label: _tr('payment_method_label'),
              value: (row, _) => row.paymentMethod),
          ListExportColumn(
              label: _tr('status_col'), value: (row, _) => row.status),
          ListExportColumn(
              label: _tr('from_date'), value: (_, __) => query.from),
          ListExportColumn(label: _tr('to_date'), value: (_, __) => query.to),
        ],
      );
}
