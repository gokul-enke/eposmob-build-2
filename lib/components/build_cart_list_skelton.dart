import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class BuildCartListDesign extends StatelessWidget {
  const BuildCartListDesign({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 2,
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) {
        return Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ListTile(
            title: _buildSkeleton(),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 15,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: ColorManager.colorPlaceholder,
            borderRadius: BorderRadius.circular(5),
          ),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 5),
        ),
        const SizedBox(
          height: 10,
        ),
        Container(
          height: 10,
          width: 100,
          color: ColorManager.colorPlaceholder,
          margin: const EdgeInsets.only(bottom: 5),
        ),
      ],
    );
  }
}
