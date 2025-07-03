import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/customer_list.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_title.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class PersonalInformationEditWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData? customer; // Add this line

  const PersonalInformationEditWidget({
    Key? key,
    required this.size,
    required this.customer, // Add this line
  }) : super(key: key);

  @override
  State<PersonalInformationEditWidget> createState() =>
      _PersonalInformationEditWidgetState();
}

class _PersonalInformationEditWidgetState
    extends State<PersonalInformationEditWidget> {
  // Gender selectedGender = Gender.Male;
  late TextEditingController firstNameTextController;
  late TextEditingController lastNameTextController;
  late TextEditingController emailTextController;
  late TextEditingController phoneNumberController;
  late TextEditingController addressTextController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with customer data if available
    firstNameTextController = TextEditingController(
        text: widget.customer?.name?.split(' ').first ?? '');
    lastNameTextController = TextEditingController(
        text: widget.customer?.name?.split(' ').last ?? '');
    emailTextController =
        TextEditingController(text: widget.customer?.email ?? '');
    phoneNumberController =
        TextEditingController(text: widget.customer?.phone ?? '');
    addressTextController =
        TextEditingController(text: widget.customer?.name ?? '');
  }

  @override
  void dispose() {
    // Dispose of controllers
    firstNameTextController.dispose();
    lastNameTextController.dispose();
    emailTextController.dispose();
    phoneNumberController.dispose();
    addressTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = widget.size;
    return Expanded(
      child: BuildBoxShadowContainer(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(15),
          height: size.height * 0.75,
          circleRadius: 7,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "First Name",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 0, right: 10, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "First Name",
                              hintStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s10,
                                0.16,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            controller: firstNameTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "Last Name",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 10, right: 0, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,

                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Last Name",
                              hintStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s10,
                                0.16,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            controller: lastNameTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BuildTitle(
                  title: "Email Address",
                  textStyle: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s10,
                    0.16,
                    Colors.black.withOpacity(0.6),
                  ),
                ),
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  alignment: Alignment.centerLeft,
                  margin: const EdgeInsets.only(
                      left: 0, right: 10, top: 15, bottom: 10),
                  padding: const EdgeInsets.only(left: 15),
                  height: size.height * .07,
                  width: size.width / 2.8, //size.width,
                  child: TextFormField(
                    //  initialValue: initialValue,
                    keyboardType: TextInputType.text,
                    cursorColor: ColorManager.kPrimaryColor,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    controller: emailTextController,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s13,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "Phone Number",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 0, right: 10, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: phoneNumberController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTitle(
                          title: "Address",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.16,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(
                              top: 15, left: 10, right: 0, bottom: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 5.8,
                          child: TextFormField(
                            //  initialValue: initialValue,
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: addressTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                RoundButton(
                    radius: 14, title: "Edit Profile", fct: () {}, size: size),
                const SizedBox(height: 10),
              ],
            ),
          )),
    );
  }
}
