import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/supplier_provider.dart';

enum PaymentType { none, to_pay, to_receive }

class SupplierInformationEditWidget extends StatefulWidget {
  final Size size;
  final Supplier supplier;

  const SupplierInformationEditWidget({
    Key? key,
    required this.size,
    required this.supplier,
  }) : super(key: key);

  @override
  State<SupplierInformationEditWidget> createState() =>
      _SupplierInformationEditWidgetState();
}

class _SupplierInformationEditWidgetState
    extends State<SupplierInformationEditWidget> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _addressController;
  late TextEditingController _taxNumberController;
  late TextEditingController _crNumberController;
  late TextEditingController _vatNumberController;
  late TextEditingController _balanceController;
  late TextEditingController _currentBalanceController;

  // Payment type selection
  PaymentType selectedPaymentType = PaymentType.to_pay;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.supplier.name);
    _emailController = TextEditingController(text: widget.supplier.email);
    _phoneController = TextEditingController(text: widget.supplier.phone);
    _altPhoneController = TextEditingController(text: widget.supplier.altPhone);
    _addressController = TextEditingController(text: widget.supplier.address);
    _taxNumberController =
        TextEditingController(text: widget.supplier.taxNumber ?? '');
    _crNumberController = TextEditingController(text: _kycValue('CR_NUMBER'));
    _vatNumberController = TextEditingController(text: _kycValue('VAT_NUMBER'));
    // Show balance as absolute value (remove negative sign)
    final balanceValue = widget.supplier.balance.abs();
    _balanceController =
        TextEditingController(text: balanceValue.toStringAsFixed(2));
    _currentBalanceController = TextEditingController(
        text: widget.supplier.currentBalance?.toStringAsFixed(2));

    // Initialize payment type based on supplier data
    debugPrint("Supplier balance: ${widget.supplier.balance}");
    debugPrint("Supplier payment type: ${widget.supplier.paymentType}");

    switch (widget.supplier.paymentType.toLowerCase()) {
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
  }

  String _kycValue(String key) {
    for (final entry in widget.supplier.kyc) {
      if (entry.key.toUpperCase() == key.toUpperCase()) {
        return entry.value;
      }
    }

    if (key == 'CR_NUMBER') return widget.supplier.crNumber ?? '';
    if (key == 'VAT_NUMBER') return widget.supplier.vatNumber ?? '';
    return '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _crNumberController.dispose();
    _vatNumberController.dispose();
    _balanceController.dispose();
    _currentBalanceController.dispose();
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
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildEditForm(),
              ),
            ],
          ),
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
            'supplier_profile.edit_title'.tr,
            style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                ColorManager.kTitleTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            _buildSectionCard(
              title: 'supplier_profile.edit_section_basic'.tr,
              icon: Icons.business_outlined,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'supplier_profile.edit_label_name'.tr,
                  hintText: 'supplier_profile.edit_hint_name'.tr,
                  isRequired: true,
                ),
                const SizedBox(height: 20),
                _buildTwoFieldRow(
                  leftController: _emailController,
                  leftLabel: 'supplier_profile.edit_label_email'.tr,
                  leftHint: 'supplier_profile.edit_hint_email'.tr,
                  leftKeyboardType: TextInputType.emailAddress,
                  rightController: _phoneController,
                  rightLabel: 'supplier_profile.edit_label_phone'.tr,
                  rightHint: 'supplier_profile.edit_hint_phone'.tr,
                  rightKeyboardType: TextInputType.phone,
                  rightRequired: true,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _altPhoneController,
                  label: 'supplier_profile.edit_label_alt_phone'.tr,
                  hintText: 'supplier_profile.edit_hint_alt_phone'.tr,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _taxNumberController,
                  label: 'supplier_profile.edit_label_tax'.tr,
                  hintText: 'supplier_profile.edit_hint_tax'.tr,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Address Information Section
            _buildSectionCard(
              title: 'supplier_profile.edit_section_address'.tr,
              icon: Icons.location_on_outlined,
              children: [
                _buildTextField(
                  controller: _addressController,
                  label: 'supplier_profile.edit_label_address'.tr,
                  hintText: 'supplier_profile.edit_hint_address'.tr,
                  maxLines: 3,
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSectionCard(
              title: 'supplier_profile.edit_section_kyc'.tr,
              icon: Icons.verified_user_outlined,
              children: [
                _buildTwoFieldRow(
                  leftController: _crNumberController,
                  leftLabel: 'supplier_profile.edit_label_cr'.tr,
                  leftHint: 'supplier_profile.edit_hint_cr'.tr,
                  rightController: _vatNumberController,
                  rightLabel: 'supplier_profile.edit_label_vat'.tr,
                  rightHint: 'supplier_profile.edit_hint_vat'.tr,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Financial Information Section
            _buildSectionCard(
              title: 'supplier_profile.edit_section_financial'.tr,
              icon: Icons.account_balance_wallet_outlined,
              children: [
                _buildBalanceAndPaymentTypeFields(),
              ],
            ),

            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kPrimaryWithOpacity10),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryWithOpacity10,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.30,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isRequired)
              Text(
                '* ',
                style: buildCustomStyle(
                    FontWeightManager.bold, FontSize.s14, 0, ColorManager.kRed),
              ),
            Text(
              label,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s14, 0,
                  ColorManager.kTitleTextColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        buildColumnWidgetForTextFields(
          controller: controller,
          hintText: hintText,
          keyboardType: keyboardType,
          size: widget.size,
          width: double.infinity,
          inputFormatters: inputFormatters,
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '$label ${'supplier_profile.edit_val_required'.tr}';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildTwoFieldRow({
    required TextEditingController leftController,
    required String leftLabel,
    required String leftHint,
    TextInputType leftKeyboardType = TextInputType.text,
    bool leftRequired = false,
    List<TextInputFormatter>? leftInputFormatters,
    required TextEditingController rightController,
    required String rightLabel,
    required String rightHint,
    TextInputType rightKeyboardType = TextInputType.text,
    bool rightRequired = false,
    List<TextInputFormatter>? rightInputFormatters,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            controller: leftController,
            label: leftLabel,
            hintText: leftHint,
            keyboardType: leftKeyboardType,
            isRequired: leftRequired,
            inputFormatters: leftInputFormatters,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildTextField(
            controller: rightController,
            label: rightLabel,
            hintText: rightHint,
            keyboardType: rightKeyboardType,
            isRequired: rightRequired,
            inputFormatters: rightInputFormatters,
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
            title: 'supplier_profile.edit_btn_save'.tr,
            fct: _saveChanges,
            height: 50,
            width: 150,
            fontSize: FontSize.s14,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomRoundButton(
            radius: 10,
            title: 'supplier_profile.edit_btn_cancel'.tr,
            fct: () {
              // Cancel editing
            },
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: ColorManager.kPrimaryColor,
        ),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      final provider = context.read<SupplierProvider>();

      // Prepare payment type value
      String? paymentTypeValue;
      if (selectedPaymentType != PaymentType.none) {
        paymentTypeValue =
            selectedPaymentType == PaymentType.to_pay ? 'to_pay' : 'to_receive';
      }

      final result = await provider.updateSupplier(
        id: widget.supplier.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        accessToken: accessToken,
        balance: double.tryParse(_balanceController.text.trim()) ?? 0.0,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        altPhone: _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        taxNumber: _taxNumberController.text.trim(),
        kyc: _buildKycEntries(),
        paymentStatus: paymentTypeValue,
      );

      Navigator.pop(context);

      final isSuccess =
          (result['status']?.toString().toLowerCase() == 'success');
      final message = result['message']?.toString() ?? 'Updated';

      // Show success or error dialog
      if (isSuccess) {
        showScaffold(
          context: context,
          message: 'supplier_profile.edit_msg_success'.tr,
        );

        // Navigate back to supplier list after successful save
        final sideBarController = Get.find<SideBarController>();
        sideBarController.index.value = 52; // Supplier list index
      } else {
        showScaffoldError(
          context: context,
          message: message,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      showScaffoldError(
        context: context,
        message: 'supplier_profile.edit_msg_failed'.tr,
      );
    }
  }

  List<SupplierKyc> _buildKycEntries() {
    final editedKeys = {'CR_NUMBER', 'VAT_NUMBER'};
    return [
      if (_crNumberController.text.trim().isNotEmpty)
        SupplierKyc(key: 'CR_NUMBER', value: _crNumberController.text.trim()),
      if (_vatNumberController.text.trim().isNotEmpty)
        SupplierKyc(key: 'VAT_NUMBER', value: _vatNumberController.text.trim()),
      ...widget.supplier.kyc.where(
        (entry) => !editedKeys.contains(entry.key.toUpperCase()),
      ),
    ];
  }

  Widget _buildBalanceAndPaymentTypeFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Payment type on the left - custom built to match text field styling
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                title: 'supplier_profile.edit_label_payment_type'.tr,
                isStarRed: true,
                textStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              // Container matching text field style
              BuildBoxShadowContainer(
                circleRadius: 7,
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                padding: const EdgeInsets.only(left: 15),
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
                      'supplier_profile.edit_radio_to_pay'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s13,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                      'supplier_profile.edit_radio_to_receive'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s13,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Balance field on the right
        Expanded(
          flex: 2,
          child: buildColumnWidgetForTextFields(
            controller: _balanceController,
            hintText: 'supplier_profile.edit_label_balance'.tr,
            title: 'supplier_profile.edit_label_balance'.tr,
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
                  return 'supplier_profile.edit_val_invalid_balance'.tr;
                }
                if (balance < 0) {
                  return 'supplier_profile.edit_val_negative_balance'.tr;
                }
              }
              return null;
            },
            onchanged: (value) {
              // Trigger validation when balance changes
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}
