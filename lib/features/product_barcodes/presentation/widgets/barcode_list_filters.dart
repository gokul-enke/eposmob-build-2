import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../domain/barcode_list_query.dart';

FilterPanel barcodeListFilters({
  required TextEditingController name,
  required TextEditingController barcode,
  required List<BarcodeCategory> categories,
  required int? categoryId,
  required bool loading,
  required VoidCallback onSearch,
  required VoidCallback onSubmit,
  required VoidCallback onReset,
  required ValueChanged<int?> onCategory,
}) =>
    FilterPanel(
      title: 'product_barcode.filters_title'.tr,
      hint: 'product_barcode.filters_hint'.tr,
      resetLabel: 'product_barcode.reset'.tr,
      onSearch: onSearch,
      onSubmit: onSubmit,
      onReset: onReset,
      fields: [
        CustomFilterField(
            child: DropdownSearch<int>(
          enabled: !loading,
          selectedItem: categoryId ?? 0,
          items: (filter, loadProps) => [
            0,
            ...categories
                .map((category) => category.id)
                .whereType<int>()
                .where((id) => id != 0)
          ],
          itemAsString: (id) => id == 0
              ? 'product_barcode.all_categories'.tr
              : categories.firstWhere((category) => category.id == id).name,
          decoratorProps: DropDownDecoratorProps(
              decoration: AppInputDecoration.filter(
                  label: 'product_barcode.category'.tr,
                  hint: 'product_barcode.all_categories'.tr,
                  icon: Icons.category_outlined)),
          popupProps: PopupProps.menu(
              showSearchBox: true,
              constraints: const BoxConstraints(maxHeight: 320),
              menuProps: const MenuProps(backgroundColor: AppColors.surface),
              searchFieldProps: TextFieldProps(
                  decoration: AppInputDecoration.filter(
                      label: 'product_barcode.search_category'.tr,
                      hint: 'product_barcode.search_category'.tr,
                      icon: Icons.search))),
          onChanged: (id) => onCategory(id == 0 ? null : id),
        )),
        TextFilterField(
            controller: name,
            label: 'product_barcode.product_name'.tr,
            hint: 'product_barcode.product_name'.tr,
            icon: Icons.search),
        TextFilterField(
            controller: barcode,
            label: 'product_barcode.barcode'.tr,
            hint: 'product_barcode.barcode'.tr,
            icon: Icons.qr_code_rounded),
      ],
    );
