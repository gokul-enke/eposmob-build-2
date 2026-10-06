import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/product_sales_query.dart';

void main() {
  test('query compares all filters and accepts open date bounds', () {
    const query = ProductSalesQuery(
        categoryId: '88',
        productId: '9',
        customerId: '7',
        from: '2026-09-01',
        to: '2026-09-30');
    expect(query.active, isTrue);
    expect(query.valid, isTrue);
    expect(query.matches(query), isTrue);
    expect(query.matches(const ProductSalesQuery(categoryId: '99')), isFalse);
    expect(const ProductSalesQuery(from: '2026-09-01').valid, isTrue);
    expect(const ProductSalesQuery(from: '2026-09-30', to: '2026-09-01').valid,
        isFalse);
    expect(const ProductSalesQuery().active, isFalse);
  });
}
