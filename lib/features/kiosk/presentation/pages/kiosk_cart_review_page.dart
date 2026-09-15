import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_display.dart';
import 'package:pos_machine/features/kiosk/presentation/models/kiosk_order_draft.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_order_details_page.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_flow_scaffold.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskCartReviewPage extends StatefulWidget {
  final List<LocalCartItem> items;
  final String currency;
  final ValueChanged<List<LocalCartItem>>? onChanged;

  const KioskCartReviewPage({
    super.key,
    required this.items,
    required this.currency,
    this.onChanged,
  });

  @override
  State<KioskCartReviewPage> createState() => _KioskCartReviewPageState();
}

class _KioskCartReviewPageState extends State<KioskCartReviewPage> {
  late final List<LocalCartItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map(copyKioskCartItem).toList();
  }

  KioskOrderDraft get _draft => KioskOrderDraft(items: _items);

  void _changeQuantity(int index, int delta) {
    setState(() {
      final item = _items[index];
      final next = item.displayQuantity + delta;
      if (next <= 0) {
        _items.removeAt(index);
      } else {
        item.quantity = item.toBaseQuantity(next);
      }
    });
    _notifyChanged();
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onChanged?.call(
      _items.map(copyKioskCartItem).toList(growable: true),
    );
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KioskOrderDetailsPage(
          items: _items,
          currency: widget.currency,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KioskFlowScaffold(
      title: 'Review your order',
      stepLabel: 'Step 1 of 3',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          final padding = constraints.maxWidth < 600 ? 14.0 : 22.0;
          final list = _CartList(
            items: _items,
            currency: widget.currency,
            expandItems: wide,
            onDecrease: (index) => _changeQuantity(index, -1),
            onIncrease: (index) => _changeQuantity(index, 1),
            onRemove: _removeItem,
          );
          final summary = _CartSummary(
            draft: _draft,
            currency: widget.currency,
            onContinue: _items.isEmpty ? null : _continue,
          );

          if (wide) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 7, child: list),
                  const SizedBox(width: 20),
                  SizedBox(width: 360, child: summary),
                ],
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              list,
              const SizedBox(height: 16),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _CartList extends StatelessWidget {
  final List<LocalCartItem> items;
  final String currency;
  final bool expandItems;
  final ValueChanged<int> onDecrease;
  final ValueChanged<int> onIncrease;
  final ValueChanged<int> onRemove;

  const _CartList({
    required this.items,
    required this.currency,
    required this.expandItems,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return KioskSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KioskSectionTitle(
            '${items.length} ${items.length == 1 ? 'item' : 'items'}',
            subtitle: 'Check quantities and remove anything you do not need',
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            expandItems
                ? const Expanded(child: _EmptyOrder())
                : const SizedBox(height: 220, child: _EmptyOrder())
          else if (expandItems)
            Expanded(child: _buildItemList())
          else
            _buildItemColumn(),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 28),
      itemBuilder: (_, index) => _buildItem(index),
    );
  }

  Widget _buildItemColumn() {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 28),
          _buildItem(index),
        ],
      ],
    );
  }

  Widget _buildItem(int index) {
    return _ReviewItem(
      item: items[index],
      currency: currency,
      onDecrease: () => onDecrease(index),
      onIncrease: () => onIncrease(index),
      onRemove: () => onRemove(index),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final LocalCartItem item;
  final String currency;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  const _ReviewItem({
    required this.item,
    required this.currency,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMarketProductImageUrl(item.product);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final details = Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: compact ? 72 : 92,
                height: compact ? 72 : 92,
                child: ColoredBox(
                  color: const Color(0xFFF7F9FC),
                  child: imageUrl == null
                      ? const Icon(Icons.inventory_2_outlined,
                          color: ColorManager.kGreyColor)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: ColorManager.kGreyColor,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ColorManager.kTitleTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.saleUnitName?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.saleUnitName!,
                      style: const TextStyle(color: ColorManager.kTextColor),
                    ),
                  ],
                  if (item.comment?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Note: ${item.comment}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColorManager.kTextColor),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Text(
                    _money(
                      currency,
                      (item.displayPrice ?? item.price ?? 0) *
                          item.displayQuantity,
                    ),
                    style: const TextStyle(
                      color: ColorManager.kPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmallButton(icon: Icons.remove_rounded, onPressed: onDecrease),
            SizedBox(
              width: 48,
              child: Text(
                '${item.displayQuantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _SmallButton(icon: Icons.add_rounded, onPressed: onIncrease),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove item',
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.redAccent,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: controls),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 16),
            controls,
          ],
        );
      },
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SmallButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryWithOpacity10,
          foregroundColor: ColorManager.kPrimaryColor,
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final KioskOrderDraft draft;
  final String currency;
  final VoidCallback? onContinue;

  const _CartSummary({
    required this.draft,
    required this.currency,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return KioskSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KioskSectionTitle('Order summary'),
          const SizedBox(height: 22),
          _AmountRow(
            label: 'Subtotal',
            value: _money(currency, draft.subtotal),
          ),
          const SizedBox(height: 12),
          _AmountRow(
            label: 'Included tax',
            value: _money(currency, draft.includedTax),
          ),
          const Divider(height: 32),
          _AmountRow(
            label: 'Total',
            value: _money(currency, draft.total),
            emphasized: true,
          ),
          const SizedBox(height: 24),
          KioskPrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color:
          emphasized ? ColorManager.kTitleTextColor : ColorManager.kTextColor,
      fontSize: emphasized ? 22 : 16,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: ColorManager.kGreyColor),
          SizedBox(height: 12),
          Text(
            'Your order is empty',
            style: TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 5),
          Text('Go back and choose a product.'),
        ],
      ),
    );
  }
}

String _money(String currency, num value) {
  final prefix = currency.trim().isEmpty ? '' : '${currency.trim()} ';
  return '$prefix${AmountHelper.formatAmount(value)}';
}
