import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/screens/transactions/invoice_list/invoice_list_cells.dart';

Future<File> exportInvoiceList(List<Invoice> items,
    {required String currency, required bool showZatca}) {
  return ListExcelExportService.export<Invoice>(
      items: items,
      fileNamePrefix: 'invoices',
      sheetName: 'invoice.list_title'.tr,
      columns: [
        ListExportColumn(
            label: 'invoice.field_invoice_number'.tr,
            value: (v, _) => v.invoiceNumber),
        ListExportColumn(
            label: 'invoice.col_offline_receipt'.tr,
            value: (v, _) => v.receiptNumber ?? ''),
        ListExportColumn(
            label: 'invoice.col_amount'.tr,
            value: (v, _) => ListExcelExportService.numericValue(v.amount)),
        ListExportColumn(
            label: 'supplier_transactions.currency'.tr,
            value: (_, __) => currency),
        ListExportColumn(
            label: 'invoice.col_name'.tr,
            value: (v, _) => v.customer.user.name),
        ListExportColumn(
            label: 'invoice.phone'.tr, value: (v, _) => v.customer.user.phone),
        ListExportColumn(
            label: 'invoice.field_invoice_date'.tr,
            value: (v, _) => v.invoiceDate),
        ListExportColumn(
            label: 'invoice.field_type'.tr,
            value: (v, _) => InvoiceListLabels.type(v.type)),
        ListExportColumn(
            label: 'invoice.field_due_date'.tr, value: (v, _) => v.dueDate),
        ListExportColumn(
            label: 'invoice.field_status'.tr,
            value: (v, _) => UiCodeLabels.status(v.status)),
        if (showZatca)
          ListExportColumn(
              label: 'invoice.col_zatca_status'.tr,
              value: (v, _) =>
                  v.zatcaStatus ?? v.zatcaRequestStatus ?? 'not_sent'),
      ]);
}
