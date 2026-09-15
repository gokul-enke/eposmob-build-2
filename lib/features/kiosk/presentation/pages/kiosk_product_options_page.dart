import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_display.dart';
import 'package:pos_machine/features/kiosk/presentation/models/kiosk_order_draft.dart';
import 'package:pos_machine/features/kiosk/presentation/theme/kiosk_design_system.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_flow_scaffold.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

List<SaleUnit> kioskSelectableSaleUnits(GetProduct product) {
  final baseUnit = product.unit?.trim().toLowerCase() ?? '';
  final basePrice = kioskProductPrice(product);

  return (product.saleUnits ?? const <SaleUnit>[]).where((saleUnit) {
    final unitName = saleUnit.unitName?.trim().toLowerCase() ?? '';
    final conversionRate = saleUnit.conversionRateValue ?? 1;
    final unitPrice = SaleUnit.resolveDisplayPrice(
      product: product,
      saleUnit: saleUnit,
    );
    final sameName = baseUnit.isNotEmpty && unitName == baseUnit;
    final sameConversion = (conversionRate - 1).abs() < 0.0001;
    final samePrice =
        unitPrice == null || (unitPrice - basePrice).abs() < 0.005;
    return !(sameName && sameConversion && samePrice);
  }).toList();
}

bool kioskProductHasOptions(GetProduct product) {
  final hasVariants =
      product.variants?.any((variant) => variant.active) == true;
  return hasVariants || kioskSelectableSaleUnits(product).isNotEmpty;
}

Future<LocalCartItem?> showKioskProductOptionsModal(
  BuildContext context, {
  required GetProduct product,
  required String currency,
}) {
  final size = MediaQuery.sizeOf(context);
  final portrait = size.height > size.width;

  if (portrait) {
    return showModalBottomSheet<LocalCartItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990F172A),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: KioskProductOptionsPage(
          product: product,
          currency: currency,
          modal: true,
        ),
      ),
    );
  }

  return showDialog<LocalCartItem>(
    context: context,
    barrierColor: const Color(0x990F172A),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(32),
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KioskRadius.modal),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
        child: SizedBox(
          width: size.width * 0.88,
          height: size.height * 0.88,
          child: KioskProductOptionsPage(
            product: product,
            currency: currency,
            modal: true,
          ),
        ),
      ),
    ),
  );
}

class KioskProductOptionsPage extends StatefulWidget {
  final GetProduct product;
  final String currency;
  final bool modal;

  const KioskProductOptionsPage({
    super.key,
    required this.product,
    required this.currency,
    this.modal = false,
  });

  @override
  State<KioskProductOptionsPage> createState() =>
      _KioskProductOptionsPageState();
}

class _KioskProductOptionsPageState extends State<KioskProductOptionsPage> {
  final TextEditingController _noteController = TextEditingController();
  ProductVariant? _variant;
  SaleUnit? _saleUnit;
  int _quantity = 1;

  List<ProductVariant> get _variants =>
      widget.product.variants?.where((variant) => variant.active).toList() ??
      const [];

  List<SaleUnit> get _saleUnits => kioskSelectableSaleUnits(widget.product);

