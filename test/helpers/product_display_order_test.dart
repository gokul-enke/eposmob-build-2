import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/product_display_order.dart';
import 'package:pos_machine/models/get_product.dart';

GetProduct _product(int id, String name, [int? sortOrder]) =>
    GetProduct(productId: id, productName: name, sortOrder: sortOrder);

List<int?> _ids(List<GetProduct> products) =>
    products.map((p) => p.productId).toList();

void main() {
  test('sort_order ascending comes before name', () {
    final sorted = sortProductsForDisplay([
      _product(1, 'asd', 46),
      _product(2, 'zeta', 1),
      _product(3, 'beta', 10),
    ]);
    expect(_ids(sorted), [2, 3, 1]);
  });

  test('products without sort_order follow ordered ones', () {
    final sorted = sortProductsForDisplay([
      _product(1, 'asd'),
      _product(2, 'Test', 46),
      _product(3, 'classic', 0),
    ]);
    expect(_ids(sorted), [3, 2, 1]);
  });

  test('equal sort_order falls back to case-insensitive name, then id', () {
    final sorted = sortProductsForDisplay([
      _product(4, 'ok', 5),
      _product(1, 'Fire Test', 5),
      _product(3, 'ok', 5),
      _product(2, 'dfsad', 5),
    ]);
    expect(_ids(sorted), [2, 1, 3, 4]);
  });

  test('order does not depend on input order', () {
    final a = [_product(1, 'b', 2), _product(2, 'a'), _product(3, 'c', 1)];
    final b = a.reversed.toList();
    expect(_ids(sortProductsForDisplay(a)), _ids(sortProductsForDisplay(b)));
  });
}
