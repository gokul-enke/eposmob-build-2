import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_avatar.dart';
import 'package:pos_machine/features/customers/presentation/widgets/list/customer_list_card.dart';
import 'package:pos_machine/features/customers/presentation/widgets/list/customer_table_columns.dart';

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
    name: 'no name',
    balance: -10,
    customerType: 'b2b',
  );

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(GetMaterialApp(
      home: Scaffold(body: SizedBox(width: 1000, height: 500, child: child)),
    ));
  }

  testWidgets('table columns render customer data and the View action',
      (tester) async {
    CustomerListModelData? viewed;
    await pump(
      tester,
      AppDataTable<CustomerListModelData>(
        items: [alice, business],
        columns: customerTableColumns(onView: (c) => viewed = c),
        rowNumberOf: (index) => index + 21,
        emptyState: const SizedBox(),
      ),
    );

    expect(find.text('21'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Unnamed customer'), findsOneWidget);
    expect(find.text('25.00'), findsOneWidget);
    expect(find.text('-10.00'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('B2B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility).first);
    expect(viewed, alice);
  });

  testWidgets('card shows number, balance, phone placeholder and opens',
      (tester) async {
    var opened = 0;
    await pump(
      tester,
      CustomerListCard(
        customer: business,
        rowNumber: 22,
        onView: () => opened++,
      ),
    );

    expect(find.text('#22'), findsOneWidget);
    expect(find.text('Unnamed customer'), findsOneWidget);
    expect(find.text('-10.00'), findsOneWidget);
    expect(find.text('Not provided'), findsOneWidget);

    await tester.tap(find.text('View Profile'));
    expect(opened, 1);
  });

  testWidgets('avatar uses the initial, or # for unnamed customers',
      (tester) async {
    await pump(
      tester,
      const Row(children: [
        CustomerAvatar(name: ' bob'),
        CustomerAvatar(name: 'Unnamed'),
      ]),
    );
    expect(find.text('B'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);
  });
}
