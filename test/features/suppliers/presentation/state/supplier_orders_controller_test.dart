import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_orders_controller.dart';

import '../widgets/profile/supplier_profile_test_helpers.dart';

void main() {
  group('SupplierOrdersController', () {
    test('loads every purchase and pages them locally', () async {
      final rows = [for (var i = 1; i <= 25; i++) testPurchase(i)];
      final controller = SupplierOrdersController(fetch: () async => rows);

      await controller.load();

      expect(controller.allPurchases, hasLength(25));
      expect(controller.purchases, hasLength(20));
      expect(controller.totalPages, 2);
      expect(controller.showPagination, isTrue);

      controller
        ..goToPage(0)
        ..goToPage(1)
        ..goToPage(3);
      expect(controller.currentPage, 1);

      controller.goToPage(2);
      expect(controller.currentPage, 2);
      expect(controller.purchases.map((p) => p.id), [21, 22, 23, 24, 25]);
    });

    test('an empty supplier shows no pagination', () async {
      final controller = SupplierOrdersController(fetch: () async => const []);

      await controller.load();

      expect(controller.purchases, isEmpty);
      expect(controller.showPagination, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('a failing fetch sets the error and retry recovers', () async {
      var fail = true;
      final controller = SupplierOrdersController(fetch: () async {
        if (fail) throw Exception('boom');
        return [testPurchase(1)];
      });

      await controller.load();
      expect(controller.hasError, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.purchases, isEmpty);

      fail = false;
      await controller.retry();
      expect(controller.hasError, isFalse);
      expect(controller.purchases, hasLength(1));
    });

    test('reports loading while the fetch runs', () async {
      final controller = SupplierOrdersController(fetch: () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return [testPurchase(1)];
      });

      final pending = controller.load();
      expect(controller.isLoading, isTrue);
      expect(controller.showPagination, isFalse);
      await pending;
      expect(controller.isLoading, isFalse);
    });
  });
}
