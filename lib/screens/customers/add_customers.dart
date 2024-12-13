import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
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

class AddCustomersScreen extends StatefulWidget {
  const AddCustomersScreen({super.key});

  @override
  State<AddCustomersScreen> createState() => _AddCustomersScreenState();
}

class _AddCustomersScreenState extends State<AddCustomersScreen> {
  final firstNameTextController = TextEditingController();
  final lastNameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressTextController = TextEditingController();
  final countryTextController = TextEditingController();
  final pincodeTextController = TextEditingController();

  String? selectedStateId;
  String? selectedDistrictId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      locationProvider.listAllStates(accessToken!);
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final locationProvider = Provider.of<LocationProvider>(context);
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    SideBarController sideBarController = Get.put(SideBarController());
    return SafeArea(
      child: Container(
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
          padding: const EdgeInsets.all(8),
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: () {
                      sideBarController.index.value = 5;
                    },
                    text: 'All Customers',
                  ),
                  Text(
                    'Add New Customer',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  SizedBox(
                    height: size.height * 0.8,
                    width: double.infinity,
                    child: BuildBoxShadowContainer(
                      circleRadius: 7,
                      // margin: const EdgeInsets.only(bottom: 10),
                      blurRadius: 6,
                      padding: const EdgeInsets.only(
                          left: 10.0, right: 20, top: 30, bottom: 10),
                      offsetValue: const Offset(1, 1),
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
                                    //  initialValue: initialValue,
                                    keyboardType: TextInputType.text,
                                    cursorColor: ColorManager.kPrimaryColor,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                    controller: firstNameTextController,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'This field is required';
                                      }
                                      return null;
                                    },
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
                                    //  initialValue: initialValue,
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
                              margin:
                                  const EdgeInsets.only(left: 20, right: 10),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width,
                              child: TextFormField(
                                //  initialValue: initialValue,
                                keyboardType: TextInputType.text,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
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
                              margin:
                                  const EdgeInsets.only(left: 20, right: 10),
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
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'This field is required';
                                  }
                                  return null;
                                },
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
                              margin:
                                  const EdgeInsets.only(left: 20, right: 10),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width,
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
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    hintText: ""),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                        hint: Text("Select State"),
                                        items: locationProvider.stateList
                                            .map((state) {
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
                                            await locationProvider
                                                .listAllDistricts(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    hintText: ""),
                              ],
                            ),
                            const SizedBox(height: 30),
                            Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: CustomRoundButton(
                                title: "Submit",
                                fct: () async {
                                  debugPrint("Add New Customer");
                                  debugPrint(phoneNumberController.text
                                      .replaceAll("-", ""));
                                  if (phoneNumberController.text.isEmpty) {
                                    showScaffold(
                                      context: context,
                                      message:
                                          'Please Fill the Required Fields',
                                    );
                                  } else {
                                    showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) {
                                          return const Center(
                                            child: CircularProgressIndicator
                                                .adaptive(),
                                          );
                                        });

                                    String? accessToken =
                                        Provider.of<AuthModel>(context,
                                                listen: false)
                                            .token;
                                    debugPrint(
                                        "accessToken From AuthModel $accessToken");
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
                                                    state.key ==
                                                    selectedStateId)
                                                .value,
                                            locationProvider.districtList
                                                .firstWhere((district) =>
                                                    district.key ==
                                                    selectedDistrictId)
                                                .value,
                                            countryTextController.text,
                                            context)
                                        .then((value) {
                                      if (value["status"] == "success") {
                                        showScaffold(
                                          context: context,
                                          message: '${value["message"]}',
                                        );

                                        Navigator.pop(context);
                                        emailTextController.clear();
                                        pincodeTextController.clear();
                                        phoneNumberController.clear();
                                        lastNameTextController.clear();
                                        firstNameTextController.clear();
                                        addressTextController.clear();
                                        countryTextController.clear();
                                        selectedDistrictId = null;
                                        selectedStateId = null;
                                      } else {
                                        Map<String, dynamic> errorResponse =
                                            value['errors'];
                                        debugPrint(
                                            errorResponse.values.map((e) {
                                          return e.join('');
                                        }).join('\n'));

                                        debugPrint("errors.password !=null");
                                        showScaffold(
                                          context: context,
                                          message:
                                              errorResponse.values.map((e) {
                                            return e.join('');
                                          }).join('\n'),
                                        );
                                        Navigator.pop(context);
                                      }
                                    });
                                  }
                                },
                                height: 50,
                                width: size.width * 0.19,
                                fontSize: FontSize.s12,
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )),
    );
  }

  String? validateEmail(String? value) {
    const pattern = r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'"
        r'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-'
        r'\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*'
        r'[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4]'
        r'[0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9]'
        r'[0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\'
        r'x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])';
    final regex = RegExp(pattern);

    return value!.isNotEmpty && !regex.hasMatch(value)
        ? 'Enter a valid email address'
        : null;
  }
}

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Implement your phone number formatting logic here
    String formattedText = formatPhoneNumber(newValue.text);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String formatPhoneNumber(String input) {
    // Implement your phone number formatting logic here
    // This is a basic example; you can customize it based on your requirements
    input =
        input.replaceAll(RegExp(r'\D'), ''); // Remove non-numeric characters
    if (input.length > 3) {
      input = '${input.substring(0, 3)}-${input.substring(3)}';
    }
    if (input.length > 7) {
      input = '${input.substring(0, 7)}-${input.substring(7)}';
    }
    return input;
  }
}
