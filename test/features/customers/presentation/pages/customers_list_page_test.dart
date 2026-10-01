import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/domain/balance_filter.dart';
import 'package:pos_machine/features/customers/domain/customer_filter.dart';
import 'package:pos_machine/features/customers/presentation/pages/customers_list_page.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_list_controller.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../../support/fake_customer_repository.dart';

void main() {
  late FakeCustomerRepository repository;
  late CustomerProvider provider;
  late SideBarController sidebar;

  setUp(() {
    repository = FakeCustomerRepository(numberedCustomers(25));
    provider = CustomerProvider(repository: repository);
    sidebar = Get.put(SideBarController());
    sidebar.index.value = SideBarController.customersScreenIndex;
  });

  tearDown(() => Get.delete<SideBarController>(force: true));

  Future<void> pumpPage(WidgetTester tester, Size size,
      {String? token = 'token', CustomerExporter? exporter}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = AuthModel();
    if (token != null) auth.login(token, 1);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>.value(value: auth),
          ChangeNotifierProvider<CustomerProvider>.value(value: provider),
        ],
        child: GetMaterialApp(
          home: Scaffold(body: CustomersListPage(exporter: exporter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop: loads customers into the table with pagination',
      (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    expect(repository.queries.single.loadAll, isTrue);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Find customers'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsOneWidget);
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('20 customers on this page'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Customer 21'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('5 customers on this page'), findsOneWidget);
  });

  testWidgets('desktop: typing filters after the debounce', (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    final nameField = find.widgetWithText(TextFormField, 'Name');
    await tester.enterText(nameField, 'Customer 2');
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.filter.name, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(provider.filter.name, 'Customer 2');
    // Customer 2 and Customer 20..25.
    expect(find.text('7 customers on this page'), findsOneWidget);
  });

  testWidgets('desktop: balance filter and Reset', (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    await tester.tap(find.byType(DropdownButtonFormField<BalanceFilter>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Positive (+ve)').last);
    await tester.pumpAndSettle();
    expect(provider.filter.balance, BalanceFilter.positive);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(provider.filter, CustomerFilter.none);
  });

  testWidgets('desktop: View and row tap open the profile', (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    await tester.tap(find.text('View').first);
    expect(provider.getSelectedCustomer!.id, 1);
    expect(sidebar.index.value, SideBarController.customerProfileScreenIndex);

    sidebar.index.value = SideBarController.customersScreenIndex;
    await tester.tap(find.text('Customer 3'));
    expect(provider.getSelectedCustomer!.id, 3);
  });

  testWidgets('phone: cards, collapsible filters, no overflow', (tester) async {
    await pumpPage(tester, const Size(375, 812));

    expect(find.byType(CollapsibleFilterTile), findsOneWidget);
    expect(find.text('Search and filters'), findsOneWidget);
    expect(find.text('Name, email, phone and balance'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('View Profile'), findsWidgets);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('Search and filters'));
    await tester.pumpAndSettle();
    expect(find.text('Hide filter controls'), findsOneWidget);
    expect(find.text('Reset filters'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View Profile').first);
    expect(provider.getSelectedCustomer!.id, 1);
  });

  testWidgets('coming back keeps the applied filter in the inputs',
      (tester) async {
    await provider.loadAllCustomers('t');
    provider.applyFilter(const CustomerFilter(name: 'Customer 1'));
    await pumpPage(tester, const Size(1280, 800));

    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Name'),
    );
    expect(field.controller!.text, 'Customer 1');
    expect(provider.filter.name, 'Customer 1');
  });

  testWidgets('empty results show the empty state', (tester) async {
    repository.customers = [];
    await pumpPage(tester, const Size(1280, 800));
    expect(find.text('No customers found'), findsOneWidget);
  });

  testWidgets('a missing token shows a message and loads nothing',
      (tester) async {
    await pumpPage(tester, const Size(1280, 800), token: null);
    expect(find.text('Authentication token is missing'), findsOneWidget);
    await tester.pump(AppToastType.error.duration);
    expect(repository.queries, isEmpty);
  });

  testWidgets('desktop: Filters, Export, Refresh sit before Add, same height',
      (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    final keys = [
      CustomersListPage.filterToggleKey,
      CustomersListPage.exportKey,
      CustomersListPage.refreshKey,
    ];
    final xs = [for (final key in keys) tester.getCenter(find.byKey(key)).dx];
    expect(xs, orderedEquals([...xs]..sort()));
    final add = find.widgetWithText(FilledButton, 'Add customer');
    expect(xs.last, lessThan(tester.getCenter(add).dx));
    for (final key in keys) {
      expect(
          tester.getSize(find.byKey(key)).height, tester.getSize(add).height);
    }
  });

  testWidgets('desktop: the filter toggle hides and shows the panel',
      (tester) async {
    await pumpPage(tester, const Size(1280, 800));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Customer 2');
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(CustomersListPage.filterToggleKey));
    await tester.pumpAndSettle();
    expect(find.text('Find customers'), findsNothing);
    expect(find.byType(AppBadgeDot), findsOneWidget);
    // The filter keeps applying while hidden.
    expect(find.text('7 customers on this page'), findsOneWidget);

    await tester.tap(find.byKey(CustomersListPage.filterToggleKey));
    await tester.pumpAndSettle();
    expect(find.text('Find customers'), findsOneWidget);
    expect(find.byType(AppBadgeDot), findsNothing);
  });

  testWidgets('desktop: Export exports the filtered customers', (tester) async {
    List<CustomerListModelData>? exported;
    await pumpPage(tester, const Size(1280, 800),
        exporter: (customers) async => exported = customers);

    await tester.tap(find.byKey(CustomersListPage.exportKey));
    await tester.pumpAndSettle();
    expect(exported, hasLength(25));
  });

  testWidgets('desktop: a failed export shows a message', (tester) async {
    await pumpPage(tester, const Size(1280, 800),
        exporter: (_) async => throw StateError('no disk'));

    await tester.tap(find.byKey(CustomersListPage.exportKey));
    await tester.pumpAndSettle();
    expect(find.text('Could not export customers'), findsOneWidget);
    await tester.pump(AppToastType.error.duration);
  });

  testWidgets('phone: actions fold into a menu that works', (tester) async {
    List<CustomerListModelData>? exported;
    await pumpPage(tester, const Size(375, 812),
        exporter: (customers) async => exported = customers);

    expect(find.byKey(CustomersListPage.exportKey), findsNothing);
    expect(find.byKey(PageHeader.moreActionsKey), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide filters'));
    await tester.pumpAndSettle();
    expect(find.byType(CollapsibleFilterTile), findsNothing);

    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export to Excel'));
    await tester.pumpAndSettle();
    expect(exported, hasLength(25));
    expect(tester.takeException(), isNull);
  });
}
