// Add this class after the ProductSelectionModal class
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class StockSelectionModal extends StatelessWidget {
  final GetProduct product;
  final List<Stock> stockOptions;

  const StockSelectionModal({
    Key? key,
    required this.product,
    required this.stockOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Multiple Stock Options Available',
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s16,
                    0.21,
                    ColorManager.kPrimaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Product: ${product.productName}',
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s16,
                0.21,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 12),
            // Stock list
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
                    itemCount: stockOptions.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final stock = stockOptions[index];
                      return BuildBoxShadowContainer(
                        circleRadius: 7,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            'Stock ID: ${stock.id}',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s14,
                              0.21,
                              ColorManager.textColor,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Price: ₹${stock.price ?? "0.00"}',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'MRP: ₹${stock.mrp ?? "0.00"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Available Quantity: ${stock.quantity ?? 0}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorManager.kPrimaryColor,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () {
                              // Return both product and selected stock
                              Navigator.pop(context, {
                                'product': product,
                                'stock': stock,
                              });
                            },
                            child: const Text('Choose'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Close Button
                CustomRoundButton(
                  title: "Cancel",
                  fontSize: FontSize.s12,
                  height: MediaQuery.of(context).size.height * .05,
                  width: 120,
                  textColor: Colors.blue,
                  borderColor: Colors.blue,
                  boxColor: Colors.white,
                  fct: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                // Add Product Button
                CustomRoundButton(
                  title: "Add New Stock",
                  fontSize: FontSize.s12,
                  height: MediaQuery.of(context).size.height * .05,
                  width: 120,
                  fct: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
