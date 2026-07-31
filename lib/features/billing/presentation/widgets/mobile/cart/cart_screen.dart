import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/product_details_helpers.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_action_buttons.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/payment_summary.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

/// Height of [MobileBottomNav] container plus its SafeArea minimum bottom inset.
const double kMobileBottomNavClearance = 76;

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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer2<LocalProductProvider, AppSettingsProvider>(
        builder: (context, provider, appSettingsProvider, _) {
          final cartItems = provider.getCartItems();
          final appSettings = appSettingsProvider.appSettings;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildCartContent(
              provider: provider,
              cartItems: cartItems,
              showMrp: appSettings?.showMrpPos ?? false,
              showTaxRate: appSettings?.showTaxRatePos ?? false,
              showTaxAmount: appSettings?.showTaxPos ?? false,
              showItemCode: appSettings?.itemCodeEnabled ?? false,
              stockEnabled: provider.isStockEnabled,
              bottomScrollPadding: bottomInset + kMobileBottomNavClearance,
            ),
          );
        },
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
    required double bottomScrollPadding,
  }) {
    if (cartItems.isEmpty) {
      return _EmptyCart(onAddMoreItems: widget.onBackToMarket);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomScrollPadding + 12),
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
              isOutOfStock: stockEnabled &&
                  item.selectedStock != null &&
                  isProductOutOfStock(
                    provider.getAvailableQuantityForSelection(
                      product: item.product,
                      selectedStock: item.selectedStock,
                      stockGroupIds: item.stockGroupIds,
                      variantId: item.variantId,
                    ),
                  ),
            ),
            const SizedBox(height: 10),
          ],
          _AddMoreItemsButton(onTap: widget.onBackToMarket),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const PaymentSummary(compact: true),
          ),
          const SizedBox(height: 12),
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2E69C8),
              width: 1.2,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Color(0xFF2E69C8), size: 18),
              SizedBox(width: 6),
              Text(
                'Add More Items',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2E69C8),
                  fontSize: 13,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Products you add from Market will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            _AddMoreItemsButton(onTap: onAddMoreItems),
          ],
        ),
      ),
    );
  }
}
