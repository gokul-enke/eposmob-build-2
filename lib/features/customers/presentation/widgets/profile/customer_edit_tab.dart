import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import '../../navigation/customer_navigation.dart';
import '../form/customer_form.dart';

/// Profile "Edit details" tab: the customer form in edit mode. After a
/// successful update the customers list is shown.
class CustomerEditTab extends StatelessWidget {
  const CustomerEditTab({super.key, required this.customer});

  final CustomerListModelData customer;

  /// Pause before leaving so the success message is seen.
  static const leaveDelay = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'customer_profile.edit_header'.tr,
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomerForm.edit(
            customer: customer,
            onUpdated: (_) => Future<void>.delayed(leaveDelay, () {
              if (context.mounted) CustomerNavigation.openList();
            }),
          ),
        ],
      ),
    );
  }
}
