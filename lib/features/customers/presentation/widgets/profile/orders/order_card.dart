import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';

import 'order_labels.dart';

/// Card for one order on narrow layouts.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.rowNumber,
    required this.currency,
    required this.onView,
  });

  final ListOrderModelData order;
  final int rowNumber;
  final String currency;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      leading: OrderStatusIcon(status: order.status),
      title: OrderLabels.number(order),
      subtitle: '#$rowNumber · ${OrderLabels.date(order)}',
      trailing: OrderStatusBadge(status: order.status),
      body: AppMetricStrip(
        metrics: [
          AppMetric(
            icon: Icons.payments_outlined,
            label: 'customer_orders.label_grand_total'.tr,
            value: OrderLabels.money(currency, OrderLabels.grandTotal(order)),
            valueColor: AppColors.green,
          ),
          AppMetric(
            icon: Icons.verified_outlined,
            label: 'customer_orders.label_payment_status'.tr,
            value: OrderLabels.orNa(order.paymentStatus),
            valueColor: OrderLabels.paymentStatusColor(order.paymentStatus),
          ),
        ],
      ),
      actionLabel: 'general.view_details'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: onView,
      onTap: onView,
    );
  }
}
