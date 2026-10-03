import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// Small rounded square holding an icon — used in section headers, metrics
/// and page headers.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.size = 34,
    this.iconSize,
    this.background = AppColors.canvas,
    this.foreground = AppColors.body,
    this.radius = AppRadius.tile,
  });

  final IconData icon;
  final double size;
  final double? iconSize;
  final Color background;
  final Color foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.53, color: foreground),
    );
  }
}
