import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import '../customer_avatar.dart';
import '../customer_labels.dart';

/// Avatar, name, id and type of a customer — the summary block of the
/// profile page (sidebar header on wide screens, header card on phones).
class CustomerProfileSummary extends StatelessWidget {
  const CustomerProfileSummary({super.key, required this.customer});

  final CustomerListModelData customer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomerAvatar(name: customer.name, size: 52),
        const SizedBox(height: AppSpacing.sm),
        Text(
          CustomerLabels.name(customer.name),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${'customer_profile.label_id'.tr} ${customer.id ?? ''}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        CustomerTypeBadge(type: customer.customerType),
      ],
    );
  }
}
