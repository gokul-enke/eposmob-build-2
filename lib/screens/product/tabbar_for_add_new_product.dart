import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';

import '../../controllers/sidebar_controller.dart';

import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/add_product/add_image_or_video.dart';
import 'widgets/add_product/add_primary_details.dart';
import 'widgets/add_product/add_product_names.dart';
import 'widgets/add_product/add_product_properties.dart';

class TabBarForAddNewProduct extends StatefulWidget {
  const TabBarForAddNewProduct({Key? key}) : super(key: key);

  @override
  State<TabBarForAddNewProduct> createState() => _TabBarForAddNewProductState();
}

class _TabBarForAddNewProductState extends State<TabBarForAddNewProduct>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  SideBarController sideBarController = Get.put(SideBarController());
  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void navigateToScreen(int index) {
    tabController.animateTo(index);
  }

  void navigateToPreviousScreen(int index) {
    if (index > 0) {
      tabController.animateTo(index - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SizedBox(
        height: size.height,
        child: SafeArea(
          child: Container(
            margin:
                const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
              padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBackButton(
                      onPressed: () {
                        sideBarController.index.value = 14;
                      },
                      text: 'All Products',
                      // Optionally, you can customize the color and size
                      // color: ColorManager.customColor,
                      // size: 20.0,
                    ),
                    Text(
                      'Add New Product',
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s20, 0.30, ColorManager.textColor),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    TabBar(
                      controller: tabController,
                      key: UniqueKey(),
                      tabs: const [
                        Tab(
                          text: 'Primary Details',
                        ),
                        Tab(text: 'Product Names'),
                        Tab(text: 'Product Properties'),
                        Tab(text: 'Image/Video'),
                      ],
                      labelColor: ColorManager.kPrimaryColor,
                      indicatorColor:
                          ColorManager.kPrimaryColor.withOpacity(0.6),
                    ),
                    Expanded(
                        child: SizedBox(
                      height: size.height,
                      child: TabBarView(
                        key: UniqueKey(),
                        controller: tabController,
                        children: [
                          AddProductPageScreen(
                            navigateToScreen: navigateToScreen,
                          ),
                          AddProductNamePageScreen(
                              navigateToScreen: navigateToScreen),
                          AddProductPropertiesScreen(
                              navigateToScreen: navigateToScreen),
                          AddProductImageOrVideoScreen(
                              navigateToScreen: navigateToScreen),
                        ],
                      ),
                    ))
                  ]),
            ),
          ),
        ));
  }
}
