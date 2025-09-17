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

class MobileBillingTab extends StatefulWidget {
  final GlobalKey autocompletePhoneKey;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;

  const MobileBillingTab({
    super.key,
    required this.autocompletePhoneKey,
    required this.onConfirmOrder,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
  });

  @override
  State<MobileBillingTab> createState() => _MobileBillingTabState();
}

class _MobileBillingTabState extends State<MobileBillingTab> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.payment,
                  color: ColorManager.kPrimaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
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
              padding: const EdgeInsets.all(16),
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

                  const SizedBox(height: 100), // Space for bottom actions
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
                    boxColor: hasItems ? ColorManager.kPrimaryColor : Colors.grey.shade300,
                    borderColor: hasItems ? ColorManager.kPrimaryColor : Colors.grey.shade300,
                    textColor: hasItems ? Colors.white : Colors.grey.shade600,
                    radius: 12,
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
        return Column(
          children: [
            // Payment Method Buttons
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodButton(
                    'Cash',
                    Icons.money,
                    provider.isCashSelected,
                    () => PaymentCoordinator.showPaymentMethodModal(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentMethodButton(
                    'Card',
                    Icons.credit_card,
                    provider.isCardSelected,
                    () => PaymentCoordinator.showPaymentMethodModal(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodButton(
                    'UPI',
                    Icons.qr_code,
                    provider.isUpiSelected,
                    () => PaymentCoordinator.showPaymentMethodModal(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentMethodButton(
                    'Debit',
                    Icons.account_balance,
                    provider.isDebitSelected,
                    () => PaymentCoordinator.showPaymentMethodModal(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Selected Payment Methods Summary
            if (provider.getSelectedPaymentMethodsExcludingEmpty().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ColorManager.kPrimaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Payment Methods:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ColorManager.kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...provider.getSelectedPaymentMethodsExcludingEmpty().map(
                      (method) => Text(
                        '• $method',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodButton(
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? ColorManager.kPrimaryColor.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? ColorManager.kPrimaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? ColorManager.kPrimaryColor : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? ColorManager.kPrimaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
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
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
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
                Expanded(
                  child: _buildOptionButton(
                    'Set Date/Time',
                    Icons.schedule,
                    () => PaymentCoordinator.showDeliveryMethodModal(context),
                  ),
                ),
                const SizedBox(width: 8),
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
          color: Colors.grey.shade50,
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
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
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
                            'Apply Coupon',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            provider.coupenCodeTextController.text.isEmpty
                                ? 'Tap to add coupon code'
                                : provider.coupenCodeTextController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: provider.coupenCodeTextController.text.isEmpty
                                  ? Colors.grey.shade600
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
                    (summary.flatDiscount > 0 || summary.percentageDiscount > 0)) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: provider.commentController,
          decoration: const InputDecoration(
            hintText: 'Enter your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
