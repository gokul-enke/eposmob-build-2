import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/features/billing/domain/billing_crash_guards.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
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
  static const _couponController = BillingMobileCouponController();
  static const _paymentController = BillingMobilePaymentController();

  DiscountData? _selectedDiscount;
  late TextEditingController flatDiscountController;
  late TextEditingController percentageDiscountController;

  @override
  void initState() {
    super.initState();
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final currentDiscounts = localProductProvider.getCurrentDiscount();

    final initialFlat = currentDiscounts['flatDiscount'] ?? 0.0;
    final initialPercentage = currentDiscounts['percentageDiscount'] ?? 0.0;

    flatDiscountController = TextEditingController(
      text: _couponController.initialDiscountFieldText(initialFlat),
    );
    percentageDiscountController = TextEditingController(
      text: _couponController.initialDiscountFieldText(initialPercentage),
    );

    flatDiscountController.addListener(_onManualDiscountChanged);
    percentageDiscountController.addListener(_onManualDiscountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final discountProvider =
          Provider.of<DiscountProvider>(context, listen: false);
      if (discountProvider.discounts.isEmpty && !discountProvider.isLoading) {
        try {
          await discountProvider.fetchDiscounts();
        } catch (_) {
          if (mounted) {
            showScaffoldError(
              context: context,
              message: BillingMobileErrorMessages.loadDiscountsFailed,
            );
          }
        }
      }
      if (!mounted) return;
      final match = _couponController.findDiscountByCode(
        discountProvider.discounts,
        bp.coupenCodeTextController.text,
      );
      if (match != null && mounted) {
        setState(() {
          _selectedDiscount = match;
        });
      }
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

  void _onManualDiscountChanged() {
    if (_couponController.shouldClearSelectedCouponOnManualInput(
      flatDiscountText: flatDiscountController.text,
      percentageDiscountText: percentageDiscountController.text,
      selectedDiscount: _selectedDiscount,
    )) {
      setState(() {
        _selectedDiscount = null;
      });
    }
  }

  void _onDiscountSelected(DiscountData? discount) {
    if (discount == null) return;
    final values = _couponController.fieldValuesForSelectedDiscount(discount);

    setState(() {
      flatDiscountController.text = values.flat;
      percentageDiscountController.text = values.percent;
      _selectedDiscount = discount;
    });
  }

  Future<void> _applyDiscount() async {
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final discountProvider =
        Provider.of<DiscountProvider>(context, listen: false);

    final result = await _couponController.applyDiscount(
      localProductProvider: localProductProvider,
      billingProvider: bp,
      discountProvider: discountProvider,
      paymentController: _paymentController,
      flatDiscountText: flatDiscountController.text,
      percentageDiscountText: percentageDiscountController.text,
      selectedDiscount: _selectedDiscount,
      applyCouponApi: () async {
        await PaymentCoordinator.applyCoupon(context);
        return bp.isCouponApplied;
      },
    );

    if (!mounted) return;

    if (!result.success) {
      if (result.errorMessage != null) {
        showScaffoldError(context: context, message: result.errorMessage!);
      }
      return;
    }

    showScaffold(
      context: context,
      message: 'billing.discount_applied_successfully'.tr,
    );
  }

  void _clearDiscount() {
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final auth = Provider.of<AuthModel>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    _couponController.clearDiscount(
      localProductProvider: localProductProvider,
      billingProvider: bp,
      paymentController: _paymentController,
      accessToken: BillingCrashGuards.accessTokenOrNull(auth.token),
      customerId: auth.userId,
      refreshCart: ({required int customerId, required String accessToken}) {
        cartProvider.fetchCartDataFromApi(
          customerId: customerId,
          accessToken: accessToken,
        );
      },
    );

    setState(() {
      flatDiscountController.clear();
      percentageDiscountController.clear();
      _selectedDiscount = null;
    });

    showScaffold(context: context, message: 'billing.discount_cleared'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final discountProvider = Provider.of<DiscountProvider>(context);
    final localProductProvider = Provider.of<LocalProductProvider>(context);

    final currentDiscounts = localProductProvider.getCurrentDiscount();
    final flat = currentDiscounts['flatDiscount'] ?? 0.0;
    final pct = currentDiscounts['percentageDiscount'] ?? 0.0;
    if (_couponController.shouldSyncClearedDiscountFields(
      flatDiscount: flat,
      percentageDiscount: pct,
      flatFieldText: flatDiscountController.text,
      percentageFieldText: percentageDiscountController.text,
    )) {
      flatDiscountController.clear();
      percentageDiscountController.clear();
      _selectedDiscount = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'coupon.flat_discount'.tr,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: flatDiscountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                        borderSide: const BorderSide(
                            color: ColorManager.kPrimaryColor, width: 1.5),
                      ),
                    ),
                    onTap: () {
                      Provider.of<KeyboardProvider>(context, listen: false)
                          .show(
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
                  Text(
                    'coupon.percentage_discount'.tr,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: percentageDiscountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                        borderSide: const BorderSide(
                            color: ColorManager.kPrimaryColor, width: 1.5),
                      ),
                    ),
                    onTap: () {
                      Provider.of<KeyboardProvider>(context, listen: false)
                          .show(
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

        Text(
          'coupon.select_coupon'.tr,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        CustomDropDownWithSearch<DiscountData>(
          hintText: 'coupon.search_or_select'.tr,
          value: _selectedDiscount,
          items: discountProvider.discounts,
          displayText: (discount) =>
              '${discount.couponName} (${discount.couponCode})',
          onChanged: _onDiscountSelected,
          showName: false,
          isRequired: false,
          width: double.infinity,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
                  backgroundColor: const Color(0xFF0066CC),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
