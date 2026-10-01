import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/features/customers/domain/customer_filter.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_list_controller.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';

import '../../support/fake_customer_repository.dart';

void main() {
  late CustomerProvider provider;

  setUp(() async {
    provider = CustomerProvider(
      repository: FakeCustomerRepository(numberedCustomers(30)),
    );
    await provider.loadAllCustomers('t');
  });

  test('starts from the filter the provider already applies', () {
    provider.applyFilter(const CustomerFilter(
      name: 'Ann',
      phone: '55',
      balance: BalanceFilter.zero,
    ));

    final controller = CustomerListController(provider);
    addTearDown(controller.dispose);

    expect(controller.nameController.text, 'Ann');
    expect(controller.phoneController.text, '55');
    expect(controller.emailController.text, isEmpty);
    expect(controller.balance, BalanceFilter.zero);
  });

  // testWidgets runs on a fake clock, so the debounce timer is driven by pump.
  testWidgets('typing is debounced into a single search', (tester) async {
    {
      final controller = CustomerListController(provider,
          debounce: const Duration(milliseconds: 300));
      var notifications = 0;
      provider.addListener(() => notifications++);

      controller.nameController.text = 'Customer 1';
      controller.scheduleSearch();
      await tester.pump(const Duration(milliseconds: 200));
      controller.nameController.text = 'Customer 2';
      controller.scheduleSearch();
      await tester.pump(const Duration(milliseconds: 299));
      expect(notifications, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(notifications, 1);
      expect(provider.filter.name, 'Customer 2');
      controller.dispose();
    }
  });

  testWidgets('search applies immediately and cancels a pending debounce',
      (tester) async {
    {
      final controller = CustomerListController(provider);
      var notifications = 0;
      provider.addListener(() => notifications++);

      controller.emailController.text = 'x';
      controller.scheduleSearch();
      controller.search();
      await tester.pump(const Duration(seconds: 1));

      expect(notifications, 1);
      expect(provider.filter.email, 'x');
      controller.dispose();
    }
  });

  test('setBalance searches at once and notifies the page', () {
    final controller = CustomerListController(provider);
    addTearDown(controller.dispose);
    var pageNotifications = 0;
    controller.addListener(() => pageNotifications++);

    controller.setBalance(BalanceFilter.positive);

    expect(controller.balance, BalanceFilter.positive);
    expect(provider.filter.balance, BalanceFilter.positive);
    expect(pageNotifications, 1);

    controller.setBalance(null);
    expect(controller.balance, BalanceFilter.all);
  });

  test('reset clears the inputs and the provider filter', () {
    final controller = CustomerListController(provider);
    addTearDown(controller.dispose);
    controller.nameController.text = 'abc';
    controller.setBalance(BalanceFilter.negative);

    controller.reset();

    expect(controller.nameController.text, isEmpty);
    expect(controller.balance, BalanceFilter.all);
    expect(provider.filter, CustomerFilter.none);
    expect(provider.getCustomerList, hasLength(20));
  });

  test('filters start visible and toggle without touching the filter', () {
    final controller = CustomerListController(provider);
    addTearDown(controller.dispose);
    provider.applyFilter(const CustomerFilter(name: 'Customer 1'));

    expect(controller.filtersVisible, isTrue);
    controller.toggleFilters();
    expect(controller.filtersVisible, isFalse);
    expect(controller.hasActiveFilter, isTrue);
    expect(provider.filter.name, 'Customer 1');
  });

  test('export sends every filtered customer across pages', () async {
    List<CustomerListModelData>? exported;
    final controller = CustomerListController(
      provider,
      exporter: (customers) async => exported = customers,
    );
    addTearDown(controller.dispose);
    provider.applyFilter(const CustomerFilter(balance: BalanceFilter.positive));

    expect(await controller.export(), isTrue);

    expect(exported, hasLength(15));
    expect(exported!.every((c) => c.balance! > 0), isTrue);
    expect(controller.isExporting, isFalse);
  });

  test('export is busy while running and reports failures', () async {
    final busyStates = <bool>[];
    final controller = CustomerListController(
      provider,
      exporter: (_) async => throw StateError('disk full'),
    );
    addTearDown(controller.dispose);
    controller.addListener(() => busyStates.add(controller.isExporting));

    expect(await controller.export(), isFalse);
    expect(busyStates, [true, false]);
  });

  test('export is unavailable when nothing matches', () {
    final controller = CustomerListController(provider);
    addTearDown(controller.dispose);
    provider.applyFilter(const CustomerFilter(name: 'nobody'));
    expect(controller.canExport, isFalse);
  });
}
