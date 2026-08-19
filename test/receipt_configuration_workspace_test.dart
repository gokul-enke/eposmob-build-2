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

    expect(find.text('Receipt Setup & Live Preview'), findsOneWidget);
    expect(find.text('Test Store'), findsWidgets);
    expect(find.text('متجر الاختبار'), findsWidgets);

    await tester.tap(find.text('Customer').first);
    await tester.pumpAndSettle();

    expect(find.text('showCustomerName'), findsOneWidget);
    expect(find.text('Order data'), findsWidgets);
  });
}
