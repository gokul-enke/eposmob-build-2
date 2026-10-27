import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import '../../../domain/models/discount_sale_report.dart';
import '../../state/discount_sale_report_controller.dart';

String _tr(String key, [Map<String, String> params = const {}]) =>
    'discount_sale_report.$key'.trParams(params);
String _text(String? value) => value ?? '—';

/// Translated discount type; unknown API values are shown as sent.
String discountTypeLabel(DiscountSaleReportRow row) =>
    row.discountType?.labelKey.tr ?? _text(row.discountTypeText);

String discountSaleReportDate(DiscountSaleReportRow row) =>
    row.orderDate == null ? '—' : DateHelper.formatYearMonthDay(row.orderDate!);

String discountSaleReportMoney(String currency, double? value) =>
    value == null ? '—' : '$currency ${AmountHelper.formatAmount(value)}';

/// "10 orders · Discount SAR 140.70" from the API summary (falls back to the
/// row count).
String discountSaleReportCountLabel(
    DiscountSaleReportController report, String currency) {
  final orders = report.summary['orders']?.round() ?? report.total;
  final value = report.summary['total_discount'];
  if (orders == null) {
    return _tr('page_count', {'count': '${report.rows.length}'});
  }
  return value == null
      ? _tr('total_count', {'count': '$orders'})
      : _tr('summary', {
          'orders': '$orders',
          'amount': discountSaleReportMoney(currency, value)
        });
}

/// Table cell whose text can be selected and copied (order numbers), styled
/// like [TableCells.text].
Widget _selectable(String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
    child: SelectableText(value,
        maxLines: 1,
        style: TextStyle(
            color: color ?? AppColors.body,
            fontSize: 13,
            fontWeight: FontWeight.w600)));

Widget _discount(String currency, double? value) =>
    TableCells.text(discountSaleReportMoney(currency, value),
        color: (value ?? 0) > 0 ? AppColors.red : AppColors.body,
        weight: FontWeight.w700);

/// The web's columns: Date, Order Number, Executive, Customer, Discount Type,
/// Cart Items Discount, Overall Order Discount, Discount Amount, Store.
List<TableColumnDef<DiscountSaleReportRow>> discountSaleReportColumns(
        String currency) =>
    [
      TableColumnDef(
          label: _tr('col_no'),
          flex: .45,
          cellBuilder: (_, n) => TableCells.number(n)),
      TableColumnDef(
          label: _tr('col_date'),
          cellBuilder: (r, _) => TableCells.text(discountSaleReportDate(r))),
      TableColumnDef(
          label: _tr('col_order_number'),
          flex: 1.2,
          cellBuilder: (r, _) =>
              _selectable(r.orderNumber, color: AppColors.primary)),
      TableColumnDef(
          label: _tr('col_executive'),
          cellBuilder: (r, _) => TableCells.text(_text(r.salesExecutive))),
      TableColumnDef(
          label: _tr('col_customer'),
          cellBuilder: (r, _) => TableCells.text(_text(r.customer))),
      TableColumnDef(
          label: _tr('col_discount_type'),
          flex: 1.1,
          cellBuilder: (r, _) => TableCells.text(discountTypeLabel(r))),
      TableColumnDef(
          label: _tr('col_cart_items_discount'),
          cellBuilder: (r, _) => Tooltip(
              message: _tr('cart_items_discount_tooltip'),
              child: TableCells.text(
                  discountSaleReportMoney(currency, r.cartItemsDiscount)))),
      TableColumnDef(
          label: _tr('col_overall_order_discount'),
          cellBuilder: (r, _) => TableCells.text(
              discountSaleReportMoney(currency, r.overallOrderDiscount))),
      TableColumnDef(
          label: _tr('col_discount_amount'),
          cellBuilder: (r, _) => _discount(currency, r.discountAmount)),
      TableColumnDef(
          label: _tr('col_store'),
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.text(_text(r.store))),
    ];

class DiscountSaleReportCard extends StatelessWidget {
  const DiscountSaleReportCard(
      {super.key,
      required this.row,
      required this.number,
      required this.currency});
  final DiscountSaleReportRow row;
  final int number;
  final String currency;

  @override
  Widget build(BuildContext context) => AppListCard(
      title: '#$number  ${row.orderNumber}',
      subtitle: '${discountSaleReportDate(row)} · ${discountTypeLabel(row)}',
      trailing: AppBadge(
          label: discountSaleReportMoney(currency, row.discountAmount),
          tone: AppBadgeTone.danger),
      body: InfoGrid(minColumnWidth: 130, maxColumns: 2, children: [
        if (row.offlineReceiptNumber != null)
          InfoRow(
              label: _tr('col_offline_receipt'),
              value: row.offlineReceiptNumber!),
        InfoRow(label: _tr('col_executive'), value: _text(row.salesExecutive)),
        InfoRow(label: _tr('col_customer'), value: _text(row.customer)),
        InfoRow(label: _tr('col_store'), value: _text(row.store)),
        InfoRow(
            label: _tr('col_cart_items_discount'),
            value: discountSaleReportMoney(currency, row.cartItemsDiscount)),
        InfoRow(
            label: _tr('col_overall_order_discount'),
            value: discountSaleReportMoney(currency, row.overallOrderDiscount)),
      ]));
}
