import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_text_styles.dart';

/// One label/value pair on a detail screen.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.label),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyles.value.copyWith(
                    color: valueColor ?? AppColors.heading,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Lays [children] (usually [InfoRow]s) out in 1, 2 or 3 columns depending
/// on the available width.
class InfoGrid extends StatelessWidget {
  const InfoGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 240,
    this.maxColumns = 3,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var columns = ((available + spacing) / (minColumnWidth + spacing))
            .floor()
            .clamp(1, maxColumns);
        final width = (available - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
