import 'package:flutter/material.dart';

import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'build_title.dart';

class BuildPaymentMethodRow extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final double? padding;
  final TextStyle? firstRowTextStyle;
  final TextStyle? secondRowTextStyle;
  final TextStyle? thirdRowTextStyle;
  const BuildPaymentMethodRow({
    Key? key,
    required this.title,
    required this.amount,
    required this.color,
    this.padding,
    this.firstRowTextStyle,
    this.secondRowTextStyle,
    this.thirdRowTextStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BuildTitle(
          title: title,
          textStyle: firstRowTextStyle ??
              buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.18,
                color,
              ),
        ),
        BuildTitle(
          title: amount,
          textStyle: secondRowTextStyle ??
              buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.18,
                color,
              ),
        ),
        // BuildTitle(
        //   title: amount,
        //   textStyle: thirdRowTextStyle ??
        //       buildCustomStyle(
        //         FontWeightManager.medium,
        //         FontSize.s12,
        //         0.18,
        //         color,
        //       ),
        // ),
      ],
    );
  }
}
