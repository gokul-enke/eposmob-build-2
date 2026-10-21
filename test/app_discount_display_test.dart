import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/sections/order_detail_desktop_cart_items_table.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/sections/order_detail_mobile_cart_item_card.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/sections/order_detail_inputs.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/sections/order_detail_presentation_data.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/screens/print/receipt_line_discount.dart';

void main() {
  test('cart saving matches uploaded and printed money in base and sale units',
      () {
    for (final saleUnit in [false, true]) {
      for (final offer in [false, true]) {
        final item = LocalCartItem(
          product: GetProduct(productId: 1, productName: 'Item'),
          price: 17,
          quantity: 24,
          standardUnitPrice: 20,
          offerId: offer ? 28 : null,
          isManualPriceOverride: !offer,
          saleUnitId: saleUnit ? 3 : null,
          saleUnitConversionRate: saleUnit ? 12 : null,
        );
        final upload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
        final uploadSaving = upload.fold<double>(
            0,
            (sum, row) =>
                sum + (row['item_discount_amount'] as num).toDouble());
        final receipt = ReceiptLineDiscount.fromItem(
            PrintService.savedOrderReceiptItem(item));
        expect(item.itemDiscountAmount, 72);
        expect(item.itemDiscountAmount, uploadSaving);
        expect(item.itemDiscountAmount, receipt.itemDiscount);
      }
    }
  });

  test(
      'ordinary prices, missing references and increases do not invent a saving',
      () {
    for (final reference in [null, 15.0, 20.0]) {
      final item = LocalCartItem(
        product: GetProduct(productId: 1),
        price: 17,
        quantity: 2,
        standardUnitPrice: reference,
      );
      expect(item.itemDiscountAmount, 0);
      item.isManualPriceOverride = true;
      expect(item.itemDiscountAmount, reference == 20 ? 6 : 0);
    }
  });

  for (final mobile in [false, true]) {
    for (final scenario in ['allocated', 'offer', 'legacy', 'zero']) {
      testWidgets(
          '${mobile ? 'mobile' : 'desktop'} sales row agrees with receipt ($scenario)',
          (tester) async {
        tester.view.physicalSize = Size(mobile ? 420 : 1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = OrderDetailsModelDataCartItem.fromJson({
          'product_name': 'Product name only',
          'quantity': 1,
          'unit_price': '17',
          'total_price': '17',
          'tax_amount': '2.59',
          if (scenario == 'allocated') ...{
            'line_discount': '2',
            'discounted_total': '15',
            'discounted_tax_amount': '2.29',
          },
          if (scenario == 'offer') 'standard_unit_price': '20',
          if (scenario == 'zero') ...{
            'standard_unit_price': '20',
            'item_discount_amount': '0',
            'discounted_total': '0',
            'discounted_tax_amount': '0',
          },
        });
        final inputs = OrderDetailInputs(
            currency: 'SAR',
            data: OrderDetailPresentationData(
              orderDetailsModelData: null,
              priceSummary: null,
              cartItem: [item],
              customerDetails: null,
            ));
        final receipt = ReceiptLineDiscount.fromItem(item);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: mobile
                    ? OrderDetailMobileCartItemCard(0, item, 'SAR',
                        inputs: inputs)
                    : OrderDetailDesktopCartItemsTable('SAR',
                        inputs: inputs))));
        expect(find.text('Product name only'), findsOneWidget);
        expect(find.text('SAR ${receipt.discountedTotal.toStringAsFixed(2)}'),
            findsWidgets);
        expect(find.text('SAR ${receipt.originalRate.toStringAsFixed(2)}'),
            findsWidgets);
        expect(
            find.text(
                'SAR ${double.parse(item.discountedTaxAmount ?? item.taxAmount!).toStringAsFixed(2)}'),
            findsWidgets);
        if (receipt.totalDiscount > 0) {
          expect(
              find.text(mobile
                  ? '${'billing.discount_label'.tr}: '
                  : 'billing.discount_label'.tr),
              findsOneWidget);
          expect(find.text('SAR ${receipt.totalDiscount.toStringAsFixed(2)}'),
              findsOneWidget);
        } else {
          expect(
              find.text(mobile
                  ? '${'billing.discount_label'.tr}: '
                  : 'billing.discount_label'.tr),
              findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
