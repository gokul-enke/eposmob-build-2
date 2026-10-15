import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'day_close_list_rows.dart';

List<TableColumnDef<DailySalesCloseData>> adminDayCloseColumns(
        {required String currency,
        required ValueChanged<DailySalesCloseData> onView}) =>
    [
      TableColumnDef(
          label: 'daily_sales_close.col_id'.tr,
          flex: .7,
          cellBuilder: (r, _) =>
              TableCells.text(r.salesExecutive?.id?.toString() ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.sales_executive'.tr,
          flex: 1.5,
          cellBuilder: (r, _) =>
              TableCells.text(r.salesExecutive?.name ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.col_phone'.tr,
          flex: 1.2,
          cellBuilder: (r, _) =>
              TableCells.text(r.salesExecutive?.phone ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.col_store'.tr,
          flex: 1.5,
          cellBuilder: (r, _) => TableCells.text(r.store?.name ?? '-')),
      TableColumnDef(
          label: 'daily_sales_close.col_closing_period'.tr,
          flex: 2.3,
          cellBuilder: (r, _) => Directionality(
              textDirection: TextDirection.ltr,
              child: TableCells.text(r.closingPeriod ?? '-'))),
      TableColumnDef(
          label: 'daily_sales_close.total_orders'.tr,
          flex: .9,
          cellBuilder: (r, _) =>
              TableCells.text(r.totalOrders?.toString() ?? '-')),
      for (final metric in [
        'total_sales',
        'online_sales',
        'cash_sales',
        'credit_amount'
      ])
        TableColumnDef(
            label: 'daily_sales_close.$metric'.tr,
            flex: 1.2,
            cellBuilder: (r, _) => TableCells.text(dayCloseAmount(
                switch (metric) {
                  'total_sales' => r.totalSales,
                  'online_sales' => r.totalOnline,
                  'cash_sales' => r.totalCash,
                  _ => r.totalCredit
                },
                currency))),
      TableColumnDef(
          label: 'daily_sales_close.action'.tr,
          flex: .6,
          cellBuilder: (r, _) => TableCells.widget(dayCloseView(r, onView))),
    ];

Widget adminDayCloseCard(DailySalesCloseData row,
        {required String currency,
        required ValueChanged<DailySalesCloseData> onView}) =>
    AppListCard(
        title: row.salesExecutive?.name ?? '-',
        subtitle: row.store?.name ?? '-',
        trailing: dayCloseView(row, onView),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '${'daily_sales_close.col_id'.tr}: ${row.salesExecutive?.id ?? '-'}',
              style: AppTextStyles.body),
          Text(
              '${'daily_sales_close.col_phone'.tr}: ${row.salesExecutive?.phone ?? '-'}',
              style: AppTextStyles.body),
          Text(
              '${'daily_sales_close.col_closing_period'.tr}: \u2066${row.closingPeriod ?? '-'}\u2069',
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
            ('credit_amount', row.totalCredit)
          ]) ...[
            const SizedBox(height: 8),
            AppMetric(
                icon: Icons.payments_outlined,
                label: 'daily_sales_close.${metric.$1}'.tr,
                value: dayCloseAmount(metric.$2, currency)),
          ],
        ]));
