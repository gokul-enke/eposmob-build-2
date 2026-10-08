import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/category_list_entry.dart';

Future<File> exportCategoryList(List<CategoryListEntry> entries,
    {Directory? outputDirectory}) async {
  final snapshot = List<CategoryListEntry>.unmodifiable(entries);
  final ids = <int>{};
  for (final entry in snapshot) {
    if (entry.id != null && !ids.add(entry.id!)) {
      throw StateError('Category export contains a repeated category ID');
    }
  }
  return ListExcelExportService.export<CategoryListEntry>(
      items: snapshot,
      fileNamePrefix: 'categories',
      sheetName: 'category.title'.tr,
      outputDirectory: outputDirectory,
      columns: [
        ListExportColumn(
            label: 'category.col_no'.tr, value: (_, index) => index + 1),
        ListExportColumn(
            label: 'category.col_name'.tr, value: (entry, _) => entry.name),
        ListExportColumn(
            label: 'category.col_slug'.tr, value: (entry, _) => entry.slug),
      ]);
}
