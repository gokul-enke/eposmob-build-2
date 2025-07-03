import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class BuildDetailRow extends StatelessWidget {
  final String title1;
  final String content1;
  final String title2;
  final String content2;

  const BuildDetailRow({
    Key? key,
    required this.title1,
    required this.content1,
    required this.title2,
    required this.content2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        title1 != ""
            ? Expanded(
                child: _buildDetailItem(title1, content1),
              )
            : Expanded(
                child: Container(),
              ),
        title2 != ""
            ? Expanded(
                child: _buildDetailItem(title2, content2),
              )
            : Expanded(
                child: Container(),
              ),
      ],
    );
  }

  Widget _buildDetailItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, top: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$title: ",
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s15,
                0.30,
                ColorManager.textColor,
              ),
            ),
            TextSpan(
              text: content,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s15,
                0.30,
                ColorManager.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
