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

  String? selectedStateId;
  String? selectedDistrictId;
  String? selectedPincodeId;
  bool isLoadingPincodes = false;
  bool isLoadingDistricts = false;

  Key stateDropdownKey = UniqueKey();
  Key districtDropdownKey = UniqueKey();
  Key pincodeDropdownKey = UniqueKey();

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
                              _buildPincodeDropdown(size, locationProvider),
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
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
          width: size.width / 3,
          child: DropdownButton<String>(
            key: stateDropdownKey,
            isExpanded: true,
            value: selectedStateId,
            hint: Text(
              "Select State",
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            items: locationProvider.stateList.map((state) {
              return DropdownMenuItem<String>(
                value: state.key,
                child: Text(
                  state.value,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) async {
              setState(() {
                selectedStateId = newValue;
                selectedDistrictId = null;
                selectedPincodeId = null;
                districtDropdownKey = UniqueKey();
                pincodeDropdownKey = UniqueKey();
                isLoadingDistricts = true;
              });
              if (newValue != null) {
                try {
                  await locationProvider.listAllDistricts(
                      stateId: newValue, accessToken: accessToken!);
                } catch (e) {
                  debugPrint("Error loading districts: $e");
                } finally {
                  if (mounted) {
                    setState(() {
                      isLoadingDistricts = false;
                    });
                  }
                }
              } else {
                setState(() {
                  isLoadingDistricts = false;
                });
              }
            },
            underline: Container(),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: ColorManager.kPrimaryColor,
            ),
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
          child: isLoadingDistricts
              ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ),
                )
              : DropdownButton<String>(
                  key: districtDropdownKey,
                  isExpanded: true,
                  value: selectedDistrictId,
                  hint: Text(
                    selectedStateId == null
                        ? "Select State First"
                        : locationProvider.districtList.isEmpty
                            ? "No districts available"
                            : "Select District",
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.27,
                      selectedStateId == null
                          ? Colors.grey
                          : ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                  items: locationProvider.districtList.isEmpty
                      ? []
                      : locationProvider.districtList.map((district) {
                          return DropdownMenuItem<String>(
                            value: district.key,
                            child: Text(
                              district.value,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s12,
                                0.27,
                                ColorManager.textColor,
                              ),
                            ),
                          );
                        }).toList(),
                  onChanged: (selectedStateId == null || isLoadingDistricts)
                      ? null
                      : (String? newValue) async {
                          setState(() {
                            selectedDistrictId = newValue;
                            selectedPincodeId = null;
                            pincodeDropdownKey = UniqueKey();
                            isLoadingPincodes = true;
                          });
                          if (newValue != null) {
                            String? accessToken =
                                Provider.of<AuthModel>(context, listen: false)
                                    .token;
                            try {
                              await locationProvider.listAllPincodes(
                                  districtId: newValue,
                                  accessToken: accessToken!);
                            } catch (e) {
                              debugPrint("Error loading pincodes: $e");
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isLoadingPincodes = false;
                                });
                              }
                            }
                          } else {
                            setState(() {
                              isLoadingPincodes = false;
                            });
                          }
                        },
                  underline: Container(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: ColorManager.kPrimaryColor,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPincodeDropdown(Size size, LocationProvider locationProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: "Pincode",
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
          width: size.width / 3.05,
          child: isLoadingPincodes
              ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ),
                )
              : DropdownButton<String>(
                  key: pincodeDropdownKey,
                  isExpanded: true,
                  value: selectedPincodeId,
                  hint: Text(
                    selectedDistrictId == null
                        ? "Select District First"
                        : locationProvider.pincodeList.isEmpty
                            ? "No pincodes available"
                            : "Select Pincode",
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.27,
                      selectedDistrictId == null
                          ? Colors.grey
                          : ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                  items: locationProvider.pincodeList.isEmpty
                      ? []
                      : locationProvider.pincodeList.map((pincode) {
                          return DropdownMenuItem<String>(
                            value: pincode.key,
                            child: Text(
                              pincode.value,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s12,
                                0.27,
                                ColorManager.textColor,
                              ),
                            ),
                          );
                        }).toList(),
                  onChanged: (selectedDistrictId == null || isLoadingPincodes)
                      ? null
                      : (String? newValue) {
                          setState(() {
                            selectedPincodeId = newValue;
                          });
                        },
                  underline: Container(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: ColorManager.kPrimaryColor,
                  ),
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
          debugPrint("Submit button pressed - attempting to add new customer");
          if (_formKey.currentState!.validate()) {
            // Validate the form
            debugPrint("Form validation passed");
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

              String pincodeName = locationProvider.pincodeList
                  .firstWhere(
                    (pincode) => pincode.key == selectedPincodeId,
                    orElse: () => const MapEntry("unknown", "Unknown Pincode"),
                  )
                  .value;

              debugPrint("Preparing API call with data:");
              debugPrint(
                  "Phone: ${phoneNumberController.text.replaceAll("-", "")}");
              debugPrint(
                  "Name: ${firstNameTextController.text} ${lastNameTextController.text}");
              debugPrint("Email: ${emailTextController.text}");
              debugPrint(
                  "State: $stateName, District: $districtName, Pincode: $pincodeName");
              debugPrint(
                  "Selected IDs - State: $selectedStateId, District: $selectedDistrictId, Pincode: $selectedPincodeId");
              debugPrint(
                  "Available pincodes count: ${locationProvider.pincodeList.length}");

              final response = await CustomerProvider().addCustomer(
                accessToken ?? "",
                phoneNumberController.text.replaceAll("-", ""),
                "1",
                "${firstNameTextController.text} ${lastNameTextController.text}",
                emailTextController.text,
                addressTextController.text,
                pincodeName, // Use selected pincode name instead of text field
                districtName, // Note: API expects district in city field
                stateName,
                countryTextController.text,
                context,
              );

              debugPrint("API response received: $response");

              // Close loading dialog
              Navigator.pop(context);

              if (response["status"] == "success") {
                debugPrint(
                    "Customer added successfully: ${response["message"]}");
                showScaffold(
                    context: context,
                    message:
                        response["message"] ?? "Customer added successfully");
                _clearFields();
              } else {
                // Handle error case
                String errorMessage = "";

                if (response.containsKey("errors")) {
                  // Extract error messages from API response
                  Map<String, dynamic> errors = response["errors"];
                  List<String> errorMessages = [];

                  errors.forEach((field, messages) {
                    if (messages is List) {
                      for (var message in messages) {
                        errorMessages.add("$field: $message");
                      }
                    } else {
                      errorMessages.add("$field: $messages");
                    }
                  });

                  errorMessage = errorMessages.join("\n");
                  debugPrint("Validation errors: $errorMessage");
                } else {
                  errorMessage =
                      response["message"] ?? "Failed to add customer";
                  debugPrint("Error message: $errorMessage");
                }

                // Show error to user
                showScaffoldError(context: context, message: errorMessage);
              }
            } catch (error) {
              debugPrint("Exception occurred during API call: $error");
              Navigator.pop(context); // Close loading dialog
              showScaffoldError(context: context, message: 'Error: $error');
            }
          } else {
            debugPrint("Form validation failed");
            showScaffoldError(
                context: context,
                message: "Please fill all required fields correctly");
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
        phoneNumberController.clear();
        lastNameTextController.clear();
        firstNameTextController.clear();
        addressTextController.clear();
        countryTextController.clear();
        selectedDistrictId = null;
        selectedStateId = null;
        selectedPincodeId = null;
        isLoadingDistricts = false;
        isLoadingPincodes = false;
        districtDropdownKey = UniqueKey();
        stateDropdownKey = UniqueKey();
        pincodeDropdownKey = UniqueKey();
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
