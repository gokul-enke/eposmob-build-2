import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_screen.dart';

class MobileCartTab extends StatelessWidget {
  const MobileCartTab({
    super.key,
    required this.onBackToMarket,
    required this.onProceedToPayment,
    required this.onSaveOrder,
    required this.onClearCart,
  });

  final VoidCallback onBackToMarket;
  final VoidCallback onProceedToPayment;
  final VoidCallback onSaveOrder;
  final VoidCallback onClearCart;

  @override
  Widget build(BuildContext context) {
    return CartScreen(
      onBackToMarket: onBackToMarket,
      onProceedToPayment: onProceedToPayment,
      onSaveOrder: onSaveOrder,
      onClearCart: onClearCart,
    );
  }
}
