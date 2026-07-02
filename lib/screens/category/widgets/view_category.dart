import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_detail_row.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../models/view_category.dart';
import '../../../providers/category_providers.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewCategoryWidget extends StatelessWidget {
  const ViewCategoryWidget({Key? key}) : super(key: key);

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    ViewCategory? viewCategory = categoryProvider.getViewCategory;
    final bool isMobile = _isMobile(context);
    final double horizontalMargin = isMobile ? 8 : 12;

    return SafeArea(
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
          color: Colors.white),
      child: ListView(
        children: [
          CustomBackButton(
            onPressed: () {
              sideBarController.index.value = 12;
            },
            text: 'All Categories',
          ),
          const SizedBox(height: 8),
          Text(
            "Show Category",
            style: buildCustomStyle(FontWeightManager.semiBold,
                FontSize.s20, 0.30, ColorManager.kTitleTextColor),
          ),
          const SizedBox(height: 16),
          BuildBoxShadowContainer(
            circleRadius: 14,
            blurRadius: 10,
            offsetValue: const Offset(0, 3),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BuildDetailRow(
                  title1: "Name",
                  content1: viewCategory?.name ?? "",
                  title2: "Slug",
                  content2: viewCategory?.slug ?? "",
                ),
                BuildDetailRow(
                  title1: "Sort",
                  content1: viewCategory?.sort ?? "",
                  title2: "Arabic",
                  content2: viewCategory?.names?.ar ?? "N/A",
                ),
                BuildDetailRow(
                  title1: "English",
                  content1: viewCategory?.names?.en ?? "N/A",
                  title2: "Hindi",
                  content2: viewCategory?.names?.hi ?? "N/A",
                ),
                const BuildDetailRow(
                  title1: "Category Image ",
                  content1: "",
                  title2: "Category Icon ",
                  content2: "",
                ),
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImagePreview(
                            viewCategory?.categoryImageFullPath,
                            'No image available',
                          ),
                          const SizedBox(height: 12),
                          _buildImagePreview(
                            viewCategory?.categoryIconFullPath,
                            'No icon available',
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildImagePreview(
                              viewCategory?.categoryImageFullPath,
                              'No image available',
                            ),
                          ),
                          Expanded(
                            child: _buildImagePreview(
                              viewCategory?.categoryIconFullPath,
                              'No icon available',
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),
                CustomRoundButton(
                  title: "Back",
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: () async {
                    sideBarController.index.value = 12;
                  },
                  height: 50,
                  width: isMobile ? double.infinity : 180,
                  fontSize: FontSize.s12,
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildImagePreview(String? imageUrl, String emptyLabel) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 5),
      circleRadius: 10,
      height: 120,
      width: double.infinity,
      child: imageUrl != null
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                  Center(child: Text(emptyLabel)),
            )
          : Center(child: Text(emptyLabel)),
    );
  }
}
