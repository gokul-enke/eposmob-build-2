import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../resources/asset_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

class BuildCategoryContainer extends StatelessWidget {
  const BuildCategoryContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: ColorManager.textColor1,
            radius: 50,
            child: Container(
              height: 95,
              width: 95,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Container(
                height: 85,
                width: 85,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorManager.colorPlaceholder,
                ),
                alignment: Alignment.center,
              ),
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            '',
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s11, 0.17, Colors.black),
          ),
        ],
      ),
    );
  }
}

class BuildCategoryContainerDummy extends StatelessWidget {
  const BuildCategoryContainerDummy({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: ColorManager.kPrimaryColor,
            radius: 40,
            child: Container(
              height: 80,
              width: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: WebsafeSvg.asset(
                ImageAssets.allCategoryIcon,
                fit: BoxFit.none,
              ),
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            'category.new_category'.tr,
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s11, 0.17, Colors.black),
          ),
        ],
      ),
    );
  }
}
