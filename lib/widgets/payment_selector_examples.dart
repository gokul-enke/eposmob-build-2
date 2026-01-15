import 'package:flutter/material.dart';
import '../components/build_payment_method_selector.dart';
import '../components/build_simple_payment_selector.dart';
import '../components/build_restricted_payment_selector.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

/// Example usage of payment selector components
/// This file demonstrates different configurations and use cases
class PaymentSelectorExamples extends StatefulWidget {
  const PaymentSelectorExamples({Key? key}) : super(key: key);

  @override
  State<PaymentSelectorExamples> createState() =>
      _PaymentSelectorExamplesState();
}

class _PaymentSelectorExamplesState extends State<PaymentSelectorExamples> {
  List<PaymentMethodData> advancedPaymentData = [];
  SimplePaymentData simplePaymentData = SimplePaymentData();
  RestrictedPaymentData restrictedPaymentData = RestrictedPaymentData();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Selector Examples'),
        backgroundColor: ColorManager.kPrimaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example 1: Simple Payment Selector (Recommended for most use cases)
            _buildSectionTitle('1. Simple Payment Selector (Recommended)'),
            _buildDescription(
                'Perfect for common scenarios: Cash only, Cash + UPI, or Cash + Card. '
                'Automatically handles validation and prevents more than 2 payment methods.'),
            BuildSimplePaymentSelector(
              title: "Select Payment Method",
              availableMethods: const [
                SimplePaymentType.cash,
                SimplePaymentType.card,
                SimplePaymentType.upi,
              ],
              onPaymentChanged: (data) {
                setState(() {
                  simplePaymentData = data;
                });
                debugPrint('Simple Payment Data: $data');
              },
              showTotalAmount: true,
              expectedAmount: 1500.0,
            ),
            const SizedBox(height: 12),
            _buildPaymentSummary(
                'Simple Payment Summary', _formatSimplePaymentData()),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Example 2: Cash + UPI Only
            _buildSectionTitle('2. Cash + UPI Only Configuration'),
            _buildDescription(
                'Restricted to only Cash and UPI payment methods.'),
            BuildSimplePaymentSelector(
              title: "Cash / UPI Payment",
              availableMethods: const [
                SimplePaymentType.cash,
                SimplePaymentType.upi,
              ],
              onPaymentChanged: (data) {
                debugPrint('Cash + UPI Payment: $data');
              },
              showTotalAmount: true,
              expectedAmount: 850.0,
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Example 3: Cash + Card Only
            _buildSectionTitle('3. Cash + Card Only Configuration'),
            _buildDescription(
                'Restricted to only Cash and Card payment methods.'),
            BuildSimplePaymentSelector(
              title: "Cash / Card Payment",
              availableMethods: const [
                SimplePaymentType.cash,
                SimplePaymentType.card,
              ],
              onPaymentChanged: (data) {
                debugPrint('Cash + Card Payment: $data');
              },
              showTotalAmount: true,
              expectedAmount: 2200.0,
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Example 4: Restricted Payment Selector (NEW - With Card Support)
            _buildSectionTitle('4. Restricted Payment Selector (Card Support)'),
            _buildDescription(
                'NEW: Supports Card but blocks Card + UPI combination. '
                'Allows: Cash+Card, Cash+UPI, Cash only, Card only, UPI only. '
                'Blocks: Card+UPI combination. Clean UI without restriction message.'),
            BuildRestrictedPaymentSelector(
              title: "Select Payment Method (Card Supported)",
              availableMethods: const [
                RestrictedPaymentType.cash,
                RestrictedPaymentType.card,
                RestrictedPaymentType.upi,
              ],
              onPaymentChanged: (data) {
                setState(() {
                  restrictedPaymentData = data;
                });
                debugPrint('Restricted Payment Data: $data');
              },
              showTotalAmount: true,
              expectedAmount: 1200.0,
              // No restriction message shown by default
            ),
            const SizedBox(height: 12),
            _buildPaymentSummary(
                'Restricted Payment Summary', _formatRestrictedPaymentData()),

            const SizedBox(height: 20),

            // Example 4b: With Restriction Message (Optional)
            Text(
              'Optional: With Restriction Info Message',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.27,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            BuildRestrictedPaymentSelector(
              title: "Payment with Info Message",
              availableMethods: const [
                RestrictedPaymentType.cash,
                RestrictedPaymentType.card,
                RestrictedPaymentType.upi,
              ],
              onPaymentChanged: (data) {
                debugPrint('Payment with Info: $data');
              },
              showTotalAmount: true,
              expectedAmount: 800.0,
              showRestrictionInfo: true, // Enable the info box
              restrictionMessage: "Card and UPI cannot be used together",
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Example 5: Advanced Payment Selector (For complex scenarios)
            _buildSectionTitle('5. Advanced Payment Selector'),
            _buildDescription(
                'Advanced component with more flexibility. Use this when you need '
                'custom validation logic or more complex payment combinations.'),
            BuildPaymentMethodSelector(
              title: "Advanced Payment Options",
              availableMethods: const [
                PaymentMethod.cash,
                PaymentMethod.card,
                PaymentMethod.upi,
              ],
              onPaymentChanged: (data) {
                setState(() {
                  advancedPaymentData = data;
                });
                debugPrint('Advanced Payment Data: $data');
              },
              showAmountInputs: true,
              totalAmount: 3000.0,
              validateTotalAmount: true,
            ),
            const SizedBox(height: 12),
            _buildPaymentSummary(
                'Advanced Payment Summary', _formatAdvancedPaymentData()),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // Usage Guidelines
            _buildSectionTitle('Usage Guidelines'),
            _buildGuidelines(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s18,
          0.30,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        description,
        style: buildCustomStyle(
          FontWeightManager.regular,
          FontSize.s14,
          0.27,
          Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(String title, String summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.27,
              Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelines() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Component Selection Guide:',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildGuideline('✅ Use BuildSimplePaymentSelector for most cases'),
          _buildGuideline(
              '✅ Supports max 2 payment methods (as per business requirements)'),
          _buildGuideline('✅ Built-in validation and total amount checking'),
          _buildGuideline(
              '✅ Optimized for common combinations: Cash+UPI, Cash+Card'),
          const SizedBox(height: 8),
          _buildGuideline(
              '⚙️ Use BuildPaymentMethodSelector for complex scenarios'),
          _buildGuideline('⚙️ When you need custom validation logic'),
          _buildGuideline('⚙️ When working with dynamic payment method lists'),
        ],
      ),
    );
  }

  Widget _buildGuideline(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: buildCustomStyle(
          FontWeightManager.regular,
          FontSize.s12,
          0.27,
          Colors.grey.shade700,
        ),
      ),
    );
  }

  String _formatSimplePaymentData() {
    if (!simplePaymentData.hasPaymentMethods) {
      return 'No payment methods selected';
    }

    List<String> methods = [];
    if (simplePaymentData.primaryMethod != null) {
      methods.add(
          '${_getSimpleMethodName(simplePaymentData.primaryMethod!)}: ${simplePaymentData.primaryAmount}');
    }
    if (simplePaymentData.secondaryMethod != null) {
      methods.add(
          '${_getSimpleMethodName(simplePaymentData.secondaryMethod!)}: ${simplePaymentData.secondaryAmount}');
    }

    return 'Methods: ${methods.join(", ")} | Total: ${simplePaymentData.totalAmount.toStringAsFixed(2)}';
  }

  String _formatRestrictedPaymentData() {
    if (!restrictedPaymentData.hasPaymentMethods) {
      return 'No payment methods selected';
    }

    List<String> methods = [];
    if (restrictedPaymentData.primaryMethod != null) {
      methods.add(
          '${_getRestrictedMethodName(restrictedPaymentData.primaryMethod!)}: ${restrictedPaymentData.primaryAmount}');
    }
    if (restrictedPaymentData.secondaryMethod != null) {
      methods.add(
          '${_getRestrictedMethodName(restrictedPaymentData.secondaryMethod!)}: ${restrictedPaymentData.secondaryAmount}');
    }

    return 'Methods: ${methods.join(", ")} | Total: ${restrictedPaymentData.totalAmount.toStringAsFixed(2)}';
  }

  String _formatAdvancedPaymentData() {
    if (advancedPaymentData.isEmpty) {
      return 'No payment methods selected';
    }

    double total = 0;
    List<String> methods = [];

    for (PaymentMethodData data in advancedPaymentData) {
      double amount = double.tryParse(data.amount) ?? 0;
      total += amount;
      methods.add('${_getAdvancedMethodName(data.method)}: ${data.amount}');
    }

    return 'Methods: ${methods.join(", ")} | Total: ${total.toStringAsFixed(2)}';
  }

  String _getSimpleMethodName(SimplePaymentType method) {
    switch (method) {
      case SimplePaymentType.cash:
        return 'Cash';
      case SimplePaymentType.card:
        return 'Card';
      case SimplePaymentType.upi:
        return 'UPI';
    }
  }

  String _getRestrictedMethodName(RestrictedPaymentType method) {
    switch (method) {
      case RestrictedPaymentType.cash:
        return 'Cash';
      case RestrictedPaymentType.card:
        return 'Card';
      case RestrictedPaymentType.upi:
        return 'UPI';
    }
  }

  String _getAdvancedMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.upi:
        return 'UPI';
    }
  }
}

