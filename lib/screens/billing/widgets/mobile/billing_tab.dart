import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/billing_provider.dart';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary Actions Row
            Row(
              children: [
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
              ],
            ),
            const SizedBox(height: 12),
            // Confirm Order Button
            SizedBox(
              width: double.infinity,
              child: Consumer<LocalProductProvider>(
                builder: (context, provider, child) {
                  final hasItems = provider.cartItems.isNotEmpty;
                  return CustomRoundButton(
                    title: "Confirm Order",
                    fct: hasItems ? widget.onConfirmOrder : () {},
                    fontSize: 16,
                    height: 52,
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
            ]
          ],
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
