import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/supplier.dart';
import '../../navigation/supplier_navigation.dart';
import '../form/supplier_form.dart';

/// Profile "Edit details" tab: the supplier form in edit mode. After a
/// successful update the suppliers list is shown.
class SupplierEditTab extends StatelessWidget {
  const SupplierEditTab({super.key, required this.supplier});

  final Supplier supplier;

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
            'supplier_profile.edit_title'.tr,
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.lg),
          SupplierForm.edit(
            key: ValueKey('supplier-edit-${supplier.id}'),
            supplier: supplier,
            onUpdated: () => Future<void>.delayed(leaveDelay, () {
              if (context.mounted) SupplierNavigation.openList();
            }),
          ),
        ],
      ),
    );
  }
}
