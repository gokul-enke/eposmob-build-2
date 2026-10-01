import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Close, "create another" (when [onCreateAnother] is set) and create
/// buttons of the add-supplier form. Stacks them full-width, primary first,
/// when [stacked] is true.
class SupplierCreateActions extends StatelessWidget {
  const SupplierCreateActions({
    super.key,
    required this.onCreate,
    this.onCreateAnother,
    this.onClose,
    this.busy = false,
    this.stacked = false,
  });

  static const createKey = ValueKey('supplier-form-create');
  static const createAnotherKey = ValueKey('supplier-form-create-another');
  static const closeKey = ValueKey('supplier-form-close');

  final VoidCallback onCreate;
  final VoidCallback? onCreateAnother;
  final VoidCallback? onClose;
  final bool busy;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final create = AppPrimaryButton(
      key: createKey,
      label: 'add_supplier.btn_create'.tr,
      busy: busy,
      expand: stacked,
      onPressed: onCreate,
    );
    final createAnother = onCreateAnother == null
        ? null
        : AppOutlinedButton(
            key: createAnotherKey,
            label: 'add_supplier.btn_create_another'.tr,
            expand: stacked,
            onPressed: busy ? null : onCreateAnother,
          );
    final close = onClose == null
        ? null
        : AppOutlinedButton(
            key: closeKey,
            label: 'add_supplier.btn_close'.tr,
            expand: stacked,
            foreground: AppColors.body,
            onPressed: busy ? null : onClose,
          );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          create,
          if (createAnother != null) ...[
            const SizedBox(height: AppSpacing.sm),
            createAnother,
          ],
          if (close != null) ...[const SizedBox(height: AppSpacing.sm), close],
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        if (close != null) close,
        if (createAnother != null) createAnother,
        create,
      ],
    );
  }
}
