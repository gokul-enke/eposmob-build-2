import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/receipt_list_query.dart';

Future<File> exportReceiptListExcel(List<Receipt> rows,
        {required String currency}) =>
    ListExcelExportService.export<Receipt>(
        items: rows,
        fileNamePrefix: 'receipts',
        sheetName: 'receipt.list_title'.tr,
        columns: [
          ListExportColumn(
              label: 'receipt.col_receipt_number'.tr,
              value: (r, _) => r.receiptNumber),
          ListExportColumn(
              label: 'receipt.col_customer_name'.tr,
              value: (r, _) => r.customer.user.name),
          ListExportColumn(
              label: 'receipt.phone_hint'.tr,
              value: (r, _) => r.customer.user.phone),
          ListExportColumn(
              label: 'receipt.email_hint'.tr,
              value: (r, _) => r.customer.user.email),
          ListExportColumn(
              label: 'receipt.field_amount'.tr,
              value: (r, _) => ListExcelExportService.numericValue(r.amount)),
          ListExportColumn(
              label: 'supplier_transactions.currency'.tr,
              value: (r, _) => currency),
          ListExportColumn(
              label: 'receipt.col_type'.tr,
              value: (r, _) => receiptTypeKey(r).tr),
          ListExportColumn(
              label: 'receipt.col_status'.tr,
              value: (r, _) => UiCodeLabels.status(r.receiptStatus)),
          ListExportColumn(
              label: 'receipt.col_payment_reference'.tr,
              value: (r, _) => r.paymentReference),
          ListExportColumn(
              label: 'receipt.col_method'.tr,
              value: (r, _) => r.paymentMethods.join(', ')),
          ListExportColumn(
              label: 'receipt.col_date'.tr,
              value: (r, _) => r.createdAt.toIso8601String()),
        ]);
