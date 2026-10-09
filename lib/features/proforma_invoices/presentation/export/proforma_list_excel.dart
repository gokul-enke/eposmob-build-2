import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/proforma_list_query.dart';
import '../widgets/proforma_labels.dart';

Future<File> exportProformaListExcel(List<Map<String, dynamic>> items) async {
  return ListExcelExportService.export<Map<String, dynamic>>(
      items: items,
      fileNamePrefix: 'proforma-invoices',
      sheetName: 'proforma_invoice.title'.tr,
      columns: [
        ListExportColumn(
            label: 'proforma_invoice.invoice_number_label'.tr,
            value: (v, _) => proformaText(v['invoice_number'])),
        ListExportColumn(
            label: 'proforma_invoice.customer_label'.tr,
            value: (v, _) => proformaText(proformaMap(v['customer'])['name'])),
        ListExportColumn(
            label: 'proforma_invoice.field_quotation_number'.tr,
            value: (v, _) =>
                proformaText(proformaMap(v['quotation'])['quotation_number'])),
        ListExportColumn(
            label: 'proforma_invoice.field_invoice_date'.tr,
            value: (v, _) => proformaText(v['invoice_date'])),
        ListExportColumn(
            label: 'proforma_invoice.field_due_date'.tr,
            value: (v, _) => proformaText(v['due_date'])),
        ListExportColumn(
            label: 'proforma_invoice.field_amount'.tr,
            value: (v, _) =>
                ListExcelExportService.numericValue(v['amount']?.toString())),
        ListExportColumn(
            label: 'proforma_invoice.status_label'.tr,
            value: (v, _) => proformaStatusLabel(proformaText(v['status']))),
      ]);
}
