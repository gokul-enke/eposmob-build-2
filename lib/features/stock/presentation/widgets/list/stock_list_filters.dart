import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../state/stock_list_controller.dart';

FilterPanel stockListFilters(StockListController inputs) {
  CustomFilterField picker(
      {required String label,
      required String all,
      required IconData icon,
      required List<String> options,
      required TextEditingController selection,
      String Function(String)? optionLabel}) {
    String display(String value) =>
        value == all ? labelForAll(all) : (optionLabel?.call(value) ?? value);
    // Search text belongs only to the popup, never to the selected field.
    return CustomFilterField(
        child: DropdownSearch<String>(
      key: ValueKey('stock-picker-$all'),
      selectedItem: selection.text,
      items: (_, __) => options.toSet().toList(),
      itemAsString: display,
      decoratorProps: DropDownDecoratorProps(
          baseStyle: AppTextStyles.input,
          decoration: AppInputDecoration.filter(
              label: label, hint: display(all), icon: icon)),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        constraints: const BoxConstraints(maxHeight: 320),
        menuProps: const MenuProps(backgroundColor: AppColors.surface),
        searchFieldProps: TextFieldProps(
            decoration: AppInputDecoration.filter(
                label: label,
                hint: 'stock.list_search'.tr,
                icon: Icons.search)),
      ),
      onChanged: (value) {
        selection.text = value ?? all;
        inputs.search();
      },
    ));
  }

  return FilterPanel(
      key: const ValueKey('stock-desktop-filters'),
      title: 'stock.list_find'.tr,
      hint: 'stock.list_filter_hint'.tr,
      resetLabel: 'stock.list_reset'.tr,
      embeddedResetLabel: 'stock.reset_filters_btn'.tr,
      onSearch: inputs.scheduleSearch,
      onSubmit: inputs.search,
      onReset: inputs.reset,
      fields: [
        TextFilterField(
            controller: inputs.stockNameController,
            label: 'stock.stock_name'.tr,
            hint: 'stock.stock_name'.tr,
            icon: Icons.search),
        picker(
            label: 'stock.category'.tr,
            all: 'All Categories',
            icon: Icons.category_outlined,
            options: inputs.categories,
            selection: inputs.categoryController),
        TextFilterField(
            controller: inputs.barcodeController,
            label: 'stock.barcode'.tr,
            hint: 'stock.barcode'.tr,
            icon: Icons.qr_code),
        TextFilterField(
            controller: inputs.rackController,
            label: 'stock.rack_number'.tr,
            hint: 'stock.rack_number'.tr,
            icon: Icons.shelves),
        picker(
            label: 'stock.label_store'.tr,
            all: 'All Stores',
            icon: Icons.store_outlined,
            options: inputs.stores,
            selection: inputs.storeController),
        picker(
            label: 'stock.stock_status'.tr,
            all: 'All Statuses',
            icon: Icons.inventory_2_outlined,
            options: const [
              'All Statuses',
              'Out of Stock',
              'Low Stock',
              'At Reorder Level'
            ],
            selection: inputs.stockStatusController,
            optionLabel: (s) => {
                  'Out of Stock': 'stock.status_out_of_stock',
                  'Low Stock': 'stock.status_low_stock',
                  'At Reorder Level': 'stock.status_at_reorder_level'
                }[s]!
                    .tr),
      ]);
}

String labelForAll(String value) => {
      'All Categories': 'stock.list_all_categories',
      'All Stores': 'stock.list_all_stores',
      'All Statuses': 'stock.list_all_statuses'
    }[value]!
        .tr;
