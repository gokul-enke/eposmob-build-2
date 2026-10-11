import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../state/supplier_ledger_list_controller.dart';

class SupplierLedgerFilters {
  SupplierLedgerFilters(this.list);
  final SupplierLedgerListController list;
  DropdownFilterField<String> _dropdown(
    String label,
    TextEditingController controller,
    List<String> options,
    IconData icon,
    String Function(String value) optionLabel,
  ) {
    return DropdownFilterField<String>(
      label: label,
      icon: icon,
      value: controller.text,
      options: [
        for (final value in options) FilterOption(value, optionLabel(value)),
      ],
      onChanged: (value) {
        if (value == null) return;
        controller.text = value;
        list.searchTransactions();
      },
    );
  }

  /// Supplier name with suggestions; every edit searches right away.
  Widget _supplierField(SupplierLedgerListController list) =>
      RawAutocomplete<String>(
        textEditingController: list.supplierSearchController,
        focusNode: list.supplierFocus,
        optionsBuilder: (value) => value.text.isEmpty
            ? const Iterable<String>.empty()
            : list.supplierOptions.where((name) =>
                name.toLowerCase().contains(value.text.toLowerCase())),
        onSelected: (_) => list.searchTransactions(),
        fieldViewBuilder: (context, controller, focus, submit) => TextField(
          controller: controller,
          focusNode: focus,
          textAlignVertical: TextAlignVertical.center,
          style: AppTextStyles.input,
          decoration: AppInputDecoration.filter(
            label: 'supplier_transactions.supplier'.tr,
            hint: 'supplier_transactions.supplier'.tr,
            icon: Icons.local_shipping_outlined,
          ),
          onChanged: (_) => list.searchTransactions(),
          onSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, options) => Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: SizedBox(
              width: 280,
              height: 200,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) => ListTile(
                  selected: AutocompleteHighlightedOption.of(context) == index,
                  title: Text(options.elementAt(index)),
                  onTap: () => select(options.elementAt(index)),
                ),
              ),
            ),
          ),
        ),
      );

  FilterPanel build(List<String> statuses) {
    return FilterPanel(
      key: const ValueKey('supplier-transactions-filters'),
      title: 'supplier_transactions.find'.tr,
      hint: 'supplier_transactions.find_hint'.tr,
      resetLabel: 'list.reset'.tr,
      onSearch: list.search.schedule,
      onSubmit: list.search.flush,
      onReset: list.resetSearch,
      fields: [
        TextFilterField(
          controller: list.searchController,
          label: 'supplier_transactions.search'.tr,
          hint: 'supplier_transactions.hint_search'.tr,
          icon: Icons.search_rounded,
        ),
        CustomFilterField(child: _supplierField(list)),
        _dropdown(
          'supplier_transactions.trans_type'.tr,
          list.transactionTypeController,
          const ['All', 'Invoice', 'Voucher'],
          Icons.receipt_long_outlined,
          UiCodeLabels.documentKind,
        ),
        _dropdown(
          'supplier_transactions.type'.tr,
          list.typeController,
          const ['All Types', 'Credit', 'Debit'],
          Icons.swap_vert_rounded,
          UiCodeLabels.documentKind,
        ),
        _dropdown(
          'supplier_transactions.status'.tr,
          list.statusController,
          statuses,
          Icons.check_circle_outline,
          UiCodeLabels.status,
        ),
      ],
    );
  }
}
