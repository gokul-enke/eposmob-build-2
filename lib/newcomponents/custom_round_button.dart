import 'package:flutter/material.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../responsive.dart';

class CustomRoundButton extends StatelessWidget {
  final String title;
  final Function fct;
  final double? radius;
  final Size size;
  const CustomRoundButton(
      {Key? key,
      required this.title,
      required this.fct,
      required this.size,
      this.radius})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height * .07,
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(radius ?? 5),
      ),
      child: MaterialButton(
        onPressed: () {
          fct();
        },
        child: Text(
          title,
          style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: FontSize.s14,
              fontWeight: FontWeightManager.semiBold,
              color: Colors.white),
        ),
      ),
    );
  }
}

class CustomRoundButtonWithIcon extends StatelessWidget {
  final String title;
  final Function fct;
  final Size size;
  final double? width;
  final double? fontSize;
  final double? paddingLeft;
  final String iconPath;
  const CustomRoundButtonWithIcon(
      {Key? key,
      required this.title,
      required this.fct,
      this.width,
      required this.size,
      this.paddingLeft,
      this.fontSize,
      required this.iconPath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: width ?? 200,
      height: size.height * .055,
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: MaterialButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          fct();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            WebsafeSvg.asset(
              iconPath,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            const SizedBox(
              width: 15,
            ),
            Text(
              title,
              style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: fontSize ?? FontSize.s14,
                  fontWeight: FontWeightManager.medium,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomRoundButtonWithIconAdvanced extends StatelessWidget {
  final String title;
  final Function fct;
  final Size size;
  final double fontSize;
  final double height;
  final double? radius;
  final double width;
  final Icon icon;
  final Color? boxColor;
  final Color? borderColor;
  final Color? textColor;
  final bool isLoading;
  final String? shortcutLabel;
  const CustomRoundButtonWithIconAdvanced(
      {Key? key,
      required this.title,
      required this.fct,
      required this.size,
      this.radius,
      required this.fontSize,
      required this.icon,
      required this.height,
      required this.width,
      this.boxColor,
      this.borderColor,
      this.textColor,
      this.isLoading = false,
      this.shortcutLabel})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: width, // 200,
      height: height, //size.height * .055,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? ColorManager.kPrimaryColor),
        color: boxColor ?? ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(radius ?? 8),
      ),
      child: MaterialButton(
        padding: EdgeInsets.zero,
        onPressed: isLoading
            ? null
            : () {
                fct();
              },
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      textColor ?? Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    title,
                    style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        fontSize: fontSize,
                        fontWeight: FontWeightManager.medium,
                        color: textColor ?? Colors.white),
                  ),
                  if (shortcutLabel != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: (textColor ?? Colors.white).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        shortcutLabel!,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: (textColor ?? Colors.white).withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class CustomRoundButtonAdvanced extends StatelessWidget {
  final String title;
  final Function fct;
  final double fontSize;
  final double height;
  final double width;
  final Color? boxColor;
  final Color? borderColor;
  final Color? textColor;
  final double? radius;
  final bool isLoading;
  final FocusNode? focusNode;
  const CustomRoundButtonAdvanced({
    Key? key,
    required this.title,
    required this.fct,
    required this.height,
    required this.width,
    required this.fontSize,
    this.boxColor,
    this.textColor,
    this.radius,
    this.borderColor,
    this.isLoading = false,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget buttonContent = MaterialButton(
      focusNode: focusNode,
      onPressed: isLoading
          ? null
          : () {
              fct();
            },
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              title,
              style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: fontSize,
                  fontWeight: FontWeightManager.semiBold,
                  color: textColor ?? Colors.white),
            ),
    );

    if (focusNode != null) {
      return ListenableBuilder(
        listenable: focusNode!,
        builder: (context, _) {
          final hasFocus = focusNode!.hasFocus;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(
                color: hasFocus
                    ? ColorManager.kPrimaryColor
                    : (borderColor ?? ColorManager.kPrimaryColor),
                width: hasFocus ? 1.5 : 1,
              ),
              color: boxColor ?? ColorManager.kPrimaryColor,
              borderRadius: BorderRadius.circular(radius ?? 5),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: ColorManager.kPrimaryColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ]
                  : null,
            ),
            child: buttonContent,
          );
        },
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? ColorManager.kPrimaryColor),
        color: boxColor ?? ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(radius ?? 5),
      ),
      child: buttonContent,
    );
  }
}
