import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_radio_group.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';

import '../newcomponents/custom_container_box.dart';
import '../newcomponents/custom_round_button.dart';
import '../providers/auth_model.dart';
import '../providers/app_settings_provider.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

enum PaymentType { none, toPay, toReceive }

class CustomCustomerForm extends StatefulWidget {
  final String? initialMobileNumber;
  final bool isModal;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const CustomCustomerForm({
    Key? key,
    this.initialMobileNumber,
    this.isModal = false,
    this.onSuccess,
    this.onCancel,
  }) : super(key: key);

  @override
  State<CustomCustomerForm> createState() => _CustomCustomerFormState();
}

class _CustomCustomerFormState extends State<CustomCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  bool _showPhoneValidationOnLoad = false;
  final firstNameTextController = TextEditingController();
  final lastNameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressTextController = TextEditingController();
  final countryTextController = TextEditingController();
  final stateSearchController = TextEditingController();
  final districtSearchController = TextEditingController();
  final balanceTextController = TextEditingController(text: '0');
  final altPhoneTextController = TextEditingController();
  final dobTextController = TextEditingController();
  final crNumberController = TextEditingController();
  final vatNumberController = TextEditingController();
  final FocusNode firstNameFocusNode = FocusNode();

  PaymentType selectedPaymentType = PaymentType.toReceive;
  String? selectedStateId;
  String? selectedDistrictId;
  String? selectedPincodeId;
  bool isLoadingPincodes = false;
  bool isLoadingDistricts = false;
  String? selectedGender; // male / female / other
  String selectedCustomerType = 'B2C'; // B2C / B2B

  Key stateDropdownKey = UniqueKey();
  Key districtDropdownKey = UniqueKey();
  Key pincodeDropdownKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialMobileNumber != null) {
      phoneNumberController.text = widget.initialMobileNumber!;
      final normalizedPhone =
          widget.initialMobileNumber!.replaceAll(RegExp(r'\D'), '');
      _showPhoneValidationOnLoad =
          normalizedPhone.isNotEmpty && normalizedPhone.length < 10;
    }
    _prefillCountryFromLogin();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isModal) {
        firstNameFocusNode.requestFocus();
      }
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      locationProvider.listAllStates(accessToken!);
    });
  }

  @override
  void dispose() {
    firstNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _prefillCountryFromLogin() async {
    final savedCountry = await SharedPreferenceProvider().getCountryName();
    if (!mounted) {
      return;
    }
    if ((countryTextController.text).trim().isEmpty &&
        (savedCountry ?? '').trim().isNotEmpty) {
      setState(() {
        countryTextController.text = savedCountry!.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final locationProvider = Provider.of<LocationProvider>(context);
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final bool isCompanyB2BEnabled = appSettings?.companyB2BEnabled ?? false;

    return Form(
      key: _formKey,
      autovalidateMode: _showPhoneValidationOnLoad
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: First Name, Last Name, Email Address
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  "First Name",
                  firstNameTextController,
                  TextInputType.text,
                  size,
                  focusNode: firstNameFocusNode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  "Last Name",
                  lastNameTextController,
                  TextInputType.text,
                  size,
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 20),

          // Row 2: Phone Number, Building/Apartment, Country
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
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  "Building / Apartment",
                  addressTextController,
                  TextInputType.text,
                  size,
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 20),

          // Row 3: States/Provinces, District/City, Pincode (both modes)
          Row(
            children: [
              Expanded(
                child: widget.isModal
                    ? _buildStateDropdownWithSearch(
                        size, locationProvider, accessToken)
                    : _buildStateDropdown(size, locationProvider, accessToken),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: widget.isModal
                    ? _buildDistrictDropdownWithSearch(size, locationProvider)
                    : _buildDistrictDropdown(size, locationProvider),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPincodeDropdown(size, locationProvider),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 4: Gender, Date of Birth, Alternate Phone
          Row(
            children: [
              Expanded(
                child: _buildGenderDropdown(size),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDobField(size),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  "Alternate Phone",
                  altPhoneTextController,
                  TextInputType.phone,
                  size,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 5: Customer Type, CR Number, VAT Number (shown only when B2B is enabled)
          if (isCompanyB2BEnabled)
            Row(
              children: [
                Expanded(
                  child: CustomRadioGroup<String>(
                    title: "Customer Type",
                    value: selectedCustomerType,
                    options: const ['B2C', 'B2B'],
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCustomerType = newValue ?? 'B2C';
                      });
                    },
                    displayText: (String value) => value,
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    "CR Number",
                    crNumberController,
                    TextInputType.text,
                    size,
                    isRequired: selectedCustomerType == 'B2B',
                    validator: (value) {
                      if (selectedCustomerType == 'B2B' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'CR Number is required for B2B';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    "VAT Number",
                    vatNumberController,
                    TextInputType.text,
                    size,
                    isRequired: selectedCustomerType == 'B2B',
                    validator: (value) {
                      if (selectedCustomerType == 'B2B' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'VAT Number is required for B2B';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),

          // Row 6: Balance and Payment Type
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  "Balance",
                  balanceTextController,
                  TextInputType.number,
                  size,
                  inputFormatter: FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}$')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: CustomRadioGroup<PaymentType>(
                  title: "Payment Type",
                  value: selectedPaymentType,
                  options: const [PaymentType.toPay, PaymentType.toReceive],
                  onChanged: (PaymentType? newValue) {
                    setState(() {
                      selectedPaymentType = newValue ?? PaymentType.none;
                    });
                  },
                  displayText: (PaymentType value) {
                    switch (value) {
                      case PaymentType.toPay:
                        return "To Pay";
                      case PaymentType.toReceive:
                        return "To Receive";
                      default:
                        return "";
                    }
                  },
                  isRequired: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Submit buttons
          _buildSubmitButtons(size, locationProvider, accessToken),
        ],
      ),
    );
  }

  Widget _buildTextField(String title, TextEditingController controller,
      TextInputType keyboardType, Size size,
      {FormFieldValidator<String>? validator,
      TextInputFormatter? inputFormatter,
      bool isRequired = false,
      FocusNode? focusNode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: title,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    Colors.red,
                  ),
                ),
            ],
          ),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: size.height * .048,
          width: size.width,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.next,
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            cursorColor: ColorManager.kPrimaryColor,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: validator,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s11,
                0.27, ColorManager.textColor.withOpacity(.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildStateDropdownWithSearch(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "States / Provinces",
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0.27,
                  Colors.black.withOpacity(0.6))
              .copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<String>(
          key: stateDropdownKey,
          title: "",
          hintText: "Select State",
          value: selectedStateId,
          height: size.height * .048,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          items: locationProvider.stateList.map((state) => state.key).toList(),
          onChanged: (String? newValue) async {
            setState(() {
              selectedStateId = newValue;
              selectedDistrictId = null;
              selectedPincodeId = null;
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

  Widget _buildDistrictDropdownWithSearch(
      Size size, LocationProvider locationProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "District / City",
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0.27,
                  Colors.black.withOpacity(0.6))
              .copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<String>(
          key: districtDropdownKey,
          title: "",
          height: size.height * .048,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          hintText: "Select District",
          value: selectedDistrictId,
          items: locationProvider.districtList
              .map((district) => district.key)
              .toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedDistrictId = newValue;
              selectedPincodeId = null;
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

  Widget _buildStateDropdown(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "States / Provinces",
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ).copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: size.height * .048,
          width: size.width,
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
              });
              if (newValue != null) {
                await locationProvider.listAllDistricts(
                    stateId: newValue, accessToken: accessToken!);
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
        Text(
          "District / City",
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ).copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: size.height * .048,
          width: size.width,
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
        Text(
          "Pincode",
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ).copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: size.height * .048,
          width: size.width,
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

  Widget _buildSubmitButtons(
      Size size, LocationProvider locationProvider, String? accessToken) {
    if (widget.isModal) {
      return Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Close Button
            CustomRoundButtonAdvanced(
              title: "Close",
              fct: () {
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else {
                  Navigator.pop(context);
                }
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
            CustomRoundButtonAdvanced(
              title: "Submit",
              fct: () => _submitForm(locationProvider, accessToken),
              height: 50,
              width: 120,
              fontSize: FontSize.s12,
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: CustomRoundButtonAdvanced(
          title: "Submit",
          fct: () => _submitForm(locationProvider, accessToken),
          height: 50,
          width: MediaQuery.of(context).size.width * 0.19,
          fontSize: FontSize.s12,
        ),
      );
    }
  }

  Future<void> _submitForm(
      LocationProvider locationProvider, String? accessToken) async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator.adaptive()),
      );

      try {
        // Use IDs for state and city (district)
        final String stateId = selectedStateId ?? "";
        final String cityId = selectedDistrictId ?? "";

        // Determine pin code value from dropdown for both modes
        String pincodeValue = "";
        if (selectedPincodeId != null) {
          pincodeValue = locationProvider.pincodeList
              .firstWhere(
                (pincode) => pincode.key == selectedPincodeId,
                orElse: () => const MapEntry("unknown", ""),
              )
              .value;
        }

        // Prepare payment status string
        String paymentStatus = '';
        if (selectedPaymentType == PaymentType.toPay) {
          paymentStatus = 'to_pay';
        } else if (selectedPaymentType == PaymentType.toReceive) {
          paymentStatus = 'to_receive';
        }

        // Get active store id
        final storeProvider = context.read<StoreSessionProvider>();
        final String storeId =
            (storeProvider.activeStore?.storeId ?? 1).toString();

        // B2B setting handling: if disabled, force B2C and clear CR/VAT
        final appSettings =
            Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings;
        final bool isCompanyB2BEnabled =
            appSettings?.companyB2BEnabled ?? false;
        final String customerTypeToSend =
            isCompanyB2BEnabled ? selectedCustomerType : 'B2C';
        final String crToSend =
            isCompanyB2BEnabled ? crNumberController.text.trim() : '';
        final String vatToSend =
            isCompanyB2BEnabled ? vatNumberController.text.trim() : '';

        await CustomerProvider()
            .addCustomer(
          accessToken ?? "",
          phoneNumberController.text.replaceAll("-", ""),
          storeId,
          "${firstNameTextController.text} ${lastNameTextController.text}",
          emailTextController.text,
          addressTextController.text,
          pincodeValue,
          cityId,
          stateId,
          countryTextController.text,
          context,
          balance: balanceTextController.text.trim(),
          paymentType: paymentStatus,
          altPhone: altPhoneTextController.text.trim(),
          gender: selectedGender ?? '',
          dob: dobTextController.text.trim(),
          customerType: customerTypeToSend,
          crNumber: crToSend,
          vatNumber: vatToSend,
        )
            .then((value) {
          if (value["status"] == "success") {
            showScaffold(context: context, message: '${value["message"]}');
            // Close the loading dialog first
            Navigator.pop(context);

            if (widget.isModal) {
              // Return the created customer's essential details to the caller
              Navigator.pop(context, {
                "status": "success",
                "phone": phoneNumberController.text.replaceAll("-", ""),
                "name":
                    "${firstNameTextController.text} ${lastNameTextController.text}",
                "response": value,
              });
            } else {
              _clearFields();
            }

            if (widget.onSuccess != null) {
              widget.onSuccess!();
            }
          } else {
            Map<String, dynamic> errorResponse = value['errors'] ?? {};
            String errorMessage = "";

            if (errorResponse.isNotEmpty) {
              errorMessage = errorResponse.values.map((e) {
                if (e is List) {
                  return e.join(', ');
                } else {
                  return e.toString();
                }
              }).join('\n');
            } else {
              errorMessage =
                  value['message']?.toString() ?? "An unknown error occurred";
            }

            showScaffoldError(context: context, message: errorMessage);
            Navigator.pop(context);
          }
        });
      } catch (error) {
        Navigator.pop(context);
        showScaffoldError(context: context, message: 'Error: $error');
      }
    }
  }

  Widget _buildGenderDropdown(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gender",
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ).copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: size.height * .048,
          width: size.width,
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedGender,
            hint: Text(
              "Select an option",
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (val) {
              setState(() {
                selectedGender = val;
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

  Widget _buildDobField(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Date of Birth",
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ).copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: size.height * .048,
          width: size.width,
          child: TextFormField(
            controller: dobTextController,
            readOnly: true,
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (picked != null) {
                dobTextController.text =
                    "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              }
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'YYYY-MM-DD',
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
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
        stateSearchController.clear();
        districtSearchController.clear();
        balanceTextController.clear();
        selectedDistrictId = null;
        selectedStateId = null;
        selectedPincodeId = null;
        selectedPaymentType = PaymentType.none;
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

  String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneNumber = value.replaceAll("-", "");
    if (phoneNumber.length < 10) {
      return 'Enter a valid phone number';
    }
    return null;
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
    input = input.replaceAll(RegExp(r'\D'), '');
    if (input.length > 3) {
      input = '${input.substring(0, 3)}-${input.substring(3)}';
    }
    if (input.length > 7) {
      input = '${input.substring(0, 7)}-${input.substring(7)}';
    }
    return input;
  }
}
