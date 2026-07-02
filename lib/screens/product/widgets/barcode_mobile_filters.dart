import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class BarcodeMobileFilters extends StatelessWidget {
  final TextEditingController productNameController;
  final TextEditingController barcodeController;
  final Widget categoryField;
  final void Function(String?) onSearch;
  final VoidCallback onReset;

  const BarcodeMobileFilters({
    super.key,
    required this.productNameController,
    required this.barcodeController,
    required this.categoryField,
    required this.onSearch,
    required this.onReset,
  });

  Widget _buildFilterField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildTextFilter({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Size size,
  }) {
    return _buildFilterField(
      label: label,
      child: buildColumnWidgetForTextFields(
        height: 45,
        onchanged: onSearch,
        controller: controller,
        size: size,
        hintText: hint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterField(
          label: 'Category',
          child: categoryField,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: 'Product Name',
          hint: 'Product Name',
          controller: productNameController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: 'Barcode',
          hint: 'Barcode',
          controller: barcodeController,
          size: size,
        ),
        const SizedBox(height: 16),
        CustomRoundButton(
          title: 'Reset Filters',
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          borderColor: ColorManager.kPrimaryColor,
          fct: onReset,
          height: 45,
          width: double.infinity,
          fontSize: FontSize.s12,
        ),
      ],
    );
  }
}
