import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/features/billing/controllers/coordinators/payment_coordinator.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

class CouponSection extends StatefulWidget {
  const CouponSection({super.key});

  @override
  State<CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<CouponSection> {
  DiscountData? _selectedDiscount;
  late TextEditingController flatDiscountController;
  late TextEditingController percentageDiscountController;

  @override
  void initState() {
    super.initState();
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final currentDiscounts = localProductProvider.getCurrentDiscount();

    final initialFlat = currentDiscounts['flatDiscount'] ?? 0.0;
    final initialPercentage = currentDiscounts['percentageDiscount'] ?? 0.0;

    flatDiscountController = TextEditingController(
        text: initialFlat == 0.0 ? '' : initialFlat.toString());
    percentageDiscountController = TextEditingController(
        text: initialPercentage == 0.0 ? '' : initialPercentage.toString());

    flatDiscountController.addListener(_onManualDiscountChanged);
    percentageDiscountController.addListener(_onManualDiscountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final discountProvider = Provider.of<DiscountProvider>(context, listen: false);
      if (discountProvider.discounts.isEmpty && !discountProvider.isLoading) {
        await discountProvider.fetchDiscounts();
      }
      _findDiscountByCode(bp.coupenCodeTextController.text);
    });
  }

  @override
  void dispose() {
    flatDiscountController.removeListener(_onManualDiscountChanged);
    percentageDiscountController.removeListener(_onManualDiscountChanged);
    flatDiscountController.dispose();
    percentageDiscountController.dispose();
    super.dispose();
  }

  void _findDiscountByCode(String code) {
    if (code.isEmpty) return;
    final discountProvider = Provider.of<DiscountProvider>(context, listen: false);
    for (final discount in discountProvider.discounts) {
      if (discount.couponCode.toLowerCase() == code.toLowerCase()) {
        if (mounted) {
          setState(() {
            _selectedDiscount = discount;
          });
        }
        break;
      }
    }
  }

  void _onManualDiscountChanged() {
    if (flatDiscountController.text.isNotEmpty || percentageDiscountController.text.isNotEmpty) {
      if (_selectedDiscount != null) {
        setState(() {
          _selectedDiscount = null;
        });
      }
    }
  }

  void _onDiscountSelected(DiscountData? discount) {
    if (discount == null) return;
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
    });
  }

  bool _validateDiscountInputs(double originalSubTotal) {
    final flatDiscount = double.tryParse(flatDiscountController.text) ?? 0.0;
    final percentageDiscount = double.tryParse(percentageDiscountController.text) ?? 0.0;

    if (flatDiscount < 0 || percentageDiscount < 0) {
      showScaffoldError(context: context, message: 'Discount cannot be negative');
      return false;
    }
    if (percentageDiscount > 100) {
      showScaffoldError(context: context, message: 'Percentage discount cannot exceed 100%');
      return false;
    }
    if (flatDiscount > originalSubTotal && originalSubTotal > 0) {
      showScaffoldError(context: context, message: 'Flat discount cannot exceed cart total');
      return false;
    }
    return true;
  }

  Future<void> _applyDiscount() async {
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);
    final discountProvider = Provider.of<DiscountProvider>(context, listen: false);
    final originalSubTotal = localProductProvider.priceSummary?.originalSubTotal ?? 0.0;

    if (originalSubTotal == 0) {
      showScaffoldError(context: context, message: 'Cannot apply discount to empty cart');
      return;
    }
    if (!_validateDiscountInputs(originalSubTotal)) {
      return;
    }

    if (_selectedDiscount != null) {
      final validity = discountProvider.getValidityForDiscount(_selectedDiscount!, originalSubTotal);
      if (validity != DiscountValidity.valid) {
        showScaffoldError(
          context: context,
          message: 'Cannot apply ${_selectedDiscount!.couponName}: Coupon is not valid',
        );
        return;
      }
    }

    double flat = double.tryParse(flatDiscountController.text) ?? 0.0;
    double percent = double.tryParse(percentageDiscountController.text) ?? 0.0;

    localProductProvider.applyDiscount(flatDiscount: flat, percentageDiscount: percent);
    if (_selectedDiscount != null) {
      bp.coupenCodeTextController.text = _selectedDiscount!.couponCode;
      await PaymentCoordinator.applyCoupon(context);
      bp.setCouponApplied(true, code: _selectedDiscount!.couponCode, discount: flat > 0 ? flat : percent);
    } else {
      bp.coupenCodeTextController.text = '';
      bp.setCouponApplied(flat > 0 || percent > 0, code: '', discount: flat > 0 ? flat : percent);
    }
    if (mounted) {
      showScaffold(context: context, message: 'Discount applied successfully');
    }
  }

  void _clearDiscount() {
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

    localProductProvider.clearDiscount();
    bp.clearDiscounts();

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    if (customerId != null && accessToken != null) {
      Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId,
        accessToken: accessToken,
      );
    }

    setState(() {
      flatDiscountController.clear();
      percentageDiscountController.clear();
      _selectedDiscount = null;
    });

    showScaffold(context: context, message: 'Discount cleared');
  }

  @override
  Widget build(BuildContext context) {
    final discountProvider = Provider.of<DiscountProvider>(context);
    final localProductProvider = Provider.of<LocalProductProvider>(context);

    // Sync controllers if cart discount is cleared externally
    final currentDiscounts = localProductProvider.getCurrentDiscount();
    final flat = currentDiscounts['flatDiscount'] ?? 0.0;
    final pct = currentDiscounts['percentageDiscount'] ?? 0.0;
    if (flat == 0.0 && pct == 0.0 && (flatDiscountController.text.isNotEmpty || percentageDiscountController.text.isNotEmpty)) {
      flatDiscountController.clear();
      percentageDiscountController.clear();
      _selectedDiscount = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Discount Inputs Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Flat Discount',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: flatDiscountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.5),
                      ),
                    ),
                    onTap: () {
                      Provider.of<KeyboardProvider>(context, listen: false).show(
                        'number',
                        flatDiscountController,
                        replaceOnFirstInput: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Percentage Discount (%)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: percentageDiscountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.5),
                      ),
                    ),
                    onTap: () {
                      Provider.of<KeyboardProvider>(context, listen: false).show(
                        'number',
                        percentageDiscountController,
                        replaceOnFirstInput: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Select Coupon Dropdown
        const Text(
          'Select Coupon',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        CustomDropDownWithSearch<DiscountData>(
          hintText: 'Search or select a discount',
          value: _selectedDiscount,
          items: discountProvider.discounts,
          displayText: (discount) => '${discount.couponName} (${discount.couponCode})',
          onChanged: _onDiscountSelected,
          showName: false,
          isRequired: false,
          width: double.infinity,
        ),
        const SizedBox(height: 16),

        // Action Buttons Row (Clear / Apply Discount)
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFE2E8F0), // Light grey
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _clearDiscount,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: Color(0xFF0066CC),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF0066CC), // Primary blue
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _applyDiscount,
                child: const Text(
                  'Apply Discount',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
