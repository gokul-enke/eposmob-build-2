import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';

/// Display helpers for one [SupplierPurchase].
abstract final class SupplierPurchaseLabels {
  static String orNa(String? value) =>
      value == null || value.trim().isEmpty ? 'general.na'.tr : value;

  static String title(SupplierPurchase purchase) =>
      'supplier_profile.orders_purchase_title'
          .trParams({'number': purchase.purchaseNumber});

  static String itemCount(SupplierPurchase purchase) =>
      'general.items_count'.trParams({'count': '${purchase.items.length}'});

  static String money(String currency, String? value) =>
      '$currency ${value ?? '0.00'}';

  /// `y` / `n` as Completed / Pending; anything else upper-cased.
  static String status(String? status) => switch (status?.toLowerCase()) {
        'y' => 'supplier_profile.orders_status_completed'.tr,
        'n' => 'supplier_profile.orders_status_pending'.tr,
        _ => status == null || status.trim().isEmpty
            ? 'general.na'.tr
            : status.toUpperCase(),
      };

  static AppBadgeTone statusTone(String? status) =>
      switch (status?.toLowerCase()) {
        'y' || 'completed' => AppBadgeTone.success,
        'n' || 'pending' => AppBadgeTone.warning,
        'cancelled' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral,
      };

  static IconData icon(String? status) => switch (status?.toLowerCase()) {
        'y' || 'completed' => Icons.check_circle,
        'n' || 'pending' => Icons.pending_actions,
        'cancelled' => Icons.cancel,
        _ => Icons.shopping_cart,
      };

  /// The tax total when there is one worth showing.
  static String? tax(SupplierPurchase purchase) {
    final tax = purchase.taxTotal;
    if (tax == null || tax.trim().isEmpty) return null;
    return (double.tryParse(tax) ?? 0) == 0 ? null : tax;
  }
}

/// Status pill of a purchase order.
class SupplierPurchaseStatusBadge extends StatelessWidget {
  const SupplierPurchaseStatusBadge({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: SupplierPurchaseLabels.status(status),
        tone: SupplierPurchaseLabels.statusTone(status),
      );
}

/// Round status icon of a purchase order.
class SupplierPurchaseStatusIcon extends StatelessWidget {
  const SupplierPurchaseStatusIcon({
    super.key,
    required this.status,
    this.size = 40,
  });

  final String? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = SupplierPurchaseLabels.statusTone(status);
    return AppIconTile(
      icon: SupplierPurchaseLabels.icon(status),
      size: size,
      radius: size / 2,
      background: tone.background,
      foreground: tone.foreground,
    );
  }
}
