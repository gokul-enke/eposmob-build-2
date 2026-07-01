import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/product_details_helpers.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_action_buttons.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/payment_summary.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.onBackToMarket,
    required this.onProceedToPayment,
    required this.onSaveOrder,
    required this.onClearCart,
    this.isSavingOrder = false,
    this.isClearingCart = false,
  });

  final VoidCallback onBackToMarket;
  final VoidCallback onProceedToPayment;
  final VoidCallback onSaveOrder;
  final VoidCallback onClearCart;
  final bool isSavingOrder;
  final bool isClearingCart;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const _controller = BillingMobileCartController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.kBgLightColor,
      body: SafeArea(
        bottom: false,
        child: Consumer2<LocalProductProvider, AppSettingsProvider>(
          builder: (context, provider, appSettingsProvider, _) {
            final cartItems = provider.getCartItems();
            final appSettings = appSettingsProvider.appSettings;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  Expanded(
                    child: _buildCartContent(
                      provider: provider,
                      cartItems: cartItems,
                      showMrp: appSettings?.showMrpPos ?? false,
                      showTaxRate: appSettings?.showTaxRatePos ?? false,
                      showTaxAmount: appSettings?.showTaxPos ?? false,
                      showItemCode: appSettings?.itemCodeEnabled ?? false,
                      stockEnabled: provider.isStockEnabled,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartContent({
    required LocalProductProvider provider,
    required List<LocalCartItem> cartItems,
    required bool showMrp,
    required bool showTaxRate,
    required bool showTaxAmount,
    required bool showItemCode,
    required bool stockEnabled,
  }) {
    if (cartItems.isEmpty) {
      return _EmptyCart(onAddMoreItems: widget.onBackToMarket);
    }

    return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              for (final item in cartItems) ...[
                CartItemCard(
                  item: item,
                  controller: _controller,
                  onDecrease: () {
                    _controller.changeQuantity(context, provider, item, -1);
                  },
                  onIncrease: () {
                    _controller.changeQuantity(context, provider, item, 1);
                  },
                  onRemove: () => _controller.removeItem(provider, item),
                  onSaleUnitChanged: (_) {},
                  showMrp: showMrp,
                  showTaxRate: showTaxRate,
                  showTaxAmount: showTaxAmount,
                  showItemCode: showItemCode,
                  isLowStock: stockEnabled &&
                      isProductLowStock(
                        productAvailableQuantity(item.product),
                        item.product.reorderLevel,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              _AddMoreItemsButton(onTap: widget.onBackToMarket),
              const SizedBox(height: 20),
              // Shared payment summary — same widget the Billing tab renders,
              // so currency, tax %, discount, delivery charge and round-off
              // can never drift between the two tabs.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const PaymentSummary(compact: true),
              ),
              const SizedBox(height: 18),
              CartActionButtons(
                hasItems: cartItems.isNotEmpty,
                onProceedToPayment: widget.onProceedToPayment,
                onSaveOrder: widget.onSaveOrder,
                onClearCart: widget.onClearCart,
                isSavingOrder: widget.isSavingOrder,
                isClearingCart: widget.isClearingCart,
              ),
            ],
          ),
        );
  }
}

class _AddMoreItemsButton extends StatelessWidget {
  const _AddMoreItemsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2E69C8),
              width: 1.4,
              style: BorderStyle.solid,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  color: Color(0xFF2E69C8), size: 22),
              SizedBox(width: 8),
              Text(
                'Add More Items',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2E69C8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onAddMoreItems});

  final VoidCallback onAddMoreItems;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 70,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Products you add from Market will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: _AddMoreItemsButton(onTap: onAddMoreItems),
          ),
        ],
      ),
    );
  }
}
