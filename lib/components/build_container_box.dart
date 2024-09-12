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

  const BuildBoxShadowContainer(
      {super.key,
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
      this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      height: height,
      width: width,
      alignment: alignment,
      decoration: BoxDecoration(
        border: border,
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(circleRadius),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor,
            blurRadius: blurRadius ?? 3,
            offset: offsetValue ?? const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