  @override
  void initState() {
    super.initState();
    if (_variants.length == 1) _variant = _variants.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _variantRequired => _variants.isNotEmpty;

  bool get _canAdd => !_variantRequired || _variant != null;

  double get _unitPrice => kioskProductPrice(
        widget.product,
        variant: _variant,
        saleUnit: _saleUnit,
      );

  void _addToOrder() {
    if (!_canAdd) return;
    final LocalCartItem item = createKioskDraftItem(
      product: widget.product,
      quantity: _quantity,
      variant: _variant,
      saleUnit: _saleUnit,
      note: _noteController.text,
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.product.localizedName?.trim().isNotEmpty == true
        ? widget.product.localizedName!.trim()
        : 'Unnamed product';
    final options = _OptionsPanel(
      product: widget.product,
      currency: widget.currency,
      variants: _variants,
      selectedVariant: _variant,
      onVariantSelected: (variant) => setState(() => _variant = variant),
      saleUnits: _saleUnits,
      selectedSaleUnit: _saleUnit,
      onSaleUnitSelected: (unit) => setState(() => _saleUnit = unit),
      quantity: _quantity,
      onQuantityChanged: (quantity) => setState(() => _quantity = quantity),
      noteController: _noteController,
      total: _unitPrice * _quantity,
      canAdd: _canAdd,
      onAdd: _addToOrder,
      showAction: !widget.modal,
    );

    if (widget.modal) {
      return Material(
        color: ColorManager.kBgLightColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KioskRadius.modal),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _ModalHeader(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 860;
                  final summary = _CompactProductSummary(
                    product: widget.product,
                    name: name,
                    currency: widget.currency,
                    price: _unitPrice,
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(KioskSpacing.lg),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 350, child: summary),
                              const SizedBox(width: KioskSpacing.lg),
                              Expanded(child: options),
                            ],
                          )
                        : Column(
                            children: [
                              summary,
                              const SizedBox(height: KioskSpacing.md),
                              options,
                            ],
                          ),
                  );
                },
              ),
            ),
            _ModalActionBar(
              quantity: _quantity,
              onQuantityChanged: (quantity) {
                setState(() => _quantity = quantity);
              },
              total: _unitPrice * _quantity,
              currency: widget.currency,
              canAdd: _canAdd,
              onAdd: _addToOrder,
            ),
          ],
        ),
      );
    }

    return KioskFlowScaffold(
      title: 'Customize item',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final padding =
              constraints.maxWidth < 600 ? KioskSpacing.md : KioskSpacing.xl;
          final productCard = _ProductOverview(
            product: widget.product,
            name: name,
            currency: widget.currency,
            price: _unitPrice,
          );
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: productCard),
                      const SizedBox(width: KioskSpacing.lg),
                      Expanded(flex: 6, child: options),
                    ],
                  )
                : Column(
                    children: [
                      productCard,
                      const SizedBox(height: KioskSpacing.md),
                      options,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _ModalHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KioskSpacing.xl,
        KioskSpacing.md,
        KioskSpacing.md,
        KioskSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E9F3))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('Customize item', style: KioskType.pageTitle),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            height: 52,
            child: IconButton(
              onPressed: onClose,
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded, size: 28),
              style: IconButton.styleFrom(
                foregroundColor: ColorManager.kTitleTextColor,
                backgroundColor: const Color(0xFFF0F4F9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactProductSummary extends StatelessWidget {
  final GetProduct product;
  final String name;
  final String currency;
  final double price;

  const _CompactProductSummary({
    required this.product,
    required this.name,
    required this.currency,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMarketProductImageUrl(product);
    final description = product.description?.toString().trim() ?? '';

    return KioskSurfaceCard(
      padding: const EdgeInsets.all(KioskSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(KioskRadius.control),
            child: SizedBox(
              width: 116,
              height: 116,
              child: ColoredBox(
                color: const Color(0xFFF3F6FA),
                child: imageUrl == null
                    ? const _ProductImageFallback()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _ProductImageFallback(),
                      ),
              ),
            ),
          ),
          const SizedBox(width: KioskSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KioskType.sectionTitle,
                ),
                const SizedBox(height: KioskSpacing.xs),
                Text(_money(currency, price), style: KioskType.price),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: KioskSpacing.xs),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KioskType.supporting,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 48,
        color: ColorManager.kGreyColor,
      ),
    );
  }
}

class _ModalActionBar extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final double total;
  final String currency;
  final bool canAdd;
  final VoidCallback onAdd;

  const _ModalActionBar({
    required this.quantity,
    required this.onQuantityChanged,
    required this.total,
    required this.currency,
    required this.canAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 14,
      shadowColor: const Color(0x260F172A),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(KioskSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final quantityControl = _QuantityControl(
              quantity: quantity,
              onQuantityChanged: onQuantityChanged,
              showLabel: !compact,
            );
            final addButton = SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: canAdd ? onAdd : null,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 23),
                label: Text(
                  'Add to order  •  ${_money(currency, total)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KioskType.action,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  disabledBackgroundColor: ColorManager.kGreyColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KioskRadius.control),
                  ),
                ),
              ),
            );

            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  quantityControl,
                  const SizedBox(height: KioskSpacing.sm),
                  SizedBox(width: double.infinity, child: addButton),
                ],
              );
            }

            return Row(
              children: [
                quantityControl,
                const SizedBox(width: KioskSpacing.lg),
                Expanded(child: addButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final bool showLabel;

  const _QuantityControl({
    required this.quantity,
    required this.onQuantityChanged,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          const Text('Quantity', style: KioskType.label),
          const SizedBox(width: KioskSpacing.sm),
        ],
        _QuantityButton(
          icon: Icons.remove_rounded,
          onPressed:
              quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: KioskType.sectionTitle,
          ),
        ),
        _QuantityButton(
          icon: Icons.add_rounded,
          onPressed: () => onQuantityChanged(quantity + 1),
        ),
      ],
    );
  }
}

class _ProductOverview extends StatelessWidget {
  final GetProduct product;
  final String name;
  final String currency;
  final double price;

