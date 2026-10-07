import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/products/domain/product_list_query.dart';

void main() {
  test('each existing visible filter activates the query', () {
    expect(const ProductListQuery().isEmpty, isTrue);
    for (final query in [
      const ProductListQuery(name: 'a'),
      const ProductListQuery(price: '1'),
      const ProductListQuery(barcode: '1'),
      const ProductListQuery(hsn: 'a'),
      const ProductListQuery(itemCode: 'a'),
      const ProductListQuery(categoryId: 1),
      const ProductListQuery(property: 'COLOR')
    ]) {
      expect(query.isEmpty, isFalse);
    }
  });
}
