import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class CouponModal extends StatefulWidget {
  final double? subTotal;
  final double? initialFlatDiscount;
  final double? initialPercentageDiscount;
  final String initialCouponCode;
  final bool isCouponApplied;
  final Function(String, bool,
      {double? flatDiscount, double? percentageDiscount}) onCouponAction;
  final bool closeOnApply; // Optional flag to control modal closing behavior

  const CouponModal({
    super.key,
    this.subTotal,
    this.initialFlatDiscount,
    this.initialPercentageDiscount,
    required this.initialCouponCode,
    required this.isCouponApplied,
    required this.onCouponAction,
    this.closeOnApply = true,
  });

  @override
  State<CouponModal> createState() => _CouponModalState();
}

class _CouponModalState extends State<CouponModal> {
  DiscountData? _selectedDiscount;
  late TextEditingController flatDiscountController;
  late TextEditingController percentageDiscountController;
  late bool isCouponApplied;
  bool _isLoading = false;
  Timer? _debounceTimer;

  late DiscountProvider _discountProvider;

  @override
  void initState() {
    super.initState();

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final currentDiscounts = localProductProvider.getCurrentDiscount();

    final initialFlat =
        widget.initialFlatDiscount ?? currentDiscounts['flatDiscount'] ?? 0.0;
    final initialPercentage = widget.initialPercentageDiscount ??
        currentDiscounts['percentageDiscount'] ??
        0.0;

    flatDiscountController = TextEditingController(
        text: initialFlat == 0.0 ? '' : initialFlat.toString());
    percentageDiscountController = TextEditingController(
        text: initialPercentage == 0.0 ? '' : initialPercentage.toString());

    isCouponApplied = widget.isCouponApplied;

    flatDiscountController.addListener(() {
      _onManualDiscountChanged();
      _debounceManualDiscountChange();
    });
    percentageDiscountController.addListener(() {
      _onManualDiscountChanged();
      _debounceManualDiscountChange();
    });

    _discountProvider = Provider.of<DiscountProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDiscountsIfNeeded();
      _findDiscountByCode(widget.initialCouponCode);
    });
  }

  @override
  void dispose() {
    flatDiscountController.dispose();
    percentageDiscountController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debounceManualDiscountChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  Future<void> _fetchDiscountsIfNeeded() async {
    if (_discountProvider.discounts.isEmpty && !_discountProvider.isLoading) {
      await _discountProvider.fetchDiscounts();
    }
  }

  void _findDiscountByCode(String? couponCode) {
    if (couponCode == null || couponCode!.isEmpty) {
      _selectedDiscount = null;
      return;
    }
    try {
      for (final discount in _discountProvider.discounts) {
        if (discount.couponCode.toLowerCase() == couponCode!.toLowerCase()) {
          _selectedDiscount = discount;
          return;
        }
      }
    } catch (e) {
      _selectedDiscount = null;
    }
  }

  void _onManualDiscountChanged() {
    final hasFlat = flatDiscountController.text.isNotEmpty;
    final hasPercentage = percentageDiscountController.text.isNotEmpty;

    if (hasFlat || hasPercentage) {
      if (_selectedDiscount != null) {
        setState(() {
          _selectedDiscount = null;
        });
      }
    }
  }

  void _onDiscountSelected(DiscountData discount) {
    debugPrint(
        '🎫 Discount selected: ${discount.couponName} (${discount.couponCode})');
    debugPrint('  - Type: ${discount.discountType}');
    debugPrint('  - Value: ${discount.discountValue}');
    debugPrint('  - Min Amount: ${discount.discountCouponMinAmount}');
    debugPrint('  - Max Amount: ${discount.discountCouponMaxAmount}');
    debugPrint('  - Valid From: ${discount.validFromDate}');
    debugPrint('  - Valid To: ${discount.validToDate}');

    final isPercentage = discount.discountType.toLowerCase() == 'percent';
    final finalValue = discount.discountValue.toDouble();

    setState(() {
      if (isPercentage) {
        flatDiscountController.clear();
        percentageDiscountController.text = finalValue.toString();
      } else {
        flatDiscountController.text = finalValue.toString();
        percentageDiscountController.clear();
      }
      _selectedDiscount = discount;
      isCouponApplied = false;
    });

    debugPrint('🎫 Coupon selected - Manual discounts will be replaced');
  }

  bool _validateDiscountInputs(double originalSubTotal) {
    final flatDiscount = double.tryParse(flatDiscountController.text) ?? 0.0;
    final percentageDiscount =
        double.tryParse(percentageDiscountController.text) ?? 0.0;

    if (flatDiscount < 0) {
      showScaffoldError(
        context: context,
        message: 'Flat discount cannot be negative',
      );
      return false;
    }

    if (percentageDiscount < 0) {
      showScaffoldError(
        context: context,
        message: 'Percentage discount cannot be negative',
      );
      return false;
    }

    if (percentageDiscount > 100) {
      showScaffoldError(
        context: context,
        message: 'Percentage discount cannot exceed 100%',
      );
      return false;
    }

    if (flatDiscount > originalSubTotal && originalSubTotal > 0) {
      showScaffoldError(
        context: context,
        message: 'Flat discount cannot exceed cart total',
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocalProductProvider, AppSettingsProvider,
        DiscountProvider>(
      builder: (context, localProductProvider, appSettingsProvider,
          discountProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
        final size = MediaQuery.of(context).size;

        final priceSummary = localProductProvider.priceSummary;
        final originalSubTotal =
            widget.subTotal ?? priceSummary?.originalSubTotal ?? 0.0;
        final currentFlatDiscount =
            double.tryParse(flatDiscountController.text) ?? 0.0;
        final currentPercentageDiscount =
            double.tryParse(percentageDiscountController.text) ?? 0.0;

        final percentageDiscountValue =
            originalSubTotal * (currentPercentageDiscount / 100);
        final totalDiscount = currentFlatDiscount + percentageDiscountValue;
        final newTotal = originalSubTotal - totalDiscount;
        final isCartEmpty = originalSubTotal == 0;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: BuildBoxShadowContainer(
            circleRadius: 12,
            color: Colors.white,
            width: (size.width * 0.85).clamp(450.0, 900.0),
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
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: size.height * 0.7,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            padding:
                                                const EdgeInsets.only(left: 15),
                                            height: 50,
                                            child: TextField(
                                              controller:
                                                  flatDiscountController,
                                              keyboardType:
                                                  const TextInputType
                                                          .numberWithOptions(
                                                      decimal: true,
                                                      signed: false),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(RegExp(r'[\d\.]')),
                                              ],
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
                                                  if (flatDiscountController
                                                      .text.isNotEmpty) {
                                                    flatDiscountController
                                                            .selection =
                                                        TextSelection(
                                                      baseOffset: 0,
                                                      extentOffset:
                                                          flatDiscountController
                                                              .text.length,
                                                    );
                                                  }
                                                });
                                                Provider.of<KeyboardProvider>(
                                                        context,
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            padding:
                                                const EdgeInsets.only(left: 15),
                                            height: 50,
                                            child: TextField(
                                              controller:
                                                  percentageDiscountController,
                                              keyboardType:
                                                  const TextInputType
                                                          .numberWithOptions(
                                                      decimal: false,
                                                      signed: false),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(RegExp(r'[\d]')),
                                              ],
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
                                                    percentageDiscountController
                                                            .selection =
                                                        TextSelection(
                                                      baseOffset: 0,
                                                      extentOffset:
                                                          percentageDiscountController
                                                              .text.length,
                                                    );
                                                  }
                                                });
                                                Provider.of<KeyboardProvider>(
                                                        context,
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
                                Text(
                                  'Select Coupon',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.21,
                                    ColorManager.textColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CustomDropDownWithSearch<DiscountData>(
                                  hintText: 'Search or select a discount',
                                  value: _selectedDiscount,
                                  items: discountProvider.discounts,
                                  onChanged: (val) {
                                    if (val != null) {
                                      _onDiscountSelected(val!);
                                    }
                                  },
                                  displayText: (discount) =>
                                      '${discount.couponCode} - ${discount.couponName}',
                                  searchHintText: 'Search by code or name...',
                                  showName: false,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 0),
                                  height: 50,
                                  autofocus: false,
                                ),
                                const SizedBox(height: 20),
                                if (_selectedDiscount != null)
                                  _buildDiscountDetailsCard(_selectedDiscount!,
                                      currency, discountProvider),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Net Total:',
                                            style: buildCustomStyle(
                                              FontWeightManager.semiBold,
                                              FontSize.s14,
                                              0.21,
                                              Colors.grey.shade800,
                                            ),
                                          ),
                                          Text(
                                            '$currency ${AmountHelper.formatAmount(originalSubTotal)}',
                                            style: buildCustomStyle(
                                              FontWeightManager.bold,
                                              FontSize.s15,
                                              0.21,
                                              Colors.grey.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Discount Amount:',
                                            style: buildCustomStyle(
                                              FontWeightManager.semiBold,
                                              FontSize.s14,
                                              0.21,
                                              Colors.red.shade700,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '-$currency ${AmountHelper.formatAmount(totalDiscount)}',
                                                style: buildCustomStyle(
                                                  FontWeightManager.bold,
                                                  FontSize.s15,
                                                  0.21,
                                                  Colors.red.shade700,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${(originalSubTotal > 0 ? ((totalDiscount / originalSubTotal) * 100) : 0.0).toStringAsFixed(1)}%',
                                                  style: buildCustomStyle(
                                                    FontWeightManager.semiBold,
                                                    FontSize.s11,
                                                    0.21,
                                                    Colors.red.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Divider(
                                        height: 16,
                                        color: Colors.grey.shade300,
                                        thickness: 1,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total after Discount:',
                                            style: buildCustomStyle(
                                              FontWeightManager.semiBold,
                                              FontSize.s14,
                                              0.21,
                                              Colors.grey.shade800,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ColorManager.kPrimaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '$currency ${AmountHelper.formatAmount(newTotal)}',
                                              style: buildCustomStyle(
                                                FontWeightManager.bold,
                                                FontSize.s16,
                                                0.21,
                                                Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (isCartEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange.shade300,
                                          width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Cart is empty. Add products before applying discounts.',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s11,
                                              0.21,
                                              Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomRoundButton(
                                        title: "Clear All",
                                        fct: () {
                                          setState(() {
                                            flatDiscountController.clear();
                                            percentageDiscountController
                                                .clear();
                                            _selectedDiscount = null;
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
                                        title: _isLoading
                                            ? "Applying..."
                                            : "Apply Discount",
                                        fct: _isLoading
                                            ? () {}
                                            : () {
                                                if (originalSubTotal == 0) {
                                                  showScaffoldError(
                                                    context: context,
                                                    message:
                                                        'Cannot apply discount to empty cart',
                                                  );
                                                  return;
                                                }

                                                if (!_validateDiscountInputs(
                                                    originalSubTotal)) {
                                                  return;
                                                }

                                                if (_selectedDiscount != null) {
                                                  final localProductProvider =
                                                      Provider.of<LocalProductProvider>(
                                                          context,
                                                          listen: false);
                                                  final priceSummary =
                                                      localProductProvider
                                                          .priceSummary;
                                                  final cartTotal = widget
                                                          .subTotal ??
                                                      priceSummary
                                                          ?.originalSubTotal ??
                                                      0.0;
                                                  final validity =
                                                      discountProvider
                                                          .getValidityForDiscount(
                                                    _selectedDiscount!,
                                                    cartTotal,
                                                  );
                                                  if (validity !=
                                                      DiscountValidity.valid) {
                                                    showScaffoldError(
                                                      context: context,
                                                      message:
                                                          'Cannot apply ${_selectedDiscount!.couponName}: Coupon is not valid',
                                                    );
                                                    return;
                                                  }
                                                }
                                                double flatDiscount =
                                                    double.tryParse(
                                                            flatDiscountController
                                                                .text) ??
                                                        0.0;
                                                double percentageDiscount =
                                                    double.tryParse(
                                                            percentageDiscountController
                                                                .text) ??
                                                        0.0;

                                                widget.onCouponAction(
                                                  '', // Send empty code to treat as simple discount
                                                  flatDiscount > 0 ||
                                                      percentageDiscount > 0,
                                                  flatDiscount: flatDiscount,
                                                  percentageDiscount:
                                                      percentageDiscount,
                                                );
                                                if (widget.closeOnApply) {
                                                  Navigator.of(context).pop();
                                                }
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscountDetailsCard(
    DiscountData discount,
    String currency,
    DiscountProvider discountProvider,
  ) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final priceSummary = localProductProvider.priceSummary;
    final cartTotal = widget.subTotal ?? priceSummary?.originalSubTotal ?? 0.0;

    final validity = discountProvider.getValidityForDiscount(
      discount,
      cartTotal,
    );

    final isPercentage = discount.discountType.toLowerCase() == 'percent';
    final discountText = isPercentage
        ? '${discount.discountValue}%'
        : '$currency${AmountHelper.formatAmount(discount.discountValue.toDouble())}';

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (validity) {
      case DiscountValidity.valid:
        badgeColor = Colors.green.shade600;
        badgeText = 'Valid';
        badgeIcon = Icons.check_circle;
        break;
      case DiscountValidity.belowMin:
        badgeColor = Colors.orange.shade600;
        badgeText = 'Below min';
        badgeIcon = Icons.warning;
        break;
      case DiscountValidity.aboveMax:
        badgeColor = Colors.orange.shade600;
        badgeText = 'Above max';
        badgeIcon = Icons.warning;
        break;
      case DiscountValidity.expired:
        badgeColor = Colors.red.shade600;
        badgeText = 'Expired';
        badgeIcon = Icons.cancel;
        break;
      case DiscountValidity.notStarted:
        badgeColor = Colors.grey.shade600;
        badgeText = 'Not started';
        badgeIcon = Icons.schedule;
        break;
    }

    final isClickable = validity == DiscountValidity.valid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: validity == DiscountValidity.valid
            ? Colors.green.shade50
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: validity == DiscountValidity.valid
              ? Colors.green.shade300
              : Colors.red.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                badgeIcon,
                size: 20,
                color: badgeColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  discount.couponName,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.21,
                    isClickable ? Colors.black87 : Colors.grey.shade700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: validity == DiscountValidity.valid
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  discountText,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s13,
                    0.21,
                    Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (validity != DiscountValidity.valid) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      validity == DiscountValidity.belowMin
                          ? 'Cart amount is below minimum (Min: $currency${AmountHelper.formatAmount(discount.discountCouponMinAmount?.toDouble() ?? 0.0)})'
                          : validity == DiscountValidity.aboveMax
                              ? 'Cart amount exceeds maximum (Max: $currency${AmountHelper.formatAmount(discount.discountCouponMaxAmount?.toDouble() ?? 0.0)})'
                              : validity == DiscountValidity.expired
                                  ? 'Coupon has expired'
                                  : 'Coupon not yet active',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.21,
                        Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
