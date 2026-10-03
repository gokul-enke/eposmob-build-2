import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/expense.dart';

Future<File> exportExpenseExcel(List<Expense> rows, String currency) {
  return ListExcelExportService.export<Expense>(
    items: rows,
    fileNamePrefix: 'expenses',
    sheetName: 'Expenses',
    columns: [
      ListExportColumn(
          label: 'expense.col_reference_number'.tr,
          value: (e, _) => e.referenceNumber),
      ListExportColumn(
          label: 'expense.col_payment_date'.tr,
          value: (e, _) => DateHelper.formatDate(e.paymentDate)),
      ListExportColumn(
          label: 'expense.category'.tr, value: (e, _) => e.category),
      ListExportColumn(
          label: 'expense.col_debit_ac'.tr, value: (e, _) => e.debitAccount),
      ListExportColumn(
          label: 'expense.col_credit_ac'.tr, value: (e, _) => e.creditAccount),
      ListExportColumn(label: 'expense.amount'.tr, value: (e, _) => e.amount),
      ListExportColumn(
          label: 'expense.currency'.tr, value: (_, __) => currency),
      ListExportColumn(label: 'expense.status'.tr, value: (e, _) => e.status),
      ListExportColumn(
          label: 'expense.payment_method'.tr, value: (e, _) => e.paymentMethod),
      ListExportColumn(
          label: 'expense.label_description_vendor'.tr,
          value: (e, _) => e.description),
      ListExportColumn(
          label: 'expense.label_notes_remarks'.tr, value: (e, _) => e.notes),
    ],
  );
}
