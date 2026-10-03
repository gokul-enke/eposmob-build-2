import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_sales_order.dart';

import 'order_labels.dart';

/// Columns of the orders table (wide layout).
List<TableColumnDef<ListOrderModelData>> orderTableColumns({
  required String currency,
  required ValueChanged<ListOrderModelData> onView,
}) {
  return [
    TableColumnDef(
      label: 'customers.col_no'.tr,
      flex: 0.5,
      align: TextAlign.center,
      cellBuilder: (_, number) => TableCells.number(number),
    ),
    TableColumnDef(
      label: 'customer_profile.col_order'.tr,
      flex: 1.7,
      cellBuilder: (order, _) => TableCells.avatarName(
        name: OrderLabels.number(order),
        avatar: OrderStatusIcon(status: order.status, size: 32),
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_date'.tr,
      flex: 1,
      cellBuilder: (order, _) => TableCells.text(OrderLabels.date(order)),
    ),
    TableColumnDef(
      label: 'customer_profile.col_status'.tr,
      flex: 1.1,
      cellBuilder: (order, _) =>
          TableCells.widget(OrderStatusBadge(status: order.status)),
    ),
    TableColumnDef(
      label: 'customer_profile.col_payment_status'.tr,
      flex: 1,
      cellBuilder: (order, _) => TableCells.text(
        OrderLabels.orNa(order.paymentStatus),
        color: OrderLabels.paymentStatusColor(order.paymentStatus),
        weight: FontWeight.w600,
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_items'.tr,
      flex: 0.7,
      cellBuilder: (order, _) =>
          TableCells.text('${OrderLabels.itemCount(order)}'),
    ),
    TableColumnDef(
      label: 'customer_profile.col_total'.tr,
      flex: 1.1,
      cellBuilder: (order, _) => TableCells.text(
        OrderLabels.money(currency, OrderLabels.grandTotal(order)),
        color: AppColors.green,
        weight: FontWeight.w700,
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_action'.tr,
      flex: 1,
      cellBuilder: (order, _) => TableCells.action(
        label: 'customers.view'.tr,
        icon: Icons.visibility_outlined,
        onPressed: () => onView(order),
      ),
    ),
  ];
}
