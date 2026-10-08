import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/categories/domain/category_list_entry.dart';
import 'package:pos_machine/features/categories/presentation/export/category_list_export.dart';

void main() {
  test('duplicate IDs stop export without creating a workbook', () async {
    final dir = Directory.systemTemp.createTempSync('category-duplicate-');
    addTearDown(() => dir.deleteSync(recursive: true));
    await expectLater(
        exportCategoryList([
          CategoryListEntry(id: 7, name: 'First'),
          CategoryListEntry(id: 7, name: 'Repeated')
        ], outputDirectory: dir),
        throwsStateError);
    expect(dir.listSync(), isEmpty);
  });
  test(
      'workbook covers the full immutable snapshot with text and missing values',
      () async {
    final dir = Directory.systemTemp.createTempSync('category-export-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final translations = {'ar': 'قسم'};
    final entries = List.generate(
        45,
        (i) => CategoryListEntry(
            id: i + 1,
            name: i == 44 ? null : 'Category $i',
            slug: i == 0 ? '0000123' : 'category-$i',
            translations: translations));
    final snapshot = List<CategoryListEntry>.unmodifiable(entries);
    translations['ar'] = 'changed';
    entries.clear();
    final file = await exportCategoryList(snapshot, outputDirectory: dir);
    final rows =
        Excel.decodeBytes(file.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 46);
    expect(rows[1][2]!.value, TextCellValue('0000123'));
    expect(rows[45][0]!.value, const IntCellValue(45));
    expect(rows[45][1]?.value, isNull);
    expect(snapshot.first.translations['ar'], 'قسم');
  });
  test('all category listing keys exist in the three supported locales', () {
    for (final lang in ['en', 'ar', 'ml']) {
      final section =
          jsonDecode(File('lib/resources/i18n/$lang.json').readAsStringSync())[
              'category'] as Map;
      for (final key in [
        'list_subtitle',
        'filters',
        'filters_title',
        'filters_hint',
        'export',
        'refresh',
        'retry',
        'page_count',
        'load_failed',
        'export_failed',
        'open_failed',
        'add_short'
      ]) {
        expect(section[key], isNotEmpty, reason: '$lang category.$key');
      }
    }
    Get.reset();
  });
}
