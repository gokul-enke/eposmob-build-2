import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/pine_labs_terminal_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/screens/billing/widgets/customer_input.dart';
import 'package:pos_machine/screens/billing/widgets/payment_summary.dart';
import 'package:pos_machine/screens/billing/coordinators/payment_coordinator.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

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
        final terminalProvider =
            context.read<PineLabsTerminalProvider>();
        terminalProvider.ensureBinding();
      } catch (_) {
        // Ignore; UI will still allow manual binding on first attempt.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Calculate a safe bottom padding so content can scroll fully above the
    // persistent bottomSheet buttons. This avoids the Order Summary being
    // partially hidden behind the buttons.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Approximate height of bottom actions: padding(16) + row(48) + gap(12) + button(52) + padding(16)
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
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                // Add extra bottom padding so last section clears the bottomSheet
                bottomActionsHeight + bottomInset + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Section
                  _buildSectionCard(
                    title: 'Customer Information',
                    icon: Icons.person,
                    child: CustomerInput(
                      size: size,
                      autocompletePhoneKey: widget.autocompletePhoneKey,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Methods Section
                  _buildSectionCard(
                    title: 'Payment Methods',
                    icon: Icons.credit_card,
                    child: _buildPaymentMethodsSection(),
                  ),

                  const SizedBox(height: 16),

                  // Delivery & Options Section
                  _buildSectionCard(
                    title: 'Delivery & Options',
                    icon: Icons.local_shipping,
                    child: _buildDeliveryOptionsSection(),
                  ),

                  const SizedBox(height: 16),

                  // Coupon Section
                  _buildSectionCard(
                    title: 'Discount & Coupon',
                    icon: Icons.local_offer,
                    child: _buildCouponSection(),
                  ),

                  const SizedBox(height: 16),

                  // Payment Summary
                  _buildSectionCard(
                    title: 'Order Summary',
                    icon: Icons.receipt,
                    child: const PaymentSummary(compact: false),
                  ),

                  // Bottom spacing now handled by scroll view padding above
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Action Buttons
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Save Order
            Expanded(
              child: CustomRoundButton(
                title: "Save Order",
                fct: widget.onSaveOrder,
                fontSize: 14,
                height: 48,
                width: double.infinity,
                boxColor: Colors.orange.shade50,
                borderColor: Colors.orange.shade300,
                textColor: Colors.orange.shade700,
                radius: 12,
              ),
            ),
            const SizedBox(width: 12),
            // Print Order
            Expanded(
              child: CustomRoundButton(
                title: "Print Order",
                fct: widget.onCreateOrderAndPrint,
                fontSize: 14,
                height: 48,
                width: double.infinity,
                boxColor: Colors.blue.shade50,
                borderColor: Colors.blue.shade300,
                textColor: Colors.blue.shade700,
                radius: 12,
              ),
            ),
            const SizedBox(width: 12),
            // Confirm Order
            Expanded(
              child: Consumer<LocalProductProvider>(
                builder: (context, provider, child) {
                  final hasItems = provider.cartItems.isNotEmpty;
                  return CustomRoundButton(
                    title: "Confirm Order",
                    fct: hasItems ? widget.onConfirmOrder : () {},
                    fontSize: 14,
                    height: 48,
                    width: double.infinity,
                    boxColor: hasItems
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade300,
                    borderColor: hasItems
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade300,
                    textColor: hasItems ? Colors.white : Colors.grey.shade600,
                    radius: 12,
                    isLoading: widget.isConfirmingOrder,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return BuildBoxShadowContainer(
      circleRadius: 12,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: ColorManager.kPrimaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        final selectedMethods =
            provider.getSelectedPaymentMethodsExcludingEmpty();

        // Build a single row styled exactly like Delivery section
        final summaryText = selectedMethods.isEmpty
            ? 'Select Payment Method'
            : selectedMethods.join(', ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => PaymentCoordinator.showPaymentMethodModal(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payment,
                      color: ColorManager.kPrimaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            summaryText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selectedMethods.isEmpty
                                  ? Colors.grey.shade700
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (selectedMethods.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOptionButton(
                      selectedMethods.length > 1
                          ? 'Modify Payment Methods'
                          : 'Change Payment Method',
                      Icons.edit,
                      () => PaymentCoordinator.showPaymentMethodModal(context),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _buildPineLabsSection(context),
          ],
        );
      },
    );
  }

  Widget _buildPineLabsSection(BuildContext context) {
    return Consumer2<PineLabsTerminalProvider, BillingProvider>(
      builder: (context, terminalProvider, billingProvider, child) {
        final totalAmount = billingProvider.totalOrderAmount;
        final billingRefNo = billingProvider.transactionNumberController.text;
        // Debug: trace state when widget rebuilds (e.g., after loading saved order)
        debugPrint('🧩 [PineLabs UI] pineLabsPaymentSuccess=${billingProvider.pineLabsPaymentSuccess} | methods=${billingProvider.getSelectedPaymentMethods()} | ref=$billingRefNo');

        return CustomRoundButton(
          title: terminalProvider.isProcessing
              ? 'Processing...'
              : billingProvider.pineLabsPaymentSuccess
                  ? 'Paid with Pinelabs  ✓'
                  : 'Pay with Pine Labs',
          fct: () async {
            if (totalAmount <= 0) {
              showScaffoldError(
                context: context,
                message: 'Invalid amount for Pine Labs payment',
              );
              return;
            }

            // reset success state before a new attempt
            billingProvider.setPineLabsPaymentSuccess(false);

            final String resultStr = await terminalProvider.processSale(
              amount: totalAmount,
              billingRefNo: billingRefNo.isEmpty
                  ? 'REF-${DateTime.now().millisecondsSinceEpoch}'
                  : billingRefNo,
            );
            // Prefer parsing the direct result string
            try {
              Map<String, dynamic> decoded = jsonDecode(resultStr);
              final response = decoded['Response'] as Map<String, dynamic>?;
              final dynamic rawCode = response?['ResponseCode'];
              final int code = rawCode is int
                  ? rawCode
                  : int.tryParse(rawCode?.toString() ?? '') ?? -1;
              final String msg = (response?['ResponseMsg'] ?? '').toString();

              if (code == 0) {
                // Extract reference number if available
                final detail = decoded['Detail'] as Map<String, dynamic>?;
                final String ref = (detail?['RetrievalReferenceNumber'] ??
                        detail?['ApprovalCode'] ??
                        detail?['BillingRefNo'] ??
                        '')
                    .toString();
                
                debugPrint('✅ [PineLabs] Payment SUCCESS');
                debugPrint('📋 [PineLabs] Reference Number: $ref');
                
                billingProvider.setPineLabsPaymentSuccess(true);
                
                // Update provider with ONLINE payment and reference number
                debugPrint('💳 [PineLabs] Setting payment method to ONLINE...');
                billingProvider.setPaymentMethod('ONLINE', true);
                
                debugPrint('🔢 [PineLabs] Setting transaction reference: $ref');
                billingProvider.transactionNumberController.text = ref;
                
                // Verify the payment method was set
                final selectedMethods = billingProvider.getSelectedPaymentMethodsExcludingEmpty();
                debugPrint('✔️ [PineLabs] Selected payment methods after setting ONLINE: $selectedMethods');
                debugPrint('✔️ [PineLabs] isOnlineSelected flag: ${billingProvider.isOnlineSelected}');
                
                showScaffold(
                  context: context,
                  message: msg.isNotEmpty ? msg : 'Pine Labs payment successful',
                );
              } else {
                billingProvider.setPineLabsPaymentSuccess(false);
                showScaffoldError(
                  context: context,
                  message: msg.isNotEmpty ? msg : 'Pine Labs payment failed',
                );
              }
            } catch (_) {
              // Fallback to simple contains if result is not JSON
              final String normalized = resultStr.toUpperCase();
              final bool isSuccess = normalized.contains('SUCCESS') ||
                  normalized.contains('APPROVED') ||
                  normalized.contains('TXN SUCCESS');
              if (isSuccess) {
                billingProvider.setPineLabsPaymentSuccess(true);
                showScaffold(
                  context: context,
                  message: 'Pine Labs payment successful',
                );
              } else {
                billingProvider.setPineLabsPaymentSuccess(false);
                showScaffoldError(
                  context: context,
                  message: resultStr.isEmpty
                      ? 'Pine Labs payment failed'
                      : resultStr,
                );
              }
            }
          },
          fontSize: 14,
          height: 48,
          width: double.infinity,
          radius: 12,
          boxColor:
              billingProvider.pineLabsPaymentSuccess ? ColorManager.kGreen : ColorManager.kPrimaryColor,
          borderColor:
              billingProvider.pineLabsPaymentSuccess ? ColorManager.kGreen : ColorManager.kPrimaryColor,
          textColor: Colors.white,
          isLoading: terminalProvider.isProcessing,
        );
      },
    );
  }

  Widget _buildDeliveryOptionsSection() {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Delivery Method Button
            GestureDetector(
              onTap: () => PaymentCoordinator.showDeliveryMethodModal(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      color: ColorManager.kPrimaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Method',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            provider.deliveryMethod ?? 'Store Takeaway',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Additional Options
            Row(
              children: [
                // Expanded(
                //   child: _buildOptionButton(
                //     'Set Date/Time',
                //     Icons.schedule,
                //     () => PaymentCoordinator.showDeliveryMethodModal(context),
                //   ),
                // ),
                // const SizedBox(width: 8),
                Expanded(
                  child: _buildOptionButton(
                    'Add Comment',
                    Icons.comment,
                    () => _showCommentDialog(context),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionButton(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponSection() {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Coupon Input Button
            GestureDetector(
              onTap: () => PaymentCoordinator.showCouponModal(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer,
                      color: ColorManager.kPrimaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Discount / Coupon',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            provider.coupenCodeTextController.text.isEmpty
                                ? 'Add or apply coupon'
                                : provider.coupenCodeTextController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color:
                                  provider.coupenCodeTextController.text.isEmpty
                                      ? Colors.grey.shade700
                                      : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            // Applied Discount Info
            Consumer<LocalProductProvider>(
              builder: (context, localProvider, child) {
                final summary = localProvider.priceSummary;
                if (summary != null &&
                    (summary.flatDiscount > 0 ||
                        summary.percentageDiscount > 0)) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Discount Applied: ₹${(summary.flatDiscount + summary.percentageDiscount).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCommentDialog(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.comment,
                      color: ColorManager.kPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Add Comment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Text Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: provider.commentController,
                  maxLength: 200,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Comment',
                    hintText: 'Enter any special instructions or notes...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: ColorManager.kPrimaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(height: 12),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: ColorManager.kPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          showScaffold(
                            context: context,
                            message: 'Comment updated',
                          );
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
