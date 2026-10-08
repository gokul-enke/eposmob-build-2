import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import '../../domain/day_close_list.dart';

String dayCloseStatusLabel(String? status) {
  final code = status?.trim().toLowerCase();
  if (['closed', 'completed', 'draft', 'open', 'pending'].contains(code)) {
    return 'daily_sales_close.status_$code'.tr;
  }
  return status?.trim().isNotEmpty == true ? UiCodeLabels.status(status!) : '-';
}

AppBadge dayCloseStatus(DailySalesCloseData row) => AppBadge(
    label: dayCloseStatusLabel(row.status),
    tone: ['closed', 'completed'].contains(row.status?.trim().toLowerCase())
        ? AppBadgeTone.success
        : ['draft', 'open', 'pending']
                .contains(row.status?.trim().toLowerCase())
            ? AppBadgeTone.warning
            : AppBadgeTone.neutral);

String dayCloseAmount(String? value, String currency) {
  final number = dayCloseNumber(value);
  return number == null ? '-' : '$currency ${number.toStringAsFixed(2)}';
}

Widget dayCloseView(
        DailySalesCloseData row, ValueChanged<DailySalesCloseData> onView) =>
    AppSquareIconButton(
        icon: Icons.visibility_outlined,
        foreground: AppColors.primary,
        size: 36,
        tooltip: 'daily_sales_close.btn_view_details'.tr,
        onPressed: () => onView(row));

List<TableColumnDef<DailySalesCloseData>> dayCloseListColumns(
        {required String currency,
        required ValueChanged<DailySalesCloseData> onView}) =>
    [
      TableColumnDef(
          label: 'daily_sales_close.sales_executive'.tr,
          flex: 1.5,
          cellBuilder: (r, _) =>
              TableCells.text(r.salesExecutive?.name ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.phone'.tr,
          flex: 1.1,
          cellBuilder: (r, _) =>
              TableCells.text(r.salesExecutive?.phone ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.store'.tr,
          flex: 1.5,
          cellBuilder: (r, _) => TableCells.text(r.store?.name ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.business_date'.tr,
          flex: 1.1,
          cellBuilder: (r, _) => TableCells.text(r.businessDate ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.total_orders'.tr,
          flex: .8,
          cellBuilder: (r, _) =>
              TableCells.text(r.totalOrders?.toString() ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.total_sales'.tr,
          flex: 1.2,
          cellBuilder: (r, _) =>
              TableCells.text(dayCloseAmount(r.totalSales, currency))),
      TableColumnDef(
          label: 'daily_sales_close.online_sales'.tr,
          flex: 1.2,
          cellBuilder: (r, _) =>
              TableCells.text(dayCloseAmount(r.totalOnline, currency))),
      TableColumnDef(
          label: 'daily_sales_close.cash_sales'.tr,
          flex: 1.2,
          cellBuilder: (r, _) =>
              TableCells.text(dayCloseAmount(r.totalCash, currency))),
      TableColumnDef(
          label: 'daily_sales_close.credit_amount'.tr,
          flex: 1.2,
          cellBuilder: (r, _) =>
              TableCells.text(dayCloseAmount(r.totalCredit, currency))),
      TableColumnDef(
          label: 'daily_sales_close.status'.tr,
          cellBuilder: (r, _) => TableCells.widget(dayCloseStatus(r))),
      TableColumnDef(
          label: 'daily_sales_close.action'.tr,
          flex: .7,
          cellBuilder: (r, _) => TableCells.widget(dayCloseView(r, onView))),
    ];

Widget dayCloseListCard(DailySalesCloseData row,
        {required String currency,
        required ValueChanged<DailySalesCloseData> onView}) =>
    AppListCard(
        title: row.salesExecutive?.name ?? '-',
        subtitle: row.store?.name ?? '-',
        trailing: dayCloseView(row, onView),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '${'daily_sales_close.phone'.tr}: ${row.salesExecutive?.phone ?? '-'}',
              style: AppTextStyles.body),
          Text(
              '${'daily_sales_close.business_date'.tr}: ${row.businessDate ?? '-'}',
              style: AppTextStyles.body),
          const SizedBox(height: 8),
          AppMetric(
              icon: Icons.receipt_long_outlined,
              label: 'daily_sales_close.total_orders'.tr,
              value: row.totalOrders?.toString() ?? '-'),
          for (final metric in [
            ('total_sales', row.totalSales),
            ('online_sales', row.totalOnline),
            ('cash_sales', row.totalCash),
            ('credit_amount', row.totalCredit),
          ]) ...[
            const SizedBox(height: 8),
            AppMetric(
                icon: Icons.payments_outlined,
                label: 'daily_sales_close.${metric.$1}'.tr,
                value: dayCloseAmount(metric.$2, currency)),
          ],
          const SizedBox(height: 12),
          dayCloseStatus(row),
        ]));
