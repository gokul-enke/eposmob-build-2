import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppSurface extends StatelessWidget {
  const AppSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))
          ],
        ),
        child: Padding(padding: padding, child: child),
      );
}
