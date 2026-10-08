import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/list_sales_order.dart';

String salesCustomer(ListOrderModelData row) =>
    row.customerName?.isNotEmpty == true
        ? row.customerName!
        : row.customerDetails?.phone?.isNotEmpty == true
            ? row.customerDetails!.phone!
            : 'NA';
String salesDate(ListOrderModelData row) =>
    row.orderDate == null ? '-' : DateHelper.formatYearMonthDay(row.orderDate!);
Widget salesStatus(ListOrderModelData row) => AppBadge(
    label: UiCodeLabels.status(row.status ?? 'pending'),
    tone: switch ((row.status ?? 'pending').toLowerCase()) {
      'confirmed' => AppBadgeTone.success,
      'cancelled' => AppBadgeTone.danger,
      'new' => AppBadgeTone.info,
      'pending' => AppBadgeTone.warning,
      _ => AppBadgeTone.neutral,
    });
Widget _text(String text) => Text(text,
    style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis);
Widget _order(ListOrderModelData row, ValueChanged<ListOrderModelData> copy) =>
    Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _text('#${row.orderNumber ?? "-"}'),
        if (row.receiptNumber?.trim().isNotEmpty == true)
          Text(row.receiptNumber!.trim(), style: AppTextStyles.caption)
      ])),
      if (row.customerReceiptNumber != null)
        AppSquareIconButton(
            icon: Icons.copy_outlined,
            tooltip: 'sales.list_copy'.tr,
            size: 36,
            onPressed: () => copy(row))
    ]);

List<TableColumnDef<ListOrderModelData>> salesListColumns(
        Widget Function(ListOrderModelData) actions,
        ValueChanged<ListOrderModelData> copy,
        String currency) =>
    [
      TableColumnDef(
          label: 'sales.si_no'.tr,
          flex: .5,
          align: TextAlign.center,
          cellBuilder: (_, index) => TableCells.number(index)),
      TableColumnDef(
          label: 'sales.order_number_short'.tr,
          flex: 1.6,
          cellBuilder: (row, _) => TableCells.widget(_order(row, copy))),
      TableColumnDef(
          label: 'billing.customer'.tr,
          flex: 1.3,
          cellBuilder: (row, _) => TableCells.text(salesCustomer(row))),
      TableColumnDef(
          label: 'sales.date_col'.tr,
          flex: 1,
          cellBuilder: (row, _) => TableCells.text(salesDate(row))),
      TableColumnDef(
          label: 'sales.items_col'.tr,
          flex: .5,
          cellBuilder: (row, _) =>
              TableCells.text('${row.cartItems?.length ?? 0}')),
      TableColumnDef(
          label: 'sales.amount_col'.tr,
          flex: 1.1,
          cellBuilder: (row, _) => TableCells.text(
              '$currency ${AmountHelper.formatAmount(row.grantTotal ?? 0.0)}')),
      TableColumnDef(
          label: 'sales.status'.tr,
          flex: 1.2,
          cellBuilder: (row, _) => TableCells.widget(salesStatus(row))),
      TableColumnDef(
          label: 'general.action'.tr,
          flex: 1.5,
          cellBuilder: (row, _) => TableCells.widget(actions(row))),
    ];

Widget salesListCard(ListOrderModelData row, Widget actions,
        ValueChanged<ListOrderModelData> copy, String currency) =>
    AppListCard(
      title: '#${row.orderNumber ?? "-"}',
      subtitle: salesCustomer(row),
      trailing: row.customerReceiptNumber == null
          ? null
          : AppSquareIconButton(
              icon: Icons.copy_outlined,
              tooltip: 'sales.list_copy'.tr,
              size: AppSizes.compactControl,
              onPressed: () => copy(row)),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (row.receiptNumber?.trim().isNotEmpty == true) ...[
          Text(row.receiptNumber!.trim(), style: AppTextStyles.caption),
          const SizedBox(height: 8),
        ],
        Wrap(spacing: 12, runSpacing: 8, children: [
          _text(salesDate(row)),
          _text('${row.cartItems?.length ?? 0} ${"sales.items_col".tr}'),
          _text(
              '$currency ${AmountHelper.formatAmount(row.grantTotal ?? 0.0)}'),
          salesStatus(row)
        ]),
        const SizedBox(height: 12),
        actions
      ]),
    );
