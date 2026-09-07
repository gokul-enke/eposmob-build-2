import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/models/customer_list.dart';
import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../components/build_dialog_box.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../controllers/sidebar_controller.dart';

enum PaymentType { none, to_pay, to_receive }

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
  // ZATCA related controllers
  late TextEditingController crNumberController;
  late TextEditingController vatNumberController;
  String _selectedCustomerType = 'B2C';
  String? selectedGender;
  DateTime? selectedDate;
  PaymentType selectedPaymentType = PaymentType.to_pay;
  final _formKey = GlobalKey<FormState>();

  String? _getSignedBalanceText() {
    final balanceText = balanceController.text.trim();
    if (balanceText.isEmpty) {
      return null;
    }

    final parsedBalance = double.tryParse(balanceText);
    if (parsedBalance == null) {
      return balanceText;
    }

    final normalizedBalance = parsedBalance.abs();
    final signedBalance = selectedPaymentType == PaymentType.to_pay
        ? -normalizedBalance
        : normalizedBalance;

    return signedBalance.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    final nameParts = widget.customer?.name?.split(' ') ?? [''];
    firstNameController = TextEditingController(text: nameParts.first);
    lastNameController = TextEditingController(
        text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    emailController = TextEditingController(text: widget.customer?.email ?? '');
    phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    altPhoneController =
        TextEditingController(text: widget.customer?.altPhone ?? '');
    // Show balance as absolute value (remove negative sign)
    final balanceValue = widget.customer?.balance?.abs() ?? 0.0;
    balanceController =
        TextEditingController(text: balanceValue.toStringAsFixed(2));
    // Initialize ZATCA related
    _selectedCustomerType = (widget.customer?.customerType ?? 'B2C');
    // Extract CR/VAT from KYC list if present
    String crExisting = '';
    String vatExisting = '';
    if (widget.customer?.kyc != null) {
      for (final item in widget.customer!.kyc!) {
        final key = (item.key ?? '').toUpperCase();
        if (key == 'CR NUMBER' && (item.value != null)) {
          crExisting = item.value!;
        } else if (key == 'VAT NUMBER' && (item.value != null)) {
          vatExisting = item.value!;
        }
      }
    }
    crNumberController = TextEditingController(text: crExisting);
    vatNumberController = TextEditingController(text: vatExisting);

    // Initialize gender and date
    selectedGender = widget.customer?.gender;
    selectedDate = widget.customer?.dob != null
        ? DateTime.tryParse(widget.customer!.dob!)
        : null;

    // Initialize payment type based on customer data
    debugPrint("Customer balance: ${widget.customer?.balance}");
    debugPrint("Customer payment type: ${widget.customer?.paymentType}");

    if (widget.customer?.paymentType != null) {
      switch (widget.customer!.paymentType!.toLowerCase()) {
        case 'to_pay':
          selectedPaymentType = PaymentType.to_pay;
          debugPrint("Set payment type to: To Pay");
          break;
        case 'to_receive':
          selectedPaymentType = PaymentType.to_receive;
          debugPrint("Set payment type to: To Receive");
          break;
        default:
          selectedPaymentType = PaymentType.to_pay;
          debugPrint("Set payment type to: To Pay (default)");
      }
    } else {
      selectedPaymentType = PaymentType.to_pay;
      debugPrint("Payment type is null, setting to To Pay");
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
    crNumberController.dispose();
    vatNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final bool isZatcaPhase1Enabled = appSettings?.zatcaPhase1Enabled ?? false;
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: EdgeInsets.all(widget.size.width < 600 ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(widget.size.width < 600 ? 12 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameFields(),
                      const SizedBox(height: 20),
                      buildColumnWidgetForTextFields(
                        controller: emailController,
                        hintText: 'customer_profile.field_email'.tr,
                        title: 'customer_profile.field_email'.tr,
                        size: widget.size,
                        width: double.infinity,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                            return 'customer_profile.validator_email_invalid'.tr;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      buildColumnWidgetForTextFields(
                        controller: phoneController,
                        hintText: 'customer_profile.field_phone'.tr,
                        title: 'customer_profile.field_phone'.tr,
                        size: widget.size,
                        width: double.infinity,
                        keyboardType: TextInputType.phone,
                        isStarRed: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'customer_profile.validator_phone_required'.tr;
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
                      if (isZatcaPhase1Enabled) ...[
                        _buildCustomerTypeField(),
                        const SizedBox(height: 20),
                        _buildCrVatFields(),
                        const SizedBox(height: 20),
                      ],
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
    final isMobile = widget.size.width < 600;
    return Container(
      decoration: const BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 16,
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note,
              color: ColorManager.kPrimaryColor, size: isMobile ? 24 : 28),
          SizedBox(width: isMobile ? 8 : 12),
          Flexible(
            child: Text(
              'customer_profile.edit_header'.tr,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(FontWeightManager.bold,
                  isMobile ? FontSize.s16 : FontSize.s18, 0,
                  ColorManager.kTitleTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameFields() {
    final firstNameField = buildColumnWidgetForTextFields(
      controller: firstNameController,
      hintText: 'customer_profile.field_first_name'.tr,
      title: 'customer_profile.field_first_name'.tr,
      size: widget.size,
      isStarRed: true,
      width: double.infinity,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'customer_profile.validator_first_name_required'.tr;
        }
        return null;
      },
    );
    final lastNameField = buildColumnWidgetForTextFields(
      controller: lastNameController,
      hintText: 'customer_profile.field_last_name'.tr,
      title: 'customer_profile.field_last_name'.tr,
      size: widget.size,
      isStarRed: false,
      width: double.infinity,
      validator: (value) {
        return null;
      },
    );

    if (widget.size.width < 600) {
      return Column(
        children: [
          firstNameField,
          const SizedBox(height: 12),
          lastNameField,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: firstNameField),
        const SizedBox(width: 20),
        Expanded(child: lastNameField),
      ],
    );
  }

  Widget _buildActionButtons() {
    final saveButton = CustomRoundButton(
      radius: 10,
      title: 'customer_profile.btn_save_changes'.tr,
      fct: _updateProfile,
      height: 50,
      width: double.infinity,
      fontSize: FontSize.s14,
    );
    final passwordButton = CustomRoundButton(
      radius: 10,
      title: 'customer_profile.btn_change_password'.tr,
      fct: () => _showPasswordChangeConfirmation(context),
      height: 50,
      width: double.infinity,
      fontSize: FontSize.s14,
      boxColor: Colors.white,
      textColor: ColorManager.kPrimaryColor,
      borderColor: ColorManager.kPrimaryColor,
    );

    if (widget.size.width < 600) {
      return Column(
        children: [
          saveButton,
          const SizedBox(height: 12),
          passwordButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: saveButton),
        const SizedBox(width: 16),
        Expanded(child: passwordButton),
      ],
    );
  }

  String _normalizedName() {
    final fullName = '${firstNameController.text} ${lastNameController.text}'
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return fullName;
  }

  String? _changedText(String? original, String current) {
    final normalizedOriginal = (original ?? '').trim();
    final normalizedCurrent = current.trim();
    return normalizedOriginal == normalizedCurrent ? null : normalizedCurrent;
  }

  String? _changedOptionalText(String? original, String? current) {
    final normalizedOriginal = (original ?? '').trim();
    final normalizedCurrent = (current ?? '').trim();
    return normalizedOriginal == normalizedCurrent ? null : normalizedCurrent;
  }

  String? _changedBalanceText(String? original, String? current) {
    final normalizedOriginal = (original ?? '').trim();
    final normalizedCurrent = (current ?? '').trim();

    final originalNumber = double.tryParse(normalizedOriginal);
    final currentNumber = double.tryParse(normalizedCurrent);

    if (originalNumber != null && currentNumber != null) {
      return originalNumber == currentNumber ? null : normalizedCurrent;
    }

    return normalizedOriginal == normalizedCurrent ? null : normalizedCurrent;
  }

  void _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null) {
      showScaffoldError(context: context, message: 'customer_profile.error_login_again'.tr);
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

      // ZATCA Phase 1 handling
      final appSettings =
          Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
      final bool isZatcaPhase1Enabled =
          appSettings?.zatcaPhase1Enabled ?? false;
      final String customerTypeToSend =
          isZatcaPhase1Enabled ? _selectedCustomerType : 'B2C';
      final String crToSend =
          isZatcaPhase1Enabled ? crNumberController.text.trim() : '';
      final String vatToSend =
          isZatcaPhase1Enabled ? vatNumberController.text.trim() : '';

      // Prepare payment type value
      String? paymentTypeValue;
      if (selectedPaymentType != PaymentType.none) {
        paymentTypeValue =
            selectedPaymentType == PaymentType.to_pay ? 'to_pay' : 'to_receive';
      }

      final signedBalanceText = _getSignedBalanceText();
      final updatedName = _normalizedName();
      final originalBalanceText =
          widget.customer?.balance?.toStringAsFixed(2) ?? '';
      final updatedDob = selectedDate?.toIso8601String().split('T')[0] ?? '';

      final changedPhone =
          _changedText(widget.customer?.phone, phoneController.text);
      final changedName = _changedText(widget.customer?.name, updatedName);
      final changedEmail =
          _changedText(widget.customer?.email, emailController.text);
      final changedAltPhone = _changedOptionalText(
          widget.customer?.altPhone, altPhoneController.text);
      final changedGender =
          _changedOptionalText(widget.customer?.gender, selectedGender);
      final changedDob = _changedOptionalText(widget.customer?.dob, updatedDob);
      final changedBalance =
          _changedBalanceText(originalBalanceText, signedBalanceText ?? '');
      final changedPaymentType = _changedOptionalText(
          widget.customer?.paymentType?.toLowerCase(), paymentTypeValue);
      final changedCustomerType = _changedOptionalText(
          widget.customer?.customerType ?? 'B2C', customerTypeToSend);

      String? originalCrNumber;
      String? originalVatNumber;
      if (widget.customer?.kyc != null) {
        for (final item in widget.customer!.kyc!) {
          final key = (item.key ?? '').toUpperCase();
          if (key == 'CR NUMBER') {
            originalCrNumber = item.value;
          } else if (key == 'VAT NUMBER') {
            originalVatNumber = item.value;
          }
        }
      }

      final changedCrNumber = _changedOptionalText(originalCrNumber, crToSend);
      final changedVatNumber =
          _changedOptionalText(originalVatNumber, vatToSend);

      final hasChanges = [
        changedPhone,
        changedName,
        changedEmail,
        changedAltPhone,
        changedGender,
        changedDob,
        changedBalance,
        changedPaymentType,
        changedCustomerType,
        changedCrNumber,
        changedVatNumber,
      ].any((value) => value != null);

      if (!hasChanges) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        showScaffold(context: context, message: 'customer_profile.msg_no_changes'.tr);
        return;
      }

      final response = await customerProvider.updateCustomer(
        accessToken,
        customerId,
        context,
        phone: changedPhone,
        name: changedName,
        email: changedEmail,
        altPhone: changedAltPhone,
        gender: changedGender,
        dob: changedDob,
        balance: changedBalance,
        paymentType: changedPaymentType,
        customerType: changedCustomerType,
        crNumber: changedCrNumber,
        vatNumber: changedVatNumber,
      );

      // Close loading dialog - ensure it's properly closed
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (response["status"] == "success") {
        debugPrint(
            "Customer update successful, updating local customer data...");
        showScaffold(
            context: context,
            message: response["message"] ??
                'customer_profile.updated_successfully'.tr);

        // Update the local customer data with the new information
        if (widget.customer != null) {
          final updatedBalance = double.tryParse(signedBalanceText ?? '');

          // Create a new customer object with updated data
          final updatedCustomer = CustomerListModelData(
            id: widget.customer!.id,
            name: updatedName,
            email: emailController.text,
            phone: phoneController.text,
            altPhone: altPhoneController.text.isNotEmpty
                ? altPhoneController.text
                : widget.customer!.altPhone,
            gender: selectedGender ?? widget.customer!.gender,
            dob: updatedDob.isNotEmpty ? updatedDob : widget.customer!.dob,
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
            balance: updatedBalance ?? widget.customer!.balance,
            paymentType: paymentTypeValue ?? widget.customer!.paymentType,
            customerType: customerTypeToSend,
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

        // Navigate to customers list screen after successful update
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Get.find<SideBarController>().index.value = 5;
          }
        });
      } else {
        // Handle error response
        String errorMsg = "Failed to update customer";

        try {
          // Check if message is a Map (validation errors) or String
          final messageData = response["message"];

          if (messageData is Map<String, dynamic>) {
            // Parse validation errors from message field
            final errors = <String>[];
            messageData.forEach((field, messages) {
              if (messages is List) {
                errors.add("$field: ${messages.join(', ')}");
              } else {
                errors.add("$field: $messages");
              }
            });
            errorMsg = errors.join("\n");
          } else if (messageData is String) {
            // Simple string message
            errorMsg = messageData;
          } else if (response["errors"] != null && response["errors"] is Map) {
            // Fallback: check errors field
            final errors = response["errors"] as Map<String, dynamic>;
            errorMsg = errors.entries
                .map((e) =>
                    "${e.key}: ${(e.value is List ? (e.value as List).join(', ') : e.value)}")
                .join("\n");
          }
        } catch (e) {
          debugPrint("Error parsing error message: $e");
          errorMsg = "Failed to update customer. Please try again.";
        }

        if (mounted) {
          showScaffoldError(context: context, message: errorMsg);
        }
      }
    } catch (error, stackTrace) {
      debugPrint("Exception in _updateProfile: $error");
      debugPrint("Stack trace: $stackTrace");

      // Close loading dialog - ensure it's properly closed
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        showScaffoldError(
            context: context,
            message: 'general.error_prefix'.trParams(
              {'error': error.toString()},
            ));
      }
    }
  }

  Widget _buildAltPhoneField() {
    return buildColumnWidgetForTextFields(
      controller: altPhoneController,
      hintText: 'customer_profile.field_alt_phone'.tr,
      title: 'customer_profile.field_alt_phone'.tr,
      size: widget.size,
      width: double.infinity,
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildGenderField() {
    return buildColumnWidgetForTextFields(
      controller: TextEditingController(text: selectedGender ?? ''),
      hintText: 'customer_profile.field_gender_hint'.tr,
      title: 'customer_profile.field_gender'.tr,
      size: widget.size,
      width: double.infinity,
      readOnly: true,
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('customer_profile.dialog_select_gender'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('customer_profile.gender_male'.tr),
                  onTap: () {
                    setState(() {
                      selectedGender = 'male';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('customer_profile.gender_female'.tr),
                  onTap: () {
                    setState(() {
                      selectedGender = 'female';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('customer_profile.gender_other'.tr),
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
      hintText: 'customer_profile.field_dob_hint'.tr,
      title: 'customer_profile.field_dob'.tr,
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
    final isMobile = widget.size.width < 600;

    final paymentTypeField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: 'customer_profile.field_payment_type'.tr,
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
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
          padding: EdgeInsets.only(left: isMobile ? 8 : 15),
          height: widget.size.height * .07,
          width: double.infinity,
          child: Row(
            children: [
              Radio<PaymentType>(
                value: PaymentType.to_pay,
                groupValue: selectedPaymentType,
                activeColor: ColorManager.kPrimaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity,
                ),
                onChanged: (PaymentType? value) {
                  setState(() {
                    selectedPaymentType = value ?? PaymentType.to_pay;
                  });
                },
              ),
              Text(
                'customer_profile.field_payment_to_pay'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  isMobile ? FontSize.s12 : FontSize.s13,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
              ),
              SizedBox(width: isMobile ? 8 : 16),
              Radio<PaymentType>(
                value: PaymentType.to_receive,
                groupValue: selectedPaymentType,
                activeColor: ColorManager.kPrimaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity,
                ),
                onChanged: (PaymentType? value) {
                  setState(() {
                    selectedPaymentType = value ?? PaymentType.to_pay;
                  });
                },
              ),
              Text(
                'customer_profile.field_payment_to_receive'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  isMobile ? FontSize.s12 : FontSize.s13,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final balanceField = buildColumnWidgetForTextFields(
      controller: balanceController,
      hintText: 'customer_profile.field_balance'.tr,
      title: 'customer_profile.field_balance'.tr,
      size: widget.size,
      width: double.infinity,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
      ],
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final balance = double.tryParse(value);
          if (balance == null) {
            return 'customer_profile.validator_balance_invalid'.tr;
          }
          if (balance < 0) {
            return 'customer_profile.validator_balance_negative'.tr;
          }
        }
        return null;
      },
      onchanged: (value) {
        setState(() {});
      },
    );

    if (isMobile) {
      return Column(
        children: [
          paymentTypeField,
          const SizedBox(height: 12),
          balanceField,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: paymentTypeField),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: balanceField),
      ],
    );
  }

  Widget _buildCustomerTypeField() {
    return buildColumnWidgetForTextFields(
      controller: TextEditingController(text: _selectedCustomerType),
      hintText: 'customer_profile.field_customer_type_hint'.tr,
      title: 'customer_profile.field_customer_type'.tr,
      size: widget.size,
      width: double.infinity,
      readOnly: true,
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('customer_profile.dialog_select_customer_type'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('customers.type_b2c'.tr),
                  onTap: () {
                    setState(() => _selectedCustomerType = 'B2C');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('customers.type_b2b'.tr),
                  onTap: () {
                    setState(() => _selectedCustomerType = 'B2B');
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

  Widget _buildCrVatFields() {
    return Row(
      children: [
        Expanded(
          child: buildColumnWidgetForTextFields(
            controller: crNumberController,
            hintText: 'customer_profile.field_cr_number'.tr,
            title: 'customer_profile.field_cr_number'.tr,
            size: widget.size,
            width: double.infinity,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: buildColumnWidgetForTextFields(
            controller: vatNumberController,
            hintText: 'customer_profile.field_vat_number'.tr,
            title: 'customer_profile.field_vat_number'.tr,
            size: widget.size,
            width: double.infinity,
          ),
        ),
      ],
    );
  }

  void _showPasswordChangeConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('customer_profile.dialog_change_password_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_outlined,
                size: 48, color: ColorManager.kPrimaryColor),
            const SizedBox(height: 16),
            Text(
              'customer_profile.dialog_change_password_content'.tr,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('general.cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('customer_profile.dialog_password_reset_sent'.tr),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('customer_profile.dialog_send_link'.tr),
          ),
        ],
      ),
    );
  }
}
