import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/widgets/compact_quantity_control_local.dart';
import 'package:websafe_svg/websafe_svg.dart';
import 'package:pos_machine/features/billing/presentation/widgets/price_fields.dart';

class CartItemsTable extends StatelessWidget {
  const CartItemsTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        final cartItems = localProductProvider.getCartItems();

        if (cartItems.isEmpty) {
          return _buildEmptyCart();
        }

        // Define fixed column widths for better mobile experience
        const double indexWidth = 40;
        const double itemNameWidth = 180;
        const double unitWidth = 60;
        const double qtyWidth = 120;
        const double mrpWidth = 80;
        const double priceWidth = 80;
        const double totalWidth = 80;
        const double actionsWidth = 50;

        const double totalTableWidth = indexWidth +
            itemNameWidth +
            unitWidth +
            qtyWidth +
            mrpWidth +
            priceWidth +
            totalWidth +
            actionsWidth;

        return Column(
          children: [
            // Scroll hint indicator
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Icon(
            //         Icons.swipe_left,
            //         size: 16,
            //         color: Colors.grey.shade500,
            //       ),
            //       const SizedBox(width: 4),
            //       Text(
            //         'Swipe to see all columns',
            //         style: TextStyle(
            //           fontSize: 11,
            //           color: Colors.grey.shade500,
            //           fontStyle: FontStyle.italic,
            //         ),
            //       ),
            //       const SizedBox(width: 4),
            //       Icon(
            //         Icons.swipe_right,
            //         size: 16,
            //         color: Colors.grey.shade500,
            //       ),
            //     ],
            //   ),
            // ),

            // Fixed header with horizontal scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                width: totalTableWidth,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: ColorManager.kPrimaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildFixedHeaderCell('billing.table_serial'.tr,
                        width: indexWidth, alignment: Alignment.center),
                    _buildFixedHeaderCell('billing.table_item_name'.tr,
                        width: itemNameWidth, alignment: Alignment.centerLeft),
                    _buildFixedHeaderCell('billing.table_unit'.tr,
                        width: unitWidth, alignment: Alignment.center),
                    _buildFixedHeaderCell('billing.quantity_hint'.tr,
                        width: qtyWidth, alignment: Alignment.center),
                    _buildFixedHeaderCell('billing.table_mrp'.tr,
                        width: mrpWidth, alignment: Alignment.center),
                    _buildFixedHeaderCell('billing.table_price'.tr,
                        width: priceWidth, alignment: Alignment.center),
                    _buildFixedHeaderCell('billing.table_total'.tr,
                        width: totalWidth, alignment: Alignment.center),
                    _buildFixedHeaderCell('',
                        width: actionsWidth, alignment: Alignment.center),
                  ],
                ),
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: totalTableWidth,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: index % 2 == 0
                              ? Colors.white
                              : Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Index Number
                            _buildFixedContentCell(
                              Text(
                                '${index + 1}',
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  12,
                                  0.21,
                                  ColorManager.textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              width: indexWidth,
                              alignment: Alignment.center,
                            ),

                            // Item Name
                            _buildFixedContentCell(
                              Tooltip(
                                message: item.displayName,
                                child: _buildItemNameCell(item),
                              ),
                              width: itemNameWidth,
                              alignment: Alignment.centerLeft,
                            ),

                            // Unit
                            _buildFixedContentCell(
                              Text(
                                item.displayUnitName,
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  12,
                                  0.21,
                                  ColorManager.textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              width: unitWidth,
                              alignment: Alignment.center,
                            ),

                            // Qty
                            _buildFixedContentCell(
                              CompactQuantityControlLocal(
                                key: ValueKey(
                                  'qty-${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.stockGroupIds.join('_')}-${item.saleUnitId ?? 'base'}-${item.variantId ?? 'variant-base'}',
                                ),
                                productId: item.product.productId!,
                                quantity: item.quantity.toDouble(),
                                unitPrice: item.price.toString(),
                                productUnit: item.product.unit,
                                product: item.product,
                                cartItem: item,
                                selectedStock: item.selectedStock,
                              ),
                              width: qtyWidth,
                              alignment: Alignment.center,
                            ),

                            // MRP
                            _buildFixedContentCell(
                              SizedBox(
                                width: 70,
                                child: MrpTextField(
                                  key: ValueKey(
                                    'mrp-${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.saleUnitId ?? 'base'}-${item.variantId ?? 'variant-base'}',
                                  ),
                                  item: item,
                                  localProductProvider: localProductProvider,
                                ),
                              ),
                              width: mrpWidth,
                              alignment: Alignment.center,
                            ),

                            // Price
                            _buildFixedContentCell(
                              SizedBox(
                                width: 70,
                                child: PriceTextField(
                                  key: ValueKey(
                                    'price-${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.saleUnitId ?? 'base'}-${item.variantId ?? 'variant-base'}',
                                  ),
                                  item: item,
                                  localProductProvider: localProductProvider,
                                ),
                              ),
                              width: priceWidth,
                              alignment: Alignment.center,
                            ),

                            // Total
                            _buildFixedContentCell(
                              Text(
                                (item.price! * item.quantity)
                                    .toStringAsFixed(2),
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  12,
                                  0.21,
                                  ColorManager.kPrimaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              width: totalWidth,
                              alignment: Alignment.center,
                            ),

                            // Actions
                            _buildFixedContentCell(
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  final billingProvider =
                                      Provider.of<BillingProvider>(context,
                                          listen: false);
                                  billingProvider.setLoadingAddItem(true);
                                  try {
                                    localProductProvider.removeFromCart(
                                      item.product.productId!,
                                      item.selectedStock,
                                      stockGroupIds: item.stockGroupIds,
                                      saleUnitId: item.saleUnitId,
                                      variantId: item.variantId,
                                    );
                                  } finally {
                                    billingProvider.setLoadingAddItem(false);
                                  }
                                },
                              ),
                              width: actionsWidth,
                              alignment: Alignment.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemNameCell(LocalCartItem item) {
    final variantLabel = item.variantLabel;
    if (variantLabel.isEmpty) {
      return Text(
        item.product.localizedName ?? 'general.unknown'.tr,
        style: buildCustomStyle(
          FontWeightManager.regular,
          12,
          0.21,
          ColorManager.textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.product.localizedName ?? 'general.unknown'.tr,
          style: buildCustomStyle(
            FontWeightManager.regular,
            12,
            0.21,
            ColorManager.textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          variantLabel,
          style: buildCustomStyle(
            FontWeightManager.medium,
            10,
            0.21,
            ColorManager.kPrimaryColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'billing.empty_cart'.tr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'billing.empty_cart_hint'.tr,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFixedHeaderCell(String text,
      {required double width, required Alignment alignment}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: alignment,
      child: Text(
        text,
        textAlign:
            alignment == Alignment.center ? TextAlign.center : TextAlign.left,
        style: buildCustomStyle(
          FontWeightManager.bold,
          12,
          0.21,
          ColorManager.textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFixedContentCell(Widget child,
      {required double width, required Alignment alignment}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: alignment,
      child: child,
    );
  }
}
