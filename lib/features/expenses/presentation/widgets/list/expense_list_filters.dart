import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

class ExpenseListFilters extends StatelessWidget {
  const ExpenseListFilters(
      {super.key,
      required this.reference,
      required this.filterCategory,
      required this.filterDebitAccount,
      required this.filterStatus,
      required this.categoryOptions,
      required this.debitAccountOptions,
      required this.availableStatuses,
      required this.setCategory,
      required this.setDebitAccount,
      required this.setStatus,
      required this.onSearch,
      required this.onSubmit,
      required this.onReset});
  final TextEditingController reference;
  final String filterCategory, filterDebitAccount, filterStatus;
  final List<Map<String, dynamic>> categoryOptions, debitAccountOptions;
  final List<String> availableStatuses;
  final ValueChanged<String> setCategory, setDebitAccount, setStatus;
  final VoidCallback onSearch, onSubmit, onReset;

  /// Options with "All" first; the current selection is always present.
  static List<String> _options(String selected, Iterable<String> values) =>
      <String>{'All', ...values.where((v) => v.trim().isNotEmpty), selected}
          .toList();

  static String _display(String value) =>
      value == 'All' ? 'common.all'.tr : value;

  /// Category / debit account picker with a search box.
  FilterFieldDef _searchableDropdown(
      String label,
      IconData icon,
      String selected,
      Iterable<String> values,
      ValueChanged<String> onChanged) {
    return CustomFilterField(
      child: DropdownSearch<String>(
        selectedItem: selected,
        items: (_, __) => _options(selected, values),
        itemAsString: _display,
        decoratorProps: DropDownDecoratorProps(
            decoration: AppInputDecoration.filter(label: label, icon: icon)),
        popupProps: const PopupProps.menu(showSearchBox: true),
        onChanged: (value) => onChanged(value ?? 'All'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FilterPanel(
        key: const ValueKey('expense-desktop-filters'),
        title: 'expense.find'.tr,
        hint: 'expense.filter_hint'.tr,
        resetLabel: 'list.reset'.tr,
        onSearch: onSearch,
        onSubmit: onSubmit,
        onReset: onReset,
        fields: [
          _searchableDropdown(
              'expense.category'.tr,
              Icons.category_outlined,
              filterCategory,
              categoryOptions.map((v) => v['name']?.toString() ?? ''),
              setCategory),
          TextFilterField(
              controller: reference,
              label: 'expense.hint_reference_no'.tr,
              hint: 'expense.hint_reference_no'.tr,
              icon: Icons.tag),
          _searchableDropdown(
              'expense.filter_debit_account'.tr,
              Icons.account_balance_outlined,
              filterDebitAccount,
              debitAccountOptions.map((v) => v['name']?.toString() ?? ''),
              setDebitAccount),
          DropdownFilterField<String>(
              label: 'expense.status'.tr,
              icon: Icons.check_circle_outline,
              value: filterStatus,
              options: [
                for (final value in _options(filterStatus, availableStatuses))
                  FilterOption(value, _display(value)),
              ],
              onChanged: (value) => setStatus(value ?? 'All')),
        ],
      );
}
