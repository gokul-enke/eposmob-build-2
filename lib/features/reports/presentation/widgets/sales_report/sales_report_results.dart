import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/payment_method_display.dart';
import '../../../domain/models/sales_report.dart';
import '../../state/sales_report_controller.dart';

String _tr(String key) => 'order_sales_report.$key'.tr;
String _text(String? value) => value ?? '—';

/// The order's payment methods in the app language (the API sends codes).
String salesReportPayments(SalesReportRow row) =>
    _text(row.paymentMethods == null
        ? null
        : PaymentMethodDisplay.labelForCodeList(row.paymentMethods));
String salesReportDate(SalesReportRow row) =>
    row.orderDate == null ? '—' : DateHelper.formatYearMonthDay(row.orderDate!);
String salesReportMoney(String currency, double? value) =>
    value == null ? '—' : '$currency ${AmountHelper.formatAmount(value)}';

/// "12 orders · Total SAR 1,250.00" from the API summary (falls back to the
/// row count).
String salesReportCountLabel(SalesReportController report, String currency) {
  final orders = report.summary['orders']?.round() ?? report.total;
  final value = report.summary['order_value'];
  if (orders == null) {
    return 'order_sales_report.page_count'
        .trParams({'count': '${report.rows.length}'});
  }
  return value == null
      ? 'order_sales_report.total_count'.trParams({'count': '$orders'})
      : 'order_sales_report.summary'.trParams(
          {'orders': '$orders', 'amount': salesReportMoney(currency, value)});
}

/// Order number cell whose text can be selected and copied, styled like
/// [TableCells.text].
Widget _selectableCell(String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
    child: SelectableText(value,
        maxLines: 1,
        style: TextStyle(
            color: color ?? AppColors.body,
            fontSize: 13,
            fontWeight: FontWeight.w600)));

List<TableColumnDef<SalesReportRow>> salesReportColumns(String currency) => [
      TableColumnDef(
          label: _tr('col_no'),
          flex: .45,
          cellBuilder: (_, n) => TableCells.number(n)),
      TableColumnDef(
          label: _tr('col_order'),
          flex: 1.2,
          cellBuilder: (r, _) =>
              _selectableCell(r.orderNumber, color: AppColors.primary)),
      TableColumnDef(
          label: _tr('col_order_date'),
          cellBuilder: (r, _) => TableCells.text(salesReportDate(r))),
      TableColumnDef(
          label: _tr('col_order_value'),
          cellBuilder: (r, _) => TableCells.text(
              salesReportMoney(currency, r.orderValue),
              weight: FontWeight.w700)),
      TableColumnDef(
          label: _tr('col_payment_methods'),
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.text(salesReportPayments(r))),
      TableColumnDef(
          label: _tr('col_delivery_method'),
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.text(_text(r.deliveryMethod))),
      TableColumnDef(
          label: _tr('col_sales_executive'),
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.text(_text(r.salesExecutive))),
    ];

class SalesReportCard extends StatelessWidget {
  const SalesReportCard(
      {super.key,
      required this.row,
      required this.number,
      required this.currency});
  final SalesReportRow row;
  final int number;
  final String currency;

  @override
  Widget build(BuildContext context) => AppListCard(
      title: '#$number  ${row.orderNumber}',
      subtitle: salesReportDate(row),
      body: InfoGrid(minColumnWidth: 130, maxColumns: 2, children: [
        InfoRow(
            label: _tr('col_order_value'),
            value: salesReportMoney(currency, row.orderValue)),
        InfoRow(
            label: _tr('col_payment_methods'), value: salesReportPayments(row)),
        InfoRow(
            label: _tr('col_delivery_method'),
            value: _text(row.deliveryMethod)),
        InfoRow(
            label: _tr('col_sales_executive'),
            value: _text(row.salesExecutive)),
      ]));
}
