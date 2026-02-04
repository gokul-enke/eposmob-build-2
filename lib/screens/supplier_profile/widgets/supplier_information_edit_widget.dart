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
  late TextEditingController _balanceController;
  late TextEditingController _currentBalanceController;
  late TextEditingController _productCategoriesController;
  
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
    // Show balance as absolute value (remove negative sign)
    final balanceValue = widget.supplier.balance.abs();
    _balanceController = TextEditingController(text: balanceValue.toStringAsFixed(2));
    _currentBalanceController = TextEditingController(
        text: widget.supplier.currentBalance?.toStringAsFixed(2));
    _productCategoriesController =
        TextEditingController(text: widget.supplier.productCategories);
    
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _currentBalanceController.dispose();
    _productCategoriesController.dispose();
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
            'Edit Supplier Information',
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
              title: 'Basic Information',
              icon: Icons.business_outlined,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Supplier Name',
                  hintText: 'Enter supplier name',
                  isRequired: true,
                ),
                const SizedBox(height: 20),
                _buildTwoFieldRow(
                  leftController: _emailController,
                  leftLabel: 'Email Address',
                  leftHint: 'Enter email address',
                  leftKeyboardType: TextInputType.emailAddress,
                  rightController: _phoneController,
                  rightLabel: 'Phone Number',
                  rightHint: 'Enter phone number',
                  rightKeyboardType: TextInputType.phone,
                  rightRequired: true,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _altPhoneController,
                  label: 'Alternative Phone',
                  hintText: 'Enter alternative phone number',
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Address Information Section
            _buildSectionCard(
              title: 'Address Information',
              icon: Icons.location_on_outlined,
              children: [
                _buildTextField(
                  controller: _addressController,
                  label: 'Business Address',
                  hintText: 'Enter complete business address',
                  maxLines: 3,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Financial Information Section
            _buildSectionCard(
              title: 'Financial Information',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                _buildBalanceAndPaymentTypeFields(),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _productCategoriesController,
                  label: 'Product Categories',
                  hintText: 'e.g., Electronics, Furniture',
                ),
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
          validator: isRequired ? (value) {
            if (value == null || value.isEmpty) {
              return '$label is required';
            }
            return null;
          } : null,
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
            title: "Save Changes",
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
            title: "Cancel",
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
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        altPhone: _altPhoneController.text.trim().isEmpty ? null : _altPhoneController.text.trim(),
        paymentStatus: paymentTypeValue,
        productCategories: _productCategoriesController.text.trim().isEmpty ? null : _productCategoriesController.text.trim(),
      );

      Navigator.pop(context);

      final isSuccess = (result['status']?.toString().toLowerCase() == 'success');
      final message = result['message']?.toString() ?? 'Updated';

      // Show success or error dialog
      if (isSuccess) {
        showScaffold(
          context: context,
          message: 'Supplier information updated successfully',
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
        message: 'Failed to update supplier',
      );
    }
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
                title: 'Payment Type',
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
                      'To Pay',
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
                      'To Receive',
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
            hintText: 'Balance',
            title: 'Balance',
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
                  return 'Please enter a valid balance';
                }
                if (balance < 0) {
                  return 'Balance cannot be negative';
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
