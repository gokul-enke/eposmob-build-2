import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class BuildCartListDesign extends StatelessWidget {
  const BuildCartListDesign({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 3,
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) {
        return Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            maintainState: true,
            childrenPadding: const EdgeInsets.only(
              bottom: 10,
            ),
            collapsedBackgroundColor:
                index % 2 == 0 ? Colors.grey.withOpacity(0.1) : null,
            backgroundColor:
                index % 2 == 0 ? Colors.grey.withOpacity(0.1) : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            tilePadding: const EdgeInsets.only(right: 10, left: 5),
            controlAffinity: ListTileControlAffinity.leading,
            iconColor: ColorManager.textColor,
            collapsedIconColor: ColorManager.textColor,
            title: _buildSkeleton(),
            children: const <Widget>[],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: [
        Container(
          height: 10,
          width: double.infinity,
          color: ColorManager.colorPlaceholder,
          margin: const EdgeInsets.only(bottom: 5),
        ),
      ],
    );
  }
}
