import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_display.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskCartPanel extends StatelessWidget {
  final List<LocalCartItem> items;
  final String currency;
  final ValueChanged<LocalCartItem>? onIncrease;
  final ValueChanged<LocalCartItem>? onDecrease;
  final ValueChanged<LocalCartItem>? onRemove;
  final VoidCallback onCheckout;
  final bool sheetMode;

  const KioskCartPanel({
    super.key,
    required this.items,
    required this.currency,
    this.onIncrease,
    this.onDecrease,
    this.onRemove,
    required this.onCheckout,
    this.sheetMode = false,
  });

  double get subtotal => items.fold(
        0,
        (sum, item) => sum + ((item.price ?? 0) * item.quantity),
      );
  double get tax => items.fold(
        0,
        (sum, item) => sum + ((item.taxAmount ?? 0) * item.quantity),
      );
  double get total => subtotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: sheetMode ? null : 370,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(22),
          bottom: Radius.circular(sheetMode ? 0 : 22),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your order',
                  style: TextStyle(
                    color: ColorManager.kTitleTextColor,
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sheetMode)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const Expanded(child: _EmptyCart())
          else
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 26),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return _CartItem(
                    item: item,
                    currency: currency,
                    onIncrease:
                        onIncrease == null ? null : () => onIncrease!(item),
                    onDecrease:
                        onDecrease == null ? null : () => onDecrease!(item),
                    onRemove: onRemove == null ? null : () => onRemove!(item),
                  );
                },
              ),
            ),
          if (items.isNotEmpty) ...[
            const Divider(height: 28),
            _AmountRow(label: 'Subtotal', value: subtotal, currency: currency),
            const SizedBox(height: 9),
            _AmountRow(label: 'Included tax', value: tax, currency: currency),
            const Divider(height: 28),
            _AmountRow(
              label: 'Total',
              value: total,
              currency: currency,
              emphasized: true,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: onCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Review order  ${_formatMoney(currency, total)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final LocalCartItem item;
  final String currency;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback? onRemove;

  const _CartItem({
    required this.item,
    required this.currency,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: const Color(0xFFF7F9FC),
            child: SizedBox(
              width: 62,
              height: 62,
              child: _CartProductImage(product: item.product),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ColorManager.kTitleTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatMoney(
                  currency,
                  (item.price ?? 0) * item.quantity,
                ),
                style: const TextStyle(color: ColorManager.kTextColor),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _QuantityButton(icon: Icons.remove, onPressed: onDecrease),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${item.displayQuantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _QuantityButton(icon: Icons.add, onPressed: onIncrease),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
          color: ColorManager.kGreyColor,
          tooltip: 'Remove item',
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 19),
        color: ColorManager.kPrimaryColor,
        style: IconButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryWithOpacity10,
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final bool emphasized;

  const _AmountRow({
    required this.label,
    required this.value,
    required this.currency,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color:
          emphasized ? ColorManager.kTitleTextColor : ColorManager.kTextColor,
      fontSize: emphasized ? 22 : 15,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(_formatMoney(currency, value), style: style),
      ],
    );
  }
}

class _CartProductImage extends StatelessWidget {
  final GetProduct product;

  const _CartProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMarketProductImageUrl(product);
    if (imageUrl == null) {
      return const Icon(
        Icons.inventory_2_outlined,
        color: ColorManager.kGreyColor,
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.broken_image_outlined,
        color: ColorManager.kGreyColor,
      ),
    );
  }
}

String _formatMoney(String currency, num value) {
  final prefix = currency.trim().isEmpty ? '' : '${currency.trim()} ';
  return '$prefix${AmountHelper.formatAmount(value)}';
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: ColorManager.kGreyColor,
          ),
          const SizedBox(height: 14),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a product to add it',
            style: TextStyle(
              color: ColorManager.kTextColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
