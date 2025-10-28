import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/customer_list.dart';
import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../components/build_dialog_box.dart';

enum PaymentType { none, toPay, toReceive }

class CustomerInformationEditWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData? customer;

  const CustomerInformationEditWidget({
    Key? key,
    required this.size,
    required this.customer,
  }) : super(key: key);

  @override
  State<CustomerInformationEditWidget> createState() =>
      _CustomerInformationEditWidgetState();
}

class _CustomerInformationEditWidgetState
    extends State<CustomerInformationEditWidget> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController altPhoneController;
  late TextEditingController balanceController;
  String? selectedGender;
  DateTime? selectedDate;
  PaymentType selectedPaymentType = PaymentType.none;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final nameParts = widget.customer?.name?.split(' ') ?? [''];
    firstNameController = TextEditingController(text: nameParts.first);
    lastNameController = TextEditingController(
        text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    emailController = TextEditingController(text: widget.customer?.email ?? '');
    phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    altPhoneController = TextEditingController(text: widget.customer?.altPhone ?? '');
    balanceController = TextEditingController(text: widget.customer?.balance?.toString() ?? '0.00');
    
    // Initialize gender and date
    selectedGender = widget.customer?.gender;
    selectedDate = widget.customer?.dob != null ? DateTime.tryParse(widget.customer!.dob!) : null;
    
    // Initialize payment type based on customer data
    debugPrint("Customer balance: ${widget.customer?.balance}");
    debugPrint("Customer payment type: ${widget.customer?.paymentType}");
    
    if (widget.customer?.paymentType != null) {
      switch (widget.customer!.paymentType!.toLowerCase()) {
        case 'to_pay':
          selectedPaymentType = PaymentType.toPay;
          debugPrint("Set payment type to: To Pay");
          break;
        case 'to_receive':
          selectedPaymentType = PaymentType.toReceive;
          debugPrint("Set payment type to: To Receive");
          break;
        default:
          selectedPaymentType = PaymentType.none;
          debugPrint("Set payment type to: None (default)");
      }
    } else {
      debugPrint("Payment type is null, setting to None");
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    altPhoneController.dispose();
    balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameFields(),
                      const SizedBox(height: 20),
                      buildColumnWidgetForTextFields(
                        controller: emailController,
                        hintText: 'Email Address',
                        title: 'Email Address',
                        size: widget.size,
                        width: double.infinity,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      buildColumnWidgetForTextFields(
                        controller: phoneController,
                        hintText: 'Phone Number',
                        title: 'Phone Number',
                        size: widget.size,
                        width: double.infinity,
                        keyboardType: TextInputType.phone,
                        isStarRed: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildAltPhoneField(),
                      const SizedBox(height: 20),
                      _buildGenderField(),
                      const SizedBox(height: 20),
                      _buildDateOfBirthField(),
                      const SizedBox(height: 20),
                      _buildBalanceAndPaymentTypeFields(),
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
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.edit_note,
              color: ColorManager.kPrimaryColor, size: 28),
          const SizedBox(width: 12),
          Text(
            'Edit Customer Information',
            style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                ColorManager.kTitleTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNameFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: buildColumnWidgetForTextFields(
            controller: firstNameController,
            hintText: 'First Name',
            title: 'First Name',
            size: widget.size,
            isStarRed: true,
            width: double.infinity,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'First name is required';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: buildColumnWidgetForTextFields(
            controller: lastNameController,
            hintText: 'Last Name',
            title: 'Last Name',
            size: widget.size,
            isStarRed: false,
            width: double.infinity,
            validator: (value) {
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomRoundButton(
            radius: 10,
            title: "Save Changes",
            fct: _updateProfile,
            height: 50,
            width: 150,
            fontSize: FontSize.s14,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomRoundButton(
            radius: 10,
            title: "Change Password",
            fct: () => _showPasswordChangeConfirmation(context),
            height: 50,
            width: 150,
            fontSize: FontSize.s14,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            borderColor: ColorManager.kPrimaryColor,
          ),
        ),
      ],
    );
  }

  void _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null) {
      showScaffoldError(context: context, message: "Please login again");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final customerId = widget.customer?.id;
      if (customerId == null) throw Exception("Invalid customer ID");

      final response = await customerProvider.updateCustomer(
        accessToken,
        phoneController.text,
        "${firstNameController.text} ${lastNameController.text}",
        emailController.text,
        "", // address - removed since not in API
        "", "", "", "", // pincode, city, state, country
        customerId,
        context,
        altPhone: altPhoneController.text,
        gender: selectedGender,
        dob: selectedDate?.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
        storeId: widget.customer?.storeId ?? 1,
        balance: balanceController.text.trim(),
      );

      Navigator.pop(context); // Close loading dialog

      if (response["status"] == "success") {
        debugPrint("Customer update successful, updating local customer data...");
        showScaffold(
            context: context,
            message: response["message"] ?? "Customer updated successfully");
        
        // Update the local customer data with the new information
        if (widget.customer != null) {
          // Create a new customer object with updated data
          final updatedCustomer = CustomerListModelData(
            id: widget.customer!.id,
            name: "${firstNameController.text} ${lastNameController.text}",
            email: emailController.text,
            phone: phoneController.text,
            altPhone: altPhoneController.text.isNotEmpty ? altPhoneController.text : widget.customer!.altPhone,
            gender: selectedGender ?? widget.customer!.gender,
            dob: selectedDate?.toIso8601String().split('T')[0] ?? widget.customer!.dob,
            profileImage: widget.customer!.profileImage,
            storeId: widget.customer!.storeId,
            userId: widget.customer!.userId,
            createdAt: widget.customer!.createdAt,
            updatedAt: widget.customer!.updatedAt,
            deletedAt: widget.customer!.deletedAt,
            cardNumber: widget.customer!.cardNumber,
            loyaltyPoints: widget.customer!.loyaltyPoints,
            validFrom: widget.customer!.validFrom,
            validUntil: widget.customer!.validUntil,
            cardStatus: widget.customer!.cardStatus,
            membershipName: widget.customer!.membershipName,
            membershipCode: widget.customer!.membershipCode,
            minRedeemablePoints: widget.customer!.minRedeemablePoints,
            pricePerPoint: widget.customer!.pricePerPoint,
            balance: double.tryParse(balanceController.text.trim()) ?? widget.customer!.balance,
            paymentType: widget.customer!.paymentType,
            address: widget.customer!.address,
            pincode: widget.customer!.pincode,
            city: widget.customer!.city,
            state: widget.customer!.state,
            country: widget.customer!.country,
            district: widget.customer!.district,
            transactions: widget.customer!.transactions,
            orders: widget.customer!.orders,
          );
          
          // Update the selected customer in the provider
          customerProvider.selectCustomer(updatedCustomer);
        }
      } else {
        String errorMsg = response["message"] ?? "Failed to update customer";
        if (response["errors"] != null) {
          final errors = response["errors"] as Map<String, dynamic>;
          errorMsg +=
              "\n${errors.entries.map((e) => "${e.key}: ${(e.value as List).join(', ')}").join("\n")}";
        }
        showScaffoldError(context: context, message: errorMsg);
      }
    } catch (error) {
      Navigator.pop(context); // Close loading dialog
      showScaffoldError(
          context: context, message: "An error occurred: $error");
    }
  }

  Widget _buildAltPhoneField() {
    return buildColumnWidgetForTextFields(
      controller: altPhoneController,
      hintText: 'Alternative Phone Number',
      title: 'Alternative Phone Number',
      size: widget.size,
      width: double.infinity,
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildGenderField() {
    return buildColumnWidgetForTextFields(
      controller: TextEditingController(text: selectedGender ?? ''),
      hintText: 'Select Gender',
      title: 'Gender',
      size: widget.size,
      width: double.infinity,
      readOnly: true,
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Gender'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Male'),
                  onTap: () {
                    setState(() {
                      selectedGender = 'male';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('Female'),
                  onTap: () {
                    setState(() {
                      selectedGender = 'female';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('Other'),
                  onTap: () {
                    setState(() {
                      selectedGender = 'other';
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateOfBirthField() {
    return buildColumnWidgetForTextFields(
      controller: TextEditingController(
        text: selectedDate != null
            ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
            : '',
      ),
      hintText: 'Select Date of Birth',
      title: 'Date of Birth',
      size: widget.size,
      width: double.infinity,
      readOnly: true,
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            selectedDate = picked;
          });
        }
      },
    );
  }

  Widget _buildBalanceAndPaymentTypeFields() {
    return buildColumnWidgetForTextFields(
      controller: balanceController,
      hintText: 'Balance',
      title: 'Balance',
      size: widget.size,
      width: double.infinity,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}$')),
      ],
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final balance = double.tryParse(value);
          if (balance == null) {
            return 'Please enter a valid balance';
          }
        }
        return null;
      },
    );
  }

  void _showPasswordChangeConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Change Password Request"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.mark_email_read_outlined,
                size: 48, color: ColorManager.kPrimaryColor),
            SizedBox(height: 16),
            Text(
              "A password reset link will be sent to the customer's registered email.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Password reset link sent (demo)"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text("Send Link"),
          ),
        ],
      ),
    );
  }
}
