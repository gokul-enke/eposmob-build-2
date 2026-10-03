import 'package:flutter/material.dart';

import '../form/form_actions_bar.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

/// Bottom of the location picker: the picked address (or [emptyLabel]) and
/// cancel / confirm buttons. Confirm is disabled until [address] is set.
class LocationPickerFooter extends StatelessWidget {
  const LocationPickerFooter({
    super.key,
    required this.address,
    required this.emptyLabel,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  /// The selected address; null when nothing is picked yet.
  final String? address;
  final String emptyLabel;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;

  /// Null disables the confirm button.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final picked = address != null && address!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: picked ? AppColors.softGreen : AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: picked ? AppColors.green : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: picked ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    picked ? address! : emptyLabel,
                    style: picked
                        ? AppTextStyles.body.copyWith(color: AppColors.green)
                        : AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) => FormActionsBar(
              stacked: constraints.maxWidth < 360,
              submitLabel: confirmLabel,
              submitIcon: Icons.check_rounded,
              onSubmit: onConfirm,
              cancelLabel: cancelLabel,
              onCancel: onCancel,
            ),
          ),
        ],
      ),
    );
  }
}
