import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_sheet_header.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// Mobile bottom sheet for choosing a product variant before add-to-cart.
Future<ProductVariant?> showMobileVariantPickerSheet({
  required BuildContext context,
  required GetProduct product,
}) {
  return showModalBottomSheet<ProductVariant>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _MobileVariantPickerSheet(product: product),
  );
}

class _MobileVariantPickerSheet extends StatefulWidget {
  const _MobileVariantPickerSheet({required this.product});

  final GetProduct product;

  @override
  State<_MobileVariantPickerSheet> createState() =>
      _MobileVariantPickerSheetState();
}

class _MobileVariantPickerSheetState extends State<_MobileVariantPickerSheet> {
  ProductVariant? _selected;

  @override
  void initState() {
    super.initState();
    final active = widget.product.activeVariants;
    if (active.length == 1) {
      _selected = active.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.activeVariants;
    final productPrice = ProductVariantSelection.productBasePrice(widget.product);
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? '';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return ColoredBox(
            color: Colors.white,
            child: Column(
            children: [
              MobileSheetHeader(
                title: widget.product.productName ?? 'Select variant',
                subtitle: 'Choose a variant to add to cart',
                thumbnail: buildProductThumbnail(
                  productName: widget.product.productName,
                  attachments: widget.product.attachment,
                ),
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: variants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final variant = variants[index];
                    final isSelected = _selected?.id == variant.id;
                    final effectivePrice =
                        variant.effectivePrice(productPrice);
                    final outOfStock =
                        ProductVariantSelection.isOutOfStock(variant);
                    final label = variant.formattedAttributes.isEmpty
                        ? (variant.sku ?? 'Variant ${index + 1}')
                        : variant.formattedAttributes;

                    // Out-of-stock variants stay selectable: the cashier may
                    // hold the physical item, and the add-to-cart flow asks
                    // for an oversell confirmation instead of blocking.
                    return Opacity(
                      opacity: outOfStock ? 0.6 : 1,
                      child: Material(
                        color: isSelected
                            ? ColorManager.kPrimaryColor.withValues(alpha: 0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => setState(() => _selected = variant),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? ColorManager.kPrimaryColor
                                    : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (variant.sku != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'SKU: ${variant.sku}',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                      if (outOfStock) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Out of stock',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currency.isEmpty
                                          ? effectivePrice.toStringAsFixed(2)
                                          : '$currency ${effectivePrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: ColorManager.kPrimaryColor,
                                      ),
                                    ),
                                    if (variant.quantity != null)
                                      Text(
                                        'Qty: ${variant.quantity}',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    color: ColorManager.kPrimaryColor,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.kPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }
}
