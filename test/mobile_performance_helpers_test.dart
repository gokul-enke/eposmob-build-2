import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  const controller = BillingMobileMarketController();

  GetProduct buildProduct(int id) {
    return GetProduct(
      productId: id,
      productName: 'Product $id',
      category: ProductCategory(name: id.isEven ? 'Snacks' : 'Drinks'),
      price: ProductPrice(price: '10'),
      mrp: '10',
      purchasePrice: '5',
      unit: 'PCS',
      stock: const <Stock>[],
      taxes: const <ProductTax>[],
    );
  }

  group('BillingMobileMarketController performance', () {
    test('visibleProducts completes under 100ms for 1000 products', () {
      final products = List.generate(1000, buildProduct);

      final stopwatch = Stopwatch()..start();
      final result = controller.visibleProducts(
        products: products,
        query: 'product 5',
        selectedCategory: BillingMobileMarketController.allProductsCategory,
      );
      stopwatch.stop();

      expect(result, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('visibleProducts category filter stays fast for 1000 products', () {
      final products = List.generate(1000, buildProduct);

      final stopwatch = Stopwatch()..start();
      final result = controller.visibleProducts(
        products: products,
        query: '',
        selectedCategory: 'Snacks',
      );
      stopwatch.stop();

      expect(result.length, 500);
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
