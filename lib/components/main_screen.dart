import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/responsive.dart';
import 'package:pos_machine/widgets/side_menu_mobile.dart';

import '../controllers/sidebar_controller.dart';
import '../resources/color_manager.dart';
import '../widgets/user_switcher.dart';

import '../widgets/side_menu.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late SideBarController sideBarController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    sideBarController = Get.find();
  }

  /// On mobile, Android's left-edge back gesture overlaps the drawer drag zone.
  /// Intercept root back: close drawer if open, otherwise open drawer (POS-safe).
  void _handleMobileBack(bool didPop, Object? result) {
    if (didPop) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
      return;
    }

    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState == null) return;

    if (scaffoldState.isDrawerOpen) {
      scaffoldState.closeDrawer();
    } else {
      scaffoldState.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    Widget content =
        Obx(() => sideBarController.screens[sideBarController.index.value]);

    final scaffold = Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: isMobile ? const SideMenuMobile() : null,
      drawerEnableOpenDragGesture: isMobile,
      appBar: isMobile
          ? AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              centerTitle: true,
              title: Obx(() {
                final title = sideBarController.billingMobileAppBarTitle.value;
                final onBilling =
                    sideBarController.index.value ==
                        SideBarController.billingScreenIndex;
                if (onBilling && title != null) {
                  return Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  );
                }
                return const SidebarBrandLogo(height: 30);
              }),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (ctx) {
                          return SafeArea(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                              ),
                              child: const SizedBox(
                                height: 420,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: UserSwitcher(),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(
                          color: ColorManager.kPrimaryColor,
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_outline,
                          color: ColorManager.kPrimaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
          mobile: content,
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

    if (!isMobile) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleMobileBack,
      child: scaffold,
    );
  }
}
