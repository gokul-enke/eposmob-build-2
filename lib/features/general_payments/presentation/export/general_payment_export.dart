import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/general_payment.dart';
import '../widgets/general_payment_results.dart'
    show generalPaymentStatusLabel, generalPaymentTypeLabel;

/// Workbook of the filtered General Payments. Amounts stay numeric; the last
/// column says what the export was filtered by.
abstract final class GeneralPaymentExport {
  /// "Entry type: Income; Date Range: This Month" from the controller's
  /// applied filters (translation keys are translated, names kept), or "None".
  static String describe(List<(String, String, {bool translate})> filters) =>
      filters.isEmpty
          ? 'general_payments.no_filters'.tr
          : [
              for (final (label, value, :translate) in filters)
                '${label.tr}: ${translate ? value.tr : value}'
            ].join('; ');

  static List<ListExportColumn<GeneralPayment>> columns(String filters,
      {String currency = ''}) {
    String tr(String key) => 'general_payments.$key'.tr;
    return [
      ListExportColumn(
          label: tr('col_reference'), value: (r, _) => r.referenceNumber),
      ListExportColumn(
          label: tr('col_entry_type'),
          value: (r, _) => generalPaymentTypeLabel(r)),
      ListExportColumn(
          label: tr('col_payment_date'),
          value: (r, _) => r.paymentDate.toIso8601String().substring(0, 10)),
      ListExportColumn(label: tr('col_category'), value: (r, _) => r.category),
      ListExportColumn(
          label: tr('col_debit_account'), value: (r, _) => r.debitAccount),
      ListExportColumn(
          label: tr('col_credit_account'), value: (r, _) => r.creditAccount),
      ListExportColumn(
          label: currency.isEmpty
              ? tr('col_amount')
              : '${tr('col_amount')} ($currency)',
          value: (r, _) => r.amount),
      ListExportColumn(
          label: tr('col_payment_method'), value: (r, _) => r.paymentMethod),
      ListExportColumn(
          label: tr('col_status'),
          value: (r, _) => generalPaymentStatusLabel(r)),
      ListExportColumn(
          label: tr('col_description'), value: (r, _) => r.description),
      ListExportColumn(label: tr('col_notes'), value: (r, _) => r.notes),
      ListExportColumn(
          label: tr('col_created_by'), value: (r, _) => r.createdBy),
      ListExportColumn(label: tr('applied_filters'), value: (_, __) => filters),
    ];
  }

  static Future<File> build(List<GeneralPayment> rows, String filters,
          {String currency = '', Directory? outputDirectory}) =>
      ListExcelExportService.export(
          items: List.of(rows),
          columns: columns(filters, currency: currency),
          fileNamePrefix: 'general-payments',
          sheetName: 'General Payments',
          outputDirectory: outputDirectory);
}
