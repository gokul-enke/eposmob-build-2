import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/data/customer_repository.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/features/customers/domain/customer_filter.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';

import '../../support/fake_customer_repository.dart';

void main() {
  late FakeCustomerRepository repository;
  late CustomerProvider provider;

  setUp(() {
    repository = FakeCustomerRepository(numberedCustomers(45));
    provider = CustomerProvider(repository: repository);
  });

  List<int?> pageIds() =>
      provider.getCustomerList!.map((customer) => customer.id).toList();

  group('loading', () {
    test('loadAllCustomers fetches the directory and shows page 1', () async {
      await provider.loadAllCustomers('t');

      expect(repository.queries.single.loadAll, isTrue);
      expect(provider.allCustomers, hasLength(45));
      expect(pageIds().first, 1);
      expect(provider.getCustomerList, hasLength(20));
      expect(provider.totalPages, 3);
      expect(provider.isLoading, isFalse);
    });

    test('isLoading is true while the request runs', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));
      await provider.loadAllCustomers('t');
      expect(states.first, isTrue);
      expect(states.last, isFalse);
    });

    test('a single server page replaces only the visible list', () async {
      repository.nextResult = CustomerPageLoaded(
        customers: [CustomerListModelData(id: 99)],
        response: const {'status': 'success'},
      );
      final response = await provider.listCustomer(accessToken: 't', page: 2);

      expect(response, {'status': 'success'});
      expect(pageIds(), [99]);
      expect(provider.allCustomers, isEmpty);
    });

    test('a failure keeps the state and returns the error map', () async {
      await provider.loadAllCustomers('t');
      repository.nextResult = const CustomerListFailed('Error: offline');

      final response =
          await provider.listCustomer(accessToken: 't', loadAll: true);

      expect(response, {'status': 'error', 'message': 'Error: offline'});
      expect(provider.allCustomers, hasLength(45));
    });

    test('reloading keeps the current filter and page', () async {
      await provider.loadAllCustomers('t');
      provider
          .applyFilter(const CustomerFilter(balance: BalanceFilter.positive));
      provider.goToPage(2);

      await provider.loadAllCustomers('t');

      expect(provider.filter.balance, BalanceFilter.positive);
      expect(provider.currentPage, 2);
    });
  });

  group('filtering and paging', () {
    setUp(() => provider.loadAllCustomers('t'));

    test('applyFilter filters, pages and remembers the filter', () {
      provider
          .applyFilter(const CustomerFilter(balance: BalanceFilter.negative));

      expect(provider.filter.balance, BalanceFilter.negative);
      expect(provider.getCustomerList!.every((c) => c.balance! < 0), isTrue);
      expect(provider.totalPages, 2);
      expect(provider.currentPage, 1);
    });

    test('legacy applyFiltersLocally maps the balance strings', () {
      provider.applyFiltersLocally(
          filterBalance: 'Positive (+ve)', filterName: '1');

      expect(provider.filter,
          const CustomerFilter(name: '1', balance: BalanceFilter.positive));
      expect(provider.getCustomerList!.every((c) => c.balance! > 0), isTrue);
    });

    test('goToPage moves within range and ignores out-of-range pages', () {
      provider.goToPage(3);
      expect(pageIds(), [41, 42, 43, 44, 45]);

      provider.goToPage(4);
      provider.goToPage(0);
      expect(provider.currentPage, 3);
    });

    test('goToPage keeps the filter', () {
      provider.applyFilter(const CustomerFilter(name: 'Customer 1'));
      provider.goToPage(1);
      expect(
          provider.getCustomerList!
              .every((c) => c.name!.contains('Customer 1')),
          isTrue);
    });

    test('resetFilters shows everyone from page 1', () {
      provider.applyFilter(const CustomerFilter(name: 'zzz'));
      expect(provider.getCustomerList, isEmpty);

      provider.resetFilters();

      expect(provider.filter, CustomerFilter.none);
      expect(provider.getCustomerList, hasLength(20));
    });
  });

  test('applyFilter on an empty directory shows an empty first page', () {
    provider.applyFilter(const CustomerFilter(name: 'a'));
    expect(provider.getCustomerList, isEmpty);
    expect(provider.totalPages, 1);
    expect(provider.filter, CustomerFilter.none);
  });

  group('selection and realtime sync', () {
    setUp(() => provider.loadAllCustomers('t'));

    test('selectCustomer fills the report bindings', () {
      provider.selectCustomer(provider.allCustomers![4]);
      expect(provider.getSelectedCustomer!.id, 5);
      expect(provider.selectedCustomerId, '5');
      expect(provider.selectedCustomerName, 'Customer 5');
    });

    test('merge upserts, deletes, refreshes the selection and caches',
        () async {
      provider.selectCustomer(provider.allCustomers![1]);

      await provider.mergeRealtimeCustomers(
        [
          CustomerListModelData(id: 2, name: 'Renamed'),
          CustomerListModelData(id: 100, name: 'New'),
        ],
        storeId: 1,
        deletedCustomerIds: {1},
      );

      final ids = provider.allCustomers!.map((c) => c.id).toList();
      expect(ids.contains(1), isFalse);
      expect(ids.last, 100);
      expect(provider.getSelectedCustomer!.name, 'Renamed');
      expect(repository.savedToCache.single, hasLength(45));
    });

    test('a deleted selected customer is deselected', () async {
      provider.selectCustomer(provider.allCustomers![0]);
      await provider.mergeRealtimeCustomers(
        const [],
        storeId: 1,
        deletedCustomerIds: {1},
      );
      expect(provider.getSelectedCustomer, isNull);
      expect(provider.selectedCustomerId, isNull);
    });

    test('clearCachedCustomers wipes the directory and filter', () async {
      provider.applyFilter(const CustomerFilter(name: 'Customer'));
      provider.selectCustomer(provider.allCustomers!.first);

      await provider.clearCachedCustomers();

      expect(repository.cacheCleared, isTrue);
      expect(provider.allCustomers, isEmpty);
      expect(provider.getSelectedCustomer, isNull);
      expect(provider.filter, CustomerFilter.none);
    });
  });
}
