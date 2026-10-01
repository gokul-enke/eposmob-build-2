import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Rounded-square initial avatar. Shows `#` when [name] is empty.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    required this.semanticLabel,
    this.size = 40,
    this.background = AppColors.softBlue,
    this.foreground = AppColors.primary,
  });

  /// Display name the initial is taken from. Empty → `#`.
  final String name;
  final String semanticLabel;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '#' : trimmed[0].toUpperCase();

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: foreground,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