  const _ProductOverview({
    required this.product,
    required this.name,
    required this.currency,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMarketProductImageUrl(product);
    final description = product.description?.toString().trim() ?? '';

    return KioskSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: ColoredBox(
                color: const Color(0xFFF7F9FC),
                child: imageUrl == null
                    ? const Icon(
                        Icons.inventory_2_outlined,
                        size: 78,
                        color: ColorManager.kGreyColor,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 72,
                          color: ColorManager.kGreyColor,
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: ColorManager.kTitleTextColor,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _money(currency, price),
                  style: const TextStyle(
                    color: ColorManager.kPrimaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    description,
                    style: const TextStyle(
                      color: ColorManager.kTextColor,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsPanel extends StatelessWidget {
  final GetProduct product;
  final String currency;
  final List<ProductVariant> variants;
  final ProductVariant? selectedVariant;
  final ValueChanged<ProductVariant> onVariantSelected;
  final List<SaleUnit> saleUnits;
  final SaleUnit? selectedSaleUnit;
  final ValueChanged<SaleUnit?> onSaleUnitSelected;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final TextEditingController noteController;
  final double total;
  final bool canAdd;
  final VoidCallback onAdd;
  final bool showAction;

  const _OptionsPanel({
    required this.product,
    required this.currency,
    required this.variants,
    required this.selectedVariant,
    required this.onVariantSelected,
    required this.saleUnits,
    required this.selectedSaleUnit,
    required this.onSaleUnitSelected,
    required this.quantity,
    required this.onQuantityChanged,
    required this.noteController,
    required this.total,
    required this.canAdd,
    required this.onAdd,
    this.showAction = true,
  });

  @override
  Widget build(BuildContext context) {
    return KioskSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (variants.isNotEmpty) ...[
            const KioskSectionTitle(
              'Choose an option',
              subtitle: 'Select one product variant',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: variants.map((variant) {
                return _ChoiceTile(
                  label: _variantLabel(variant),
                  price: variant.price == null
                      ? null
                      : _money(currency, variant.price!),
                  selected: selectedVariant?.id == variant.id,
                  onTap: () => onVariantSelected(variant),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),
          ],
          if (saleUnits.isNotEmpty) ...[
            const KioskSectionTitle(
              'Sale unit',
              subtitle: 'Choose how you want to buy this item',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ChoiceTile(
                  label: product.unit?.trim().isNotEmpty == true
                      ? 'Standard (${product.unit!.trim()})'
                      : 'Standard',
                  selected: selectedSaleUnit == null,
                  onTap: () => onSaleUnitSelected(null),
                ),
                ...saleUnits.map((unit) {
                  final price = SaleUnit.resolveDisplayPrice(
                    product: product,
                    saleUnit: unit,
                  );
                  return _ChoiceTile(
                    label: unit.unitName?.trim().isNotEmpty == true
                        ? unit.unitName!.trim()
                        : 'Unit',
                    price: price == null ? null : _money(currency, price),
                    selected: selectedSaleUnit?.id == unit.id,
                    onTap: () => onSaleUnitSelected(unit),
                  );
                }),
              ],
            ),
            const SizedBox(height: 26),
          ],
          const KioskSectionTitle(
            'Special instructions',
            subtitle: 'We will do our best to follow your request',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 3,
            maxLength: 180,
            decoration: InputDecoration(
              hintText: 'Example: no ice, less spicy…',
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (showAction) ...[
            const SizedBox(height: KioskSpacing.sm),
            _QuantityControl(
              quantity: quantity,
              onQuantityChanged: onQuantityChanged,
              showLabel: true,
            ),
          ],
          if (!canAdd) ...[
            const SizedBox(height: 14),
            const Text(
              'Please choose an option to continue.',
              style: TextStyle(color: Colors.redAccent),
            ),
          ],
          if (showAction) ...[
            const SizedBox(height: KioskSpacing.xl),
            KioskPrimaryButton(
              label: 'Add to order  •  ${_money(currency, total)}',
              icon: Icons.add_shopping_cart_rounded,
              onPressed: canAdd ? onAdd : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final String? price;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ColorManager.kPrimaryWithOpacity10
          : const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? ColorManager.kPrimaryColor
                  : const Color(0xFFE3E8F1),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? ColorManager.kPrimaryColor
                    : ColorManager.kGreyColor,
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: ColorManager.kTitleTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (price != null)
                    Text(
                      price!,
                      style: const TextStyle(
                        color: ColorManager.kPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryWithOpacity10,
          foregroundColor: ColorManager.kPrimaryColor,
          disabledForegroundColor: ColorManager.kGreyColor,
        ),
      ),
    );
  }
}

String _variantLabel(ProductVariant variant) {
  final values = variant.attributes.values
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .join(' • ');
  if (values.isNotEmpty) return values;
  if (variant.sku?.trim().isNotEmpty == true) return variant.sku!.trim();
  return 'Option ${variant.id}';
}

String _money(String currency, num value) {
  final prefix = currency.trim().isEmpty ? '' : '${currency.trim()} ';
  return '$prefix${AmountHelper.formatAmount(value)}';
}
