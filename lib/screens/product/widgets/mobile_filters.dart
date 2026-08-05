import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      label: 'product.property'.tr,
      child: BuildDropDownWithSearch<String>(
        title: null,
        showName: false,
        hintText: 'product.select_property'.tr,
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
          label: 'product.product_name'.tr,
          hint: 'product.product_name'.tr,
          controller: productNameController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildFilterField(
          label: 'product.category'.tr,
          child: categoryField,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: 'product.price'.tr,
          hint: 'product.price'.tr,
          controller: amountController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: 'product.barcode'.tr,
          hint: 'product.barcode'.tr,
          controller: barcodeController,
          size: size,
        ),
        const SizedBox(height: 12),
        _buildTextFilter(
          label: 'product.hsn_code'.tr,
          hint: 'product.hsn_code'.tr,
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
                  label: 'product.item_code'.tr,
                  hint: 'product.item_code'.tr,
                  controller: itemCodeController,
                  size: size,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        CustomRoundButton(
          title: 'product.reset_filters'.tr,
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
