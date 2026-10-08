import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/stock_report_query.dart';
import 'stock_report_product_picker.dart';

String _tr(String key) => 'stock_report.$key'.tr;

/// A configured shared panel, so the scaffold can embed it in the phone filter tile.
class StockReportFilters extends FilterPanel {
  StockReportFilters(
      {super.key,
      required StockReportQuery query,
      required int revision,
      required List<StockReportOption> stores,
      required List<StockReportOption> categories,
      required List<StockReportOption> products,
      required StockReportOption? store,
      required StockReportOption? category,
      required StockReportOption? product,
      required ValueChanged<StockReportOption?> onStore,
      required ValueChanged<StockReportOption?> onCategory,
      required ValueChanged<StockReportOption?> onProduct,
      required ValueChanged<StockLevel> onLevel,
      required ValueChanged<StockExpiry> onExpiry,
      required void Function(DateTime?, String) onDate,
      required super.onReset})
      : super(
            title: _tr('find'),
            hint: _tr('filter_hint'),
            resetLabel: 'list.reset'.tr,
            onSearch: _noSearch,
            fields: [
              _date('snapshot', 'view_stock_as_of', 'snapshot_hint',
                  query.snapshot, onDate),
              _picker('store', 'all_stores', stores, store, revision, onStore),
              _picker('category', 'all_categories', categories, category,
                  revision, onCategory),
              _picker('product', 'all_products', products, product, revision,
                  onProduct),
              CustomFilterField(
                  fixedHeight: false,
                  child: _menu(AppSearchDropdownField<StockLevel>(
                      key: ValueKey(('stock-level', revision)),
                      label: _tr('stock_level'),
                      value: query.stockLevel,
                      items: StockLevel.values,
                      itemLabel: (v) =>
                          _tr(v == StockLevel.all ? 'all' : 'below_reorder'),
                      onChanged: (v) {
                        if (v != null) onLevel(v);
                      }))),
              CustomFilterField(
                  fixedHeight: false,
                  child: _menu(AppSearchDropdownField<StockExpiry>(
                      key: ValueKey(('stock-expiry', revision)),
                      label: _tr('expiry_filter'),
                      value: query.expiry,
                      items: StockExpiry.values,
                      itemLabel: (v) => _tr(switch (v) {
                            StockExpiry.all => 'all',
                            StockExpiry.oneMonth => 'one_month',
                            StockExpiry.threeMonths => 'three_months',
                            StockExpiry.sixMonths => 'six_months',
                            StockExpiry.oneYear => 'one_year'
                          }),
                      onChanged: (v) {
                        if (v != null) onExpiry(v);
                      }))),
              _date('from', 'from_date', 'select_date', query.from, onDate),
              _date('until', 'until_date', 'select_date', query.until, onDate),
            ]);
  static void _noSearch() {}
  static Widget _menu(Widget child) => DropdownMenuTheme(
      data: DropdownMenuThemeData(
          menuStyle: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
              surfaceTintColor: const WidgetStatePropertyAll(AppColors.surface),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control))))),
      child: child);
  static CustomFilterField _date(String name, String label, String hint,
          DateTime? value, void Function(DateTime?, String) changed) =>
      CustomFilterField(
          fixedHeight: false,
          child: StockReportDateField(
              name: name,
              label: _tr(label),
              hint: _tr(hint),
              value: value,
              onChanged: (date) => changed(date, name)));
  static CustomFilterField _picker(
      String name,
      String all,
      List<StockReportOption> choices,
      StockReportOption? selected,
      int revision,
      ValueChanged<StockReportOption?> changed) {
    final options = <String, StockReportOption>{
      for (final option in choices) option.id: option
    };
    if (selected != null) options.putIfAbsent(selected.id, () => selected);
    if (name == 'product') {
      return CustomFilterField(
          fixedHeight: false,
          child: StockReportProductPicker(
              key: ValueKey(('stock-product', revision)),
              options: options,
              value: selected?.id,
              onChanged: changed));
    }
    return CustomFilterField(
        fixedHeight: false,
        child: _menu(AppSearchDropdownField<String>(
            key: ValueKey(('stock-$name', revision)),
            label: _tr(name),
            hint: _tr(all),
            value: selected?.id ?? '',
            items: ['', ...options.keys],
            itemLabel: (id) => id.isEmpty ? _tr(all) : options[id]!.label,
            onChanged: (id) =>
                changed(id == null || id.isEmpty ? null : options[id]))));
  }
}

class StockReportDateField extends StatelessWidget {
  const StockReportDateField(
      {super.key,
      required this.name,
      required this.label,
      required this.hint,
      required this.value,
      required this.onChanged});
  final String name, label, hint;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FieldLabel(label: label),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
                key: ValueKey('stock-date-$name'),
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: () async {
                  final date = await showAutoDismissDatePicker(
                      context: context,
                      initialDate: value ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101));
                  if (date != null && context.mounted) onChanged(date);
                },
                child: InputDecorator(
                    decoration: AppInputDecoration.filter(
                        icon: Icons.calendar_today_outlined,
                        suffix: value == null
                            ? null
                            : IconButton(
                                key: ValueKey('stock-clear-$name'),
                                tooltip: 'list.reset'.tr,
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => onChanged(null))),
                    child: Text(
                        value == null
                            ? hint
                            : DateFormat('yyyy-MM-dd').format(value!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: value == null
                            ? AppTextStyles.caption
                            : AppTextStyles.input))),
          ]);
}
