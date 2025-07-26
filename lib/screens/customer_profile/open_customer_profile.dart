import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_chat_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_information_edit_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_information_view_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_loyalty_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_orders_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_transactions_widget.dart';
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
  bool isChanged = false;
  bool isTransactions = false;
  int selectedIndex = 0; // Added to track which button is selected

  @override
  Widget build(BuildContext context) {
    CustomerProvider customerProvider = Provider.of<CustomerProvider>(context);
    CustomerListModelData? selectedCustomer =
        customerProvider.getSelectedCustomer;
    final authModel = Provider.of<AuthModel>(context);
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());

    // Calculate responsive widths
    final bool isSmallScreen = size.width < 1200;
    final double sidebarWidth =
        isSmallScreen ? size.width / 3.5 : size.width / 4;
    final double contentWidth =
        isSmallScreen ? size.width / 1.8 : size.width / 2;

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.all(15),
                    padding: const EdgeInsets.all(15),
                    height: size.height * 0.75,
                    width: sidebarWidth,
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
                          const SizedBox(height: 13),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  BuildBoxShadowContainer(
                                    circleRadius: 10,
                                    margin: const EdgeInsets.only(
                                        top: 10, bottom: 15),
                                    color: (!isChanged &&
                                            !isTransactions &&
                                            selectedIndex == 0)
                                        ? ColorManager.kPrimaryColor
                                        : ColorManager.kListTileColor,
                                    offsetValue: const Offset(1, 1),
                                    blurRadius: 6,
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          isChanged = false;
                                          isTransactions = false;
                                          selectedIndex = 0;
                                        });
                                      },
                                      horizontalTitleGap: 0,
                                      minVerticalPadding: 0,
                                      minLeadingWidth: 30,
                                      leading: WebsafeSvg.asset(
                                        ImageAssets.userProfile,
                                        color: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 0)
                                            ? Colors.white
                                            : ColorManager.textColor,
                                        fit: BoxFit.none,
                                      ),
                                      title: Text(
                                        'Customer Information',
                                        style: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 0)
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
                                                    .textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Icon(
                                        Icons.keyboard_arrow_right,
                                        color: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 0)
                                            ? Colors.white
                                            : ColorManager.textColor,
                                      ),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        top: 0, bottom: 15),
                                    circleRadius: 10,
                                    color: (isChanged && !isTransactions)
                                        ? ColorManager.kPrimaryColor
                                        : ColorManager.kListTileColor,
                                    offsetValue: const Offset(1, 1),
                                    blurRadius: 6,
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          isChanged = true;
                                          isTransactions = false;
                                        });
                                      },
                                      horizontalTitleGap: 0,
                                      minVerticalPadding: 4,
                                      minLeadingWidth: 30,
                                      leading: WebsafeSvg.asset(
                                          ImageAssets.lock,
                                          color: (isChanged && !isTransactions)
                                              ? Colors.white
                                              : ColorManager
                                                  .textColor),
                                      title: Text(
                                        "Edit Details",
                                        style: (isChanged && !isTransactions)
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
                                                    .textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Icon(
                                        Icons.keyboard_arrow_right,
                                        color: (isChanged && !isTransactions)
                                            ? Colors.white
                                            : ColorManager.textColor,
                                      ),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        top: 0, bottom: 15),
                                    circleRadius: 10,
                                    color: (!isChanged && isTransactions)
                                        ? ColorManager.kPrimaryColor
                                        : ColorManager.kListTileColor,
                                    offsetValue: const Offset(1, 1),
                                    blurRadius: 6,
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          isChanged = false;
                                          isTransactions = true;
                                        });
                                      },
                                      horizontalTitleGap: 0,
                                      minVerticalPadding: 4,
                                      minLeadingWidth: 30,
                                      leading: WebsafeSvg.asset(
                                          ImageAssets.transactionIcon,
                                          color: (!isChanged && isTransactions)
                                              ? Colors.white
                                              : ColorManager
                                                  .textColor),
                                      title: Text(
                                        "Transactions",
                                        style: (!isChanged && isTransactions)
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
                                                    .textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Icon(
                                        Icons.keyboard_arrow_right,
                                        color: (!isChanged && isTransactions)
                                            ? Colors.white
                                            : ColorManager.textColor,
                                      ),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        top: 0, bottom: 15),
                                    circleRadius: 10,
                                    color: (!isChanged &&
                                            !isTransactions &&
                                            selectedIndex == 1)
                                        ? ColorManager.kPrimaryColor
                                        : ColorManager.kListTileColor,
                                    offsetValue: const Offset(1, 1),
                                    blurRadius: 6,
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          isChanged = false;
                                          isTransactions = false;
                                          selectedIndex = 1;
                                        });
                                      },
                                      horizontalTitleGap: 0,
                                      minVerticalPadding: 4,
                                      minLeadingWidth: 30,
                                      leading: WebsafeSvg.asset(
                                          ImageAssets.saleIcon,
                                          color: (!isChanged &&
                                                  !isTransactions &&
                                                  selectedIndex == 1)
                                              ? Colors.white
                                              : ColorManager
                                                  .textColor),
                                      title: Text(
                                        "All Orders",
                                        style: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 1)
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
                                                    .textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Icon(
                                        Icons.keyboard_arrow_right,
                                        color: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 1)
                                            ? Colors.white
                                            : ColorManager.textColor,
                                      ),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        top: 0, bottom: 15),
                                    circleRadius: 10,
                                    color: (!isChanged &&
                                            !isTransactions &&
                                            selectedIndex == 2)
                                        ? ColorManager.kPrimaryColor
                                        : ColorManager.kListTileColor,
                                    offsetValue: const Offset(1, 1),
                                    blurRadius: 6,
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          isChanged = false;
                                          isTransactions = false;
                                          selectedIndex = 2;
                                        });
                                      },
                                      horizontalTitleGap: 0,
                                      minVerticalPadding: 4,
                                      minLeadingWidth: 30,
                                      leading: WebsafeSvg.asset(
                                          ImageAssets.cardIcon,
                                          color: (!isChanged &&
                                                  !isTransactions &&
                                                  selectedIndex == 2)
                                              ? Colors.white
                                              : ColorManager
                                                  .textColor),
                                      title: Text(
                                        "Loyalty Card",
                                        style: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 2)
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
                                                    .textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Icon(
                                        Icons.keyboard_arrow_right,
                                        color: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 2)
                                            ? Colors.white
                                            : ColorManager.textColor,
                                      ),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        top: 0, bottom: 15),
                                    circleRadius: 10,
                                    color: (!isChanged &&
                                            !isTransactions &&
                                            selectedIndex == 3)
                                        ? ColorManager.kPrimaryColor
                                        : ColorManager.kListTileColor,
                                    offsetValue: const Offset(1, 1),
                                    blurRadius: 6,
                                    child: ListTile(
                                      onTap: () {
                                        setState(() {
                                          isChanged = false;
                                          isTransactions = false;
                                          selectedIndex = 3;
                                        });
                                      },
                                      horizontalTitleGap: 0,
                                      minVerticalPadding: 4,
                                      minLeadingWidth: 30,
                                      leading: WebsafeSvg.asset(
                                          ImageAssets.supportIcon,
                                          color: (!isChanged &&
                                                  !isTransactions &&
                                                  selectedIndex == 3)
                                              ? Colors.white
                                              : ColorManager
                                                  .textColor),
                                      title: Text(
                                        "Chat",
                                        style: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 3)
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
                                                    .textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Icon(
                                        Icons.keyboard_arrow_right,
                                        color: (!isChanged &&
                                                !isTransactions &&
                                                selectedIndex == 3)
                                            ? Colors.white
                                            : ColorManager.textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                  ),
                  !isChanged && !isTransactions && selectedIndex == 0
                      ? CustomerInformationViewWidget(
                          size: size,
                          customer: selectedCustomer,
                        )
                      : isChanged && !isTransactions
                          ? CustomerInformationEditWidget(
                              size: size,
                              customer: selectedCustomer,
                            )
                          : !isChanged && isTransactions
                              ? CustomerTransactionsWidget(
                                  size: size,
                                  customer: selectedCustomer,
                                )
                              : !isChanged &&
                                      !isTransactions &&
                                      selectedIndex == 1
                                  ? CustomerOrdersWidget(
                                      size: size,
                                      customer: selectedCustomer, accessToken: '',
                                    )
                                  : !isChanged &&
                                          !isTransactions &&
                                          selectedIndex == 2
                                      ? CustomerLoyaltyWidget(
                                          size: size,
                                          customer: selectedCustomer,
                                        )
                                      : CustomerChatWidget(
                                          size: size,
                                          customer: selectedCustomer,
                                        ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
