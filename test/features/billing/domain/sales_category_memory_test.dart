import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/sales_category_memory.dart';

void main() {
  group('SalesCategoryMemory.resolveCategoryId', () {
    test('keeps a category that still exists', () {
      expect(SalesCategoryMemory.resolveCategoryId(7, [3, 7, 9]), 7);
    });

    test('falls back to All when the category is gone', () {
      expect(SalesCategoryMemory.resolveCategoryId(7, [3, 9]), 0);
    });

    test('All stays All', () {
      expect(SalesCategoryMemory.resolveCategoryId(0, const <int>[]), 0);
    });

    test('Favourites only where the screen offers it', () {
      expect(SalesCategoryMemory.resolveCategoryId(-1, [3]), 0);
      expect(
        SalesCategoryMemory.resolveCategoryId(-1, [3], allowFavourites: true),
        -1,
      );
    });
  });
}
