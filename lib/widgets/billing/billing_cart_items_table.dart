import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/widgets/compact_quantity_control_local.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

class BillingCartItemsTable extends StatelessWidget {
  final Size size;

  const BillingCartItemsTable({
    Key? key,
    required this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        List<LocalCartItem> cartItems = localProductProvider.getCartItems();

        return LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: constraints.maxWidth, maxHeight: 200),
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 20,
                  horizontalMargin: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.transparent),
                  ),
                  headingRowColor: WidgetStateColor.resolveWith(
                      (states) => ColorManager.kPrimaryColor.withOpacity(0.1)),
                  dataRowColor: WidgetStateColor.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.grey.shade100
                          : Colors.white),
                  dividerThickness: 0,
                  columns: [
                    DataColumn(
                      label: Expanded(
                        child: Text('Item Name',
                            textAlign: TextAlign.center,
                            style: buildCustomStyle(FontWeightManager.bold, 14,
                                0.21, ColorManager.textColor)),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Text('Unit',
                            textAlign: TextAlign.center,
                            style: buildCustomStyle(FontWeightManager.bold, 14,
                                0.21, ColorManager.textColor)),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Text('Quantity',
                            textAlign: TextAlign.center,
                            style: buildCustomStyle(FontWeightManager.bold, 14,
                                0.21, ColorManager.textColor)),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Text('Unit Price',
                            textAlign: TextAlign.center,
                            style: buildCustomStyle(FontWeightManager.bold, 14,
                                0.21, ColorManager.textColor)),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Text('Total Price',
                            textAlign: TextAlign.center,
                            style: buildCustomStyle(FontWeightManager.bold, 14,
                                0.21, ColorManager.textColor)),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Text('Actions',
                            textAlign: TextAlign.center,
                            style: buildCustomStyle(FontWeightManager.bold, 14,
                                0.21, ColorManager.textColor)),
                      ),
                    ),
                  ],
                  rows: cartItems.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Align(
                          alignment: Alignment.center,
                          child: Text(
                            item.product.productName ?? 'Unknown',
                            style: buildCustomStyle(FontWeightManager.regular,
                                12, 0.21, ColorManager.textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        )),
                        DataCell(Align(
                          alignment: Alignment.center,
                          child: Text(
                            item.product.unit ?? '-',
                            style: buildCustomStyle(FontWeightManager.regular,
                                12, 0.21, ColorManager.textColor),
                            textAlign: TextAlign.center,
                          ),
                        )),
                        DataCell(Center(
                          child: CompactQuantityControlLocal(
                            productId: item.product.productId!,
                            quantity: item.quantity.toDouble(),
                            unitPrice: item.price.toString(),
                            productUnit: item.product.unit,
                            product: item.product,
                            selectedStock: item.selectedStock,
                          ),
                        )),
                        DataCell(Center(
                          child: SizedBox(
                            width: 80,
                            child: Builder(builder: (context) {
                              // Create a controller that we can actually reference
                              final TextEditingController controller =
                                  TextEditingController(
                                      text: item.price.toString());
                              final FocusNode focusNode = FocusNode();

                              // Add listener to focus node to select all text when focused
                              focusNode.addListener(() {
                                if (focusNode.hasFocus) {
                                  controller.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: controller.text.length,
                                  );
                                } else {
                                  // When focus is lost, update the price
                                  localProductProvider.updateItemPrice(
                                    item.product.productId!,
                                    double.tryParse(controller.text) ??
                                        item.price!,
                                  );
                                }
                              });

                              return TextField(
                                textAlign: TextAlign.center,
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Unit Price',
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                onSubmitted: (newPrice) {
                                  // Update when user presses enter
                                  localProductProvider.updateItemPrice(
                                    item.product.productId!,
                                    double.tryParse(newPrice) ?? item.price!,
                                  );
                                },
                              );
                            }),
                          ),
                        )),
                        DataCell(
                          Center(
                            child: SizedBox(
                              width: 80,
                              child: Text(
                                (item.price! * item.quantity)
                                    .toStringAsFixed(2),
                              ),
                            ),
                          ),
                        ),
                        DataCell(Center(
                          child: IconButton(
                            icon: WebsafeSvg.asset(
                              ImageAssets.oderlistCloseIcon,
                              width: 15,
                            ),
                            onPressed: () {
                              localProductProvider
                                  .removeFromCart(item.product.productId!);
                            },
                          ),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
} 