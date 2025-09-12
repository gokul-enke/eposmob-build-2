import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/screens/login/login.dart';
import 'package:pos_machine/widgets/drawer_list_tile_expandable.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../controllers/sidebar_controller.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../widgets/user_switcher.dart';
import 'side_menu.dart'; // For DrawerListTile

class SideMenuMobile extends StatefulWidget {
  const SideMenuMobile({Key? key}) : super(key: key);

  @override
  State<SideMenuMobile> createState() => _SideMenuMobileState();
}

class _SideMenuMobileState extends State<SideMenuMobile> {
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  void _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
    if (mounted) {
      setState(() {
        userRole = role;
      });
    }
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
  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.find<SideBarController>();

    // Helper function to handle navigation and drawer closing
    void navigate(int index) {
      sideBarController.index.value = index;
      Navigator.of(context).pop();
    }

    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Center(child: WebsafeSvg.asset(ImageAssets.posLogo)),
              const SizedBox(height: 5),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'Cloud',
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
              if (_hasRole('sales_executive')) const SizedBox(height: 20),
              if (_hasRole('sales_executive'))
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0),
                  child: UserSwitcher(),
                ),
              const SizedBox(height: 20),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.homeIcon,
                      title: 'Home',
                      onTap: () => navigate(46),
                      selected: sideBarController.index.value == 46,
                    )),
              if (_hasAnyRole(['attender']))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.barcodeIcon,
                      title: 'Restaurant',
                      onTap: () => navigate(55),
                      selected: sideBarController.index.value == 55,
                    )),
              if (_hasAnyRole(['kitchen_master']))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.barcodeIcon,
                      title: 'Kitchen Master',
                      onTap: () => navigate(56),
                      selected: sideBarController.index.value == 56,
                    )),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.dashBoardIcon,
                      title: 'Dashboard',
                      onTap: () => navigate(1),
                      selected: sideBarController.index.value == 1,
                    )),
              if (_hasAnyRole(['kitchen_master', 'attender', 'sales_executive']))
                Obx(() => DrawerListTileExpandableColumn(
                      onTapTitle1: () => navigate(2),
                      onTapTitle2: () => navigate(54),
                      onTapTitle3: () => navigate(50),
                      listTitle1: "Sales",
                      listTitle2: "Confirmed Orders",
                      listTitle3: "Sales Return",
                      iconPath: ImageAssets.saleIcon,
                      title: 'Sales',
                      onTap: () {
                        final salesProvider = Provider.of<SalesProvider>(context, listen: false);
                        String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
                        salesProvider.fetchOrders(accessToken: accessToken ?? '', storeId: 1);
                        navigate(2);
                      },
                      selected: [2, 51, 54, 50, 49, 11].contains(sideBarController.index.value),
                    )),
              if (_hasAnyRole(['kitchen_master', 'sales_executive', 'admin']))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.creditCardIcon,
                      title: 'Category',
                      onTap: () => navigate(12),
                      selected: [12, 13, 27, 16, 34].contains(sideBarController.index.value),
                    )),
              if (_hasAnyRole(['kitchen_master', 'sales_executive']))
                Obx(() => DrawerListTileExpandableColumn(
                      onTapTitle1: () => navigate(14),
                      onTapTitle2: () => navigate(15),
                      listTitle1: "Product",
                      listTitle2: "Stock",
                      iconPath: ImageAssets.allCategoryIcon,
                      title: 'Product',
                      onTap: () => navigate(14),
                      selected: [14, 15, 18, 28, 17, 33, 35].contains(sideBarController.index.value),
                    )),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.cardIcon,
                      title: 'Suppliers',
                      onTap: () {
                        final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
                        String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
                        supplierProvider.fetchSuppliers(accessToken: accessToken ?? '');
                        navigate(52);
                      },
                      selected: sideBarController.index.value == 52,
                    )),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTileExpandableColumn(
                      onTapTitle1: () => navigate(21),
                      onTapTitle2: () => navigate(47),
                      listTitle1: "Invoice",
                      listTitle2: "Receipts",
                      iconPath: ImageAssets.transactionIcon,
                      title: 'Accounts',
                      onTap: () => navigate(21),
                      selected: [21, 22, 30, 31, 32, 24, 25, 48, 47].contains(sideBarController.index.value),
                    )),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTileExpandableColumn(
                      onTapTitle1: () => navigate(4),
                      onTapTitle2: () => navigate(23),
                      listTitle1: "Supplier Transactions",
                      listTitle2: "Customer Transactions",
                      iconPath: ImageAssets.transactionIcon,
                      title: 'Transactions',
                      onTap: () => navigate(4),
                      selected: [4, 23].contains(sideBarController.index.value),
                    )),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.customerIcon,
                      title: 'Customers',
                      onTap: () => navigate(5),
                      selected: [5, 9, 38].contains(sideBarController.index.value),
                    )),
              if (_hasRole('sales_executive')) const SizedBox(height: 15),
              if (_hasRole('sales_executive'))
                Padding(
                  padding: const EdgeInsets.only(left: 45.0),
                  child: Text('Other',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s13, 0.16, ColorManager.textColor)),
                ),
              if (_hasRole('sales_executive')) const SizedBox(height: 15),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.printIcon,
                      title: 'Printer',
                      onTap: () => navigate(53),
                      selected: sideBarController.index.value == 53,
                    )),
              if (_hasRole('sales_executive'))
                Obx(() => DrawerListTile(
                      iconPath: ImageAssets.consultingIcon,
                      title: 'Settings',
                      onTap: () => navigate(62),
                      selected: [62, 63].contains(sideBarController.index.value),
                    )),
              DrawerListTile(
                iconPath: ImageAssets.logoutIcon,
                title: 'Logout',
                onTap: () async {
                  final authModel = Provider.of<AuthModel>(context, listen: false);
                  String token = authModel.token ?? '';
                  showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return const Center(
                          child: CircularProgressIndicator.adaptive(),
                        );
                      });
                  await AuthenticationProvider().logout(token, context).then((value) async {
                    if (value["status"] == "success") {
                      authModel.logout();
                      SharedPreferenceProvider().removeTokenAndCustomerId();
                      showScaffold(context: context, message: '${value["message"]}');
                      Navigator.pop(context);
                      await Future.delayed(const Duration(seconds: 0)).then((value) =>
                          Navigator.pushReplacement(context,
                              MaterialPageRoute(builder: (context) => const SignInScreen())));
                    } else {
                      Navigator.pop(context);
                      showScaffoldError(context: context, message: '${value["message"]}');
                    }
                  });
                },
                selected: false,
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
