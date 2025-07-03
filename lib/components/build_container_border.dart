import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class BuildBorderContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const BuildBorderContainer({
    super.key,
    this.width,
    this.height,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      height: height,
      width: width,
      decoration: BoxDecoration(
        border: Border.all(
          width: 0.4, // Same width as in InputDecoration
          color: ColorManager.grey.withOpacity(0.7), // Same color
        ),
        borderRadius: BorderRadius.circular(6.0), // Same border radius
      ),
      child: child,
    );
  }
}
