import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class ProductMobileFilters extends StatelessWidget {
  final TextEditingController productNameController;
  final TextEditingController amountController;
  final TextEditingController barcodeController;
  final TextEditingController hsnCodeController;
  final TextEditingController itemCodeController;
  final TextEditingController propertySearchController;
  final String? selectedProperty;
  final List<String> propertyList;
  final Widget categoryField;
  final void Function(String?) onSearch;
  final void Function(String?) onPropertyChanged;
  final VoidCallback onReset;

  const ProductMobileFilters({
    super.key,
    required this.productNameController,
    required this.amountController,
    required this.barcodeController,
    required this.hsnCodeController,
    required this.itemCodeController,
    required this.propertySearchController,
    required this.selectedProperty,
    required this.propertyList,
    required this.categoryField,
    required this.onSearch,
    required this.onPropertyChanged,
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

  Widget _buildPropertyDropdown() {
    return _buildFilterField(
      label: "Property",
      child: BuildDropDownWithSearch<String>(
        title: null,
        showName: false,
        hintText: 'Select Property',
        value: selectedProperty,
        items: propertyList,
        onChanged: onPropertyChanged,
        displayText: (property) => property,
        searchController: propertySearchController,
        height: 45,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextFilter(
          label: "Product Name",
          hint: 'Product Name',
          controller: productNameController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildFilterField(
          label: "Category",
          child: categoryField,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: "Price",
          hint: 'Price',
          controller: amountController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: "Barcode",
          hint: 'Barcode',
          controller: barcodeController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: "HSN Code",
          hint: 'HSN Code',
          controller: hsnCodeController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildPropertyDropdown(),
        Consumer<AppSettingsProvider>(
          builder: (context, appSettingsProvider, child) {
            final itemCodeEnabled =
                appSettingsProvider.appSettings?.itemCodeEnabled ?? false;
            if (!itemCodeEnabled) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _buildTextFilter(
                  label: "Item Code",
                  hint: 'Item Code',
                  controller: itemCodeController,
                  size: size,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        CustomRoundButton(
          title: "Reset Filters",
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          fct: onReset,
          height: 45,
          width: double.infinity,
          fontSize: FontSize.s12,
        ),
      ],
    );
  }
}
