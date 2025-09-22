import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

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
  late TextEditingController _paymentTypeController;
  late TextEditingController _productCategoriesController;

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
    _balanceController = TextEditingController(text: widget.supplier.balance);
    _currentBalanceController = TextEditingController(
        text: widget.supplier.currentBalance?.toStringAsFixed(2));
    _paymentTypeController =
        TextEditingController(text: widget.supplier.paymentType);
    _productCategoriesController =
        TextEditingController(text: widget.supplier.productCategories);
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
    _paymentTypeController.dispose();
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
          const Icon(Icons.edit, color: ColorManager.kPrimaryColor, size: 28),
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
            _buildSectionTitle('Basic Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Supplier Name',
              hintText: 'Enter supplier name',
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hintText: 'Enter email address',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hintText: 'Enter phone number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _altPhoneController,
              label: 'Alternative Phone',
              hintText: 'Enter alternative phone number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Address Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Address',
              hintText: 'Enter full address',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Financial Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _balanceController,
              label: 'Balance',
              hintText: 'Enter balance',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _currentBalanceController,
              label: 'Current Balance',
              hintText: 'Enter current balance',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _paymentTypeController,
              label: 'Payment Type',
              hintText: 'Enter payment type',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _productCategoriesController,
              label: 'Product Categories',
              hintText: 'Enter product categories',
            ),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16, 0,
          ColorManager.kTitleTextColor),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isRequired)
              Text(
                '*',
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
          // maxLines: maxLines,
          size: widget.size,
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
          fct: () {
            // Cancel editing
          },
          height: 45,
          width: 120,
          fontSize: FontSize.s14,
        ),
        const SizedBox(width: 16),
        CustomRoundButton(
          title: "Save Changes",
          boxColor: ColorManager.kPrimaryColor,
          textColor: Colors.white,
          fct: _saveChanges,
          height: 45,
          width: 150,
          fontSize: FontSize.s14,
        ),
      ],
    );
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      // Save the changes
      // This would typically involve calling an API to update the supplier information
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Supplier information updated successfully'),
          backgroundColor: ColorManager.kSuccessColor,
        ),
      );
    }
  }
}
