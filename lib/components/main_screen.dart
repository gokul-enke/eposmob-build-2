import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:pos_machine/responsive.dart';
import 'package:pos_machine/widgets/side_menu_mobile.dart';

import '../controllers/sidebar_controller.dart';
import '../resources/color_manager.dart';
import '../widgets/category_list.dart';

import '../widgets/side_menu.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.find();

    Widget content =
        Obx(() => sideBarController.screens[sideBarController.index.value]);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer:
          ResponsiveWidget.isMobile(context) ? const SideMenuMobile() : null,
      appBar: ResponsiveWidget.isMobile(context)
          ? AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              leading: Builder(builder: (context) {
                return IconButton(
                  color: ColorManager.kPrimaryColor,
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              }),
            )
          : null,
      body: SafeArea(
        child: ResponsiveWidget(
          mobile: const CategoryList(),
          desktop: CollapsibleSidebar(
            sidebarContent: const SideMenu(),
            child: content,
          ),
          tablet: CollapsibleSidebar(
            sidebarContent: const SideMenu(),
            child: content,
          ),
          // desktop: Row(
          //     children: [
          //       const Expanded(
          //         child: SideMenu(),
          //       ),
          //       Expanded(
          //         flex: 4,
          //         // child: CategoryList(),
          //         child: Obx(() =>
          //             sideBarController.screens[sideBarController.index.value]),
          //       ),
          //       // Expanded(
          //       //   flex: size.width > 1340 ? 8 : 10,
          //       //   child: const OrderList(),
          //       // ),
          //       // Expanded(
          //       //   flex: size.width > 1340 ? 2 : 4,
          //       //   child: const SideMenu(),
          //       // ),
          //       // Expanded(
          //       //   flex: size.width > 1340 ? 3 : 5,
          //       //   child: const CategoryList(),
          //       // ),
          //       // Expanded(
          //       //   flex: size.width > 1340 ? 8 : 10,
          //       //   child: const OrderList(),
          //       // ),
          //     ],
          //   ),
          //   tablet: Row(
          //     children: [
          //       Expanded(
          //         flex:
          //             MediaQuery.of(context).orientation == Orientation.portrait
          //                 ? 1200
          //                 : 1200,
          //         child: const SideMenu(),
          //       ),
          //       Expanded(
          //         flex:
          //             MediaQuery.of(context).orientation == Orientation.portrait
          //                 ? 5000
          //                 : 6000,
          //         // child: const CategoryList(),
          //         child: Obx(() =>
          //             sideBarController.screens[sideBarController.index.value]),
          //       ),
          //     ],
          //   ),
        ),
      ),
    );
  }
}
