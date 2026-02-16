import 'package:flutter/material.dart';

import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'build_title.dart';

class BuildPaymentRow extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final EdgeInsets? padding;
  final TextStyle? firstRowTextStyle;
  final TextStyle? secondRowTextStyle;
  final bool? isTextField;
  final Widget? child;
  final Widget?
      titleWidget; // Optional custom widget for title with mixed styles
  const BuildPaymentRow({
    Key? key,
    required this.title,
    required this.amount,
    required this.color,
    this.padding,
    this.firstRowTextStyle,
    this.secondRowTextStyle,
    this.isTextField,
    this.child,
    this.titleWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget leftContent = titleWidget ??
        BuildTitle(
          title: title,
          textStyle: firstRowTextStyle ??
              buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.18,
                color,
              ),
        );

    final Widget rightContent = isTextField == false
        ? BuildTitle(
            title: amount,
            textStyle: secondRowTextStyle ??
                buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.18,
                  color,
                ),
          )
        : child ??
            BuildTitle(
              title: amount,
              textStyle: secondRowTextStyle ??
                  buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.18,
                    color,
                  ),
            );

    return Padding(
      padding: padding ?? const EdgeInsets.all(0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: leftContent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: rightContent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
