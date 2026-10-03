import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// Colour pairs for [AppBadge].
enum AppBadgeTone {
  info(AppColors.softBlue, AppColors.primary),
  success(AppColors.softGreen, AppColors.green),
  danger(AppColors.softRed, AppColors.red),
  warning(AppColors.softAmber, AppColors.amber),
  neutral(AppColors.canvas, AppColors.body);

  const AppBadgeTone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// Small pill label (status, type, tag).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.info,
    this.semanticLabel,
  });

  final String label;
  final AppBadgeTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tone.foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
