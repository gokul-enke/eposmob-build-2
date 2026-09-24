import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/billing/domain/non_stock_visibility.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_sheet_header.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// Desktop/wide-window breakpoint: below this width the picker behaves like a
/// mobile bottom sheet (edge-to-edge, drag handle); at or above it, the same
/// content is shown as a centered, fully-rounded dialog — matching
/// [StockSelectionModal]'s presentation on desktop billing screens.
const double _kDesktopVariantPickerBreakpoint = 700;

/// Shows a variant picker before add-to-cart: a bottom sheet on narrow/mobile
/// screens, a centered dialog on desktop/wide screens.
Future<ProductVariant?> showMobileVariantPickerSheet({
  required BuildContext context,
  required GetProduct product,
  int? activeStoreId,
}) {
  final isDesktop =
      MediaQuery.sizeOf(context).width >= _kDesktopVariantPickerBreakpoint;

  if (isDesktop) {
    return showDialog<ProductVariant>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _MobileVariantPickerSheet(
            product: product,
            activeStoreId: activeStoreId,
            expandToFill: false,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<ProductVariant>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _MobileVariantPickerSheet(
      product: product,
      activeStoreId: activeStoreId,
    ),
  );
}

class _MobileVariantPickerSheet extends StatefulWidget {
  const _MobileVariantPickerSheet({
    required this.product,
    this.activeStoreId,
    this.expandToFill = true,
  });

  final GetProduct product;
  final int? activeStoreId;

  /// True for the mobile bottom sheet (fills the draggable sheet extent).
  /// False for the desktop dialog, where the content should size itself to
  /// its constraints instead of expanding to fill the screen.
  final bool expandToFill;

  @override
  State<_MobileVariantPickerSheet> createState() =>
      _MobileVariantPickerSheetState();
}

class _MobileVariantPickerSheetState extends State<_MobileVariantPickerSheet> {
  ProductVariant? _selected;

  @override
  void initState() {
    super.initState();
    var active = ProductVariantSelection.activeVariantsForStore(
      widget.product,
      activeStoreId: widget.activeStoreId,
    );
    // Never pre-select a variant the list is about to hide.
    if (NonStockVisibility.isEnabledIn(context, listen: false)) {
      active = NonStockVisibility.visibleVariants(active);
    }
    if (active.length == 1) {
      _selected = active.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expandToFill) {
      // Desktop dialog: size to content instead of a draggable fraction of
      // the screen.
      return _buildContent(context, null);
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) =>
            _buildContent(context, scrollController),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ScrollController? scrollController) {
    final activeVariants = ProductVariantSelection.activeVariantsForStore(
      widget.product,
      activeStoreId: widget.activeStoreId,
    );
    // POS_HIDE_NONSTOCK_PRODUCT: out-of-stock variants are not offered at all.
    final variants = NonStockVisibility.isEnabledIn(context)
        ? NonStockVisibility.visibleVariants(activeVariants)
        : activeVariants;
    final productPrice =
        ProductVariantSelection.productBasePrice(widget.product);
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? '';

    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: widget.expandToFill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          MobileSheetHeader(
            title: widget.product.productName ?? 'billing.select_variant'.tr,
            subtitle: 'billing.choose_variant_to_cart'.tr,
            thumbnail: buildProductThumbnail(
              productName: widget.product.productName,
              attachments: widget.product.attachment,
            ),
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            fit: widget.expandToFill ? FlexFit.tight : FlexFit.loose,
            child: ListView.separated(
              controller: scrollController,
              shrinkWrap: !widget.expandToFill,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: variants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final variant = variants[index];
                final isSelected = _selected?.id == variant.id;
                final effectivePrice = variant.effectivePrice(productPrice);
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      'product.sku_prefix'.tr + (variant.sku ?? ''),
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
                                      'billing.out_of_stock'.tr,
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
                                    'general.quantity_prefix'.tr +
                                        variant.quantity.toString(),
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
                child: Text(
                  'billing.add_to_cart'.tr,
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
  }
}
