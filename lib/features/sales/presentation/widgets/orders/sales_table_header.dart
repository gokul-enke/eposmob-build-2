import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SalesTableHeader extends StatelessWidget {
  const SalesTableHeader({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }
}
