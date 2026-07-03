import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../components/build_container_box.dart';
import '../components/build_round_button.dart';
import '../components/build_title.dart';
import '../providers/auth_model.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

enum PaymentType { none, toPay, toReceive }

class AddCustomerForm extends StatefulWidget {
  final String? initialMobileNumber;
  final bool isModal;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const AddCustomerForm({
    Key? key,
    this.initialMobileNumber,
    this.isModal = false,
    this.onSuccess,
    this.onCancel,
  }) : super(key: key);

  @override
  State<AddCustomerForm> createState() => _AddCustomerFormState();
}

class _AddCustomerFormState extends State<AddCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final firstNameTextController = TextEditingController();
  final lastNameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressTextController = TextEditingController();
  final streetAddressTextController = TextEditingController();
  final countryTextController = TextEditingController();
  final stateSearchController = TextEditingController();
  final districtSearchController = TextEditingController();
  final balanceTextController = TextEditingController();

  PaymentType selectedPaymentType = PaymentType.none;
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
    if (widget.initialMobileNumber != null) {
      phoneNumberController.text = widget.initialMobileNumber!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('🚀 [AddCustomerForm] START: Initializing location data...');
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      final sharedPrefProvider = Provider.of<SharedPreferenceProvider>(context, listen: false);
      String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

      debugPrint('🔑 [AddCustomerForm] Token exists: ${accessToken != null && accessToken.isNotEmpty}');

      if (accessToken == null) {
        debugPrint('⚠️ [AddCustomerForm] EXIT: No access token found.');
        return;
      }

      // Fetch states
      await locationProvider.listAllStates(accessToken);
      debugPrint('📊 [AddCustomerForm] States in list: ${locationProvider.stateList.length}');
      if (locationProvider.stateList.isNotEmpty) {
        debugPrint('   - First State: ${locationProvider.stateList.first.key} (${locationProvider.stateList.first.value})');
      }

      // Get activeStoreId from storage
      final activeStoreId = await sharedPrefProvider.getActiveStoreId();
      debugPrint('🔑 [AddCustomerForm] active_store_id from storage: $activeStoreId');

      // Inspect storeList
      debugPrint('🏬 [AddCustomerForm] purchaseProvider.storeList items: ${purchaseProvider.storeList.length}');
      for (var s in purchaseProvider.storeList.take(5)) {
        debugPrint('   - Store [ID: ${s.id}, Name: ${s.name}]');
      }

      // Find store details
      if (activeStoreId != null && purchaseProvider.storeList.isNotEmpty) {
        final currentStore = purchaseProvider.storeList.firstWhere(
          (s) => s.id == activeStoreId,
          orElse: () {
            debugPrint('⚠️ [AddCustomerForm] Store ID $activeStoreId NOT FOUND in list. Fallback to first.');
            return purchaseProvider.storeList.first;
          },
        );

        debugPrint('🏪 [AddCustomerForm] SELECTED STORE: ${currentStore.name} (ID: ${currentStore.id})');
        debugPrint('📍 [AddCustomerForm] METADATA: stateId=${currentStore.stateId}, districtId=${currentStore.districtId}, pincodeId=${currentStore.pincodeId}');

        if (currentStore.stateId != null) {
          final stateIdStr = currentStore.stateId.toString();
          bool stateExists = locationProvider.stateList.any((s) => s.key == stateIdStr);
          
          debugPrint('🏁 [AddCustomerForm] Matching State ID [$stateIdStr] in States List? $stateExists');

          if (stateExists) {
            setState(() {
              selectedStateId = stateIdStr;
              isLoadingDistricts = true;
              stateDropdownKey = UniqueKey();
            });

            debugPrint('🌆 [AddCustomerForm] Fetching Districts for State: $selectedStateId');
            await locationProvider.listAllDistricts(
              stateId: selectedStateId!,
              accessToken: accessToken,
            );
            debugPrint('📊 [AddCustomerForm] Districts in list: ${locationProvider.districtList.length}');

            if (currentStore.districtId != null) {
              final districtIdStr = currentStore.districtId.toString();
              bool districtExists = locationProvider.districtList.any((d) => d.key == districtIdStr);
              debugPrint('🏁 [AddCustomerForm] Matching District ID [$districtIdStr] in Districts List? $districtExists');

              if (districtExists) {
                setState(() {
                  selectedDistrictId = districtIdStr;
                  isLoadingDistricts = false;
                  isLoadingPincodes = true;
                  districtDropdownKey = UniqueKey();
                });

                debugPrint('🏘️ [AddCustomerForm] Fetching Pincodes for District: $selectedDistrictId');
                await locationProvider.listAllPincodes(
                  districtId: selectedDistrictId!,
                  accessToken: accessToken,
                );
                debugPrint('📊 [AddCustomerForm] Pincodes in list: ${locationProvider.pincodeList.length}');

                if (currentStore.pincodeId != null) {
                  final pincodeIdStr = currentStore.pincodeId.toString();
                  bool pincodeExists = locationProvider.pincodeList.any((p) => p.key == pincodeIdStr);
                  debugPrint('🏁 [AddCustomerForm] Matching Pincode ID [$pincodeIdStr] in Pincodes List? $pincodeExists');
                  
                  if (pincodeExists) {
                    setState(() {
                      selectedPincodeId = pincodeIdStr;
                      isLoadingPincodes = false;
                      pincodeDropdownKey = UniqueKey();
                    });
                  } else {
                    debugPrint('⚠️ [AddCustomerForm] Pincode ID not found in list.');
                    setState(() => isLoadingPincodes = false);
                  }
                } else {
                  setState(() => isLoadingPincodes = false);
                }
              } else {
                debugPrint('⚠️ [AddCustomerForm] District ID not found in list.');
                setState(() => isLoadingDistricts = false);
              }
            } else {
              setState(() => isLoadingDistricts = false);
            }
          }
        } else {
          debugPrint('⚠️ [AddCustomerForm] currentStore.stateId is NULL.');
        }
      } else {
        debugPrint('⚠️ [AddCustomerForm] SKIPPING AUTOFILL: storeList is empty or activeStoreId is null.');
      }
      debugPrint('🏁 [AddCustomerForm] END: Initialization complete.');
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final locationProvider = Provider.of<LocationProvider>(context);
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    return Form(
      key: _formKey,
      child: Column(
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
              if (!widget.isModal) ...[
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
            ],
          ),
          const SizedBox(height: 15),

          // Row 2: Phone, Building/Apartment, Email (for modal) or Country
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
                  "Building / Apartment",
                  addressTextController,
                  TextInputType.text,
                  size,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: widget.isModal
                    ? _buildTextField(
                        "Email Address",
                        emailTextController,
                        TextInputType.emailAddress,
                        size,
                        validator: validateEmail,
                      )
                    : _buildTextField(
                        "Country",
                        countryTextController,
                        TextInputType.text,
                        size,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          _buildTextField(
            "Street Address",
            streetAddressTextController,
            TextInputType.streetAddress,
            size,
            maxLines: 2,
            minLines: 2,
            hintText: "Street name, area, locality",
          ),
          const SizedBox(height: 15),

          // Row 3: States/Provinces, District/City, Pincode/Country
          Row(
            children: [
              Expanded(
                child: widget.isModal
                    ? _buildStateDropdownWithSearch(size, locationProvider, accessToken)
                    : _buildStateDropdown(size, locationProvider, accessToken),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: widget.isModal
                    ? _buildDistrictDropdownWithSearch(size, locationProvider)
                    : _buildDistrictDropdown(size, locationProvider),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: widget.isModal
                    ? _buildTextField(
                        "Country",
                        countryTextController,
                        TextInputType.text,
                        size,
                      )
                    : _buildPincodeDropdown(size, locationProvider),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Row 4: Balance and Payment Type
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  "Balance",
                  balanceTextController,
                  TextInputType.number,
                  size,
                  inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildPaymentTypeSection(size),
              ),
            ],
          ),
          const SizedBox(height: 25),

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
      int maxLines = 1,
      int minLines = 1,
      String? hintText}) {
    final isMultiline = maxLines > 1;
    final fieldHeight =
        isMultiline ? size.height * .12 : size.height * .07;

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
          alignment: isMultiline ? Alignment.topLeft : Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: EdgeInsets.only(
            left: 15,
            top: isMultiline ? 8 : 0,
            right: isMultiline ? 8 : 0,
          ),
          height: fieldHeight,
          width: size.width,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            minLines: minLines,
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.colorPlaceholder,
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: isMultiline ? 4 : 0,
              ),
            ),
            validator: validator,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                0.27, ColorManager.textColor.withOpacity(.5)),
          ),
        ),
      ],
    );
  }

  String _composeAddress() {
    final building = addressTextController.text.trim();
    final street = streetAddressTextController.text.trim();
    final parts = <String>[];
    if (building.isNotEmpty) parts.add(building);
    if (street.isNotEmpty) parts.add(street);
    return parts.join(', ');
  }

  Widget _buildStateDropdownWithSearch(
      Size size, LocationProvider locationProvider, String? accessToken) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildDropDownWithSearch<String>(
          key: stateDropdownKey,
          title: "States / Provinces",
          hintText: "Select State",
          value: selectedStateId,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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

  Widget _buildDistrictDropdownWithSearch(Size size, LocationProvider locationProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildDropDownWithSearch<String>(
          key: districtDropdownKey,
          title: "District / City",
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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
        BuildTextTile(
          title: "States / Provinces",
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
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
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
                ColorManager.colorPlaceholder,
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
          title: "District / City",
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
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
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
                          : ColorManager.colorPlaceholder,
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
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
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
                          : ColorManager.colorPlaceholder,
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

  Widget _buildPaymentTypeSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BuildTextTile(
              title: "Payment Type",
              textStyle: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
            Text(
              ' *',
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          height: size.height * .07,
          width: size.width,
          child: Row(
            children: [
              _buildRadioOption("To Pay", PaymentType.toPay),
              const SizedBox(width: 24),
              _buildRadioOption("To Receive", PaymentType.toReceive),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String title, PaymentType value) {
    return Row(
      children: [
        Radio<PaymentType>(
          value: value,
          groupValue: selectedPaymentType,
          activeColor: ColorManager.kPrimaryColor,
          onChanged: (PaymentType? newValue) {
            setState(() {
              selectedPaymentType = newValue!;
            });
          },
        ),
        Text(
          title,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
              0.27, ColorManager.textColor.withOpacity(.7)),
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
            CustomRoundButton(
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
            CustomRoundButton(
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
        child: CustomRoundButton(
          title: "Submit",
          fct: () => _submitForm(locationProvider, accessToken),
          height: 50,
          width: MediaQuery.of(context).size.width * 0.19,
          fontSize: FontSize.s12,
        ),
      );
    }
  }

  Future<void> _submitForm(LocationProvider locationProvider, String? accessToken) async {
    if (_formKey.currentState!.validate()) {
      // Validate payment type
      if (selectedPaymentType == PaymentType.none) {
        showScaffoldError(context: context, message: "Please select a payment type");
        return;
      }

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

        String pincodeValue = "";
        if (!widget.isModal && selectedPincodeId != null) {
          pincodeValue = locationProvider.pincodeList
              .firstWhere(
                (pincode) => pincode.key == selectedPincodeId,
                orElse: () => const MapEntry("unknown", "Unknown Pincode"),
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

        await CustomerProvider()
            .addCustomer(
          accessToken ?? "",
          phoneNumberController.text.replaceAll("-", ""),
          "1",
          "${firstNameTextController.text} ${lastNameTextController.text}",
          emailTextController.text,
          _composeAddress(),
          widget.isModal ? "" : pincodeValue,
          stateName,
          districtName,
          countryTextController.text,
          context,
          balance: balanceTextController.text.trim(),
          paymentType: paymentStatus,
        )
            .then((value) {
          if (value["status"] == "success") {
            showScaffold(
                context: context, message: '${value["message"]}');
            // Close the loading dialog first
            Navigator.pop(context);
            
            if (widget.isModal) {
              // Return the created customer's essential details to the caller
              Navigator.pop(context, {
                "status": "success",
                "phone": phoneNumberController.text.replaceAll("-", ""),
                "name": "${firstNameTextController.text} ${lastNameTextController.text}",
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
              errorMessage = errorResponse.values
                  .map((e) {
                    if (e is List) {
                      return e.join(', ');
                    } else {
                      return e.toString();
                    }
                  })
                  .join('\n');
            } else {
              errorMessage = value['message']?.toString() ?? "An unknown error occurred";
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

  void _clearFields() {
    if (mounted) {
      setState(() {
        emailTextController.clear();
        phoneNumberController.clear();
        lastNameTextController.clear();
        firstNameTextController.clear();
        addressTextController.clear();
        streetAddressTextController.clear();
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
