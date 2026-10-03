import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_text_styles.dart';
import 'app_icon_tile.dart';

/// Icon tile + small label + single-line value.
class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconTile(
          icon: icon,
          size: 32,
          iconSize: 16,
          foreground: AppColors.muted,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.value.copyWith(
                  color: valueColor ?? AppColors.heading,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Canvas-coloured strip holding two or more [AppMetric]s separated by
/// vertical dividers.
class AppMetricStrip extends StatelessWidget {
  const AppMetricStrip({super.key, required this.metrics});

  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < metrics.length; i++) {
      if (i > 0) {
        children
          ..add(Container(width: 1, height: 34, color: AppColors.border))
          ..add(const SizedBox(width: 12));
      }
      children.add(Expanded(child: metrics[i]));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: children),
    );
  }
}
