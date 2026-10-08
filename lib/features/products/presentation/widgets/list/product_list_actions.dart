import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// The existing View and Delete actions, styled with the shared buttons.
class ProductListActions extends StatelessWidget {
  const ProductListActions({super.key, required this.onView, this.onDelete});
  final VoidCallback onView;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        AppOutlinedButton(
            label: 'list.view'.tr,
            icon: Icons.visibility_outlined,
            height: AppSizes.compactControl,
            onPressed: onView),
        AppOutlinedButton(
            label: 'product.delete'.tr,
            icon: Icons.delete_outline,
            height: AppSizes.compactControl,
            foreground: AppColors.red,
            onPressed: onDelete),
      ]);
}
