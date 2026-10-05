import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

class SupplierVoucherFilters {
  SupplierVoucherFilters(
      {required this.voucherNumberController,
      required this.selectedType,
      required this.selectedStatus,
      required this.typeOptions,
      required this.statusOptions,
      required this.onSearch,
      required this.onSubmit,
      required this.onReset,
      required this.onType,
      required this.onStatus,
      required this.selectedSupplierId,
      required this.suppliers,
      required this.onSupplier});
  final TextEditingController voucherNumberController;
  final String? selectedType, selectedStatus;
  final List<String> typeOptions, statusOptions;
  final VoidCallback onSearch, onSubmit, onReset;
  final ValueChanged<String?> onType, onStatus;
  final int? selectedSupplierId;
  final Map<int, String> suppliers;
  final ValueChanged<int?> onSupplier;

  /// Supplier picker with search; picking one searches right away.
  Widget _supplierPicker(Map<int, String> suppliers) => DropdownSearch<int>(
        key: ValueKey(selectedSupplierId),
        selectedItem:
            suppliers.containsKey(selectedSupplierId) ? selectedSupplierId : 0,
        items: (_, __) => [0, ...suppliers.keys],
        itemAsString: (id) => id == 0
            ? 'supplier_voucher.all_suppliers_hint'.tr
            : suppliers[id] ?? '',
        decoratorProps: DropDownDecoratorProps(
          decoration: AppInputDecoration.filter(
            label: 'supplier_voucher.col_supplier_name'.tr,
            icon: Icons.local_shipping_outlined,
          ),
        ),
        dropdownBuilder: (_, id) => Text(
          id == null || id == 0
              ? 'supplier_voucher.all_suppliers_hint'.tr
              : suppliers[id] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.input,
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: AppInputDecoration.of(
              label: 'general.search'.tr,
              icon: Icons.search,
            ),
          ),
        ),
        onChanged: (value) => onSupplier(value == 0 ? null : value),
      );

  FilterPanel build() {
    return FilterPanel(
      key: const ValueKey('supplier-voucher-desktop-filters'),
      title: 'supplier_voucher.find'.tr,
      hint: 'supplier_voucher.filter_hint'.tr,
      resetLabel: 'list.reset'.tr,
      onSearch: onSearch,
      onSubmit: onSubmit,
      onReset: onReset,
      fields: [
        CustomFilterField(child: _supplierPicker(suppliers)),
        TextFilterField(
          controller: voucherNumberController,
          label: 'supplier_voucher.voucher_no_hint'.tr,
          hint: 'supplier_voucher.voucher_no_hint'.tr,
          icon: Icons.receipt_long_outlined,
        ),
        DropdownFilterField<String?>(
          label: 'supplier_voucher.col_type'.tr,
          icon: Icons.swap_vert,
          value: selectedType,
          options: [
            FilterOption(null, 'supplier_voucher.hint_all_types'.tr),
            for (final type in typeOptions.where((v) => v != 'All Types'))
              FilterOption(type, UiCodeLabels.voucherType(type)),
          ],
          onChanged: onType,
        ),
        DropdownFilterField<String?>(
          label: 'supplier_voucher.col_status'.tr,
          icon: Icons.check_circle_outline,
          value: selectedStatus,
          options: [
            FilterOption(null, 'supplier_voucher.hint_all_status'.tr),
            for (final status in statusOptions.where((v) => v != 'All Status'))
              FilterOption(status, UiCodeLabels.status(status)),
          ],
          onChanged: onStatus,
        ),
      ],
    );
  }
}
