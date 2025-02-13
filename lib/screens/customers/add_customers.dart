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
  final _formKey = GlobalKey<FormState>(); // Add this line
  final firstNameTextController = TextEditingController();
  final lastNameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressTextController = TextEditingController();
  final countryTextController = TextEditingController();
  final pincodeTextController = TextEditingController();

  String? selectedStateId;
  String? selectedDistrictId;

  Key stateDropdownKey = UniqueKey();
  Key districtDropdownKey = UniqueKey();

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
      child: Scaffold(
        body: Container(
          margin: const EdgeInsets.all(10),
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
            color: Colors.white,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Form(
                // Wrap with Form widget
                key: _formKey, // Assign the key
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
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
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                "First Name",
                                firstNameTextController,
                                TextInputType.text,
                                size,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                "Last Name",
                                lastNameTextController,
                                TextInputType.text,
                                size,
                              ),
                            ),
                          ],
                        ),
                        _buildTextField("Email Address", emailTextController,
                            TextInputType.emailAddress, size,
                            validator: validateEmail),
                        _buildTextField("Phone Number", phoneNumberController,
                            TextInputType.number, size,
                            inputFormatter: PhoneNumberFormatter(),
                            validator:
                                validatePhoneNumber), // Add validator here
                        _buildTextField("Address", addressTextController,
                            TextInputType.text, size),
                        _buildCountryStateDistrictFields(
                            size, locationProvider, accessToken),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(right: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDistrictDropdown(size, locationProvider),
                              buildColumnWidgetForTextFields(
                                controller: pincodeTextController,
                                height: size.height * .07,
                                width: size.width / 3.05,
                                size: size,
                                isLeft: false,
                                readOnly: false,
                                title: "Pincode",
                                onchanged: (value) {},
                                hintText: "",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSubmitButton(size, locationProvider, accessToken),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String title, TextEditingController controller,
      TextInputType keyboardType, Size size,
      {FormFieldValidator<String>? validator,
      TextInputFormatter? inputFormatter}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: title,
          textStyle: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
              0.27, Colors.black.withOpacity(0.6)),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
          width: size.width,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(border: InputBorder.none),
            validator: validator, // Use the validator here
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                0.27, ColorManager.textColor.withOpacity(.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryStateDistrictFields(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        buildColumnWidgetForTextFields(
          controller: countryTextController,
          height: size.height * .07,
          width: size.width / 3.05,
          size: size,
          isLeft: false,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          readOnly: false,
          title: "Country",
          onchanged: (value) {},
          hintText: "",
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: _buildStateDropdown(size, locationProvider, accessToken),
        ),
      ],
    );
  }

  Widget _buildStateDropdown(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: "State",
          textStyle: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
              0.27, Colors.black.withOpacity(0.6)),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
          width: size.width / 3,
          child: DropdownButton<String>(
            key: stateDropdownKey,
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
                selectedDistrictId = null;
              });
              if (newValue != null) {
                await locationProvider.listAllDistricts(
                    stateId: newValue, accessToken: accessToken!);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictDropdown(Size size, LocationProvider locationProvider) {
    return Column(
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
            key: districtDropdownKey,
            isExpanded: true,
            value: selectedDistrictId,
            hint: const Text("Select District"),
            items: locationProvider.districtList.map((district) {
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
    );
  }

  Widget _buildSubmitButton(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: CustomRoundButton(
        title: "Submit",
        fct: () async {
          // debugPrintdebugPrint("Add New Customer");
          if (_formKey.currentState!.validate()) {
            // Validate the form
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator.adaptive()),
            );

            try {
              String stateName = locationProvider.stateList
                  .firstWhere(
                    (state) => state.key == selectedStateId,
                    orElse: () => const MapEntry("unknown", "Unknown State"),
                  )
                  .value;

              String districtName = locationProvider.districtList
                  .firstWhere(
                    (district) => district.key == selectedDistrictId,
                    orElse: () => const MapEntry("unknown", "Unknown District"),
                  )
                  .value;

              await CustomerProvider()
                  .addCustomer(
                accessToken ?? "",
                phoneNumberController.text.replaceAll("-", ""),
                "1",
                "${firstNameTextController.text} ${lastNameTextController.text}",
                emailTextController.text,
                addressTextController.text,
                pincodeTextController.text,
                stateName,
                districtName,
                countryTextController.text,
                context,
              )
                  .then((value) {
                if (value["status"] == "success") {
                  showScaffold(
                      context: context, message: '${value["message"]}');
                  Navigator.pop(context);
                  _clearFields();
                } else {
                  Map<String, dynamic> errorResponse = value['errors'];
                  debugPrint(
                      errorResponse.values.map((e) => e.join('')).join('\n'));
                  showScaffold(
                      context: context,
                      message: errorResponse.values
                          .map((e) => e.join(''))
                          .join('\n'));
                  Navigator.pop(context);
                }
              });
            } catch (error) {
              // debugPrintdebugPrint("Error: $error");
              Navigator.pop(context);
            }
          }
        },
        height: 50,
        width: size.width * 0.19,
        fontSize: FontSize.s12,
      ),
    );
  }

  void _clearFields() {
    if (mounted) {
      setState(() {
        emailTextController.clear();
        pincodeTextController.clear();
        phoneNumberController.clear();
        lastNameTextController.clear();
        firstNameTextController.clear();
        addressTextController.clear();
        countryTextController.clear();
        selectedDistrictId = null;
        selectedStateId = null;
        districtDropdownKey = GlobalKey();
        stateDropdownKey = GlobalKey();
      });
    }
  }

  String? validateEmail(String? value) {
    const pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$";
    final regex = RegExp(pattern);
    return value!.isNotEmpty && !regex.hasMatch(value)
        ? 'Enter a valid email address'
        : null;
  }

  // Phone number validation function
  String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    // Check if the phone number is valid (e.g., length check)
    final phoneNumber = value.replaceAll("-", ""); // Remove formatting
    if (phoneNumber.length < 10) {
      return 'Enter a valid phone number';
    }
    return null; // Return null if there are no errors
  }
}

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String formattedText = formatPhoneNumber(newValue.text);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String formatPhoneNumber(String input) {
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
