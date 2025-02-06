import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/responsive.dart';
import 'package:pos_machine/screens/kiosk/kiosk.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../controllers/sidebar_controller.dart';
import '../providers/auth_model.dart';
import '../providers/authentication_providers.dart';

import '../providers/sales_provider.dart';
import '../providers/shared_preferences.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../screens/login/login.dart';
import 'drawer_list_tile_expandable.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Widget child;
  final Widget sidebarContent;

  const CollapsibleSidebar({
    Key? key,
    required this.child,
    required this.sidebarContent,
  }) : super(key: key);

  @override
  _CollapsibleSidebarState createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar> {
  bool _isExpanded = true;
  final double _expandedWidth = 200;
  final double _collapsedWidth = 40;

  void _toggleSidebar() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isExpanded ? _expandedWidth : _collapsedWidth,
              child: _isExpanded
                  ? widget.sidebarContent
                  : Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: _toggleSidebar,
                          ),
                        ],
                      ),
                    ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ],
    );
  }
}

class SideMenu extends StatelessWidget {
  const SideMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    final authModel = Provider.of<AuthModel>(context);
    // Size size = MediaQuery.of(context).size;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              final _CollapsibleSidebarState? sidebarState =
                  context.findAncestorStateOfType<_CollapsibleSidebarState>();
              sidebarState?._toggleSidebar();
            },
          ),
          const SizedBox(
            height: 15,
          ),
          Center(child: WebsafeSvg.asset(ImageAssets.posLogo)),
          const SizedBox(
            height: 5,
          ),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: 'Smart',
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s18, 0.27, ColorManager.textColor),
                children: <TextSpan>[
                  TextSpan(
                    text: 'POS',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s18, 0.27, ColorManager.kPrimaryColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          // SizedBox(
          //   height: 300,
          //   child: Row(
          //     children: [
          //       NavigationRail(destinations: [
          //         NavigationRailDestination(
          //             icon: WebsafeSvg.asset(
          //               ImageAssets.homeIcon,
          //             ),
          //             label: Text(
          //               "Home",
          //               style: TextStyle(color: Colors.black),
          //             )),
          //         NavigationRailDestination(
          //             icon: WebsafeSvg.asset(
          //               ImageAssets.homeIcon,
          //             ),
          //             label: Text("Home")),
          //         NavigationRailDestination(
          //             icon: WebsafeSvg.asset(
          //               ImageAssets.homeIcon,
          //             ),
          //             label: Text("Home")),
          //         NavigationRailDestination(
          //             icon: WebsafeSvg.asset(
          //               ImageAssets.homeIcon,
          //             ),
          //             label: Text("Home")),
          //       ], selectedIndex: 0)
          //     ],
          //   ),
          // ),
          // RoundButtonWithIcon(
          //   title: 'Home',
          //   fct: () {},
          //   size: size,
          //   iconPath: ImageAssets.homeIcon,
          // ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.homeIcon,
              title: 'Home',
              onTap: () {
                debugPrint(" 'Home',${sideBarController.index.value}");
                sideBarController.index.value = 0;
              },
              selected: sideBarController.index.value == 0,
            ),
          ),
          // Obx(
          //   () => DrawerListTile(
          //     iconPath: ImageAssets.homeIcon,
          //     title: 'Home Old',
          //     onTap: () {
          //       debugPrint(" 'Home Old',${sideBarController.index.value}");
          //       sideBarController.index.value = 45;
          //     },
          //     selected: sideBarController.index.value == 45,
          //   ),
          // ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.barcodeIcon,
              title: 'Billing',
              onTap: () {
                debugPrint(" Billing, ${sideBarController.index.value}");
                sideBarController.index.value = 46;
              },
              selected: sideBarController.index.value == 46,
            ),
          ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.homeIcon,
              title: 'Kiosk',
              onTap: () {
                Get.to(() => const KioskScreen());
              },
              selected: sideBarController.index.value == 900,
            ),
          ),

          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.dashBoardIcon,
              title: 'Dashboard',
              onTap: () {
                debugPrint(" 'Dashboard',${sideBarController.index.value}");
                sideBarController.index.value = 1;
              },
              selected: sideBarController.index.value == 1,
            ),
          ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.saleIcon,
              title: 'Sales',
              onTap: () {
                debugPrint(" 'Sales',${sideBarController.index.value}");
                sideBarController.index.value = 2;
                final salesProvider =
                    Provider.of<SalesProvider>(context, listen: false);
                String? accessToken =
                    Provider.of<AuthModel>(context, listen: false).token;
                //-------------------------
                salesProvider.fetchOrders(
                  accessToken: accessToken ?? '',
                  storeId: 1,
                );
              },
              selected: sideBarController.index.value == 2 ||
                  sideBarController.index.value == 11,
            ),
          ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.saleIcon,
              title: 'Sales Return',
              onTap: () {
                sideBarController.index.value = 50;
              },
              selected: sideBarController.index.value == 50 ||
                  sideBarController.index.value == 49,
            ),
          ),
          Obx(
            () => DrawerListTile(
              // onTapTitle1: () {
              //   sideBarController.index.value = 12;
              // },
              // onTapTitle2: () {
              //   sideBarController.index.value = 13;
              // },
              // listTitle1: "Category",
              // listTitle2: "Category Properties",
              iconPath: ImageAssets.creditCardIcon,
              title: 'Category',
              onTap: () {
                sideBarController.index.value = 12;
                debugPrint(" 'Category',${sideBarController.index.value}");
              },
              selected: sideBarController.index.value == 12 ||
                  sideBarController.index.value == 13 ||
                  sideBarController.index.value == 27 ||
                  sideBarController.index.value == 16 ||
                  sideBarController.index.value == 34,
            ),
          ),
          Obx(
            () => DrawerListTileExpandableColumn(
                onTapTitle1: () {
                  sideBarController.index.value = 14;
                },
                onTapTitle2: () {
                  sideBarController.index.value = 15;
                },
                listTitle1: "Product",
                listTitle2: "Stock",
                iconPath: ImageAssets.allCategoryIcon,
                title: 'Product',
                onTap: () async {
                  sideBarController.index.value = 14;
                  debugPrint(" 'Category',${sideBarController.index.value}");
                },
                selected: sideBarController.index.value == 14 ||
                    sideBarController.index.value == 15 ||
                    sideBarController.index.value == 18 ||
                    sideBarController.index.value == 28 ||
                    sideBarController.index.value == 17 ||
                    sideBarController.index.value == 33 ||
                    sideBarController.index.value == 35),
          ),
          Obx(
            () => DrawerListTileExpandableColumn(
                onTapTitle1: () {
                  sideBarController.index.value = 19;
                },
                onTapTitle2: () {
                  sideBarController.index.value = 26;
                },
                listTitle1: "Purchase",
                listTitle2: "Purchase Voucher",
                iconPath: ImageAssets.cardIcon,
                title: 'Purchase',
                onTap: () async {
                  sideBarController.index.value = 19;
                  debugPrint(" 'Purchase',${sideBarController.index.value}");
                },
                selected: sideBarController.index.value == 19 ||
                    sideBarController.index.value == 29 ||
                    sideBarController.index.value == 20 ||
                    sideBarController.index.value == 26 ||
                    sideBarController.index.value == 37 ||
                    sideBarController.index.value == 36),
          ),
          // Obx(
          //   () => DrawerListTile(
          //     iconPath: ImageAssets.cartIcon,
          //     title: 'Cart',
          //     items: Provider.of<Cart>(context, listen: true).getCartItems,
          //     onTap: () {
          //       sideBarController.index.value = 3;
          //       debugPrint(" 'Cart',${sideBarController.index.value}");
          //     },
          //     selected: sideBarController.index.value == 3,
          //   ),
          // ),
          Obx(
            () => DrawerListTileExpandableColumn(
              onTapTitle1: () {
                sideBarController.index.value = 21;
              },
              // onTapTitle2: () {
              //   sideBarController.index.value = 22;
              // },
              onTapTitle3: () {
                sideBarController.index.value = 23;
              },
              onTapTitle2: () {
                sideBarController.index.value = 47;
              },
              listTitle1: "Invoice",
              // listTitle2: "Voucher",
              listTitle3: "Transactions",
              listTitle2: "Receipts",
              iconPath: ImageAssets.transactionIcon,
              title: 'Accounts',
              onTap: () {
                sideBarController.index.value = 21;
                debugPrint(" 'Category',${sideBarController.index.value}");
              },
              selected: sideBarController.index.value == 21 ||
                  sideBarController.index.value == 22 ||
                  sideBarController.index.value == 30 ||
                  sideBarController.index.value == 31 ||
                  sideBarController.index.value == 32 ||
                  sideBarController.index.value == 23 ||
                  sideBarController.index.value == 24 ||
                  sideBarController.index.value == 25 ||
                  sideBarController.index.value == 47,
            ),
          ),
          // Obx(
          //   () => DrawerListTile(
          //     iconPath: ImageAssets.transactionIcon,
          //     title: 'Transaction',
          //     onTap: () {
          //       sideBarController.index.value = 4;
          //       debugPrint(" 'Transaction',${sideBarController.index.value}");
          //     },
          //     selected: sideBarController.index.value == 4,
          //   ),
          // ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.customerIcon,
              title: 'Customers',
              onTap: () {
                sideBarController.index.value = 5;
                debugPrint(" 'Customers',${sideBarController.index.value}");
              },
              selected: sideBarController.index.value == 5 ||
                  sideBarController.index.value == 9 ||
                  sideBarController.index.value == 38,
            ),
          ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.cardIcon,
              title: 'Loyalty Card',
              onTap: () {
                sideBarController.index.value = 6;
                debugPrint(" 'Loyality Card',${sideBarController.index.value}");
              },
              selected: sideBarController.index.value == 6,
            ),
          ),
          Obx(
            () => DrawerListTileExpandableColumn(
                onTapTitle1: () {
                  sideBarController.index.value = 39;
                },
                onTapTitle2: () {
                  sideBarController.index.value = 40;
                },
                onTapTitle3: () {
                  sideBarController.index.value = 41;
                },
                onTapTitle4: () {
                  sideBarController.index.value = 42;
                },
                listTitle1: "Account Book",
                listTitle2: "Product Sales Report",
                listTitle3: "Sales Report",
                listTitle4: "Supplier Sales Report",
                icon: Icons.bar_chart,
                title: 'Reports',
                onTap: () {
                  sideBarController.index.value = 39;
                  debugPrint(" 'Reports',${sideBarController.index.value}");
                },
                selected: sideBarController.index.value == 39 ||
                    sideBarController.index.value == 40 ||
                    sideBarController.index.value == 41 ||
                    sideBarController.index.value == 42),
          ),
          Obx(
            () => DrawerListTileExpandableColumn(
                onTapTitle1: () {
                  sideBarController.index.value = 43;
                },
                listTitle1: "Location Management",
                icon: Icons.settings,
                title: 'Settings',
                onTap: () {
                  sideBarController.index.value = 43;
                  debugPrint(" 'Settings',${sideBarController.index.value}");
                },
                selected: sideBarController.index.value == 43),
          ),
          const SizedBox(
            height: 15,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 45.0),
            child: Text(
              'Other',
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
                  0.16, ColorManager.textColor),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.notificationIcon,
              title: 'Notifications',
              items: 3,
              onTap: () {
                sideBarController.index.value = 7;
                debugPrint(" 'Notifications',${sideBarController.index.value}");
              },
              selected: sideBarController.index.value == 7,
            ),
          ),

          Obx(
            () => DrawerListTile(
              iconPath: ImageAssets.supportIcon,
              title: 'Support',
              onTap: () {
                sideBarController.index.value = 8;
                debugPrint(" 'Support',${sideBarController.index.value}");
              },
              selected: sideBarController.index.value == 8,
            ),
          ),

          DrawerListTile(
            iconPath: ImageAssets.logoutIcon,
            title: 'Logout',
            onTap: () async {
              String token = authModel.token ?? '';
              showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  });
              await AuthenticationProvider()
                  .logout(token, context)
                  .then((value) async {
                if (value["status"] == "success") {
                  authModel.logout();
                  SharedPreferenceProvider().removeTokenAndCustomerId();

                  debugPrint(" authmodel logout token ${authModel.token}");
                  showScaffold(
                    context: context,
                    message: '${value["message"]}',
                  );
                  Navigator.pop(context);
                  await Future.delayed(const Duration(seconds: 0)).then(
                      (value) => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignInScreen())));
                } else {
                  Navigator.pop(context);
                  showScaffoldError(
                    context: context,
                    message: '${value["message"]}',
                  );
                }
              });
              debugPrint(" 'Logout',${sideBarController.index.value}");
            },
            selected: false,
          ),
          const SizedBox(
            height: 10,
          ),
          Container(
            height: 170,
            width: 180,
            margin: ResponsiveWidget.isTablet(context)
                ? const EdgeInsets.only(
                    left: 20, top: 20, bottom: 10, right: 10)
                : const EdgeInsets.only(left: 30, top: 20, bottom: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(
                    color: ColorManager.boxShadowColor,
                    blurRadius: 6,
                    offset: Offset(1, 1),
                  ),
                ],
                color: Colors.white),
            child: Column(
              children: [
                const SizedBox(
                  height: 5,
                ),
                const CircleAvatar(
                  backgroundImage: AssetImage(ImageAssets.profilePhotoIcon),
                ),
                const SizedBox(
                  height: 10,
                ),
                FutureBuilder<String>(
                  future: SharedPreferenceProvider().getCustomerName(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(
                        snapshot.data ?? 'Default Name',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s14, 0.21, ColorManager.textColor),
                      );
                    } else {
                      return const CircularProgressIndicator(); // Or any loading widget
                    }
                  },
                ),
                const SizedBox(
                  height: 10,
                ),
                InkWell(
                  onTap: () {
                    sideBarController.index.value = 10;
                  },
                  child: Container(
                      height: 30,
                      width: 130,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ColorManager.containerShadowColor1,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'Open profile',
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s12, 0.16, ColorManager.textColor),
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Center(
            child: Text(
              '2022 SmartPOP App',
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.16, ColorManager.textColor),
            ),
          ),
          const SizedBox(
            height: 50,
          ),
        ],
      ),
    );
  }
}

