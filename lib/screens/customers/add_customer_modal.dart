import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/extensions/widget_functions.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../components/build_title.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

void showAddCustomerModal(BuildContext context, Size size,
    {String? mobileNumber}) {
  final firstNameTextController = TextEditingController();
  final lastNameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController(text: mobileNumber ?? '');
  final addressTextController = TextEditingController();
  final countryTextController = TextEditingController();
  final pincodeTextController = TextEditingController();

  String? selectedStateId;
  String? selectedDistrictId;
  bool statesLoaded = false;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      final locationProvider = Provider.of<LocationProvider>(context);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

// In your showDialog method
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!statesLoaded) {
          locationProvider.listAllStates(accessToken!);
          statesLoaded = true; // Set flag to true after loading
        }
      });
      return StatefulBuilder(builder: (context, setState) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AlertDialog(
            contentPadding: const EdgeInsets.all(0),
            content: Container(
              padding: const EdgeInsets.all(16),
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BuildTextTile(
                      title: "FirstName",
                      textStyle: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                    Row(
                      children: [
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 3.05,
                          child: TextFormField(
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: firstNameTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(left: 20),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 3.05,
                          child: TextFormField(
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: lastNameTextController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    BuildTextTile(
                      title: "Email Address",
                      textStyle: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(left: 20, right: 10),
                      padding: const EdgeInsets.only(left: 15),
                      height: size.height * .07,
                      width: size.width,
                      child: TextFormField(
                        keyboardType: TextInputType.text,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: validateEmail,
                        cursorColor: ColorManager.kPrimaryColor,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        controller: emailTextController,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                    ),
                    BuildTextTile(
                      title: "Phone Number",
                      textStyle: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(left: 20, right: 10),
                      padding: const EdgeInsets.only(left: 15),
                      height: size.height * .07,
                      width: size.width,
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [PhoneNumberFormatter()],
                        cursorColor: ColorManager.kPrimaryColor,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        controller: phoneNumberController,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                    ),
                    BuildTextTile(
                      title: "Address",
                      textStyle: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(left: 20, right: 10),
                      padding: const EdgeInsets.only(left: 15),
                      height: size.height * .07,
                      width: size.width,
                      child: TextFormField(
                        keyboardType: TextInputType.text,
                        cursorColor: ColorManager.kPrimaryColor,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        controller: addressTextController,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                    ),
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        buildColumnWidgetForTextFields(
                          controller: countryTextController,
                          height: size.height * .07,
                          width: size.width / 3.05,
                          size: size,
                          isLeft: false,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          readOnly: false,
                          title: "Country",
                          onchanged: (value) {},
                          hintText: "",
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            BuildTextTile(
                              title: "State",
                              textStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 0),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width / 3,
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedStateId,
                                hint: const Text("Select State"),
                                items: locationProvider.stateList.map((state) {
                                  return DropdownMenuItem<String>(
                                    value: state.key,
                                    child: Text(state.value),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) async {
                                  setState(() {
                                    selectedStateId = newValue;
                                    selectedDistrictId =
                                        null; // Reset district when state changes
                                  });
                                  if (newValue != null) {
                                    await locationProvider.listAllDistricts(
                                      stateId: newValue,
                                      accessToken: accessToken!,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildTextTile(
                              title: "District",
                              textStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              margin: const EdgeInsets.only(left: 20),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width / 3,
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedDistrictId,
                                hint: Text("Select District"),
                                items: locationProvider.districtList
                                    .map((district) {
                                  return DropdownMenuItem<String>(
                                    value: district.key,
                                    child: Text(district.value),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedDistrictId = newValue;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        buildColumnWidgetForTextFields(
                          controller: pincodeTextController,
                          height: size.height * .07,
                          width: size.width / 3.05,
                          size: size,
                          isLeft: true,
                          readOnly: false,
                          title: "Pincode",
                          onchanged: (value) {},
                          hintText: "",
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: CustomRoundButton(
                            title: "Submit",
                            fct: () async {
                              if (phoneNumberController.text.isEmpty) {
                                showScaffoldError(
                                  context: context,
                                  message: 'Please Fill Phone Number',
                                );
                              } else {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) {
                                    return const Center(
                                      child:
                                          CircularProgressIndicator.adaptive(),
                                    );
                                  },
                                );

                                debugPrint(phoneNumberController.text);

                                String? accessToken = Provider.of<AuthModel>(
                                        context,
                                        listen: false)
                                    .token;

                                await CustomerProvider()
                                    .addCustomer(
                                  accessToken ?? "",
                                  phoneNumberController.text
                                      .replaceAll("-", ""),
                                  "1",
                                  "${firstNameTextController.text} ${lastNameTextController.text}",
                                  emailTextController.text,
                                  addressTextController.text,
                                  pincodeTextController.text,
                                  locationProvider.stateList
                                      .firstWhere((state) =>
                                          state.key == selectedStateId)
                                      .value,
                                  locationProvider.districtList
                                      .firstWhere((district) =>
                                          district.key == selectedDistrictId)
                                      .value,
                                  countryTextController.text,
                                  context,
                                )
                                    .then((value) {
                                  Navigator.pop(context);
                                  if (value["status"] == "success") {
                                    showScaffold(
                                      context: context,
                                      message: '${value["message"]}',
                                    );

                                    emailTextController.clear();
                                    pincodeTextController.clear();
                                    phoneNumberController.clear();
                                    lastNameTextController.clear();
                                    firstNameTextController.clear();
                                    addressTextController.clear();
                                    countryTextController.clear();
                                    selectedDistrictId = null;
                                    selectedStateId = null;
                                    Navigator.of(context).pop();
                                  } else {
                                    Map<String, dynamic> errorResponse =
                                        value['errors'];
                                    showScaffold(
                                      context: context,
                                      message: errorResponse.values
                                          .map((e) => e.join(''))
                                          .join('\n'),
                                    );
                                  }
                                });
                              }
                            },
                            height: 50,
                            width: size.width * 0.19,
                            fontSize: FontSize.s12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: CustomRoundButton(
                            title: "Close",
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: () async {
                              Navigator.of(context).pop();
                            },
                            height: 50,
                            width: size.width * 0.19,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        );
      });
    },
  );
}
