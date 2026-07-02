import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

GetProduct _multiVariantProduct() {
  return GetProduct(
    productId: 1,
    productName: 'T-Shirt',
    price: ProductPrice(price: '299'),
    variants: [
      ProductVariant(
        id: 10,
        price: 349,
        attributes: const {'COLOR': 'Red', 'SIZE': 'L'},
        quantity: 5,
      ),
      ProductVariant(
        id: 20,
        price: 359,
        attributes: const {'COLOR': 'Blue', 'SIZE': 'M'},
        quantity: 0,
      ),
    ],
  );
}

void main() {
  group('MobileVariantPickerSheet', () {
    testWidgets('renders active variants and returns selection on confirm',
        (tester) async {
      ProductVariant? selected;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        selected = await showMobileVariantPickerSheet(
                          context: context,
                          product: _multiVariantProduct(),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('T-Shirt'), findsOneWidget);
      expect(find.text('Red | L'), findsOneWidget);
      expect(find.text('Blue | M'), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);

      await tester.tap(find.text('Red | L'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(selected?.id, 10);
    });

    testWidgets('dismisses without selection when closed', (tester) async {
      ProductVariant? selected;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        selected = await showMobileVariantPickerSheet(
                          context: context,
                          product: _multiVariantProduct(),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(selected, isNull);
    });

    testWidgets('cannot confirm out-of-stock variant selection', (tester) async {
      ProductVariant? selected;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        selected = await showMobileVariantPickerSheet(
                          context: context,
                          product: _multiVariantProduct(),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Blue | M is out of stock — tap should not select it.
      await tester.tap(find.text('Blue | M'));
      await tester.pumpAndSettle();

      final addButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add to Cart'),
      );
      expect(addButton.onPressed, isNull);
      expect(selected, isNull);
    });
  });
}
