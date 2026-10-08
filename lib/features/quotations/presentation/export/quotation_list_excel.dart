import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../widgets/list/quotation_list_labels.dart';

Future<File> exportQuotationListExcel(List<Quotation> rows) =>
    ListExcelExportService.export<Quotation>(
        items: rows,
        fileNamePrefix: 'quotations',
        sheetName: 'Quotations',
        columns: [
          ListExportColumn(
              label: 'quotations.quotation_number_label'.tr,
              value: (q, _) => q.quotationNumber),
          ListExportColumn(
              label: 'quotations.customer_col'.tr, value: (q, _) => q.customer),
          ListExportColumn(
              label: 'quotations.store_col'.tr, value: (q, _) => q.store),
          ListExportColumn(
              label: 'quotations.quotation_date'.tr,
              value: (q, _) => quotationDateLabel(q.quotationDate)),
          ListExportColumn(
              label: 'quotations.expiry_date'.tr,
              value: (q, _) => quotationDateLabel(q.expiryDate)),
          ListExportColumn(
              label: 'sales.status'.tr,
              value: (q, _) => quotationStatusLabel(q.status ?? '')),
        ]);
