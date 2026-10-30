import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/discount_sale_report.dart';
import '../widgets/discount_sale_report/discount_sale_report_results.dart'
    show discountTypeLabel;

/// Workbook of the Discount Sale Report. Amounts stay numeric; order numbers
/// stay text. [filters] describes what the export was filtered by.
abstract final class DiscountSaleReportExport {
  /// "Date Range: This Month; Store: Main" from the controller's applied
  /// filters (translation keys are translated, names kept).
  static String describe(List<(String, String, {bool translate})> filters) => [
        for (final (label, value, :translate) in filters)
          '${label.tr}: ${translate ? value.tr : value}'
      ].join('; ');

  static List<ListExportColumn<DiscountSaleReportRow>> columns(String filters) {
    String tr(String key) => 'discount_sale_report.$key'.tr;
    return [
      ListExportColumn(label: tr('col_no'), value: (_, i) => i + 1),
      ListExportColumn(
          label: tr('col_date'),
          value: (r, _) => r.orderDate?.toIso8601String().substring(0, 10)),
      ListExportColumn(
          label: tr('col_order_number'), value: (r, _) => r.orderNumber),
      ListExportColumn(
          label: tr('col_executive'), value: (r, _) => r.salesExecutive),
      ListExportColumn(label: tr('col_customer'), value: (r, _) => r.customer),
      ListExportColumn(
          label: tr('col_discount_type'),
          value: (r, _) => discountTypeLabel(r)),
      ListExportColumn(
          label: tr('col_cart_items_discount'),
          value: (r, _) => r.cartItemsDiscount),
      ListExportColumn(
          label: tr('col_overall_order_discount'),
          value: (r, _) => r.overallOrderDiscount),
      ListExportColumn(
          label: tr('col_discount_amount'), value: (r, _) => r.discountAmount),
      ListExportColumn(label: tr('col_store'), value: (r, _) => r.store),
      ListExportColumn(label: tr('applied_filters'), value: (_, __) => filters),
    ];
  }

  static Future<File> build(List<DiscountSaleReportRow> rows, String filters,
          {Directory? outputDirectory}) =>
      ListExcelExportService.export(
          items: List.of(rows),
          columns: columns(filters),
          fileNamePrefix: 'discount-sale-report',
          sheetName: 'Discount Sale Report',
          outputDirectory: outputDirectory);
}
