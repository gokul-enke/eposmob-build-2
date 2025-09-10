import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class AddCompanyAccountScreen extends StatefulWidget {
  const AddCompanyAccountScreen({super.key});

  @override
  State<AddCompanyAccountScreen> createState() =>
      _AddCompanyAccountScreenState();
}

class _AddCompanyAccountScreenState extends State<AddCompanyAccountScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());

  // Form controllers
  final TextEditingController nameController = TextEditingController();

  // Dropdown values
  String? selectedType;
  String? selectedStore;
  String? selectedBankAccount;
  String? selectedPaymentMethod;

  // Toggle state
  bool isActive = true;

  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Sample data - replace with actual API calls when backend is ready
  final List<String> typeOptions = ['Cash', 'Bank'];
  final List<String> storeOptions = [
    'Store 1',
    'Store 2',
    'Store 3'
  ]; // TODO: Replace with API data
  final List<String> bankAccountOptions = [
    'Account 1',
    'Account 2',
    'Account 3'
  ]; // TODO: Replace with API data
  final List<String> paymentMethodOptions = [
    'COD',
    'Online',
    'Cheque',
    'UPI',
    'Cash'
  ];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormFields(),
                        const SizedBox(height: 30),
                        _buildActionButtons(),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Add Company Account",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        Row(
          children: [
            Text(
              "Is Active",
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: isActive,
              onChanged: (value) {
                setState(() {
                  isActive = value;
                });
              },
              activeColor: ColorManager.kPrimaryColor,
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withOpacity(0.3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // First row: Name and Type
        Row(
          children: [
            Expanded(child: _buildNameField()),
            const SizedBox(width: 15),
            Expanded(child: _buildTypeDropdown()),
          ],
        ),
        const SizedBox(height: 20),
        // Second row: Store and Bank Account ID
        Row(
          children: [
            Expanded(child: _buildStoreDropdown()),
            const SizedBox(width: 15),
            Expanded(child: _buildBankAccountDropdown()),
          ],
        ),
        const SizedBox(height: 20),
        // Third row: Payment Method
        Row(
          children: [
            Expanded(child: _buildPaymentMethodDropdown()),
            Expanded(child: Container()), // Empty space for layout
          ],
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Name *",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextFormField(
            controller: nameController,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              ColorManager.textColor,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
            decoration: decoration.copyWith(
              hintText: "Enter name",
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Type *",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: DropdownButtonFormField<String>(
            value: selectedType,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              ColorManager.textColor,
            ),
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              hintText: "Select type",
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Type is required';
              }
              return null;
            },
            items: typeOptions.map((String type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedType = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoreDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Store",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: DropdownButtonFormField<String>(
            value: selectedStore,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              ColorManager.textColor,
            ),
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              hintText: "Select store",
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            items: storeOptions.map((String store) {
              return DropdownMenuItem(
                value: store,
                child: Text(
                  store,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedStore = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBankAccountDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Bank Account ID",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: DropdownButtonFormField<String>(
            value: selectedBankAccount,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              ColorManager.textColor,
            ),
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              hintText: "Select bank account",
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            items: bankAccountOptions.map((String account) {
              return DropdownMenuItem(
                value: account,
                child: Text(
                  account,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedBankAccount = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Payment Method *",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: DropdownButtonFormField<String>(
            value: selectedPaymentMethod,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              ColorManager.textColor,
            ),
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              hintText: "Select payment method",
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Payment method is required';
              }
              return null;
            },
            items: paymentMethodOptions.map((String method) {
              return DropdownMenuItem(
                value: method,
                child: Text(
                  method,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedPaymentMethod = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CustomRoundButton(
          title: "Cancel",
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          borderColor: ColorManager.kPrimaryColor,
          fct: _handleCancel,
          height: 45,
          width: 150,
          fontSize: 12,
        ),
        const SizedBox(width: 15),
        CustomRoundButton(
          title: "Create & Create Another",
          fct: _handleCreateAndCreateAnother,
          height: 45,
          width: 200,
          fontSize: 12,
        ),
        const SizedBox(width: 15),
        CustomRoundButton(
          title: "Create",
          fct: _handleCreate,
          height: 45,
          width: 150,
          fontSize: 12,
        ),
      ],
    );
  }

  void _handleCreate() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement create company account API call
      debugPrint("Creating company account...");
      debugPrint("Name: ${nameController.text}");
      debugPrint("Type: $selectedType");
      debugPrint("Store: $selectedStore");
      debugPrint("Bank Account: $selectedBankAccount");
      debugPrint("Payment Method: $selectedPaymentMethod");
      debugPrint("Is Active: $isActive");

      // Navigate back to company accounts list
      sideBarController.index.value = 59; // Company accounts screen index
    }
  }

  void _handleCreateAndCreateAnother() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement create company account API call
      debugPrint("Creating company account and preparing for another...");
      debugPrint("Name: ${nameController.text}");
      debugPrint("Type: $selectedType");
      debugPrint("Store: $selectedStore");
      debugPrint("Bank Account: $selectedBankAccount");
      debugPrint("Payment Method: $selectedPaymentMethod");
      debugPrint("Is Active: $isActive");

      // Clear form for next entry
      _clearForm();
    }
  }

  void _handleCancel() {
    // Navigate back to company accounts list
    sideBarController.index.value = 59; // Company accounts screen index
  }

  void _clearForm() {
    setState(() {
      nameController.clear();
      selectedType = null;
      selectedStore = null;
      selectedBankAccount = null;
      selectedPaymentMethod = null;
      isActive = true;
    });
  }
}
