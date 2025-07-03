import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';

import 'package:pos_machine/screens/product/widgets/view_image_or_video.dart';
import 'package:pos_machine/screens/product/widgets/view_primary_details.dart';
import 'package:pos_machine/screens/product/widgets/view_product_names.dart';
import 'package:pos_machine/screens/product/widgets/view_product_properties.dart';

import '../../../controllers/sidebar_controller.dart';

import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewProductWidget extends StatefulWidget {
  const ViewProductWidget({Key? key}) : super(key: key);

  @override
  State<ViewProductWidget> createState() => _ViewProductWidgetState();
}

class _ViewProductWidgetState extends State<ViewProductWidget>
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBackButton(
                onPressed: () {
                  sideBarController.index.value = 14;
                },
                text: 'All Products',
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    " Show Product  ",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                ],
              ),
              Container(
                height: 60,
                width: size.width,
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
                  " Show Product  ",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s15, 0.30, Colors.white),
                ),
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
                indicatorColor: ColorManager.kPrimaryColor.withOpacity(0.6),
              ),
              Expanded(
                  child: SizedBox(
                height: size.height,
                child: TabBarView(
                  key: UniqueKey(),
                  controller: tabController,
                  children: [
                    ViewPrimaryDetailsScreen(
                      navigateToScreen: navigateToScreen,
                    ),
                    ViewProductNameScreen(navigateToScreen: navigateToScreen),
                    ViewProductPropertiesScreen(
                        navigateToScreen: navigateToScreen),
                    ViewImageOrVideoScreen(navigateToScreen: navigateToScreen),
                  ],
                ),
              )),
            ],
          ),
        ),
      )),
    );
  }
}
