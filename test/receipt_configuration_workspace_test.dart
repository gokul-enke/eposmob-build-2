import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/widgets/receipt_configuration_workspace.dart';

void main() {
  testWidgets('shows synced fields and switches receipt sections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final config = DocumentConfig.fromJson({
      'id': 1102,
      'type': 'Bill',
      'language': 'en_ar',
      'display_configuration': {
        'showStoreName': {
          'visible': true,
          'value': 'متجر الاختبار',
          'default': 'Test Store',
        },
        'showInvoiceTitle': {
          'visible': true,
          'value': 'فاتورة ضريبية',
          'default': 'Tax Invoice',
        },
        'showCustomerName': {
          'visible': true,
          'value': 'العميل',
          'default': 'Customer',
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReceiptConfigurationWorkspace(
              config: config,
              paperSize: '80mm',
              themeName: 'Classic',
              themeId: 'classic',
              onResync: () {},
              isResyncing: false,
            ),
          ),
        ),
      ),
    );

    // The workspace and its expensive preview are now collapsed by default.
    await tester.tap(find.text('Receipt layout & preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field reference'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Live preview'));
    await tester.tap(find.text('Live preview'));
    await tester.pumpAndSettle();
    expect(find.text('Receipt layout & preview'), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    expect(
      find.textContaining('Classic is selected.'),
      findsOneWidget,
    );
    expect(find.text('Test Store'), findsWidgets);
    expect(find.text('متجر الاختبار'), findsWidgets);

    await tester.ensureVisible(find.text('Customer').first);
    await tester.tap(find.text('Customer').first);
    await tester.pumpAndSettle();

    expect(find.text('showCustomerName'), findsOneWidget);
    expect(find.text('Order data'), findsWidgets);
  });
}
