import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_information_edit_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_information_view_widget.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';
import '../../components/build_container_box.dart';
import '../../components/build_profile_picture.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class OpenCustomerProfileScreen extends StatefulWidget {
  const OpenCustomerProfileScreen({super.key});

  @override
  State<OpenCustomerProfileScreen> createState() =>
      _OpenCustomerProfileScreenState();
}

class _OpenCustomerProfileScreenState extends State<OpenCustomerProfileScreen> {
// Use selectedCustomer to display the customer's details
  bool isChanged = false;
  @override
  Widget build(BuildContext context) {
    CustomerProvider customerProvider = Provider.of<CustomerProvider>(context);
    CustomerListModelData? selectedCustomer =
        customerProvider.getSelectedCustomer;
    final authModel = Provider.of<AuthModel>(context);
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          //height: size.height,
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 10, right: 10),
          padding:
              const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomBackButton(
                onPressed: () {
                  sideBarController.index.value = 5;
                },
                text: 'All Customers',
              ),
              Text(
                'Customer Profile',
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
                            child: Column(
                              children: [
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text: selectedCustomer!.name ??
                                        'Customer Name',
                                    style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s24,
                                        0.35,
                                        ColorManager.textColor),
                                  ),
                                ),
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text:
                                        'Customer ID : ${selectedCustomer.id}',
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s13,
                                        0.20,
                                        ColorManager.blackWithOpacity50),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 60),
                          BuildBoxShadowContainer(
                              circleRadius: 10,
                              margin:
                                  const EdgeInsets.only(top: 10, bottom: 15),
                              color: isChanged
                                  ? ColorManager.kListTileColor
                                  : ColorManager.kPrimaryColor,
                              offsetValue: const Offset(1, 1),
                              blurRadius: 6,
                              child: ListTile(
                                onTap: () {
                                  setState(() {
                                    isChanged = !isChanged;
                                  });
                                },
                                horizontalTitleGap: 0,
                                minVerticalPadding: 0,
                                minLeadingWidth: 30,
                                leading: WebsafeSvg.asset(
                                  ImageAssets.userProfile,
                                  color: !isChanged
                                      ? Colors.white
                                      : ColorManager.kListTiletextColor,
                                  fit: BoxFit.none,
                                ),
                                title: Text(
                                  'Customer Information',
                                  style: !isChanged
                                      ? buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.12,
                                          Colors.white)
                                      : buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.12,
                                          ColorManager.kListTiletextColor),
                                ),
                                trailing: Icon(
                                  Icons.keyboard_arrow_right,
                                  color: !isChanged
                                      ? Colors.white
                                      : ColorManager.kListTiletextColor,
                                ),
                              )),
                          BuildBoxShadowContainer(
                              margin: const EdgeInsets.only(top: 0, bottom: 15),
                              circleRadius: 10,
                              color: isChanged
                                  ? ColorManager.kPrimaryColor
                                  : ColorManager.kListTileColor,
                              offsetValue: const Offset(1, 1),
                              blurRadius: 6,
                              child: ListTile(
                                onTap: () {
                                  setState(() {
                                    isChanged = !isChanged;
                                  });
                                },
                                horizontalTitleGap: 0,
                                minVerticalPadding: 4,
                                minLeadingWidth: 30,
                                leading: WebsafeSvg.asset(ImageAssets.lock,
                                    color: isChanged
                                        ? Colors.white
                                        : ColorManager.kListTiletextColor),
                                title: Text(
                                  "Edit Details",
                                  style: isChanged
                                      ? buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.12,
                                          Colors.white)
                                      : buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.12,
                                          ColorManager.kListTiletextColor),
                                ),
                                trailing: Icon(
                                  Icons.keyboard_arrow_right,
                                  color: isChanged
                                      ? Colors.white
                                      : ColorManager.kListTiletextColor,
                                ),
                              )),
                          // BuildBoxShadowContainer(
                          //     circleRadius: 10,
                          //     margin: const EdgeInsets.only(top: 0, bottom: 15),
                          //     color: ColorManager.kListTileColor,
                          //     offsetValue: const Offset(1, 1),
                          //     blurRadius: 6,
                          //     child: ListTile(
                          //       hoverColor: ColorManager.blackWithOpacity50,
                          //       horizontalTitleGap: 0,
                          //       minVerticalPadding: 0,
                          //       minLeadingWidth: 30,
                          //       leading: WebsafeSvg.asset(
                          //         ImageAssets.deleteIcon,
                          //         color: ColorManager.kRed,
                          //         fit: BoxFit.none,
                          //       ),
                          //       title: Text(
                          //         'Delete Account',
                          //         style: buildCustomStyle(
                          //             FontWeightManager.medium,
                          //             FontSize.s12,
                          //             0.12,
                          //             ColorManager.kRed),
                          //       ),
                          //       trailing: const Icon(
                          //         Icons.keyboard_arrow_right,
                          //         color: ColorManager.kListTiletextColor,
                          //       ),
                          //     )),
                        ]),
                  ),
                  !isChanged
                      ? CustomerInformationViewWidget(
                          size: size,
                          customer: selectedCustomer,
                        )
                      : CustomerInformationEditWidget(
                          size: size,
                          customer: selectedCustomer,
                        ),
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
