import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_sales_order.dart';

/// Display helpers for one [ListOrderModelData].
abstract final class OrderLabels {
  static String number(ListOrderModelData order) =>
      '${'general.order_number_hash'.tr}${orNa(order.orderNumber)}';

  /// `d/M/yyyy`, or N/A.
  static String date(ListOrderModelData order) {
    final date = order.orderDate;
    if (date == null) return 'general.na'.tr;
    return '${date.day}/${date.month}/${date.year}';
  }

  static String grandTotal(ListOrderModelData order) =>
      order.priceSummary?.grandTotal ?? order.grantTotal ?? '0.00';

  static String money(String currency, String? value) =>
      '$currency${value ?? '0.00'}';

  static String customerName(ListOrderModelData order, String? fallback) =>
      order.customerName ??
      order.customerDetails?.name ??
      fallback ??
      'general.na'.tr;

  static String status(String? status) =>
      status == null || status.isEmpty ? 'general.na'.tr : status.toUpperCase();

  static String orNa(String? value) =>
      value == null || value.isEmpty ? 'general.na'.tr : value;

  static int itemCount(ListOrderModelData order) =>
      order.cartItems?.length ?? 0;

  /// Tax row is shown only for a non-empty, non-zero tax total.
  static String? tax(ListOrderModelData order) {
    final tax = order.priceSummary?.taxTotal;
    if (tax == null || tax.isEmpty || tax == '0.00') return null;
    return tax;
  }

  static AppBadgeTone statusTone(String? status) =>
      switch (status?.toLowerCase()) {
        'delivered' || 'completed' => AppBadgeTone.success,
        'pending' => AppBadgeTone.warning,
        'cancelled' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral,
      };

  static IconData statusIcon(String? status) => switch (status?.toLowerCase()) {
        'delivered' => Icons.local_shipping,
        'completed' => Icons.check_circle,
        'pending' => Icons.pending_actions,
        'cancelled' => Icons.cancel,
        _ => Icons.help_outline,
      };

  static Color paymentStatusColor(String? status) =>
      switch (status?.toLowerCase()) {
        'paid' => AppColors.green,
        'pending' => AppColors.red,
        _ => AppColors.muted,
      };
}

/// Upper-case status pill of an order.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: OrderLabels.status(status),
        tone: OrderLabels.statusTone(status),
      );
}

/// Round status icon of an order.
class OrderStatusIcon extends StatelessWidget {
  const OrderStatusIcon({super.key, required this.status, this.size = 40});

  final String? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = OrderLabels.statusTone(status);
    return AppIconTile(
      icon: OrderLabels.statusIcon(status),
      size: size,
      radius: size / 2,
      background: tone.background,
      foreground: tone.foreground,
    );
  }
}
