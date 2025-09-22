import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/responsive.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../controllers/sidebar_controller.dart';
import '../providers/auth_model.dart';
import '../providers/authentication_providers.dart';

import '../providers/sales_provider.dart';
import '../providers/shared_preferences.dart';
import '../providers/supplier_provider.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../screens/login/login.dart';
import 'drawer_list_tile_expandable.dart';
import '../widgets/user_switcher.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Widget child;
  final Widget sidebarContent;

  const CollapsibleSidebar({
    Key? key,
    required this.child,
    required this.sidebarContent,
  }) : super(key: key);

  @override
  CollapsibleSidebarState createState() => CollapsibleSidebarState();
}

class CollapsibleSidebarState extends State<CollapsibleSidebar> {
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
              height: double.infinity,
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
            // Wrap child in a stateful widget to preserve its state
            Expanded(
              child: _PreservedChild(
                child: widget.child,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Helper widget to preserve child state during parent rebuilds
class _PreservedChild extends StatefulWidget {
  final Widget child;

  const _PreservedChild({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _PreservedChildState createState() => _PreservedChildState();
}

class _PreservedChildState extends State<_PreservedChild>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class SideMenu extends StatefulWidget {
  const SideMenu({Key? key}) : super(key: key);

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  void _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
    setState(() {
      userRole = role;
    });
  }

  // Helper method to check if user has specific role
  bool _hasRole(String role) {
    return userRole == role;
  }

  // Helper method to check if user has any of the specified roles
  bool _hasAnyRole(List<String> roles) {
    return roles.contains(userRole);
  }

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    final authModel = Provider.of<AuthModel>(context);
    // Size size = MediaQuery.of(context).size;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              final CollapsibleSidebarState? sidebarState =
                  context.findAncestorStateOfType<CollapsibleSidebarState>();
              sidebarState?._toggleSidebar();
            },
          ),
          const SizedBox(
            height: 15,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Center(
              child: Image.asset(
                ImageAssets.posImageLogo,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // const SizedBox(
          //   height: 5,
          // ),
          // Center(
          //   child: RichText(
          //     textAlign: TextAlign.center,
          //     text: TextSpan(
          //       text: 'Cloud',
          //       style: buildCustomStyle(FontWeightManager.semiBold,
          //           FontSize.s18, 0.27, ColorManager.textColor),
          //       children: <TextSpan>[
          //         TextSpan(
          //           text: 'POS',
          //           style: buildCustomStyle(FontWeightManager.semiBold,
          //               FontSize.s18, 0.27, ColorManager.kPrimaryColor),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          if (_hasRole('sales_executive'))
            const SizedBox(
              height: 20,
            ),
          if (_hasRole('sales_executive'))
            Builder(
              builder: (context) {
                debugPrint("🔧 SideMenu: Building UserSwitcher widget");
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0),
                  child: UserSwitcher(),
                );
              },
            ),
          const SizedBox(
            height: 20,
          ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.homeIcon,
                title: 'Home',
                onTap: () {
                  sideBarController.index.value = 46;
                },
                selected: sideBarController.index.value == 46,
              ),
            ),
          if (_hasAnyRole(['attender']))
            // if (_hasRole('attender'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.barcodeIcon,
                title: 'Restaurant',
                onTap: () {
                  sideBarController.index.value = 55;
                },
                selected: sideBarController.index.value == 55,
              ),
            ),
          if (_hasAnyRole(['kitchen_master']))
            // if (_hasRole('kitchen_master'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.barcodeIcon,
                title: 'Kitchen Master',
                onTap: () {
                  sideBarController.index.value = 56;
                },
                selected: sideBarController.index.value == 56,
              ),
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.dashBoardIcon,
                title: 'Dashboard',
                onTap: () {
                  // debugPrint(" 'Dashboard',${sideBarController.index.value}");
                  sideBarController.index.value = 1;
                },
                selected: sideBarController.index.value == 1,
              ),
            ),
          if (_hasAnyRole(['kitchen_master', 'attender', 'sales_executive']))
            Obx(
              () => DrawerListTileExpandableColumn(
                onTapTitle1: () {
                  sideBarController.index.value = 2;
                },
                onTapTitle2: () {
                  sideBarController.index.value = 54;
                },
                onTapTitle3: () {
                  sideBarController.index.value = 50;
                },
                listTitle1: "Sales",
                listTitle2: "Confirmed Orders",
                listTitle3: "Sales Return",
                iconPath: ImageAssets.saleIcon,
                title: 'Sales',
                onTap: () {
                  // debugPrint(" 'Sales',${sideBarController.index.value}");
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
                    sideBarController.index.value == 51 ||
                    sideBarController.index.value == 54 ||
                    sideBarController.index.value == 50 ||
                    sideBarController.index.value == 49 ||
                    sideBarController.index.value == 11,
              ),
            ),
          if (_hasAnyRole(['kitchen_master', 'sales_executive', 'admin']))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.creditCardIcon,
                title: 'Category',
                onTap: () {
                  sideBarController.index.value = 12;
                  // debugPrint(" 'Category',${sideBarController.index.value}");
                },
                selected: sideBarController.index.value == 12 ||
                    sideBarController.index.value == 13 ||
                    sideBarController.index.value == 27 ||
                    sideBarController.index.value == 16 ||
                    sideBarController.index.value == 34,
              ),
            ),
          if (_hasAnyRole(['kitchen_master', 'sales_executive']))
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
                    // debugPrint(" 'Category',${sideBarController.index.value}");
                  },
                  selected: sideBarController.index.value == 14 ||
                      sideBarController.index.value == 15 ||
                      sideBarController.index.value == 18 ||
                      sideBarController.index.value == 28 ||
                      sideBarController.index.value == 17 ||
                      sideBarController.index.value == 33 ||
                      sideBarController.index.value == 35),
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.cardIcon,
                title: 'Suppliers',
                onTap: () {
                  sideBarController.index.value =
                      52; // New index for supplier screen
                  // Load supplier data when selected
                  final supplierProvider =
                      Provider.of<SupplierProvider>(context, listen: false);
                  String? accessToken =
                      Provider.of<AuthModel>(context, listen: false).token;
                  supplierProvider.fetchSuppliers(
                      accessToken: accessToken ?? '');
                },
                selected: sideBarController.index.value == 52 ||
                    sideBarController.index.value == 57 ||
                    sideBarController.index.value == 67,
              ),
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTileExpandableColumn(
                  onTapTitle1: () {
                    sideBarController.index.value =
                        58; // Sales Executive Report
                  },
                  onTapTitle2: () {
                    sideBarController.index.value = 65;
                  },
                  listTitle1: "Sales Executive Reports",
                  listTitle2: "Customer Transactions Reports ",
                  iconPath: ImageAssets.transactionIcon,
                  title: 'Reports',
                  onTap: () {
                    sideBarController.index.value =
                        58; // Default to Sales Executive Report
                  },
                  selected: sideBarController.index.value == 58 ||
                      sideBarController.index.value == 65 ||
                      sideBarController.index.value == 66),
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTileExpandableColumn(
                  onTapTitle1: () {
                    sideBarController.index.value = 21;
                  },
                  onTapTitle2: () {
                    sideBarController.index.value = 47;
                  },
                  onTapTitle3: () {
                    sideBarController.index.value = 59; // Company Accounts
                  },
                  listTitle1: "Invoice",
                  listTitle2: "Receipts",
                  listTitle3: "Company Accounts",
                  iconPath: ImageAssets.transactionIcon,
                  title: 'Accounts',
                  onTap: () {
                    sideBarController.index.value = 21;
                    // debugPrint(" 'Category',${sideBarController.index.value}");
                  },
                  selected: sideBarController.index.value == 21 ||
                      sideBarController.index.value == 22 ||
                      sideBarController.index.value == 30 ||
                      sideBarController.index.value == 31 ||
                      sideBarController.index.value == 32 ||
                      sideBarController.index.value == 24 ||
                      sideBarController.index.value == 25 ||
                      sideBarController.index.value == 48 ||
                      sideBarController.index.value == 47 ||
                      sideBarController.index.value == 59 ||
                      sideBarController.index.value == 60 ||
                      sideBarController.index.value == 61),
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTileExpandableColumn(
                  onTapTitle1: () {
                    sideBarController.index.value = 4;
                  },
                  onTapTitle2: () {
                    sideBarController.index.value = 23;
                  },
                  listTitle1: "Supplier Transactions",
                  listTitle2: "Customer Transactions",
                  iconPath: ImageAssets.transactionIcon,
                  title: 'Transactions',
                  onTap: () {
                    sideBarController.index.value = 4;
                    // debugPrint(" 'Category',${sideBarController.index.value}");
                  },
                  selected: sideBarController.index.value == 4 ||
                      sideBarController.index.value == 23),
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.customerIcon,
                title: 'Customers',
                onTap: () {
                  sideBarController.index.value = 5;
                  // debugPrint(" 'Customers',${sideBarController.index.value}");
                },
                selected: sideBarController.index.value == 5 ||
                    sideBarController.index.value == 9 ||
                    sideBarController.index.value == 38,
              ),
            ),
          if (_hasRole('sales_executive'))
            const SizedBox(
              height: 15,
            ),
          if (_hasRole('sales_executive'))
            Padding(
              padding: const EdgeInsets.only(left: 45.0),
              child: Text(
                'Other',
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
                    0.16, ColorManager.textColor),
              ),
            ),
          if (_hasRole('sales_executive'))
            const SizedBox(
              height: 15,
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.printIcon,
                title: 'Printer',
                onTap: () {
                  sideBarController.index.value = 53;
                },
                selected: sideBarController.index.value == 53,
              ),
            ),
          if (_hasRole('sales_executive'))
            Obx(
              () => DrawerListTile(
                iconPath: ImageAssets.settingsIcon,
                title: 'Settings',
                iconSize: 18.0,
                horizontalGap: 12.0,
                onTap: () {
                  sideBarController.index.value = 62;
                },
                selected: sideBarController.index.value == 62 ||
                    sideBarController.index.value == 63,
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

                  // debugPrint(" authmodel logout token ${authModel.token}");
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
              // debugPrint(" 'Logout',${sideBarController.index.value}");
            },
            selected: false,
          ),
          const SizedBox(
            height: 10,
          ),
          Container(
            height: 100,
            width: 180,
            margin: ResponsiveWidget.isTablet(context)
                ? const EdgeInsets.only(
                    left: 20, top: 20, bottom: 10, right: 10)
                : const EdgeInsets.only(left: 30, top: 20, bottom: 10),
            padding: const EdgeInsets.all(6),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      } else {
                        return const CircularProgressIndicator();
                      }
                    },
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Center(
            child: Text(
              '2025 CloudPOS App',
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
  // Optional: allow custom icon size per tile
  final double? iconSize;
  // Optional: allow custom horizontal gap between icon and title per tile
  final double? horizontalGap;
  const DrawerListTile({
    super.key,
    required this.iconPath,
    required this.title,
    required this.selected,
    required this.onTap,
    this.items,
    this.iconSize,
    this.horizontalGap,
  });

  @override
  Widget build(BuildContext context) {
    final double resolvedIconSize = iconSize ?? 18.0;
    final double leadingBox =
        resolvedIconSize + 4.0; // small padding around icon
    final double gap = horizontalGap ?? 12.0;
    return selected
        ? Stack(
            children: [
              Positioned(
                left: ResponsiveWidget.isTablet(context) ? 10 : 20,
                right: ResponsiveWidget.isTablet(context) ? 10 : 20,
                child: Container(
                  alignment: Alignment.center,
                  // width intentionally omitted so it won't stretch full width
                  height: MediaQuery.of(context).size.height * .055,
                  // keep only a small bottom margin for spacing between tiles
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: ColorManager.kPrimaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ListTile(
                selected: selected,
                contentPadding: ResponsiveWidget.isTablet(context)
                    ? const EdgeInsets.only(left: 15, right: 10)
                    : const EdgeInsets.only(left: 45, right: 15),
                horizontalTitleGap: gap,
                visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                minVerticalPadding: 0,
                onTap: onTap,
                minLeadingWidth: leadingBox,
                leading: SizedBox(
                  width: leadingBox,
                  height: leadingBox,
                  child: Center(
                    child: WebsafeSvg.asset(
                      iconPath,
                      width: resolvedIconSize,
                      height: resolvedIconSize,
                      colorFilter:
                          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
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
        //  margin: const EdgeInsets.only(left: 20),
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
            horizontalTitleGap: gap,
            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
            minVerticalPadding: 0,
            onTap: onTap,
            minLeadingWidth: leadingBox,
            leading: SizedBox(
              width: leadingBox,
              height: leadingBox,
              child: Center(
                child: WebsafeSvg.asset(
                  iconPath,
                  width: resolvedIconSize,
                  height: resolvedIconSize,
                  colorFilter: const ColorFilter.mode(
                    ColorManager.kPrimaryColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
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
