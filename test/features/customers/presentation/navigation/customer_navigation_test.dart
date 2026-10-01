import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/navigation/customer_navigation.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';

import '../../support/fake_customer_repository.dart';

void main() {
  late SideBarController sidebar;

  setUp(() {
    sidebar = Get.put(SideBarController());
    sidebar.index.value = 0;
  });

  tearDown(() => Get.delete<SideBarController>(force: true));

  test('openList and openAddPage switch the sidebar screen', () {
    CustomerNavigation.openAddPage();
    expect(sidebar.index.value, SideBarController.addCustomerScreenIndex);

    CustomerNavigation.openList();
    expect(sidebar.index.value, SideBarController.customersScreenIndex);
  });

  test('openProfile selects the customer before showing the profile', () {
    final provider = CustomerProvider(repository: FakeCustomerRepository());
    final customer = CustomerListModelData(id: 7, name: 'Ann');

    CustomerNavigation.openProfile(provider, customer);

    expect(provider.getSelectedCustomer, customer);
    expect(sidebar.index.value, SideBarController.customerProfileScreenIndex);
  });

  test('every customer screen counts as the customers section', () {
    for (final index in CustomerNavigation.sectionIndices) {
      sidebar.index.value = index;
      expect(CustomerNavigation.isInCustomersSection, isTrue);
    }
    sidebar.index.value = SideBarController.billingScreenIndex;
    expect(CustomerNavigation.isInCustomersSection, isFalse);
  });

  test('the named indices point at the customer screens', () {
    final screens = SideBarController().screens;
    expect(
      screens[SideBarController.customersScreenIndex].runtimeType.toString(),
      'CustomersListPage',
    );
    expect(
      screens[SideBarController.addCustomerScreenIndex].runtimeType.toString(),
      'AddCustomerPage',
    );
    expect(
      screens[SideBarController.customerProfileScreenIndex]
          .runtimeType
          .toString(),
      'CustomerProfilePage',
    );
  });
}
