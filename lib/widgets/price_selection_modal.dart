import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

// Price Selection Modal Widget
class PriceSelectionModal extends StatelessWidget {
  final Function(double) onPriceSelected;
  final String productName;
  final List<double> prices;

  const PriceSelectionModal({
    Key? key,
    required this.onPriceSelected,
    required this.productName,
    required this.prices,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint("🎯 PRICE MODAL: Building price selection modal for: $productName");
    debugPrint("🎯 PRICE MODAL: Available prices: $prices");
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Select Price for',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.18,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              productName,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.16,
                ColorManager.kPrimaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: prices.length,
                itemBuilder: (context, index) {
                  final price = prices[index];
                  return GestureDetector(
                    onTap: () {
                      debugPrint("🎯 PRICE MODAL: User selected price: ₹$price");
                      onPriceSelected(price);
                      Navigator.of(context).pop(price);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: ColorManager.kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorManager.kPrimaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '₹${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.16,
                            ColorManager.kPrimaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      debugPrint("🎯 PRICE MODAL: User cancelled price selection");
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: ColorManager.kButtonRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.16,
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}