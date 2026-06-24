import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/cart/cart_items_table.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// The shopping-cart card (header summary + clear button + items table) on the
/// mobile Home tab. Extracted verbatim from `home_tab.dart`. Clearing the cart
/// is delegated via [onClearCart].
class MobileHomeCartCard extends StatelessWidget {
  final VoidCallback onClearCart;

  const MobileHomeCartCard({super.key, required this.onClearCart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        child: Column(
          children: [
            // Cart Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    color: ColorManager.kPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Shopping Cart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Cart Summary
                  Consumer<LocalProductProvider>(
                    builder: (context, provider, child) {
                      final total = provider.cartTotal;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${provider.cartItems.length} items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ColorManager.kPrimaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Consumer<BillingProvider>(
                    builder: (context, provider, child) {
                      final isLoading = provider.isLoadingClearCart;
                      return SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(
                              color: Colors.red.shade300,
                            ),
                          ),
                          onPressed: isLoading ? null : onClearCart,
                          child: Text(
                            isLoading ? 'Clearing...' : 'Clear Cart',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Cart Items - Takes remaining space
            const Expanded(
              child: CartItemsTable(),
            ),
          ],
        ),
      ),
    );
  }
}
