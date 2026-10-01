import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/form/customer_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'customer_form_harness.dart';

Widget _page(Widget form) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: form,
      ),
    );

Finder _field(String name) => find.byKey(ValueKey('customer-form-$name'));

/// Lets the success toast's timer run out.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  late List<FlutterErrorDetails> overflows;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'api_key': 'k',
      'active_store_id': 1,
    });
    overflows = captureOverflowErrors();
  });

  testWidgets('create mode renders all sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapCustomerForm(_page(const CustomerForm.create(cancelLabel: 'Close'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Street Address'), findsOneWidget);
    expect(find.text('States / Provinces'), findsOneWidget);
    expect(find.text('Payment Type'), findsOneWidget);
    expect(find.text('Customer Type'), findsNothing);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    // Country is prefilled from login.
    expect(find.text('India'), findsOneWidget);
    expect(overflows, isEmpty);
  });

  testWidgets('required phone blocks the submit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = RecordingCustomerRepository();
    await tester.pumpWidget(
      wrapCustomerForm(
        _page(const CustomerForm.create()),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Phone number is required'), findsOneWidget);
    expect(repository.createdFields, isNull);
  });

  testWidgets('submit creates the customer and reports the result',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = RecordingCustomerRepository();
    Map<String, dynamic>? created;
    await tester.pumpWidget(
      wrapCustomerForm(
        _page(CustomerForm.create(onCreated: (result) => created = result)),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('first-name'), 'John');
    await tester.enterText(_field('last-name'), 'Doe');
    await tester.enterText(_field('phone'), '9876543210');
    await tester.enterText(_field('email'), 'john@example.com');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    final fields = repository.createdFields!;
    expect(fields.phone, '9876543210');
    expect(fields.name, 'John Doe');
    expect(fields.email, 'john@example.com');
    expect(fields.country, 'India');
    expect(fields.paymentType, 'to_receive');
    expect(fields.customerType, 'B2C');
    expect(repository.createdStoreId, '1');
    expect(created?['status'], 'success');
    expect(created?['phone'], '9876543210');
    expect(created?['name'], 'John Doe');
    await _settleToast(tester);
  });

  testWidgets('B2B fields show when company B2B is enabled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapCustomerForm(
        _page(const CustomerForm.create()),
        companyB2BEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Customer Type'), findsOneWidget);
    await tester.tap(find.text('B2B'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('phone'), '9876543210');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('CR Number is required for B2B'), findsOneWidget);
    expect(find.text('VAT Number is required for B2B'), findsOneWidget);
  });

  testWidgets('edit mode prefills and sends only changed fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = RecordingCustomerRepository();
    CustomerListModelData? updated;
    final customer = CustomerListModelData(
      id: 7,
      name: 'Jane Doe',
      phone: '5551234567',
      email: 'jane@example.com',
      balance: 10,
      paymentType: 'to_receive',
    );
    await tester.pumpWidget(
      wrapCustomerForm(
        _page(CustomerForm.edit(
          customer: customer,
          onUpdated: (value) => updated = value,
        )),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Street Address'), findsNothing);
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('10.00'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);

    await tester.enterText(_field('first-name'), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('First name is required'), findsOneWidget);
    expect(repository.updatedFields, isNull);

    await tester.enterText(_field('first-name'), 'Jane');
    await tester.enterText(_field('email'), 'jane@new.io');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump();

    expect(repository.updatedId, 7);
    expect(repository.updatedFields!.email, 'jane@new.io');
    expect(repository.updatedFields!.name, isNull);
    expect(repository.updatedFields!.phone, isNull);
    expect(repository.updatedFields!.balance, isNull);
    expect(updated?.email, 'jane@new.io');
    await _settleToast(tester);
  });

  testWidgets('fits a 360 px wide screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapCustomerForm(
        _page(const CustomerForm.create(cancelLabel: 'Close')),
        companyB2BEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    final submit = tester.getSize(find.text('Submit').hitTestable());
    expect(submit, isNot(Size.zero));
    // Stacked actions: the submit button spans the form width.
    final button = find.ancestor(
      of: find.text('Submit'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(tester.getSize(button.first).width, greaterThan(250));
    expect(overflows, isEmpty);
  });
}
