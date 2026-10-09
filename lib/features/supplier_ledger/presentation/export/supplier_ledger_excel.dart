import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/transaction_model.dart';
import 'dart:io';
import 'package:pos_machine/services/list_excel_export_service.dart';

Future<File> createSupplierLedgerExcel(List<TransactionModel> items) async {
  return ListExcelExportService.export<TransactionModel>(
    items: items,
    fileNamePrefix: 'supplier-transactions',
    sheetName: 'supplier_transactions.title'.tr,
    columns: [
      ListExportColumn(
          label: 'supplier_transactions.col_si_no'.tr,
          value: (_, index) => index + 1),
      ListExportColumn(
          label: 'supplier_transactions.supplier'.tr,
          value: (tx, _) => tx.supplier.user.name),
      ListExportColumn(
          label: 'supplier_transactions.col_date'.tr,
          value: (tx, _) => DateHelper.formatISODate(tx.date)),
      ListExportColumn(
          label: 'supplier_transactions.type'.tr,
          value: (tx, _) => UiCodeLabels.documentKind(tx.type)),
      ListExportColumn(
          label: 'supplier_transactions.col_transaction_type'.tr,
          value: (tx, _) => UiCodeLabels.documentKind(tx.transactionType)),
      ListExportColumn(
          label: 'supplier_transactions.col_payment_mode'.tr,
          value: (tx, _) => UiCodeLabels.payment(tx.paymentMode)),
      ListExportColumn(
          label: 'supplier_transactions.col_amount'.tr,
          value: (tx, _) => ListExcelExportService.numericValue(tx.amount)),
      ListExportColumn(
          label: 'supplier_transactions.currency'.tr,
          value: (tx, _) => tx.currency),
      ListExportColumn(
          label: 'supplier_transactions.tax_amount'.tr,
          value: (tx, _) => ListExcelExportService.numericValue(tx.taxAmount)),
      ListExportColumn(
          label: 'supplier_transactions.col_reference'.tr,
          value: (tx, _) => tx.reference),
      ListExportColumn(
          label: 'supplier_transactions.status'.tr,
          value: (tx, _) => UiCodeLabels.status(tx.status)),
      ListExportColumn(
          label: 'supplier_transactions.comment'.tr,
          value: (tx, _) => tx.transactionComment),
    ],
  );
}
