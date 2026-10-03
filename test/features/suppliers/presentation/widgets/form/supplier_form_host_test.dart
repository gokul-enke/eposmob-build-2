import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/form/supplier_form_host.dart';

import 'supplier_form_harness.dart';

class _Launcher extends StatelessWidget {
  const _Launcher({required this.onResult, this.showCreateAnother = true});

  final ValueChanged<Object?> onResult;
  final bool showCreateAnother;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => onResult(
              await showAddSupplierDialog(
                context,
                showCreateAnother: showCreateAnother,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
}

void main() {
  Future<void> useSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('resolves to the create result map', (tester) async {
    await useSize(tester, const Size(1200, 1000));
    final provider = RecordingSupplierProvider();
    Object? result = 'pending';
    await tester.pumpWidget(wrapSupplierForm(
      _Launcher(onResult: (value) => result = value),
      provider: provider,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Supplier'), findsOneWidget);
    await tester.enterText(supplierField('name'), 'Acme');
    await tester.enterText(supplierField('phone'), '9876543210');
    await tester.ensureVisible(find.text('Create Supplier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Supplier'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Supplier'), findsNothing);
    expect(result, isA<Map>());
    final map = result! as Map;
    expect(map['status'], 'success');
    expect(map['name'], 'Acme');
    expect(map['phone'], '9876543210');
    expect(map['response'], provider.createResponse);
    await settleToast(tester);
  });

  testWidgets('close resolves to null', (tester) async {
    await useSize(tester, const Size(1200, 1000));
    Object? result = 'pending';
    await tester.pumpWidget(wrapSupplierForm(
      _Launcher(
        showCreateAnother: false,
        onResult: (value) => result = value,
      ),
      provider: RecordingSupplierProvider(),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Create & Another'), findsNothing);
    await tester.ensureVisible(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Supplier'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('fits a phone screen', (tester) async {
    await useSize(tester, const Size(360, 740));
    final overflows = captureOverflowErrors();
    await tester.pumpWidget(wrapSupplierForm(
      _Launcher(onResult: (_) {}),
      provider: RecordingSupplierProvider(),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Supplier'), findsOneWidget);
    expect(overflows, isEmpty);
  });
}
