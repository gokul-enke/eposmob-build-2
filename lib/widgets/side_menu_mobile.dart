import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/shared_preferences.dart';

import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/responsive.dart';

import 'package:websafe_svg/websafe_svg.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../widgets/user_switcher.dart';

class SideMenuMobile extends StatelessWidget {
  const SideMenuMobile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: const UserSwitcher(),
              ),
              const SizedBox(
                height: 20,
              ),
              RoundButtonWithIcon(
                title: 'Home',
                fct: () {},
                size: size,
                iconPath: ImageAssets.homeIcon,
              ),
              DrawerListTile(
                iconPath: ImageAssets.dashBoardIcon,
                title: 'Dashboard',
                onTap: () {},
              ),
              DrawerListTile(
                iconPath: ImageAssets.saleIcon,
                title: 'Sales',
                onTap: () {},
              ),
              DrawerListTile(
                iconPath: ImageAssets.cartIcon,
                title: 'Cart',
                items: 5,
                onTap: () {},
              ),
              DrawerListTile(
                iconPath: ImageAssets.transactionIcon,
                title: 'Transaction',
                onTap: () {},
              ),
              DrawerListTile(
                iconPath: ImageAssets.customerIcon,
                title: 'Customers',
                onTap: () {},
              ),
              DrawerListTile(
                iconPath: ImageAssets.cardIcon,
                title: 'Loyalty Card',
                onTap: () {},
              ),
              const SizedBox(
                height: 15,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 45.0),
                child: Text(
                  'Other',
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s13, 0.16, ColorManager.textColor),
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              DrawerListTile(
                iconPath: ImageAssets.notificationIcon,
                title: 'Notifications',
                items: 30,
                onTap: () {},
              ),
              DrawerListTile(
                iconPath: ImageAssets.supportIcon,
                title: 'Support',
                onTap: () {},
              ),
              DrawerListTile(
                iconPath: ImageAssets.logoutIcon,
                title: 'Logout',
                onTap: () {},
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                height: 170,
                width: 200,
                margin: ResponsiveWidget.isMobile(context)
                    ? const EdgeInsets.only(
                        left: 40, top: 20, bottom: 10, right: 0)
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
                      onTap: () {},
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
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.16, ColorManager.textColor),
                ),
              ),
              const SizedBox(
                height: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawerListTile extends StatelessWidget {
  final String iconPath;
  final String title;
  final int? items;
  final VoidCallback onTap;
  const DrawerListTile({
    super.key,
    required this.iconPath,
    required this.title,
    required this.onTap,
    this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: ResponsiveWidget.isTablet(context)
          ? const EdgeInsets.only(left: 15, right: 10)
          : const EdgeInsets.only(left: 45, right: 15),
      horizontalTitleGap: 0.0,
      visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
      minVerticalPadding: 0,
      onTap: onTap,
      leading: WebsafeSvg.asset(
        iconPath,
      ),
      trailing: items != null
          ? buildNotification(item: items ?? 0)
          : const SizedBox(
              height: 5,
              width: 5,
            ),
      title: Text(
        title,
        style: buildCustomStyle(FontWeightManager.medium, FontSize.s14, 0.21,
            ColorManager.textColor),
      ),
    );
  }
}

Widget buildNotification({
  required int item,
}) {
  return Stack(
    children: [
      Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorManager.kPrimaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$item',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeightManager.regular,
              fontFamily: FontConstants.fontFamily,
              fontSize: FontSize.s10,
              letterSpacing: 0.16,
            )),
      ),
    ],
  );
}
