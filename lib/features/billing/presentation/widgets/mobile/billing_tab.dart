import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/pine_labs_terminal_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/customer_input.dart';
import 'package:pos_machine/features/billing/presentation/widgets/payment_summary.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_section_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/payment_methods_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/delivery_options_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/coupon_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_action_buttons.dart';

/// Mobile "Billing & Payment" tab. Pure layout/composition: each section is its
/// own widget under `mobile/billing/`, and the action bar is
/// [BillingActionButtons]. Business logic lives in `BillingMobileController`.
class MobileBillingTab extends StatefulWidget {
  final GlobalKey autocompletePhoneKey;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final bool isConfirmingOrder;

  const MobileBillingTab({
    super.key,
    required this.autocompletePhoneKey,
    required this.onConfirmOrder,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    this.isConfirmingOrder = false,
  });

  @override
  State<MobileBillingTab> createState() => _MobileBillingTabState();
}

class _MobileBillingTabState extends State<MobileBillingTab> {
  @override
  void initState() {
    super.initState();
    // Proactively bind Pine Labs so the first payment attempt doesn't need to bind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final terminalProvider = context.read<PineLabsTerminalProvider>();
        terminalProvider.ensureBinding();
      } catch (_) {
        // Ignore; UI will still allow manual binding on first attempt.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Safe bottom padding so content can scroll fully above the persistent
    // bottomSheet buttons (padding 16 + row 48 + gap 12 + button 52 + padding 16).
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const double bottomActionsHeight = 144;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(
                  Icons.payment,
                  color: ColorManager.kPrimaryColor,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Billing & Payment',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                bottomActionsHeight + bottomInset + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Section
                  BillingSectionCard(
                    title: 'Customer Information',
                    icon: Icons.person,
                    child: CustomerInput(
                      size: size,
                      autocompletePhoneKey: widget.autocompletePhoneKey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Methods Section
                  const BillingSectionCard(
                    title: 'Payment Methods',
                    icon: Icons.credit_card,
                    child: PaymentMethodsSection(),
                  ),
                  const SizedBox(height: 16),

                  // Delivery & Options Section
                  const BillingSectionCard(
                    title: 'Delivery & Options',
                    icon: Icons.local_shipping,
                    child: DeliveryOptionsSection(),
                  ),
                  const SizedBox(height: 16),

                  // Coupon Section
                  const BillingSectionCard(
                    title: 'Discount & Coupon',
                    icon: Icons.local_offer,
                    child: CouponSection(),
                  ),
                  const SizedBox(height: 16),

                  // Payment Summary
                  const BillingSectionCard(
                    title: 'Order Summary',
                    icon: Icons.receipt,
                    child: PaymentSummary(compact: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Action Buttons
      bottomSheet: BillingActionButtons(
        onSaveOrder: widget.onSaveOrder,
        onCreateOrderAndPrint: widget.onCreateOrderAndPrint,
        onConfirmOrder: widget.onConfirmOrder,
        isConfirmingOrder: widget.isConfirmingOrder,
      ),
    );
  }
}
