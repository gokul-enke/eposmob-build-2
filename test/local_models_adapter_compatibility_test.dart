import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/category_providers.dart';

class _MapBinaryReader implements BinaryReader {
  _MapBinaryReader(Map<int, dynamic> fields)
      : _entries = fields.entries.toList();

  final List<MapEntry<int, dynamic>> _entries;
  int _byteIndex = 0;
  int _valueIndex = 0;

  @override
  int readByte() {
    if (_byteIndex++ == 0) return _entries.length;
    return _entries[_byteIndex - 2].key;
  }

  @override
  dynamic read([int? typeId]) => _entries[_valueIndex++].value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory =
        await Directory.systemTemp.createTemp('category-cache-test-');
    Hive.init(hiveDirectory.path);
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(HiveCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(HiveParentCategoryAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('Hive adapter backward compatibility', () {
    test('legacy cart rows use defaults for fields added later', () {
      final item = HiveLocalCartItemAdapter().read(
        _MapBinaryReader({
          0: 1,
          2: 1,
          4: HiveStringValue('{}'),
        }),
      );

      expect(item.stockDeducted, 0);
      expect(item.isManualPriceOverride, isFalse);
      expect(item.warrantyEnabled, isFalse);
    });

    test('legacy products default selection state to false', () {
      final product = HiveGetProductAdapter().read(_MapBinaryReader({}));

      expect(product.isSelected, isFalse);
    });
  });

  group('category tax IDs', () {
    test('parses category tax relationships', () {
      final category = Category.fromJson({
        'id': 1,
        'name': 'Food',
        'names': <dynamic>[],
        'category_taxes': [
          {'tax_id': 4},
          {'tax_id': '7'},
        ],
      });

      expect(category.taxIds, [4, 7]);
    });

    test('falls back to a direct tax ID list', () {
      final category = Category.fromJson({
        'id': 1,
        'name': 'Food',
        'names': <dynamic>[],
        'tax_ids': [4, '7'],
      });

      expect(category.taxIds, [4, 7]);
    });
  });

  test('category cache upsert respects and removes ineligible scopes',
      () async {
    final provider = CategoryProvider();
    final category = Category(categoryId: 1, categoryName: 'Food');

    await provider.upsertCategoryInCache(category);
    expect(provider.sellableCategories, hasLength(1));
    expect(provider.purchasableCategories, hasLength(1));
    expect(provider.allCategories, hasLength(1));

    await provider.upsertCategoryInCache(
      category,
      isSellable: false,
      isPurchasable: true,
    );
    expect(provider.sellableCategories, isEmpty);
    expect(provider.purchasableCategories, hasLength(1));
    expect(provider.allCategories, hasLength(1));

    await provider.upsertCategoryInCache(
      category,
      isSellable: false,
      isPurchasable: false,
    );
    expect(provider.sellableCategories, isEmpty);
    expect(provider.purchasableCategories, isEmpty);
    expect(provider.allCategories, hasLength(1));
  });
}
