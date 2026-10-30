import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Cancel, Create & add another and Create, as on the other kit forms
/// (see the add-supplier form). Stacked full-width, primary first, when
/// [stacked].
class GeneralPaymentFormActions extends StatelessWidget {
  const GeneralPaymentFormActions({
    super.key,
    required this.onCreate,
    required this.onCreateAnother,
    required this.onCancel,
    this.busy = false,
    this.stacked = false,
  });

  static const createKey = ValueKey('general-payment-create');
  static const createAnotherKey = ValueKey('general-payment-create-another');
  static const cancelKey = ValueKey('general-payment-cancel');

  final VoidCallback onCreate;
  final VoidCallback onCreateAnother;
  final VoidCallback onCancel;
  final bool busy;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final create = AppPrimaryButton(
        key: createKey,
        label: 'general_payments.btn_create'.tr,
        busy: busy,
        expand: stacked,
        onPressed: onCreate);
    final createAnother = AppOutlinedButton(
        key: createAnotherKey,
        label: 'general_payments.btn_create_another'.tr,
        expand: stacked,
        onPressed: busy ? null : onCreateAnother);
    final cancel = AppOutlinedButton(
        key: cancelKey,
        label: 'general_payments.btn_cancel'.tr,
        expand: stacked,
        foreground: AppColors.body,
        onPressed: busy ? null : onCancel);
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          create,
          const SizedBox(height: AppSpacing.sm),
          createAnother,
          const SizedBox(height: AppSpacing.sm),
          cancel,
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [cancel, createAnother, create],
    );
  }
}
