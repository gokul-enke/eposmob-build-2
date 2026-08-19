import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/build_container_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddCategoryPropertiesScreen extends StatelessWidget {
  const AddCategoryPropertiesScreen({super.key});

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = _isMobile(context);
    final double horizontalMargin = isMobile ? 8 : 12;

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: isMobile ? 10 : 20,
          ),
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'add_category_properties.page_title'.tr,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.kTitleTextColor,
                ),
              ),
              const SizedBox(height: 20),
              const BuildBoxShadowContainer(
                circleRadius: 14,
                blurRadius: 10,
                offsetValue: Offset(0, 3),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
