import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
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

Future<dynamic> showAddCustomerModal(BuildContext context, Size size,
    {required String mobileNumber}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: AddCustomersModal(
              mobileNumber: mobileNumber), // Pass mobile number
        ),
      );
    },
  );
}

class AddCustomersModal extends StatefulWidget {
  final String mobileNumber;

  const AddCustomersModal({Key? key, required this.mobileNumber})
      : super(key: key);

  @override
  State<AddCustomersModal> createState() => _AddCustomersModalState();
}

class _AddCustomersModalState extends State<AddCustomersModal> {
  final _formKey = GlobalKey<FormState>();
  final firstNameTextController = TextEditingController();
  final lastNameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressTextController = TextEditingController();
  final countryTextController = TextEditingController();
  final pincodeTextController = TextEditingController();
  final stateSearchController = TextEditingController();
  final districtSearchController = TextEditingController();

  String? selectedStateId;
  String? selectedDistrictId;

  Key stateDropdownKey = UniqueKey();
  Key districtDropdownKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      phoneNumberController.text = widget.mobileNumber; // Add this line
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
    Get.put(SideBarController());

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10.0, bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                // Row 1: First Name, Last Name, Email
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Email Address",
                        emailTextController,
                        TextInputType.emailAddress,
                        size,
                        validator: validateEmail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Row 2: Phone, Address, Country
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Phone Number",
                        phoneNumberController,
                        TextInputType.number,
                        size,
                        inputFormatter: PhoneNumberFormatter(),
                        validator: validatePhoneNumber,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Address",
                        addressTextController,
                        TextInputType.text,
                        size,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Country",
                        countryTextController,
                        TextInputType.text,
                        size,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Row 3: State, District, Pincode
                Row(
                  children: [
                    Expanded(
                      child: _buildStateDropdown(
                          size, locationProvider, accessToken),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDistrictDropdown(size, locationProvider),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Pincode",
                        pincodeTextController,
                        TextInputType.text,
                        size,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                _buildSubmitButton(size, locationProvider, accessToken),
                const SizedBox(height: 25),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String title, TextEditingController controller,
      TextInputType keyboardType, Size size,
      {FormFieldValidator<String>? validator,
      TextInputFormatter? inputFormatter,
      bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BuildTextTile(
              title: title,
              textStyle: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
            if (isRequired)
              Text(
                ' *',
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.red),
              ),
          ],
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

  Widget _buildStateDropdown(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildDropDownWithSearch<String>(
          key: stateDropdownKey,
          title: "State",
          hintText: "Select State",
          value: selectedStateId,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          items: locationProvider.stateList.map((state) => state.key).toList(),
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
          displayText: (String stateId) {
            final state = locationProvider.stateList.firstWhere(
                (state) => state.key == stateId,
                orElse: () => const MapEntry("", "Unknown"));
            return state.value;
          },
          searchController: stateSearchController,
          searchHintText: "Search State...",
        ),
      ],
    );
  }

  Widget _buildDistrictDropdown(Size size, LocationProvider locationProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildDropDownWithSearch<String>(
          key: districtDropdownKey,
          title: "District",
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          hintText: "Select District",
          value: selectedDistrictId,
          items: locationProvider.districtList
              .map((district) => district.key)
              .toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedDistrictId = newValue;
            });
          },
          displayText: (String districtId) {
            final district = locationProvider.districtList.firstWhere(
                (district) => district.key == districtId,
                orElse: () => const MapEntry("", "Unknown"));
            return district.value;
          },
          searchController: districtSearchController,
          searchHintText: "Search District...",
        ),
      ],
    );
  }

  Widget _buildSubmitButton(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Close Button
          CustomRoundButton(
            title: "Close",
            fct: () {
              Navigator.pop(context);
            },
            height: 50,
            width: 120,
            fontSize: FontSize.s12,
            textColor: Colors.blue,
            borderColor: Colors.blue,
            boxColor: Colors.white,
          ),
          const SizedBox(width: 10),
          // Submit Button
          CustomRoundButton(
            title: "Submit",
            fct: () async {
              // debugPrint("Add New Customer");
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
                      // Close the loading dialog first
                      Navigator.pop(context);
                      // Return the created customer's essential details to the caller
                      Navigator.pop(context, {
                        "status": "success",
                        "phone": phoneNumberController.text
                            .replaceAll("-", ""),
                        "name":
                            "${firstNameTextController.text} ${lastNameTextController.text}",
                        "response": value,
                      });
                      _clearFields();
                    } else {
                      Map<String, dynamic> errorResponse = value['errors'];
                      debugPrint(
                          errorResponse.values.map((e) => e.join('')).join('\n'));
                      showScaffoldError(
                          context: context,
                          message: errorResponse.values
                              .map((e) => e.join(''))
                              .join('\n'));
                      Navigator.pop(context);
                    }
                  });
                } catch (error) {
                  // debugPrint("Error: $error");
                  Navigator.pop(context);
                }
              }
            },
            height: 50,
            width: 120,
            fontSize: FontSize.s12,
          ),
        ],
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
        stateSearchController.clear();
        districtSearchController.clear();
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
