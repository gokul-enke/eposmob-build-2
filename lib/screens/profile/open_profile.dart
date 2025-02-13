import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/screens/login/login.dart';
import 'package:pos_machine/screens/profile/widgets/change_password_widget.dart';
import 'package:pos_machine/screens/profile/widgets/personal_information_edit_widget.dart';
import 'package:pos_machine/screens/profile/widgets/personal_information_view_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:websafe_svg/websafe_svg.dart';

import '../../components/build_container_box.dart';
import '../../components/build_profile_picture.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class OpenProfileScreen extends StatefulWidget {
  const OpenProfileScreen({super.key});

  @override
  State<OpenProfileScreen> createState() => _OpenProfileScreenState();
}

class _OpenProfileScreenState extends State<OpenProfileScreen> {
  bool isInitLoading = true;
  CustomerListModelData? selectedCustomer;

  @override
  void initState() {
    super.initState();
    fetchSpecificCustomer();
  }

  void fetchSpecificCustomer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userId = 5;
    try {
      setState(() {
        isInitLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      CustomerProvider customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      selectedCustomer = await customerProvider.fetchUserById(
          accessToken ?? "", userId, context);
    } catch (error) {
      // debugPrintdebugPrint(error.toString());
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
  }

  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final authModel = Provider.of<AuthModel>(context);
    Size size = MediaQuery.of(context).size;
    CustomerProvider customerProvider = Provider.of<CustomerProvider>(context);
    CustomerListModelData? selectedCustomer =
        customerProvider.getSelectedCustomer;
    return SafeArea(
      child: isInitLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Container(
                //height: size.height,
                margin: const EdgeInsets.only(
                    left: 10, top: 20, bottom: 10, right: 10),
                padding: const EdgeInsets.only(
                    left: 10, top: 20, bottom: 0, right: 10),
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
                  padding:
                      const EdgeInsets.only(top: 20.0, left: 10, right: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Profile',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s20, 0.30, ColorManager.textColor),
                        ),
                        // const SizedBox(
                        //   height: 10,
                        // ),
                        Row(
                          children: [
                            BuildBoxShadowContainer(
                              margin: const EdgeInsets.all(15),
                              padding: const EdgeInsets.all(15),
                              height: size.height * 0.75, //180,
                              width: size.width / 3.5,
                              circleRadius: 7,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                        child: Stack(
                                      children: [
                                        const BuildProfilePicture(),
                                        Positioned(
                                          bottom: -5,
                                          right: -10,
                                          child: WebsafeSvg.asset(
                                            ImageAssets.camera,
                                            fit: BoxFit.none,
                                          ),
                                        ),
                                      ],
                                    )),
                                    const SizedBox(height: 10),
                                    Center(
                                      child: RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          text: 'John Doe\n',
                                          style: buildCustomStyle(
                                              FontWeightManager.semiBold,
                                              FontSize.s24,
                                              0.35,
                                              ColorManager.textColor),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: 'Customer ID : 656564564',
                                              style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s13,
                                                  0.20,
                                                  ColorManager
                                                      .blackWithOpacity50),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 60),
                                    BuildBoxShadowContainer(
                                        circleRadius: 10,
                                        margin: const EdgeInsets.only(
                                            top: 10, bottom: 15),
                                        color: tab != 0
                                            ? ColorManager.kListTileColor
                                            : ColorManager.kPrimaryColor,
                                        offsetValue: const Offset(1, 1),
                                        blurRadius: 6,
                                        child: ListTile(
                                          onTap: () {
                                            setState(() {
                                              tab = 0;
                                            });
                                          },
                                          horizontalTitleGap: 0,
                                          minVerticalPadding: 0,
                                          minLeadingWidth: 30,
                                          leading: WebsafeSvg.asset(
                                            ImageAssets.userProfile,
                                            color: tab == 0
                                                ? Colors.white
                                                : ColorManager
                                                    .kListTiletextColor,
                                            fit: BoxFit.none,
                                          ),
                                          title: Text(
                                            'Personal Information',
                                            style: tab == 0
                                                ? buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.12,
                                                    Colors.white)
                                                : buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.12,
                                                    ColorManager
                                                        .kListTiletextColor),
                                          ),
                                          trailing: Icon(
                                            Icons.keyboard_arrow_right,
                                            color: tab == 0
                                                ? Colors.white
                                                : ColorManager
                                                    .kListTiletextColor,
                                          ),
                                        )),
                                    BuildBoxShadowContainer(
                                        margin: const EdgeInsets.only(
                                            top: 0, bottom: 15),
                                        circleRadius: 10,
                                        color: tab == 1
                                            ? ColorManager.kPrimaryColor
                                            : ColorManager.kListTileColor,
                                        offsetValue: const Offset(1, 1),
                                        blurRadius: 6,
                                        child: ListTile(
                                          onTap: () {
                                            setState(() {
                                              tab = 1;
                                            });
                                          },
                                          horizontalTitleGap: 0,
                                          minVerticalPadding: 4,
                                          minLeadingWidth: 30,
                                          leading: WebsafeSvg.asset(
                                              ImageAssets.lock,
                                              color: tab == 1
                                                  ? Colors.white
                                                  : ColorManager
                                                      .kListTiletextColor),
                                          title: Text(
                                            "Edit Profile",
                                            style: tab == 1
                                                ? buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.12,
                                                    Colors.white)
                                                : buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.12,
                                                    ColorManager
                                                        .kListTiletextColor),
                                          ),
                                          trailing: Icon(
                                            Icons.keyboard_arrow_right,
                                            color: tab == 1
                                                ? Colors.white
                                                : ColorManager
                                                    .kListTiletextColor,
                                          ),
                                        )),
                                    BuildBoxShadowContainer(
                                        margin: const EdgeInsets.only(
                                            top: 0, bottom: 15),
                                        circleRadius: 10,
                                        color: tab == 2
                                            ? ColorManager.kPrimaryColor
                                            : ColorManager.kListTileColor,
                                        offsetValue: const Offset(1, 1),
                                        blurRadius: 6,
                                        child: ListTile(
                                          onTap: () {
                                            setState(() {
                                              tab = 2;
                                            });
                                          },
                                          horizontalTitleGap: 0,
                                          minVerticalPadding: 4,
                                          minLeadingWidth: 30,
                                          leading: WebsafeSvg.asset(
                                              ImageAssets.lock,
                                              color: tab == 2
                                                  ? Colors.white
                                                  : ColorManager
                                                      .kListTiletextColor),
                                          title: Text(
                                            "Change Password",
                                            style: tab == 2
                                                ? buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.12,
                                                    Colors.white)
                                                : buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.12,
                                                    ColorManager
                                                        .kListTiletextColor),
                                          ),
                                          trailing: Icon(
                                            Icons.keyboard_arrow_right,
                                            color: tab == 2
                                                ? Colors.white
                                                : ColorManager
                                                    .kListTiletextColor,
                                          ),
                                        )),
                                    BuildBoxShadowContainer(
                                        circleRadius: 10,
                                        margin: const EdgeInsets.only(
                                            top: 0, bottom: 15),
                                        color: ColorManager.kListTileColor,
                                        offsetValue: const Offset(1, 1),
                                        blurRadius: 6,
                                        child: GestureDetector(
                                          onTap: () async {
                                            String token =
                                                authModel.token ?? '';
                                            showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator
                                                            .adaptive(),
                                                  );
                                                });
                                            await AuthenticationProvider()
                                                .logout(token, context)
                                                .then((value) async {
                                              if (value["status"] ==
                                                  "success") {
                                                authModel.logout();
                                                SharedPreferenceProvider()
                                                    .removeTokenAndCustomerId();

                                                debugPrint(
                                                    " authmodel logout token ${authModel.token}");
                                                showScaffold(
                                                  context: context,
                                                  message:
                                                      '${value["message"]}',
                                                );
                                                Navigator.pop(context);
                                                await Future.delayed(
                                                        const Duration(
                                                            seconds: 0))
                                                    .then((value) => Navigator
                                                        .pushReplacement(
                                                            context,
                                                            MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
                                                                        const SignInScreen())));
                                              } else {
                                                Navigator.pop(context);
                                                showScaffoldError(
                                                  context: context,
                                                  message:
                                                      '${value["message"]}',
                                                );
                                              }
                                            });
                                          },
                                          child: ListTile(
                                            hoverColor:
                                                ColorManager.blackWithOpacity50,
                                            horizontalTitleGap: 0,
                                            minVerticalPadding: 0,
                                            minLeadingWidth: 30,
                                            leading: WebsafeSvg.asset(
                                              ImageAssets.deleteIcon,
                                              color: Colors.black,
                                              fit: BoxFit.none,
                                            ),
                                            title: Text(
                                              'Logout',
                                              style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.12,
                                                  Colors.black),
                                            ),
                                            trailing: const Icon(
                                              Icons.keyboard_arrow_right,
                                              color: ColorManager
                                                  .kListTiletextColor,
                                            ),
                                          ),
                                        )),
                                    BuildBoxShadowContainer(
                                        circleRadius: 10,
                                        margin: const EdgeInsets.only(
                                            top: 0, bottom: 15),
                                        color: ColorManager.kListTileColor,
                                        offsetValue: const Offset(1, 1),
                                        blurRadius: 6,
                                        child: ListTile(
                                          hoverColor:
                                              ColorManager.blackWithOpacity50,
                                          horizontalTitleGap: 0,
                                          minVerticalPadding: 0,
                                          minLeadingWidth: 30,
                                          leading: WebsafeSvg.asset(
                                            ImageAssets.deleteIcon,
                                            color: ColorManager.kRed,
                                            fit: BoxFit.none,
                                          ),
                                          title: Text(
                                            'Delete Account',
                                            style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.12,
                                                ColorManager.kRed),
                                          ),
                                          trailing: const Icon(
                                            Icons.keyboard_arrow_right,
                                            color:
                                                ColorManager.kListTiletextColor,
                                          ),
                                        )),
                                  ]),
                            ),
                            if (tab == 0)
                              PersonalInformationViewWidget(
                                size: size,
                                customer: selectedCustomer,
                              ),
                            if (tab == 1)
                              PersonalInformationEditWidget(
                                size: size,
                                customer: selectedCustomer,
                              ),
                            if (tab == 2) ChangePasswordWidget(size: size)
                          ],
                        ),
                      ]),
                ),
                //   ],
                // ),
              ),
            ),
    );
  }
}
