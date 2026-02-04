import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:provider/provider.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_title.dart';

class CustomerAddressFormWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData customer;
  final Address? address; // If null, it's "Add", else "Edit"
  final Function(Address) onSuccess;
  final VoidCallback onCancel;

  const CustomerAddressFormWidget({
    super.key,
    required this.size,
    required this.customer,
    this.address,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<CustomerAddressFormWidget> createState() =>
      _CustomerAddressFormWidgetState();
}

class _CustomerAddressFormWidgetState extends State<CustomerAddressFormWidget> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController cityController;
  late TextEditingController landmarkController;

  late FocusNode nameFocusNode;
  late FocusNode phoneFocusNode;
  late FocusNode addressFocusNode;
  late FocusNode cityFocusNode;
  late FocusNode landmarkFocusNode;

  String? selectedStateId;
  String? selectedDistrictId;
  String? selectedPincodeId;
  String selectedType = 'Home';
  final List<String> addressTypes = ['Home', 'Office', 'Other'];

  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
        text: widget.address?.name ?? widget.customer.name);
    phoneController = TextEditingController(
        text: widget.address?.phone ?? widget.customer.phone);
    addressController =
        TextEditingController(text: widget.address?.address ?? "");
    cityController = TextEditingController(text: widget.address?.city ?? "");
    landmarkController =
        TextEditingController(text: widget.address?.landmark ?? "");

    nameFocusNode = FocusNode();
    phoneFocusNode = FocusNode();
    addressFocusNode = FocusNode();
    cityFocusNode = FocusNode();
    landmarkFocusNode = FocusNode();

    if (widget.address != null) {
      selectedStateId = widget.address!.stateId?.toString();
      selectedDistrictId = widget.address!.districtId?.toString();
      selectedPincodeId = widget.address!.pincodeId?.toString();
      selectedType = widget.address!.type ?? 'Home';
    }

    // Fetch initial location data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthModel>(context, listen: false);
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      locationProvider.listAllStates(auth.token!);

      if (selectedStateId != null) {
        locationProvider.listAllDistricts(
            accessToken: auth.token!, stateId: selectedStateId!);
      }

      if (selectedDistrictId != null) {
        locationProvider.listAllPincodes(
            accessToken: auth.token!, districtId: selectedDistrictId!);
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    landmarkController.dispose();
    nameFocusNode.dispose();
    phoneFocusNode.dispose();
    addressFocusNode.dispose();
    cityFocusNode.dispose();
    landmarkFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    final auth = Provider.of<AuthModel>(context, listen: false);
    final customerProvider =
        Provider.of<CustomerProvider>(context, listen: false);

    final Map<String, dynamic> data = {
      "customer_id": widget.customer.id,
      "name": widget.address?.name ?? widget.customer.name,
      "phone": widget.address?.phone ?? widget.customer.phone,
      "address": addressController.text,
      "city": cityController.text,
      "state_id": selectedStateId,
      "district_id": selectedDistrictId,
      "pincode_id": selectedPincodeId,
      "landmark": landmarkController.text,
      "type": selectedType,
    };

    try {
      dynamic response;
      if (widget.address == null) {
        response = await customerProvider.addAddress(
            accessToken: auth.token!, addressData: data);
      } else {
        response = await customerProvider.updateAddress(
            accessToken: auth.token!,
            addressId: widget.address!.id!,
            addressData: data);
      }

      if (response['status'] == 'success') {
        showScaffold(
          context: context,
          message: response['message'] ?? "Success",
        );
        FocusScope.of(context).unfocus(); // Unfocus to prevent FocusNode error
        if (response['data'] != null) {
          Address updatedAddress = Address.fromJson(response['data']);
          widget.onSuccess(updatedAddress);
        } else {
          // Fallback if data is missing but status is success
          widget.onSuccess(widget.address!);
        }
      } else {
        showScaffoldError(
          context: context,
          message: response['message'] ?? "Action failed",
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: "Error: $e",
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = widget.size;
    final locationProvider = Provider.of<LocationProvider>(context);

    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: size.height * 0.75,
        circleRadius: 12,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  color: ColorManager.kPrimaryWithOpacity10,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                        widget.address == null
                            ? Icons.add_location
                            : Icons.edit_location,
                        color: ColorManager.kPrimaryColor,
                        size: 28),
                    const SizedBox(width: 12),
                    Text(
                      widget.address == null
                          ? 'Add New Address'
                          : 'Edit Address',
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s18, 0, ColorManager.kTitleTextColor),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildLocationDropdown(
                                title: "State",
                                hint: "Select State",
                                value: selectedStateId,
                                items: locationProvider.stateList,
                                onChanged: (id) {
                                  setState(() {
                                    selectedStateId = id;
                                    selectedDistrictId = null;
                                    selectedPincodeId = null;
                                  });
                                  locationProvider.listAllDistricts(
                                    accessToken: Provider.of<AuthModel>(context,
                                            listen: false)
                                        .token!,
                                    stateId: id!,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildLocationDropdown(
                                title: "District",
                                hint: "Select District",
                                value: selectedDistrictId,
                                items: locationProvider.districtList,
                                onChanged: (id) {
                                  setState(() {
                                    selectedDistrictId = id;
                                    selectedPincodeId = null;
                                  });
                                  locationProvider.listAllPincodes(
                                    accessToken: Provider.of<AuthModel>(context,
                                            listen: false)
                                        .token!,
                                    districtId: id!,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildLocationDropdown(
                                title: "Pincode",
                                hint: "Select Pincode",
                                value: selectedPincodeId,
                                items: locationProvider.pincodeList,
                                onChanged: (id) {
                                  setState(() => selectedPincodeId = id);
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: buildColumnWidgetForTextFields(
                                key: const ValueKey('city_field'),
                                size: size,
                                controller: cityController,
                                focusNode: cityFocusNode,
                                title: "City",
                                hintText: "Enter city",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        buildColumnWidgetForTextFields(
                          key: const ValueKey('address_field'),
                          size: size,
                          controller: addressController,
                          focusNode: addressFocusNode,
                          title: "Full Address",
                          hintText: "House/Flat No, Apartment, Street",
                          width: double.infinity,
                          isStarRed: true,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: buildColumnWidgetForTextFields(
                                key: const ValueKey('landmark_field'),
                                size: size,
                                controller: landmarkController,
                                focusNode: landmarkFocusNode,
                                title: "Landmark",
                                hintText: "Nearby landmark",
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: "Address Type",
                                    isStarRed: true,
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
                                    width: double.infinity,
                                    child: DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                          border: InputBorder.none),
                                      value: selectedType,
                                      items: addressTypes
                                          .map((t) => DropdownMenuItem(
                                              value: t, child: Text(t)))
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => selectedType = v!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            CustomRoundButton(
                              title: "Cancel",
                              fct: widget.onCancel,
                              width: 120,
                              height: 45,
                              fontSize: FontSize.s14,
                              boxColor: Colors.white,
                              textColor: ColorManager.kPrimaryColor,
                              borderColor: ColorManager.kPrimaryColor,
                            ),
                            const SizedBox(width: 16),
                            CustomRoundButton(
                              title: isSubmitting
                                  ? "Saving..."
                                  : (widget.address == null
                                      ? "Save Address"
                                      : "Update Address"),
                              fct: isSubmitting ? () {} : _submit,
                              width: 160,
                              height: 45,
                              fontSize: FontSize.s14,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String title,
    required String hint,
    required String? value,
    required List<MapEntry<String, String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: title,
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
          height: widget.size.height * .07,
          width: double.infinity,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(border: InputBorder.none),
            isExpanded: true,
            value: items.any((e) => e.key == value) ? value : null,
            hint: Text(hint,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s11,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                )),
            items: items.map((e) {
              return DropdownMenuItem<String>(
                value: e.key,
                child: Text(
                  e.value,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
