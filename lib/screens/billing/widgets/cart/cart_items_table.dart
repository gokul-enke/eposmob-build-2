import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/widgets/compact_quantity_control_local.dart';
import 'package:websafe_svg/websafe_svg.dart';
import 'package:pos_machine/screens/billing/widgets/price_fields.dart';

class CartItemsTable extends StatelessWidget {
  const CartItemsTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        final cartItems = localProductProvider.getCartItems();

        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                children: [
                  // Fixed header
                  Container(
                    color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        _buildHeaderCell('#', flex: 1, alignment: Alignment.center),
                        _buildHeaderCell('Item Name', flex: 3, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Unit', flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Qty', flex: 2, alignment: Alignment.center),
                        _buildHeaderCell('MRP', flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Price', flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Total', flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Actions', flex: 1, alignment: Alignment.centerLeft),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            return Container(
                              color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                              child: Row(
                                children: [
                                  // Index Number
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        '${index + 1}',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          11,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.center,
                                  ),

                                  // Item Name
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        item.product.productName ?? 'Unknown',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          11,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    flex: 3,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Unit
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        item.product.unit ?? '-',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          11,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Qty
                                  _buildContentCell(
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: CompactQuantityControlLocal(
                                          productId: item.product.productId!,
                                          quantity: item.quantity.toDouble(),
                                          unitPrice: item.price.toString(),
                                          productUnit: item.product.unit,
                                          product: item.product,
                                          selectedStock: item.selectedStock,
                                        ),
                                      ),
                                    ),
                                    flex: 2,
                                    alignment: Alignment.center,
                                  ),

                                  // MRP
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: MrpTextField(
                                          item: item,
                                          localProductProvider: localProductProvider,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Price
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: PriceTextField(
                                          item: item,
                                          localProductProvider: localProductProvider,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Total
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: Text(
                                          (item.price! * item.quantity).toStringAsFixed(3),
                                          style: const TextStyle(fontSize: 11),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Actions
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: IconButton(
                                        icon: WebsafeSvg.asset(
                                          ImageAssets.oderlistCloseIcon,
                                          width: 15,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final billingProvider = Provider.of<BillingProvider>(context, listen: false);
                                          billingProvider.setLoadingAddItem(true);
                                          try {
                                            localProductProvider.removeFromCart(
                                              item.product.productId!,
                                              item.selectedStock,
                                            );
                                          } finally {
                                            billingProvider.setLoadingAddItem(false);
                                          }
                                        },
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderCell(String text, {required int flex, required Alignment alignment}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: alignment,
        child: Text(
          text,
          textAlign: alignment == Alignment.center ? TextAlign.center : TextAlign.left,
          style: buildCustomStyle(
            FontWeightManager.bold,
            12,
            0.21,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildContentCell(Widget child, {required int flex, required Alignment alignment}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        alignment: alignment,
        child: child,
      ),
    );
  }
}
