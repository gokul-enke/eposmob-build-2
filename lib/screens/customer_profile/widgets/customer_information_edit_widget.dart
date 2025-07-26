import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
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
  late TextEditingController addressController;
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
    addressController = TextEditingController(text: ''); // No address in model
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
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
                      buildColumnWidgetForTextFields(
                        controller: addressController,
                        hintText: 'Address (Optional)',
                        title: 'Address (Optional)',
                        size: widget.size,
                        width: double.infinity,
                        height: widget.size.height * 0.15,
                      ),
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
            isStarRed: true,
            width: double.infinity,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Last name is required';
              }
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
        addressController.text,
        "", "", "", "", // pincode, city, state, country
        customerId,
        context,
      );

      Navigator.pop(context); // Close loading dialog

      if (response["status"] == "success") {
        showScaffold(
            context: context,
            message: response["message"] ?? "Customer updated successfully");
        await customerProvider.fetchUserById(accessToken, customerId, context);
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
