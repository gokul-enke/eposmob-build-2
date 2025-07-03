import 'package:flutter/material.dart';

class BuildErrorText extends StatelessWidget {
  final Widget child;
  final String errorText;
  final Color color;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const BuildErrorText({
    Key? key,
    required this.child,
    required this.errorText,
    this.color = Colors.red,
    this.fontSize = 12,
    this.padding = const EdgeInsets.only(top: 7.0),
    this.margin,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          if (errorText != "" && errorText.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(top: 4.0),
              margin: margin,
              child: Text(
                errorText,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
