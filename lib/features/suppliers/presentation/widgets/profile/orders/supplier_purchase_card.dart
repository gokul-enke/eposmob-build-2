import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import 'supplier_purchase_labels.dart';

/// Card for one purchase order on narrow layouts.
class SupplierPurchaseCard extends StatelessWidget {
  const SupplierPurchaseCard({
    super.key,
    required this.purchase,
    required this.rowNumber,
    required this.currency,
    required this.onView,
  });

  final SupplierPurchase purchase;
  final int rowNumber;
  final String currency;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      leading: SupplierPurchaseStatusIcon(status: purchase.status),
      title: SupplierPurchaseLabels.title(purchase),
      subtitle: '#$rowNumber · ${SupplierPurchaseLabels.itemCount(purchase)}',
      trailing: SupplierPurchaseStatusBadge(status: purchase.status),
      body: AppMetricStrip(
        metrics: [
          AppMetric(
            icon: Icons.payments_outlined,
            label: 'supplier_profile.orders_label_total'.tr,
            value: SupplierPurchaseLabels.money(currency, purchase.amountTotal),
            valueColor: AppColors.green,
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
