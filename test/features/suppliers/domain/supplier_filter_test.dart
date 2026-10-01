import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/features/suppliers/domain/supplier_filter.dart';

import '../support/supplier_fixtures.dart';

void main() {
  final acme = supplier(
    id: 1,
    name: 'Acme Corp',
    email: 'Sales@Acme.test',
    phone: '555-01',
    balance: 20,
  );
  final bolt = supplier(id: 2, name: 'Bolt', phone: '777', balance: -5);
  final zero = supplier(id: 3, name: 'Zero Ltd', balance: 0);
  final everyone = [acme, bolt, zero];

  List<int> ids(SupplierFilter filter) =>
      filter.apply(everyone).map((s) => s.id).toList();

  test('empty filter keeps everyone and returns a copy', () {
    final result = SupplierFilter.none.apply(everyone);
    expect(result, everyone);
    expect(identical(result, everyone), isFalse);
  });

  test('name, email and phone match case-insensitively as substrings', () {
    expect(ids(const SupplierFilter(name: 'acme')), [1]);
    expect(ids(const SupplierFilter(email: 'SALES@')), [1]);
    expect(ids(const SupplierFilter(phone: '77')), [2]);
  });

  test('balance filter uses the current balance', () {
    expect(ids(const SupplierFilter(balance: BalanceFilter.positive)), [1]);
    expect(ids(const SupplierFilter(balance: BalanceFilter.negative)), [2]);
    expect(ids(const SupplierFilter(balance: BalanceFilter.zero)), [3]);
  });

  test('criteria combine', () {
    expect(
      ids(const SupplierFilter(name: 'o', balance: BalanceFilter.negative)),
      [2],
    );
  });

  test('copyWith and value equality', () {
    const base = SupplierFilter(name: 'a');
    expect(
      base.copyWith(phone: '1'),
      const SupplierFilter(name: 'a', phone: '1'),
    );
    expect(base.copyWith().hashCode, base.hashCode);
    expect(SupplierFilter.none.isEmpty, isTrue);
    expect(base.isEmpty, isFalse);
  });
}
