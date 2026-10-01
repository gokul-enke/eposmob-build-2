import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/features/suppliers/data/supplier_api.dart';
import 'package:pos_machine/features/suppliers/domain/supplier_filter.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';

import '../../support/supplier_fixtures.dart';

void main() {
  late FakeSupplierRepository repository;
  late SupplierProvider provider;

  setUp(() {
    repository = FakeSupplierRepository(numberedSuppliers(45));
    provider = SupplierProvider(repository: repository);
  });

  test('fetch loads everyone and shows page 1', () async {
    final page = await provider.fetchSuppliers(accessToken: 't');
    expect(page, hasLength(20));
    expect(provider.allSuppliers, hasLength(45));
    expect(provider.filteredSuppliers, hasLength(45));
    expect(provider.totalPages, 3);
    expect(provider.isLoading, isFalse);
  });

  test('a reload keeps every filter and the page', () async {
    await provider.fetchSuppliers(accessToken: 't');
    provider.applyFilter(const SupplierFilter(
      email: 'test.com',
      balance: BalanceFilter.positive,
    ));
    provider.goToPage(2);

    await provider.fetchSuppliers(accessToken: 't');

    expect(provider.filter.email, 'test.com');
    expect(provider.filter.balance, BalanceFilter.positive);
    expect(provider.currentPage, 2);
  });

  test('a missing API key rethrows and still clears the spinner', () async {
    repository.fetchError =
        const HttpException(SupplierApi.missingApiKeyMessage);
    await expectLater(
      provider.fetchSuppliers(accessToken: 't'),
      throwsA(isA<HttpException>()),
    );
    expect(provider.isLoading, isFalse);
  });

  test('other failures return an empty page and clear the spinner', () async {
    repository.fetchError = const SocketException('offline');
    expect(await provider.fetchSuppliers(accessToken: 't'), isEmpty);
    expect(provider.isLoading, isFalse);
  });

  test('legacy applyFiltersLocally maps strings and exposes all matches',
      () async {
    await provider.fetchSuppliers(accessToken: 't');
    provider.applyFiltersLocally(filterBalance: 'Negative (-ve)', page: 2);

    expect(provider.filter.balance, BalanceFilter.negative);
    expect(provider.filteredSuppliers, hasLength(23));
    expect(provider.supplierList, hasLength(3));
    expect(provider.hasFilteredSuppliers, isTrue);
  });

  test('goToPage ignores out-of-range pages; reset shows everyone', () async {
    await provider.fetchSuppliers(accessToken: 't');
    provider.goToPage(9);
    expect(provider.currentPage, 1);

    provider.applyFilter(const SupplierFilter(name: 'zzz'));
    expect(provider.supplierList, isEmpty);
    provider.resetFilters();
    expect(provider.filter, SupplierFilter.none);
    expect(provider.supplierList, hasLength(20));
  });

  test('loading transactions does not touch the list spinner', () async {
    final states = <bool>[];
    provider.addListener(() => states.add(provider.isLoading));
    await provider.fetchSupplierTransactions(
      accessToken: 't',
      supplierId: '4',
    );
    expect(states, isEmpty);
    expect(repository.transactionQueries.single['supplierId'], '4');
  });

  test('add and update reload the directory only on success', () async {
    await provider.addSupplier(
      name: 'New',
      email: '',
      phone: '1',
      accessToken: 't',
      balance: '0',
      paymentStatus: 'to_pay',
      address: '',
      altPhone: '',
    );
    expect(repository.fetches, 1);

    repository.mutationResponse = {'status': 'error', 'message': 'x'};
    final response = await provider.updateSupplier(
      id: 1,
      name: 'A',
      phone: '1',
      accessToken: 't',
      balance: 0,
    );
    expect(response['status'], 'error');
    expect(repository.fetches, 1);
  });

  test('selection and report bindings', () {
    final acme = supplier(id: 7, name: 'Acme');
    provider.selectSupplier(acme);
    provider.setSelectedSupplierId('7');
    provider.setSelectedSupplierName('Acme');
    expect(provider.selectedSupplier, acme);
    expect(provider.selectedSupplierId, '7');

    provider.clearSelectedSupplier();
    provider.clearSelectedSupplierId();
    provider.clearSelectedSupplierName();
    expect(provider.selectedSupplier, isNull);
    expect(provider.selectedSupplierName, isNull);
  });

  test('clearCachedSuppliers empties everything', () async {
    await provider.fetchSuppliers(accessToken: 't');
    provider.clearCachedSuppliers();
    expect(provider.allSuppliers, isEmpty);
    expect(provider.filteredSuppliers, isEmpty);
    expect(provider.filter, SupplierFilter.none);
  });
}
