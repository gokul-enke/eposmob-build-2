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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    ViewCategory? viewCategory = categoryProvider.getViewCategory;
    // debugPrint(viewCategory == null ? "viewCategory" : viewCategory.name);
    return SafeArea(
        child: Container(
      margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
        child: ListView(
          children: [
            CustomBackButton(
              onPressed: () {
                sideBarController.index.value = 12;
              },
              text: 'All Categories',
              // Optionally, you can customize the color and size
              // color: ColorManager.customColor,
              // size: 20.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  " Show Category  ",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
              ],
            ),
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: ColorManager.kPrimaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              padding: const EdgeInsets.only(
                left: 20,
                top: 20,
              ),
              margin: const EdgeInsets.only(
                  top: 20, bottom: 0, left: 10, right: 10),
              child: Text(
                " Show Category  ",
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s15, 0.30, Colors.white),
              ),
            ),
            BuildBoxShadowContainer(
                height: size.height, //120,
                margin: const EdgeInsets.only(
                    top: 0, bottom: 10, left: 10, right: 10),
                padding: const EdgeInsets.only(
                    top: 10, bottom: 10, left: 10, right: 10),
                circleRadius: 7,
                offsetValue: const Offset(1, 1),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              BuildBoxShadowContainer(
                                  margin:
                                      const EdgeInsets.only(left: 5, right: 5),
                                  circleRadius: 5,
                                  height: 100,
                                  width: 150,
                                  child: Image.network(
                                    viewCategory!.categoryImageFullPath!,
                                    fit: BoxFit.cover,
                                  )),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BuildBoxShadowContainer(
                                  margin:
                                      const EdgeInsets.only(left: 5, right: 5),
                                  circleRadius: 5,
                                  height: 100,
                                  width: 150,
                                  child: Image.network(
                                    viewCategory.categoryIconFullPath!,
                                    fit: BoxFit.cover,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: CustomRoundButton(
                        title: "Back",
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: () async {
                          sideBarController.index.value = 12;
                        },
                        height: 50,
                        width: size.width * 0.19,
                        fontSize: FontSize.s12,
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    ));
  }
}