/// Example of how to integrate payment selectors in a billing screen
class BillingWithPaymentExample extends StatefulWidget {
  final double totalBillAmount;

  const BillingWithPaymentExample({
    Key? key,
    required this.totalBillAmount,
  }) : super(key: key);

  @override
  State<BillingWithPaymentExample> createState() =>
      _BillingWithPaymentExampleState();
}

class _BillingWithPaymentExampleState extends State<BillingWithPaymentExample> {
  SimplePaymentData paymentData = SimplePaymentData();
  bool isPaymentValid = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bill summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Bill Amount:',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s16,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              Text(
                '${widget.totalBillAmount.toStringAsFixed(2)}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s18,
                  0.30,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Payment selector
        BuildSimplePaymentSelector(
          title: "Select Payment Method",
          onPaymentChanged: (data) {
            setState(() {
              paymentData = data;
              isPaymentValid = data.totalAmount == widget.totalBillAmount;
            });
          },
          showTotalAmount: true,
          expectedAmount: widget.totalBillAmount,
        ),

        const SizedBox(height: 16),

        // Payment action button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isPaymentValid ? _processPayment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isPaymentValid ? ColorManager.kSuccessColor : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isPaymentValid ? 'Process Payment' : 'Enter Valid Payment Amount',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.27,
                Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _processPayment() {
    // Process payment logic here
    debugPrint('Processing payment: $paymentData');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment processed successfully!'),
        backgroundColor: ColorManager.kSuccessColor,
      ),
    );
  }
}
