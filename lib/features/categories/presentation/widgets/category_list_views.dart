import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../domain/category_list_entry.dart';

List<TableColumnDef<CategoryListEntry>> categoryListColumns(
        {required ValueChanged<CategoryListEntry> onEdit,
        required bool enabled}) =>
    [
      TableColumnDef(
          label: 'category.col_no'.tr,
          flex: .4,
          cellBuilder: (_, number) => TableCells.number(number)),
      TableColumnDef(
          label: 'category.col_name'.tr,
          flex: 2,
          cellBuilder: (entry, _) => TableCells.text(entry.name ?? '')),
      TableColumnDef(
          label: 'category.col_slug'.tr,
          flex: 2,
          cellBuilder: (entry, _) => TableCells.text(entry.slug ?? '')),
      TableColumnDef(
          label: 'category.action'.tr,
          flex: .5,
          cellBuilder: (entry, _) => TableCells.widget(AppSquareIconButton(
              tooltip: 'category.edit_title'.tr,
              icon: Icons.edit_outlined,
              size: AppSizes.compactControl,
              foreground: AppColors.primary,
              onPressed: enabled ? () => onEdit(entry) : null))),
    ];

class CategoryListCard extends StatelessWidget {
  const CategoryListCard(
      {super.key, required this.entry, required this.onEdit});
  final CategoryListEntry entry;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => AppListCard(
      title: entry.name ?? '',
      subtitle: entry.slug ?? '',
      trailing: AppSquareIconButton(
          tooltip: 'category.edit_title'.tr,
          icon: Icons.edit_outlined,
          size: AppSizes.compactControl,
          foreground: AppColors.primary,
          onPressed: onEdit));
}

FilterPanel categoryListFilters(
        {required TextEditingController search,
        required VoidCallback onSearch,
        required VoidCallback onSubmit,
        required VoidCallback onReset}) =>
    FilterPanel(
        title: 'category.filters_title'.tr,
        hint: 'category.filters_hint'.tr,
        resetLabel: 'general.reset'.tr,
        onSearch: onSearch,
        onSubmit: onSubmit,
        onReset: onReset,
        fields: [
          TextFilterField(
              controller: search,
              label: 'category.search_label'.tr,
              hint: 'category.search_hint'.tr,
              icon: Icons.search)
        ]);
