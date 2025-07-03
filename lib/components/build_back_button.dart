import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double? iconSize;
  final String? text;
  final TextStyle? textStyle;
  final double? spacing;

  const CustomBackButton({
    Key? key,
    this.onPressed,
    this.color,
    this.iconSize,
    this.text,
    this.textStyle,
    this.spacing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onPressed ?? () => Navigator.of(context).pop(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back,
              color: color ?? ColorManager.kPrimaryColor,
              size: iconSize ?? 24.0,
            ),
            if (text != null) ...[
              SizedBox(width: spacing ?? 8.0),
              Text(
                text!,
                style: textStyle ??
                    TextStyle(
                      color: color ?? ColorManager.kPrimaryColor,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              // Icon(
              //   Icons.arrow_forward,
              //   color: color ?? Theme.of(context).primaryColor,
              //   size: iconSize ?? 24.0,
              // ),
            ],
          ],
        ),
      ),
    );
  }
}
