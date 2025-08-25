import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:provider/provider.dart';

class CouponModal extends StatefulWidget {
  final String initialCouponCode;
  final bool isCouponApplied;
  final Function(String, bool,
      {double? flatDiscount, double? percentageDiscount}) onCouponAction;

  const CouponModal({
    Key? key,
    required this.initialCouponCode,
    required this.isCouponApplied,
    required this.onCouponAction,
  }) : super(key: key);

  @override
  State<CouponModal> createState() => _CouponModalState();
}

class _CouponModalState extends State<CouponModal> {
  late TextEditingController couponController;
  late TextEditingController flatDiscountController;
  late TextEditingController percentageDiscountController;
  late bool isCouponApplied;

  @override

  void initState() {
    super.initState();
    couponController = TextEditingController(text: widget.initialCouponCode);

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final currentDiscounts = localProductProvider.getCurrentDiscount();

    flatDiscountController = TextEditingController(
        text: currentDiscounts['flatDiscount'] == 0.0
            ? ''
            : currentDiscounts['flatDiscount']?.toString());
    percentageDiscountController = TextEditingController(
        text: currentDiscounts['percentageDiscount'] == 0.0
            ? ''
            : currentDiscounts['percentageDiscount']?.toString());

    isCouponApplied = widget.isCouponApplied;

    // Add listeners for real-time calculation
    flatDiscountController.addListener(() => setState(() {}));
    percentageDiscountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    couponController.dispose();
    flatDiscountController.dispose();
    percentageDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        // Calculate totals directly from the provider's price summary
        final priceSummary = localProductProvider.priceSummary;
        final originalSubTotal = priceSummary?.originalSubTotal ?? 0.0;
        final currentFlatDiscount =
            double.tryParse(flatDiscountController.text) ?? 0.0;
        final currentPercentageDiscount =
            double.tryParse(percentageDiscountController.text) ?? 0.0;

        // Calculate the new total after applying current modal discounts
        final percentageDiscountValue =
            originalSubTotal * (currentPercentageDiscount / 100);
        final totalDiscount = currentFlatDiscount + percentageDiscountValue;
        final newTotal = originalSubTotal - totalDiscount;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: BuildBoxShadowContainer(
            circleRadius: 12,
            color: Colors.white,
            width: 450,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discount & Coupon',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.21,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Discount Fields
                Row(
                  children: [
                    // Flat Discount Field
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flat Discount',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.21,
                              ColorManager.textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 15),
                            height: 50,
                            child: TextField(
                              controller: flatDiscountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle: buildCustomStyle(
                                  FontWeight.w500,
                                  12,
                                  0.27,
                                  Colors.grey.withOpacity(.5),
                                ),
                                border: InputBorder.none,
                              ),
                              style: buildCustomStyle(
                                FontWeight.w500,
                                12,
                                0.27,
                                Colors.black.withOpacity(.5),
                              ),
                              onTap: () {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (flatDiscountController.text.isNotEmpty) {
                                    flatDiscountController.selection =
                                        TextSelection(
                                      baseOffset: 0,
                                      extentOffset:
                                          flatDiscountController.text.length,
                                    );
                                  }
                                });
                                Provider.of<KeyboardProvider>(context,
                                        listen: false)
                                    .show(
                                  'number',
                                  flatDiscountController,
                                  replaceOnFirstInput: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    // Percentage Discount Field
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Percentage Discount (%)',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.21,
                              ColorManager.textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 15),
                            height: 50,
                            child: TextField(
                              controller: percentageDiscountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: buildCustomStyle(
                                  FontWeight.w500,
                                  12,
                                  0.27,
                                  Colors.grey.withOpacity(.5),
                                ),
                                border: InputBorder.none,
                              ),
                              style: buildCustomStyle(
                                FontWeight.w500,
                                12,
                                0.27,
                                Colors.black.withOpacity(.5),
                              ),
                              onTap: () {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (percentageDiscountController
                                      .text.isNotEmpty) {
                                    percentageDiscountController.selection =
                                        TextSelection(
                                      baseOffset: 0,
                                      extentOffset: percentageDiscountController
                                          .text.length,
                                    );
                                  }
                                });
                                Provider.of<KeyboardProvider>(context,
                                        listen: false)
                                    .show(
                                  'number',
                                  percentageDiscountController,
                                  replaceOnFirstInput: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Coupon Code Field
                Text(
                  'Coupon Code (Optional)',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.21,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 15),
                  height: 50,
                  child: TextField(
                    controller: couponController,
                    enabled:
                        (!isCouponApplied || couponController.text.isEmpty),
                    decoration: InputDecoration(
                      hintText: 'Enter Coupon Code',
                      hintStyle: buildCustomStyle(
                        FontWeight.w500,
                        12,
                        0.27,
                        Colors.grey.withOpacity(.5),
                      ),
                      border: InputBorder.none,
                    ),
                    style: buildCustomStyle(
                      FontWeight.w500,
                      12,
                      0.27,
                      Colors.black.withOpacity(.5),
                    ),
                    onTap: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (couponController.text.isNotEmpty) {
                          couponController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: couponController.text.length,
                          );
                        }
                      });
                      Provider.of<KeyboardProvider>(context, listen: false)
                          .show(
                        'text',
                        couponController,
                        replaceOnFirstInput: true,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Updated Total Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColorManager.kButtonGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Net Total:',
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.21,
                              ColorManager.textColor,
                            ),
                          ),
                          Text(
                            'INR ${AmountHelper.formatAmount(originalSubTotal)}',
                            style: buildCustomStyle(
                              FontWeightManager.bold,
                              FontSize.s15,
                              0.21,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount Amount:',
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.21,
                              ColorManager.textColorRed,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'INR ${AmountHelper.formatAmount(totalDiscount)}',
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  FontSize.s15,
                                  0.21,
                                  ColorManager.textColorRed,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${(originalSubTotal > 0 ? ((totalDiscount / originalSubTotal) * 100) : 0.0).toStringAsFixed(1)}%)',
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.21,
                                  ColorManager.textColorRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total after Discount:',
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.21,
                              ColorManager.textColor,
                            ),
                          ),
                          Text(
                            'INR ${AmountHelper.formatAmount(newTotal)}',
                            style: buildCustomStyle(
                              FontWeightManager.bold,
                              FontSize.s15,
                              0.21,
                              ColorManager.kButtonGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomRoundButton(
                        title: "Clear All",
                        fct: () {
                          setState(() {
                            flatDiscountController.clear();
                            percentageDiscountController.clear();
                            couponController.clear();
                          });
                        },
                        fontSize: FontSize.s14,
                        height: 45,
                        width: double.infinity,
                        boxColor: Colors.grey.shade600,
                        borderColor: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: CustomRoundButton(
                        title: "Apply Discount",
                        fct: () {
                          double flatDiscount =
                              double.tryParse(flatDiscountController.text) ??
                                  0.0;
                          double percentageDiscount = double.tryParse(
                                  percentageDiscountController.text) ??
                              0.0;

                          widget.onCouponAction(
                            couponController.text,
                            flatDiscount > 0 ||
                                percentageDiscount > 0 ||
                                couponController.text.isNotEmpty,
                            flatDiscount: flatDiscount,
                            percentageDiscount: percentageDiscount,
                          );
                          Navigator.of(context).pop();
                        },
                        fontSize: FontSize.s14,
                        height: 45,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
