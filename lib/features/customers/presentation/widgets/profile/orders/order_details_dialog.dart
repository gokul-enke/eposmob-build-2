import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';

import 'order_labels.dart';

/// Shows payment status, customer, items, tax and grand total of [order]
/// (the old expandable card's body).
Future<void> showOrderDetailsDialog(
  BuildContext context, {
  required ListOrderModelData order,
  required String currency,
  String? fallbackCustomerName,
}) {
  return AppDialog.show<void>(
    context,
    title: OrderLabels.number(order),
    subtitle: OrderLabels.date(order),
    maxWidth: 560,
    child: OrderDetails(
      order: order,
      currency: currency,
      fallbackCustomerName: fallbackCustomerName,
    ),
  );
}

/// Body of the order details dialog.
class OrderDetails extends StatelessWidget {
  const OrderDetails({
    super.key,
    required this.order,
    required this.currency,
    this.fallbackCustomerName,
  });

  final ListOrderModelData order;
  final String currency;
  final String? fallbackCustomerName;

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    final valueStyle = (bold ? AppTextStyles.sectionTitle : AppTextStyles.value)
        .copyWith(color: color ?? AppColors.heading);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? AppTextStyles.sectionTitle : AppTextStyles.body,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: valueStyle),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = order.cartItems ?? const <CartItem>[];
    final tax = OrderLabels.tax(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OrderStatusBadge(status: order.status),
        ),
        const SizedBox(height: AppSpacing.sm),
        _row(
          'customer_orders.label_payment_status'.tr,
          OrderLabels.orNa(order.paymentStatus),
          color: OrderLabels.paymentStatusColor(order.paymentStatus),
        ),
        _row(
          'customer_orders.label_customer'.tr,
          OrderLabels.customerName(order, fallbackCustomerName),
        ),
        const Divider(height: 20, color: AppColors.border),
        if (items.isEmpty)
          Text('customer_orders.msg_no_items'.tr, style: AppTextStyles.body)
        else
          for (final item in items)
            _row(
              '${'customer_orders.label_product'.tr} '
              '${OrderLabels.orNa(item.productName)} (x${item.quantity ?? 0})',
              OrderLabels.money(currency, item.totalPrice),
            ),
        const Divider(height: 20, color: AppColors.border),
        if (tax != null)
          _row(
            'customer_orders.label_tax'.tr,
            OrderLabels.money(currency, tax),
          ),
        _row(
          'customer_orders.label_grand_total'.tr,
          OrderLabels.money(currency, OrderLabels.grandTotal(order)),
          color: AppColors.green,
          bold: true,
        ),
      ],
    );
  }
}