class DrawerListTile extends StatelessWidget {
  final String iconPath;
  final String title;
  final int? items;
  final bool selected;
  final VoidCallback onTap;
  const DrawerListTile({
    super.key,
    required this.iconPath,
    required this.title,
    required this.selected,
    required this.onTap,
    this.items,
  });

  @override
  Widget build(BuildContext context) {
    return selected
        ? Stack(
            children: [
              Positioned.fill(
                  child: Container(
                alignment: Alignment.center,
                width: 200,
                height: MediaQuery.of(context).size.height * .055,
                margin: ResponsiveWidget.isTablet(context)
                    ? const EdgeInsets.only(left: 10, bottom: 5)
                    : const EdgeInsets.only(left: 20, bottom: 5),
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              )),
              ListTile(
                selected: selected,
                contentPadding: ResponsiveWidget.isTablet(context)
                    ? const EdgeInsets.only(left: 15, right: 10)
                    : const EdgeInsets.only(left: 45, right: 15),
                horizontalTitleGap: 0.0,
                visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                minVerticalPadding: 0,
                onTap: onTap,
                leading: WebsafeSvg.asset(iconPath, color: Colors.white),
                trailing: items != null
                    ? buildNotification(
                        item: items ?? 0,
                        selected: selected,
                      )
                    : const SizedBox(
                        height: 5,
                        width: 5,
                      ),
                title: Text(
                  title,
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s14, 0.21, ColorManager.textColor),
                ),
              ),
            ],
          )
        :
        //     Container(
        //   alignment: Alignment.center,
        //   // width: 200,
        //   // height: MediaQuery.of(context).size.height * .055,
        //   // margin: ResponsiveWidget.isTablet(context)
        //   //     ? const EdgeInsets.only(left: 10, bottom: 5)
        //   //     : const EdgeInsets.only(left: 20, bottom: 5),
        // //  margin: const EdgeInsets.only(left: 20),
        //   decoration: BoxDecoration(
        //     color: selected ? ColorManager.kPrimaryColor : Colors.transparent,
        //     borderRadius: BorderRadius.circular(8),
        //   ),
        //   child:
        ListTile(
            selected: selected,
            contentPadding: ResponsiveWidget.isTablet(context)
                ? const EdgeInsets.only(left: 15, right: 10)
                : const EdgeInsets.only(left: 45, right: 15),
            horizontalTitleGap: 0.0,
            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
            minVerticalPadding: 0,
            onTap: onTap,
            leading: WebsafeSvg.asset(iconPath,
                color: ColorManager.kPrimaryColor
                // color: selected ? Colors.white : ColorManager.kPrimaryColor
                ),
            trailing: items != null
                ? buildNotification(
                    item: items ?? 0,
                    selected: selected,
                  )
                : const SizedBox(
                    height: 5,
                    width: 5,
                  ),
            title: Text(
              title,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                  0.21, ColorManager.textColor),
            ),
          );
  }
}

Widget buildNotification({
  required int item,
  required bool selected,
}) {
  return Stack(
    children: [
      Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : ColorManager.kPrimaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$item',
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeightManager.regular,
              fontFamily: FontConstants.fontFamily,
              fontSize: FontSize.s10,
              letterSpacing: 0.16,
            )),
      ),
    ],
  );
}
