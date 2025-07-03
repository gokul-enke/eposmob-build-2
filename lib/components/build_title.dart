import 'package:flutter/material.dart';

import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

class BuildTitle extends StatelessWidget {
  final String title;
  final TextStyle textStyle;

  const BuildTitle({
    Key? key,
    required this.title,
    required this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: textStyle,
    );
  }
}

class BuildTextTile extends StatelessWidget {
  final String title;
  final TextStyle textStyle;
  final bool isStarRed;
  final bool isTextField;

  const BuildTextTile({
    Key? key,
    required this.title,
    required this.textStyle,
    this.isStarRed = false,
    this.isTextField = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16, left: 15),
        child: isTextField
            ? RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: textStyle,
                    ),
                    // Add a red star if isStarRed is true
                    isStarRed
                        ? TextSpan(
                            text: '*',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s18,
                              0.27,
                              Colors.red,
                            ),
                          )
                        : TextSpan(
                            text: '',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s18,
                              0.27,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                  ],
                ),
              )
            : RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: textStyle,
                    ),
                    TextSpan(
                      text: '  ',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s18,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ));
  }
}
