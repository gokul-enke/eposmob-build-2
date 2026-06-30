import 'package:flutter/material.dart';

import '../resources/color_manager.dart';

class BuildBoxShadowContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final double circleRadius;
  final Widget child;
  final Color? color;
  final BoxBorder? border;
  final Alignment? alignment;
  final double? blurRadius;
  final Offset? offsetValue;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final bool showShadow;
  final List<BoxShadow>? boxShadow;

  const BuildBoxShadowContainer({
    super.key,
    this.width,
    this.height,
    this.blurRadius,
    required this.circleRadius,
    required this.child,
    this.padding,
    this.margin,
    this.border,
    this.offsetValue,
    this.color,
    this.alignment,
    this.constraints,
    this.showShadow = true,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      height: height,
      width: width,
      alignment: alignment,
      constraints: constraints,
      decoration: BoxDecoration(
        border: border,
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(circleRadius),
        boxShadow: boxShadow ?? (showShadow ? [
          BoxShadow(
            color: ColorManager.boxShadowColor,
            blurRadius: blurRadius ?? 3,
            offset: offsetValue ?? const Offset(0, 1),
          ),
        ] : null),
      ),
      child: child,
    );
  }
}
