import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import '../customer_avatar.dart';
import '../customer_labels.dart';

/// Card for one customer on narrow screens.
class CustomerListCard extends StatelessWidget {
  const CustomerListCard({
    super.key,
    required this.customer,
    required this.rowNumber,
    required this.onView,
  });

  final CustomerListModelData customer;
  final int rowNumber;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final balance = customer.balance ?? 0;
    return AppListCard(
      leading: CustomerAvatar(name: customer.name, size: 42),
      title: CustomerLabels.name(customer.name),
      subtitle: '#$rowNumber',
      trailing: CustomerTypeBadge(type: customer.customerType),
      body: AppMetricStrip(
        metrics: [
          AppMetric(
            icon: Icons.account_balance_wallet_outlined,
            label: 'customers.balance'.tr,
            value: balance.toStringAsFixed(2),
            valueColor: AppColors.amount(balance),
          ),
          AppMetric(
            icon: Icons.phone_outlined,
            label: 'customers.phone'.tr,
            value: CustomerLabels.phoneOrPlaceholder(customer.phone),
          ),
        ],
      ),
      actionLabel: 'customers.view_profile'.tr,
      actionIcon: Icons.open_in_new_rounded,
      onAction: onView,
    );
  }
}
