import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/features/customers/domain/customer_filter.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';

void main() {
  final alice = CustomerListModelData(
    id: 1,
    name: 'Alice Smith',
    email: 'Alice@Example.com',
    phone: '5550001',
    balance: 25,
  );
  final bob = CustomerListModelData(
    id: 2,
    name: 'Bob',
    phone: '5550002',
    altPhone: '7770009',
    balance: -10,
  );
  final carol = CustomerListModelData(id: 3, name: 'Carol', balance: 0);
  final nobody = CustomerListModelData(id: 4);
  final everyone = [alice, bob, carol, nobody];

  List<int?> ids(CustomerFilter filter) =>
      filter.apply(everyone).map((customer) => customer.id).toList();

  test('the empty filter keeps everyone and returns a copy', () {
    final result = CustomerFilter.none.apply(everyone);
    expect(result, everyone);
    expect(identical(result, everyone), isFalse);
    expect(CustomerFilter.none.isEmpty, isTrue);
  });

  test('name and email match case-insensitively as substrings', () {
    expect(ids(const CustomerFilter(name: 'smi')), [1]);
    expect(ids(const CustomerFilter(email: 'example.COM')), [1]);
  });

  test('phone matches the main or the alternative number', () {
    expect(ids(const CustomerFilter(phone: '0002')), [2]);
    expect(ids(const CustomerFilter(phone: '7770')), [2]);
  });

  test('customers without the field never match a text filter', () {
    expect(ids(const CustomerFilter(email: 'a')), [1]);
  });

  test('balance filter combines with text filters', () {
    expect(ids(const CustomerFilter(balance: BalanceFilter.negative)), [2]);
    expect(ids(const CustomerFilter(balance: BalanceFilter.zero)), [3]);
    expect(
      ids(const CustomerFilter(name: 'b', balance: BalanceFilter.positive)),
      isEmpty,
    );
  });

  test('copyWith keeps unspecified values and equality is by value', () {
    const base = CustomerFilter(name: 'a', balance: BalanceFilter.zero);
    final changed = base.copyWith(phone: '1');
    expect(
        changed,
        const CustomerFilter(
          name: 'a',
          phone: '1',
          balance: BalanceFilter.zero,
        ));
    expect(changed.hashCode, changed.copyWith().hashCode);
    expect(changed.isEmpty, isFalse);
  });
}
