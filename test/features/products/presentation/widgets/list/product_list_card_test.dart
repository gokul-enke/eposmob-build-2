import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/products/presentation/widgets/list/product_list_card.dart';
import 'package:pos_machine/features/products/presentation/widgets/list/product_list_copy.dart';
import 'package:pos_machine/models/get_product.dart';
import '../../../../../test_support/app_translations.dart';

class IdentifierTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final lang in ['en', 'ar', 'ml'])
          lang: {
            for (final entry in translationSection(lang, 'product').entries)
              'product.${entry.key}': entry.value.toString(),
          },
      };
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);
  for (final language in ['en', 'ar', 'ml']) {
    for (final itemCodeEnabled in [false, true]) {
      testWidgets(
          'mobile identifiers are labeled and copy raw values: '
          '$language, item code=$itemCodeEnabled', (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
        addTearDown(() => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null));
        var views = 0;
        const itemCode = '000123456789012345678901234567890123456789';
        const barcode = '0001234567890';
        await tester.pumpWidget(GetMaterialApp(
            translations: IdentifierTranslations(),
            locale: Locale(language),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: ProductListCard(
                        product: GetProduct(
                            productName: 'Product',
                            itemCode: itemCode,
                            barcode: barcode),
                        number: 1,
                        itemCodeEnabled: itemCodeEnabled,
                        canViewPurchasePrice: false,
                        onView: () => views++)))));
        await tester.pumpAndSettle();
        final rows = tester
            .widgetList<InfoRow>(find.byType(InfoRow))
            .map((row) => '${row.label}|${row.value}')
            .toList();
        expect(rows, [
          if (itemCodeEnabled) '${'product.item_code'.tr}|$itemCode',
          '${'product.barcode'.tr}|$barcode',
        ]);
        expect(tester.takeException(), isNull);
        if (itemCodeEnabled) {
          await tester.tap(find.byTooltip('product.item_code_copied'.tr));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('product.barcode_copied'.tr));
        await tester.pumpAndSettle();
        expect(copied, [if (itemCodeEnabled) itemCode, barcode]);
        expect(views, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('missing identifiers keep labels and have no copy buttons',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(
        translations: IdentifierTranslations(),
        locale: const Locale('en'),
        home: const Scaffold(
            body: Column(children: [
          ProductListCopy(
              label: 'Item Code',
              value: null,
              message: 'product.item_code_copied'),
          ProductListCopy(
              label: 'Barcode', value: null, message: 'product.barcode_copied'),
        ]))));
    expect(find.text('Item Code'), findsOneWidget);
    expect(find.text('Barcode'), findsOneWidget);
    expect(find.text('N/A'), findsNWidgets(2));
    expect(find.byType(IconButton), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
