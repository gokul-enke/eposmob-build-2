import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../widgets/customer_ledger_labels.dart';

Future<File> exportCustomerLedgerExcel(
    List<ListTransaction> rows, Map<String, String> paymentLabels) async {
  return ListExcelExportService.export<ListTransaction>(
      items: rows,
      fileNamePrefix: 'customer-transactions',
      sheetName: 'Customer Transactions',
      columns: [
        ListExportColumn(
            label: 'party_accounts.col_no'.tr, value: (_, i) => i + 1),
        ListExportColumn(
            label: 'party_accounts.transaction_id'.tr,
            value: (r, _) => r.id?.toString()),
        ListExportColumn(
            label: 'party_accounts.customer_name'.tr,
            value: (r, _) => r.customerName),
        ListExportColumn(
            label: 'party_accounts.date'.tr, value: (r, _) => r.date),
        ListExportColumn(
            label: 'party_accounts.amount'.tr,
            value: (r, _) => ListExcelExportService.numericValue(r.amount)),
        ListExportColumn(
            label: 'party_accounts.currency'.tr, value: (r, _) => r.currency),
        ListExportColumn(
            label: 'party_accounts.reference_id'.tr,
            value: (r, _) => r.referenceId),
        ListExportColumn(
            label: 'party_accounts.type'.tr,
            value: (r, _) => ledgerTypeLabel(r.type)),
        ListExportColumn(
            label: 'party_accounts.status'.tr,
            value: (r, _) => ledgerStatusLabel(r.status)),
        ListExportColumn(
            label: 'party_accounts.transaction_type'.tr,
            value: (r, _) =>
                UiCodeLabels.documentKind(r.transactionType ?? '')),
        ListExportColumn(
            label: 'party_accounts.payment_method'.tr,
            value: (r, _) => paymentLabels[r.paymentMethod ?? '']),
        ListExportColumn(
            label: 'party_accounts.reference'.tr, value: (r, _) => r.reference),
        ListExportColumn(
            label: 'party_accounts.comment'.tr,
            value: (r, _) => r.transactionComment),
        ListExportColumn(
            label: 'party_accounts.created_at'.tr,
            value: (r, _) => r.createdAt?.toIso8601String()),
      ]);
}
