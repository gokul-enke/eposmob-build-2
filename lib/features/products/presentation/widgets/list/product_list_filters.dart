import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/category_list.dart';
import '../../state/product_list_controller.dart';

FilterPanel productListFilters(
    ProductListController controller, List<Category> categories,
    {required bool itemCodeEnabled, required bool mobile}) {
  Category? selected;
  for (final category in categories) {
    if (category.categoryId == controller.categoryId) selected = category;
  }
  TextFilterField input(
          TextEditingController text, String key, IconData icon) =>
      TextFilterField(
          controller: text, label: key.tr, hint: key.tr, icon: icon);
  return FilterPanel(
    key:
        ValueKey(mobile ? 'product-mobile-filters' : 'product-desktop-filters'),
    title: 'product_list.find'.tr,
    hint: 'product_list.filter_hint'.tr,
    resetLabel: 'list.reset'.tr,
    embeddedResetLabel: 'product.reset_filters'.tr,
    onSearch: controller.scheduleSearch,
    onSubmit: controller.search,
    onReset: controller.reset,
    fields: [
      input(controller.name, 'product.product_name', Icons.search),
      CustomFilterField(
          child: DropdownSearch<Category>(
        selectedItem: selected,
        items: (_, __) =>
            categories.where((c) => c.categoryName != 'ALL').toList(),
        compareFn: (a, b) => a.categoryId == b.categoryId,
        itemAsString: (c) => c.categoryName ?? 'product.unknown'.tr,
        decoratorProps: DropDownDecoratorProps(
            decoration: AppInputDecoration.filter(
                label: 'product.category'.tr,
                hint: 'product.please_select'.tr,
                icon: Icons.category_outlined)),
        suffixProps: const DropdownSuffixProps(
            clearButtonProps: ClearButtonProps(isVisible: true)),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          containerBuilder: (_, child) =>
              Material(color: AppColors.surface, child: child),
          menuProps: const MenuProps(backgroundColor: AppColors.surface),
          searchFieldProps: TextFieldProps(
              decoration: AppInputDecoration.filter(
                  hint: 'product.please_select'.tr, icon: Icons.search)),
        ),
        onChanged: (c) => controller.selectCategory(c?.categoryId),
      )),
      input(controller.price, 'product.price', Icons.payments_outlined),
      input(controller.barcode, 'product.barcode', Icons.qr_code),
      input(controller.hsn, 'product.hsn_code', Icons.tag_outlined),
      DropdownFilterField<String?>(
          label: 'product.property'.tr,
          hint: 'product.select_property'.tr,
          icon: Icons.tune,
          value: controller.property,
          options: [
            FilterOption(null, 'product.select_property'.tr),
            for (final option in const {
              'MANUFACTURER': 'manufacturer',
              'PRODUCT_COLOR': 'color',
              'SHIRT_SIZE': 'shirt_size',
              'SHOE_SIZE': 'shoe_size',
            }.entries)
              FilterOption(option.key, 'product_list.${option.value}'.tr)
          ],
          onChanged: controller.selectProperty),
      if (itemCodeEnabled)
        input(controller.itemCode, 'product.item_code', Icons.numbers),
    ],
  );
}
