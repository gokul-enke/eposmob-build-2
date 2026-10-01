import 'package:flutter/material.dart';

import '../buttons/app_buttons.dart';

/// Cancel + primary submit buttons at the bottom of a form. Stacks the
/// buttons full-width when [stacked] is true (mobile).
class FormActionsBar extends StatelessWidget {
  const FormActionsBar({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.cancelLabel,
    this.onCancel,
    this.busy = false,
    this.stacked = false,
    this.submitIcon,
  });

  final String submitLabel;
  final VoidCallback? onSubmit;
  final String? cancelLabel;
  final VoidCallback? onCancel;
  final bool busy;
  final bool stacked;
  final IconData? submitIcon;

  @override
  Widget build(BuildContext context) {
    final submit = AppPrimaryButton(
      label: submitLabel,
      icon: submitIcon,
      busy: busy,
      expand: stacked,
      onPressed: onSubmit,
    );
    final cancel = cancelLabel == null
        ? null
        : AppOutlinedButton(
            label: cancelLabel!,
            height: 44,
            expand: stacked,
            onPressed: busy ? null : onCancel,
          );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          submit,
          if (cancel != null) ...[const SizedBox(height: 10), cancel],
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (cancel != null) ...[cancel, const SizedBox(width: 12)],
        submit,
      ],
    );
  }
}
