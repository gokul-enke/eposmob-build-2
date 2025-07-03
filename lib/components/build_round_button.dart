import 'package:flutter/material.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../responsive.dart';

class RoundButton extends StatelessWidget {
  final String title;
  final Function fct;
  final double? radius;
  final Size size;
  const RoundButton(
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

class RoundButtonWithIcon extends StatelessWidget {
  final String title;
  final Function fct;
  final Size size;
  final double? width;
  final double? fontSize;
  final double? paddingLeft;
  final String iconPath;
  const RoundButtonWithIcon(
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
      margin: ResponsiveWidget.isTablet(context)
          ? EdgeInsets.only(left: paddingLeft ?? 10)
          : EdgeInsets.only(left: paddingLeft ?? 20),
      padding: EdgeInsets.only(left: paddingLeft ?? 20),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: MaterialButton(
        onPressed: () {
          fct();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            WebsafeSvg.asset(iconPath, color: Colors.white),
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

class CustomRoundButtonWithIcon extends StatelessWidget {
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
  const CustomRoundButtonWithIcon(
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
      this.textColor})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: width, // 200,
      height: height, //size.height * .055,
      margin: ResponsiveWidget.isTablet(context)
          ? const EdgeInsets.only(left: 10)
          : const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? ColorManager.kPrimaryColor),
        color: boxColor ?? ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(radius ?? 8),
      ),
      child: MaterialButton(
        onPressed: () {
          fct();
        },
        child: Row(
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
          ],
        ),
      ),
    );
  }
}

class CustomRoundButton extends StatelessWidget {
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
  const CustomRoundButton({
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? ColorManager.kPrimaryColor),
        color: boxColor ?? ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(radius ?? 5),
      ),
      child: MaterialButton(
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
      ),
    );
  }
}
