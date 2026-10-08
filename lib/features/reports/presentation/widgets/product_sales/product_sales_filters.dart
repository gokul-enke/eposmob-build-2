import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/product_sales_query.dart';

/// Filter leaf widgets receive only data and callbacks; no provider access.
class ProductSalesFilters extends StatelessWidget {
  const ProductSalesFilters(
      {super.key,
      required this.categories,
      required this.products,
      required this.customers,
      required this.category,
      required this.product,
      required this.customer,
      required this.from,
      required this.to,
      required this.onCategory,
      required this.onProduct,
      required this.onCustomer,
      required this.onDate,
      required this.onReset,
      this.resetRevision = 0});
  final List<ProductSalesOption> categories, products, customers;
  final ProductSalesOption? category, product, customer;
  final DateTime? from, to;
  final ValueChanged<ProductSalesOption?> onCategory, onProduct, onCustomer;
  final void Function(DateTime? value, bool from) onDate;
  final VoidCallback onReset;
  final int resetRevision;
  String _tr(String key) => 'product_sales_report.$key'.tr;

  Widget _picker(
          String name,
          List<ProductSalesOption> items,
          ProductSalesOption? value,
          ValueChanged<ProductSalesOption?> changed,
          String hint) =>
      _ProductSalesPicker(
          key: ValueKey('product-sales-$name-picker'),
          label: _tr('filter_$name'),
          hint: hint,
          items: items,
          value: value,
          resetRevision: resetRevision,
          onChanged: changed);

  Widget _date(
          BuildContext context, String name, DateTime? value, bool start) =>
      InkWell(
        key: ValueKey('product-sales-report-$name-filter'),
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () async {
          final picked = await showAutoDismissDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          if (picked != null && context.mounted) onDate(picked, start);
        },
        child: InputDecorator(
            decoration: AppInputDecoration.filter(
                label: _tr('filter_$name'),
                icon: Icons.calendar_today_outlined),
            child: Text(
                value == null
                    ? _tr('select_date')
                    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
                style: value == null
                    ? AppTextStyles.input.copyWith(color: AppColors.hint)
                    : AppTextStyles.input)),
      );

  @override
  Widget build(BuildContext context) => FilterPanel(
          title: _tr('find'),
          hint: _tr('filter_hint'),
          resetLabel: 'list.reset'.tr,
          onSearch: () {},
          onReset: onReset,
          fields: [
            CustomFilterField(
                child: _picker(
                    'category', categories, category, onCategory, _tr('all'))),
            CustomFilterField(
                child: _picker(
                    'product', products, product, onProduct, _tr('all'))),
            CustomFilterField(child: _date(context, 'from', from, true)),
            CustomFilterField(child: _date(context, 'to', to, false)),
            CustomFilterField(
                child: _picker('customer', customers, customer, onCustomer,
                    _tr('select_customer'))),
          ]);
}

/// Searchable filter styled with the shared input decoration and menu tokens.
/// DropdownMenu does not own a Navigator popup route, so selection/Reset cannot
/// dispose a closing route and accidentally pop the report itself.
class _ProductSalesPicker extends StatelessWidget {
  const _ProductSalesPicker(
      {super.key,
      required this.label,
      required this.hint,
      required this.items,
      required this.value,
      required this.resetRevision,
      required this.onChanged});
  final String label, hint;
  final List<ProductSalesOption> items;
  final ProductSalesOption? value;
  final int resetRevision;
  final ValueChanged<ProductSalesOption?> onChanged;
  @override
  Widget build(BuildContext context) {
    // ID lookup keeps a directory refresh from losing its selected label.
    final choices = items.where((i) => i.id != value?.id).toList();
    if (value != null) choices.insert(0, value!);
    final all = ProductSalesOption(id: '', label: hint);
    return DropdownMenuTheme(
        data: DropdownMenuThemeData(
            menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(AppColors.surface),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control))),
        )),
        child: DropdownMenu<ProductSalesOption>(
          // Reset also clears uncommitted search text when selection stays null.
          key: ValueKey((value?.id, resetRevision)),
          initialSelection: value,
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          textStyle: AppTextStyles.input,
          hintText: hint,
          inputDecorationTheme: InputDecorationThemeData(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              isDense: true,
              labelStyle: AppTextStyles.label,
              hintStyle: AppTextStyles.input.copyWith(color: AppColors.hint),
              filled: true,
              fillColor: AppColors.surface,
              constraints:
                  const BoxConstraints.tightFor(height: AppSizes.control),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              border: AppInputDecoration.filter().border,
              enabledBorder: AppInputDecoration.filter().enabledBorder,
              focusedBorder: AppInputDecoration.filter().focusedBorder),
          label: Text(label),
          onSelected: (selected) => onChanged(
              selected == null || selected.id.isEmpty ? null : selected),
          dropdownMenuEntries: [
            DropdownMenuEntry(
                value: all,
                label: hint,
                style: ButtonStyle(
                    foregroundColor:
                        const WidgetStatePropertyAll(AppColors.body),
                    backgroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused)
                            ? AppColors.softBlue
                            : AppColors.surface))),
            for (final item in choices)
              DropdownMenuEntry(
                  value: item,
                  label: item.label,
                  style: ButtonStyle(
                      foregroundColor:
                          const WidgetStatePropertyAll(AppColors.body),
                      backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)
                              ? AppColors.softBlue
                              : AppColors.surface)))
          ],
        ));
  }
}
