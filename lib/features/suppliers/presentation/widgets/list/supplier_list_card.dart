import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/supplier.dart';
import '../supplier_labels.dart';

/// Card for one supplier on narrow screens.
class SupplierListCard extends StatelessWidget {
  const SupplierListCard({
    super.key,
    required this.supplier,
    required this.rowNumber,
    required this.onView,
  });

  final Supplier supplier;
  final int rowNumber;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final balance = supplier.currentBalance;
    return AppListCard(
      onTap: onView,
      leading: AppAvatar(
        name: supplier.name,
        semanticLabel: supplier.name,
        size: 42,
      ),
      title: SupplierLabels.orDash(supplier.name),
      subtitle: '#$rowNumber',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppMetricStrip(
            metrics: [
              AppMetric(
                icon: Icons.account_balance_wallet_outlined,
                label: 'suppliers.current_balance'.tr,
                value: balance.toStringAsFixed(2),
                valueColor: AppColors.amount(balance),
              ),
              AppMetric(
                icon: Icons.phone_outlined,
                label: 'suppliers.phone'.tr,
                value: SupplierLabels.orDash(supplier.phone),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'suppliers.email'.tr,
            value: SupplierLabels.orDash(supplier.email),
          ),
          InfoRow(
            icon: Icons.location_on_outlined,
            label: 'suppliers.address'.tr,
            value: SupplierLabels.orDash(supplier.address),
          ),
        ],
      ),
      actionLabel: 'list.view'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: onView,
    );
  }
}
