import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/form/supplier_form.dart';

import 'supplier_form_harness.dart';

Widget _page(Widget form) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: form,
      ),
    );

Future<void> _useSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(supplierField('name'), 'Acme');
  await tester.enterText(supplierField('phone'), '9876543210');
}

void main() {
  late List<FlutterErrorDetails> overflows;

  setUp(() => overflows = captureOverflowErrors());

  testWidgets('create mode renders all sections and actions', (tester) async {
    await _useSize(tester, const Size(1200, 1600));
    await tester.pumpWidget(wrapSupplierForm(
      _page(SupplierForm.create(onCancel: () {})),
      provider: RecordingSupplierProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Supplier Name'), findsOneWidget);
    expect(find.text('Tax Number'), findsOneWidget);
    expect(find.text('KYC Information'), findsOneWidget);
    expect(find.text('Opening Balance'), findsOneWidget);
    expect(find.text('To Pay'), findsOneWidget);
    expect(find.text('Create Supplier'), findsOneWidget);
    expect(find.text('Create & Another'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('0.00'), findsWidgets);
    expect(overflows, isEmpty);
  });

  testWidgets('required fields block the submit', (tester) async {
    await _useSize(tester, const Size(1200, 1600));
    final provider = RecordingSupplierProvider();
    await tester.pumpWidget(wrapSupplierForm(
      _page(const SupplierForm.create()),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Supplier'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(provider.created, isEmpty);
  });

  testWidgets('create formats the phone and reports the result',
      (tester) async {
    await _useSize(tester, const Size(1200, 1600));
    final provider = RecordingSupplierProvider();
    Map<String, dynamic>? result;
    await tester.pumpWidget(wrapSupplierForm(
      _page(SupplierForm.create(onCreated: (value) => result = value)),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    await _fillRequired(tester);
    expect(find.text('987-654-3210'), findsOneWidget);
    await tester.enterText(supplierField('vat-number'), 'VAT-1');
    await tester.tap(find.text('To Receive'));
    await tester.tap(find.text('Create Supplier'));
    await tester.pumpAndSettle();

    final call = provider.created.single;
    expect(call['phone'], '9876543210');
    expect(call['paymentStatus'], 'to_receive');
    expect(call['balance'], '0.00');
    expect(call['kyc'], {'VAT_NUMBER': 'VAT-1'});
    expect(result?['status'], 'success');
    expect(result?['phone'], '9876543210');
    expect(find.text('Created'), findsOneWidget);
    await settleToast(tester);
  });

  testWidgets('create another saves, empties the form and stays',
      (tester) async {
    await _useSize(tester, const Size(1200, 1600));
    final provider = RecordingSupplierProvider();
    var reported = false;
    await tester.pumpWidget(wrapSupplierForm(
      _page(SupplierForm.create(onCreated: (_) => reported = true)),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    await _fillRequired(tester);
    await tester.tap(find.text('Create & Another'));
    await tester.pumpAndSettle();

    expect(provider.created, hasLength(1));
    expect(reported, isFalse);
    expect(find.text('Acme'), findsNothing);
    await settleToast(tester);
  });

  testWidgets('create another is hidden when not offered', (tester) async {
    await _useSize(tester, const Size(1200, 1600));
    await tester.pumpWidget(wrapSupplierForm(
      _page(const SupplierForm.create(showCreateAnother: false)),
      provider: RecordingSupplierProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Create & Another'), findsNothing);
  });

  testWidgets('server errors are shown and nothing is reported',
      (tester) async {
    await _useSize(tester, const Size(1200, 1600));
    final provider = RecordingSupplierProvider(createResponse: {
      'status': 'error',
      'errors': {
        'phone': ['The phone has already been taken.'],
      },
    });
    var reported = false;
    await tester.pumpWidget(wrapSupplierForm(
      _page(SupplierForm.create(onCreated: (_) => reported = true)),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    await _fillRequired(tester);
    await tester.tap(find.text('Create Supplier'));
    await tester.pumpAndSettle();

    expect(find.text('The phone has already been taken.'), findsOneWidget);
    expect(reported, isFalse);
    await settleToast(tester);
  });

  testWidgets('phone width stacks the actions without overflow',
      (tester) async {
    await _useSize(tester, const Size(360, 2400));
    await tester.pumpWidget(wrapSupplierForm(
      _page(SupplierForm.create(onCancel: () {})),
      provider: RecordingSupplierProvider(),
    ));
    await tester.pumpAndSettle();

    final create = tester.getSize(find.text('Create Supplier').hitTestable());
    expect(create.width, greaterThan(0));
    expect(
      tester.getTopLeft(find.text('Create Supplier')).dy,
      lessThan(tester.getTopLeft(find.text('Close')).dy),
    );
    expect(overflows, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode prefills and saves the supplier', (tester) async {
    await _useSize(tester, const Size(1200, 1600));
    final provider = RecordingSupplierProvider();
    var updated = false;
    await tester.pumpWidget(wrapSupplierForm(
      _page(SupplierForm.edit(
        supplier: sampleSupplier(),
        onUpdated: () => updated = true,
      )),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Acme Traders'), findsOneWidget);
    expect(find.text('150.50'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Create Supplier'), findsNothing);

    await tester.enterText(supplierField('name'), 'Acme Ltd');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final call = provider.updated.single;
    expect(call['id'], 7);
    expect(call['name'], 'Acme Ltd');
    expect(call['balance'], 150.5);
    expect(call['paymentStatus'], 'to_receive');
    expect(updated, isTrue);
    expect(
      find.text('Supplier information updated successfully'),
      findsOneWidget,
    );
    await settleToast(tester);
  });
}
