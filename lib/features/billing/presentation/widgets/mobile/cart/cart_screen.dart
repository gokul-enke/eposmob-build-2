import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_action_buttons.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/cart_summary.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

enum CartSegment { cart, saved, ongoing }

class CartScreen extends StatefulWidget {
  const CartScreen({
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
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  CartSegment _selectedSegment = CartSegment.cart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Consumer<LocalProductProvider>(
          builder: (context, provider, _) {
            final cartItems = provider.getCartItems();
            final total = provider.cartTotal;
            final summary = provider.priceSummary;
            final tax = summary?.totalTax ?? 0.0;
            final subtotal = (((summary?.subTotal ?? total) - tax)
                    .clamp(0.0, double.infinity) as num)
                .toDouble();

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  _CartHeader(onBack: widget.onBackToMarket),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 16),
                  _SegmentedTabs(
                    selectedSegment: _selectedSegment,
                    onChanged: (segment) {
                      setState(() => _selectedSegment = segment);
                    },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _buildSegmentContent(
                      provider: provider,
                      cartItems: cartItems,
                      subtotal: subtotal,
                      tax: tax,
                      total: total,
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

  Widget _buildSegmentContent({
    required LocalProductProvider provider,
    required List<LocalCartItem> cartItems,
    required double subtotal,
    required double tax,
    required double total,
  }) {
    switch (_selectedSegment) {
      case CartSegment.saved:
        return _PlaceholderSegment(
          icon: Icons.bookmark_border,
          title: 'No saved carts yet',
          subtitle: 'Saved orders will appear here',
        );
      case CartSegment.ongoing:
        return _PlaceholderSegment(
          icon: Icons.access_time,
          title: 'No ongoing carts yet',
          subtitle: 'Active draft activity will appear here',
        );
      case CartSegment.cart:
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
                  onDecrease: () => _changeQuantity(provider, item, -1),
                  onIncrease: () => _changeQuantity(provider, item, 1),
                  onRemove: () {
                    provider.removeFromCart(
                      item.product.productId!,
                      item.selectedStock,
                      stockGroupIds: item.stockGroupIds,
                      saleUnitId: item.saleUnitId,
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              _AddMoreItemsButton(onTap: widget.onBackToMarket),
              const SizedBox(height: 20),
              CartSummary(
                subtotal: subtotal,
                tax: tax,
                total: total,
              ),
              const SizedBox(height: 18),
              CartActionButtons(
                hasItems: cartItems.isNotEmpty,
                onProceedToPayment: widget.onProceedToPayment,
                onSaveOrder: widget.onSaveOrder,
                onClearCart: widget.onClearCart,
              ),
            ],
          ),
        );
    }
  }

  void _changeQuantity(
    LocalProductProvider provider,
    LocalCartItem item,
    int step,
  ) {
    final currentDisplayQty = item.displayQuantity;
    final newDisplayQty = currentDisplayQty + step;
    final newBaseQty =
        item.hasSaleUnit ? item.toBaseQuantity(newDisplayQty) : newDisplayQty;

    provider.setCartItemQuantity(
      item.product.productId!,
      item.selectedStock,
      newBaseQty,
      stockGroupIds: item.stockGroupIds,
      saleUnitId: item.saleUnitId,
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon:
                  const Icon(Icons.arrow_back, color: Colors.black87, size: 26),
            ),
          ),
          const Text(
            'Cart Details',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.selectedSegment,
    required this.onChanged,
  });

  final CartSegment selectedSegment;
  final ValueChanged<CartSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Cart',
              selected: selectedSegment == CartSegment.cart,
              onTap: () => onChanged(CartSegment.cart),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Saved',
              selected: selectedSegment == CartSegment.saved,
              onTap: () => onChanged(CartSegment.saved),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Ongoing',
              selected: selectedSegment == CartSegment.ongoing,
              onTap: () => onChanged(CartSegment.ongoing),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF1764C0) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
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

class _PlaceholderSegment extends StatelessWidget {
  const _PlaceholderSegment({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
