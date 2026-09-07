import 'package:flutter/material.dart';
import 'package:pos_machine/providers/keyboard_focus_highlight_provider.dart';
import 'package:provider/provider.dart';
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        minHeight: height,
        maxHeight: height,
      ),
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor ?? ColorManager.kPrimaryColor),
          color: boxColor ?? ColorManager.kPrimaryColor,
          borderRadius: BorderRadius.circular(radius ?? 8),
        ),
        child: MaterialButton(
          padding: EdgeInsets.zero,
          minWidth: 0,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () {
            fct();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        fontSize: fontSize,
                        fontWeight: FontWeightManager.medium,
                        color: textColor ?? Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomRoundButton extends StatefulWidget {
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
    super.key,
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
  });

  @override
  State<CustomRoundButton> createState() => _CustomRoundButtonState();
}

class _CustomRoundButtonState extends State<CustomRoundButton> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool focusHighlightEnabled = true;
    try {
      focusHighlightEnabled =
          Provider.of<KeyboardFocusHighlightProvider>(context).enabled;
    } on ProviderNotFoundException {
      focusHighlightEnabled = true;
    }
    final bool isFocused = focusHighlightEnabled && _focusNode.hasFocus;
    final double radius = widget.radius ?? 5;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(
          color: isFocused
              ? (widget.boxColor == Colors.white ? ColorManager.kPrimaryColor : Colors.white.withOpacity(0.8))
              : widget.borderColor ?? ColorManager.kPrimaryColor,
          width: isFocused ? 2 : 1,
        ),
        color: widget.boxColor ?? ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: (widget.boxColor ?? ColorManager.kPrimaryColor).withOpacity(0.45),
                  blurRadius: 8,
                  spreadRadius: 2.5,
                )
              ]
            : null,
      ),
      child: MaterialButton(
        focusNode: _focusNode,
        focusColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        onPressed: widget.isLoading
            ? null
            : () {
                widget.fct();
              },
        child: widget.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                widget.title,
                style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeightManager.semiBold,
                    color: widget.textColor ?? Colors.white),
              ),
      ),
    );
  }
}
