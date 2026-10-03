import 'package:flutter/material.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Banner above a report's list: why the data is stale, with a Retry. The
/// rows already loaded stay visible below it.
class ReportErrorBar extends StatelessWidget {
  const ReportErrorBar({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(message,
              style: AppTextStyles.body.copyWith(color: AppColors.red)),
        ),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ]),
    );
  }
}
