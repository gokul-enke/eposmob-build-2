import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/billing_product_price.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';

class MarketProductPrice extends StatelessWidget {
  const MarketProductPrice(
      {super.key,
      required this.product,
      this.currency = '',
      this.fontSize = 14});

  final GetProduct product;
  final String currency;
  final double fontSize;

  @override
  Widget build(BuildContext context) => BillingProductPrice(
        product: product,
        currency: currency,
        priceStyle: TextStyle(
            fontFamily: 'Poppins',
            color: ColorManager.kPrimaryColor,
            fontWeight: FontWeight.w700,
            fontSize: fontSize),
        badgeFontSize: fontSize < 14 ? 8 : 10,
      );
}
