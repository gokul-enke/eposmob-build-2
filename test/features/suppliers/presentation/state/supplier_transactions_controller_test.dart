import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_transactions_controller.dart';

import '../widgets/profile/supplier_profile_test_helpers.dart';

void main() {
  group('SupplierTransactionsController', () {
    test('loads every transaction and pages them locally', () async {
      final rows = [for (var i = 1; i <= 45; i++) testTransaction(i)];
      var calls = 0;
      final controller = SupplierTransactionsController(fetch: () async {
        calls++;
        return rows;
      });

      await controller.load();

      expect(calls, 1);
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.allTransactions, hasLength(45));
      expect(controller.transactions, hasLength(20));
      expect(controller.totalPages, 3);
      expect(controller.showPagination, isTrue);

      controller
        ..goToPage(0)
        ..goToPage(4);
      expect(controller.currentPage, 1);

      controller.goToPage(3);
      expect(controller.currentPage, 3);
      expect(controller.transactions, hasLength(5));
      expect(controller.transactions.first.id, 41);
      expect(calls, 1);
    });

    test('an empty supplier has one page and no pagination', () async {
      final controller =
          SupplierTransactionsController(fetch: () async => const []);

      await controller.load();

      expect(controller.transactions, isEmpty);
      expect(controller.totalPages, 1);
      expect(controller.showPagination, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('a failing fetch sets the error and retry recovers', () async {
      var fail = true;
      final controller = SupplierTransactionsController(fetch: () async {
        if (fail) throw Exception('boom');
        return [testTransaction(1)];
      });

      await controller.load();
      expect(controller.hasError, isTrue);
      expect(controller.transactions, isEmpty);
      expect(controller.showPagination, isFalse);

      fail = false;
      await controller.retry();
      expect(controller.hasError, isFalse);
      expect(controller.transactions, hasLength(1));
    });

    test('filters by reference, type and date range', () async {
      final controller = SupplierTransactionsController(
        fetch: () async => [
          testTransaction(1, reference: 'INV-100', date: '2026-01-05'),
          testTransaction(2,
              type: 'debit', reference: 'VCH-7', date: '2026-02-10'),
          testTransaction(3, reference: 'inv-200', date: '2026-03-15'),
        ],
      );
      await controller.load();

      controller
        ..toggleFilters()
        ..referenceController.text = 'INV';
      expect(controller.filtersVisible, isTrue);
      controller.applyFilters();
      expect(controller.filtersVisible, isFalse);
      expect(controller.transactions.map((t) => t.id), [1, 3]);

      controller
        ..toggleFilters()
        ..referenceController.clear()
        ..setDraftType(SupplierTransactionDirection.debit)
        ..applyFilters();
      expect(controller.transactions.map((t) => t.id), [2]);

      controller
        ..toggleFilters()
        ..setDraftType(SupplierTransactionDirection.credit)
        ..setDraftRange(
          DateTimeRange(start: DateTime(2026, 3), end: DateTime(2026, 3, 31)),
        )
        ..applyFilters();
      expect(controller.transactions.map((t) => t.id), [3]);
      expect(controller.filter.isEmpty, isFalse);

      controller.resetFilters();
      expect(controller.filter.isEmpty, isTrue);
      expect(controller.transactions, hasLength(3));
      expect(controller.allTransactions, hasLength(3));
    });

    test('credit detection ignores case', () {
      expect(
        SupplierTransactionsController.isCredit(testTransaction(1)),
        isTrue,
      );
      expect(
        SupplierTransactionsController.isCredit(
          testTransaction(1, type: 'credit'),
        ),
        isTrue,
      );
      expect(
        SupplierTransactionsController.isCredit(
          testTransaction(1, type: 'Debit'),
        ),
        isFalse,
      );
    });

    test('a stale load does not overwrite a newer one', () async {
      final first = <SupplierTransaction>[testTransaction(1)];
      final second = <SupplierTransaction>[
        testTransaction(2),
        testTransaction(3),
      ];
      var call = 0;
      final controller = SupplierTransactionsController(fetch: () async {
        call++;
        if (call == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return first;
        }
        return second;
      });

      final slow = controller.load();
      await controller.load();
      await slow;

      expect(controller.allTransactions, hasLength(2));
    });

    test('notifies nothing after dispose', () async {
      final controller = SupplierTransactionsController(fetch: () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return [testTransaction(1)];
      });
      final pending = controller.load();
      controller.dispose();
      await pending;
    });
  });
}
