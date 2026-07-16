import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_card_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_desktop_table.dart';
import 'package:pos_machine/models/customer_list.dart';

void main() {
  final alice = CustomerListModelData(
    id: 1,
    name: 'Alice',
    phone: '1111111111',
    balance: 25,
    customerType: 'B2C',
  );
  final business = CustomerListModelData(
    id: 2,
    name: 'Business Customer',
    phone: '2222222222',
    balance: -10,
    customerType: 'B2B',
  );

  Future<void> pumpWidgetInsidePage(
    WidgetTester tester,
    Widget child,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 500,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('desktop table continues numbering on later pages',
      (tester) async {
    await pumpWidgetInsidePage(
      tester,
      CustomerDesktopTable(
        customers: [alice, business],
        currentPage: 2,
        itemsPerPage: 20,
        onViewCustomer: (_) {},
      ),
    );

    expect(find.text('21'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('-10.00'), findsOneWidget);
  });

  testWidgets('desktop View action returns the selected customer',
      (tester) async {
    CustomerListModelData? selectedCustomer;
    await pumpWidgetInsidePage(
      tester,
      CustomerDesktopTable(
        customers: [alice],
        currentPage: 1,
        itemsPerPage: 20,
        onViewCustomer: (customer) => selectedCustomer = customer,
      ),
    );

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(selectedCustomer?.id, alice.id);
  });

  testWidgets('card list continues numbering on later pages', (tester) async {
    await pumpWidgetInsidePage(
      tester,
      CustomerCardList(
        customers: [alice, business],
        currentPage: 2,
        itemsPerPage: 20,
        onViewCustomer: (_) {},
      ),
    );

    expect(find.text('#21'), findsOneWidget);
    expect(find.text('#22'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Business Customer'), findsOneWidget);
  });

  testWidgets('card View Profile returns the selected customer',
      (tester) async {
    CustomerListModelData? selectedCustomer;
    await pumpWidgetInsidePage(
      tester,
      CustomerCardList(
        customers: [alice],
        currentPage: 1,
        itemsPerPage: 20,
        onViewCustomer: (customer) => selectedCustomer = customer,
      ),
    );

    await tester.tap(find.text('View Profile'));
    await tester.pump();

    expect(selectedCustomer?.id, alice.id);
  });

  testWidgets('both list layouts show an empty-results message',
      (tester) async {
    await pumpWidgetInsidePage(
      tester,
      CustomerDesktopTable(
        customers: const [],
        currentPage: 1,
        itemsPerPage: 20,
        onViewCustomer: (_) {},
      ),
    );
    expect(find.text('No customers found'), findsOneWidget);

    await pumpWidgetInsidePage(
      tester,
      CustomerCardList(
        customers: const [],
        currentPage: 1,
        itemsPerPage: 20,
        onViewCustomer: (_) {},
      ),
    );
    expect(find.text('No customers found'), findsOneWidget);
  });
}
