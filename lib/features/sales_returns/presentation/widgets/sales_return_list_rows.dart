import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import '../../domain/sales_return_list.dart';

String salesReturnListDate(SalesReturnOrder row) => row.hasCreatedAt
    ? DateHelper.formatISODate(row.createdAt.toIso8601String())
    : '-';
String salesReturnListAmount(SalesReturnOrder row, String currency) {
  final amount = double.tryParse(row.totalAmount);
  return '$currency ${amount != null && amount.isFinite ? amount.toStringAsFixed(2) : row.totalAmount}';
}

String salesReturnListQuantity(SalesReturnOrder row) {
  final quantity = salesReturnQuantity(row);
  if (!quantity.isFinite) return '-';
  return quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : '$quantity';
}

AppBadge salesReturnListStatus(SalesReturnOrder row) => AppBadge(
    label: row.status == 1
        ? 'sales_return.status_completed'.tr
        : 'sales_return.status_pending'.tr,
    tone: row.status == 1 ? AppBadgeTone.success : AppBadgeTone.warning);
Widget salesReturnListActions(SalesReturnOrder row,
        {required ValueChanged<SalesReturnOrder> onView,
        required ValueChanged<SalesReturnOrder> onPrint}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      AppSquareIconButton(
          icon: Icons.visibility_outlined,
          foreground: AppColors.primary,
          tooltip: 'billing.view_details'.tr,
          size: 36,
          onPressed: () => onView(row)),
      const SizedBox(width: 8),
      AppSquareIconButton(
          icon: Icons.print_outlined,
          foreground: AppColors.primary,
          tooltip: 'sales_return.print_bill_tooltip'.tr,
          size: 36,
          onPressed: () => onPrint(row)),
    ]);
List<TableColumnDef<SalesReturnOrder>> salesReturnListColumns(
        {required String currency,
        required ValueChanged<SalesReturnOrder> onCopy,
        required ValueChanged<SalesReturnOrder> onView,
        required ValueChanged<SalesReturnOrder> onPrint}) =>
    [
      TableColumnDef(
          label: 'sales_return.order_or_receipt_number'.tr,
          flex: 2.2,
          cellBuilder: (row, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(row.displayNumber,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body),
                      if (row.receiptNumber != null)
                        Text(row.originalOrderNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label),
                    ])),
                const SizedBox(width: 8),
                AppSquareIconButton(
                    icon: Icons.copy_outlined,
                    size: 32,
                    tooltip: 'sales_return.copy_number'.tr,
                    onPressed: () => onCopy(row)),
              ]))),
      TableColumnDef(
          label: 'sales_return.total_quantity'.tr,
          cellBuilder: (r, _) => TableCells.text(salesReturnListQuantity(r))),
      TableColumnDef(
          label: 'sales_return.total_return_amount'.tr,
          flex: 1.4,
          cellBuilder: (r, _) =>
              TableCells.text(salesReturnListAmount(r, currency))),
      TableColumnDef(
          label: 'sales_return.status'.tr,
          cellBuilder: (r, _) => TableCells.widget(salesReturnListStatus(r))),
      TableColumnDef(
          label: 'sales_return.date'.tr,
          cellBuilder: (r, _) => TableCells.text(salesReturnListDate(r))),
      TableColumnDef(
          label: 'sales_return.action'.tr,
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.widget(
              salesReturnListActions(r, onView: onView, onPrint: onPrint))),
    ];
Widget salesReturnListCard(SalesReturnOrder row,
        {required String currency,
        required ValueChanged<SalesReturnOrder> onCopy,
        required ValueChanged<SalesReturnOrder> onView,
        required ValueChanged<SalesReturnOrder> onPrint}) =>
    AppListCard(
        title: row.displayNumber,
        subtitle: row.receiptNumber == null
            ? salesReturnListDate(row)
            : '${row.originalOrderNumber} • ${salesReturnListDate(row)}',
        trailing: AppSquareIconButton(
            icon: Icons.copy_outlined,
            size: 32,
            tooltip: 'sales_return.copy_number'.tr,
            onPressed: () => onCopy(row)),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppMetric(
              icon: Icons.inventory_2_outlined,
              label: 'sales_return.total_quantity'.tr,
              value: salesReturnListQuantity(row)),
          const SizedBox(height: 10),
          AppMetric(
              icon: Icons.payments_outlined,
              label: 'sales_return.total_return_amount'.tr,
              value: salesReturnListAmount(row, currency)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                salesReturnListStatus(row),
                salesReturnListActions(row, onView: onView, onPrint: onPrint)
              ]),
        ]));
