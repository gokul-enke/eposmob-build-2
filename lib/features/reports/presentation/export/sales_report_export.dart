import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/payment_method_display.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/sales_report.dart';

/// Sales Report workbook. Amounts stay numeric; order numbers stay text.
/// [filters] describes what the export was filtered by.
abstract final class SalesReportExport {
  /// "Date Range: This Month; Stores: Main, Branch" from the controller's
  /// applied filters (translation keys are translated, names kept).
  static String describe(List<(String, String, {bool translate})> filters) => [
        for (final (label, value, :translate) in filters)
          '${label.tr}: ${translate ? value.tr : value}'
      ].join('; ');

  static List<ListExportColumn<SalesReportRow>> columns(String filters) {
    String tr(String key) => 'order_sales_report.$key'.tr;
    return [
      ListExportColumn(label: tr('col_no'), value: (_, i) => i + 1),
      ListExportColumn(label: tr('col_order'), value: (r, _) => r.orderNumber),
      ListExportColumn(
          label: tr('col_order_date'),
          value: (r, _) => r.orderDate?.toIso8601String().substring(0, 10)),
      ListExportColumn(
          label: tr('col_order_value'), value: (r, _) => r.orderValue),
      ListExportColumn(
          label: tr('col_payment_methods'),
          value: (r, _) => r.paymentMethods == null
              ? null
              : PaymentMethodDisplay.labelForCodeList(r.paymentMethods)),
      ListExportColumn(
          label: tr('col_delivery_method'), value: (r, _) => r.deliveryMethod),
      ListExportColumn(
          label: tr('col_sales_executive'), value: (r, _) => r.salesExecutive),
      ListExportColumn(label: tr('applied_filters'), value: (_, __) => filters),
    ];
  }

  static Future<File> build(List<SalesReportRow> rows, String filters,
          {Directory? outputDirectory}) =>
      ListExcelExportService.export(
          items: List.of(rows),
          columns: columns(filters),
          fileNamePrefix: 'sales-report',
          sheetName: 'Sales Report',
          outputDirectory: outputDirectory);
}
