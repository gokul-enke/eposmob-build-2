import 'package:flutter/material.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/screens/billing/widgets/delivery_method_modal.dart';
import 'package:pos_machine/screens/billing/mobile_screen/widgets/payment_method_modal_wrapper.dart';
import 'package:provider/provider.dart';

class BillingWidget extends StatefulWidget {
  const BillingWidget({super.key});

  @override
  State<BillingWidget> createState() => _BillingWidgetState();
}

class _BillingWidgetState extends State<BillingWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<BillingProvider, LocalProductProvider>(
      builder: (context, billingProvider, localProvider, child) {
        final cartTotal = localProvider.cartTotal;
        final priceSummary = localProvider.priceSummary;
        final subtotal = priceSummary?.subTotal ?? 0.0;
        final discountAmount = priceSummary?.discount ?? 0.0;
        final taxAmount = priceSummary?.totalTax ?? 0.0;
        final grandTotal = cartTotal;

        return Column(
          children: [
            // Fixed Top Section - Customer Information
            Material(
              elevation: 4,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: billingProvider.mobileNumberTextController,
                      decoration: InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOptionsRow(billingProvider),
                  ],
                ),
              ),
            ),

            // Flexible Middle Section with Proper Scroll
            Flexible(
              child: Container(
                color: Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Order Summary Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Text(
                                    'ORDER SUMMARY',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSummaryRow('Subtotal:',
                                      '${subtotal.toStringAsFixed(2)}'),
                                  if (billingProvider.isCouponApplied ||
                                      discountAmount > 0)
                                    _buildSummaryRow('Discount:',
                                        '-${discountAmount.toStringAsFixed(2)}'),
                                  _buildSummaryRow('Tax (10%):',
                                      '${taxAmount.toStringAsFixed(2)}'),
                                  const Divider(height: 24),
                                  _buildSummaryRow(
                                    'GRAND TOTAL:',
                                    '${grandTotal.toStringAsFixed(2)}',
                                    isBold: true,
                                    textColor: Colors.green,
                                  ),
                                ],
                              ),
                            ),

                            // Payment Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Text(
                                    'PAYMENT',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller:
                                        billingProvider.paidAmountController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Paid Amount',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                      prefixText: ' ',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSummaryRow(
                                    'BALANCE:',
                                    '${billingProvider.balanceAmount.toStringAsFixed(2)}',
                                    textColor:
                                        billingProvider.balanceAmount >= 0
                                            ? Colors.green
                                            : Colors.red,
                                    isBold: true,
                                  ),
                                  const SizedBox(height: 12),
                                  if (billingProvider
                                      .transactionNumberController
                                      .text
                                      .isNotEmpty)
                                    _buildSummaryRow(
                                      'Transaction Ref:',
                                      billingProvider
                                          .transactionNumberController.text,
                                      textColor: Colors.blueGrey,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Fixed Bottom Section - Action Buttons
            Material(
              elevation: 8,
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _completeOrder(context,
                            billingProvider, localProvider, grandTotal),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'COMPLETE ORDER',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionsRow(BillingProvider billingProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return Row(
            children: _buildButtonChildren(true, billingProvider),
          );
        } else {
          return Column(
            children: _buildButtonChildren(false, billingProvider)
                .map((button) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: button,
                    ))
                .toList(),
          );
        }
      },
    );
  }

  List<Widget> _buildButtonChildren(
      bool isRowLayout, BillingProvider billingProvider) {
    return [
      if (isRowLayout)
        Expanded(child: _buildPaymentButton(billingProvider))
      else
        _buildPaymentButton(billingProvider),
      if (isRowLayout) const SizedBox(width: 8) else const SizedBox.shrink(),
      if (isRowLayout)
        Expanded(child: _buildDeliveryButton(billingProvider))
      else
        _buildDeliveryButton(billingProvider),
      if (isRowLayout) const SizedBox(width: 8) else const SizedBox.shrink(),
      if (isRowLayout)
        Expanded(child: _buildCouponButton(billingProvider))
      else
        _buildCouponButton(billingProvider),
    ];
  }

  Widget _buildPaymentButton(BillingProvider billingProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showPaymentMethodModal(billingProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[100],
          foregroundColor: Colors.blue[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                billingProvider.getPaymentLabel(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryButton(BillingProvider billingProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showDeliveryMethodModal(billingProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[100],
          foregroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              billingProvider.deliveryMethod == "Store Takeaway"
                  ? Icons.shopping_bag
                  : billingProvider.deliveryMethod == "Car Delivery"
                      ? Icons.car_rental
                      : Icons.delivery_dining,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                billingProvider.deliveryMethod,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponButton(BillingProvider billingProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // TODO: Implement coupon modal
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: billingProvider.isCouponApplied
              ? Colors.purple[100]
              : Colors.grey[200],
          foregroundColor: billingProvider.isCouponApplied
              ? Colors.purple[800]
              : Colors.grey[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              billingProvider.isCouponApplied
                  ? Icons.discount
                  : Icons.discount_outlined,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                billingProvider.isCouponApplied
                    ? 'Coupon Applied'
                    : 'Add Coupon',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.blueGrey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodModal(BillingProvider billingProvider) {
    final localProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final grandTotal = localProvider.cartTotal;

    billingProvider.setTotalOrderAmount(grandTotal);

    showDialog(
      context: context,
      builder: (context) => const PaymentMethodModalWrapper(),
    );
  }

  void _showDeliveryMethodModal(BillingProvider billingProvider) {
    showDialog(
      context: context,
      builder: (context) => DeliveryMethodModal(
        initialDeliveryMethod: billingProvider.deliveryMethod,
        initialDeliveryMethodId: billingProvider.deliveryMethodId,
        initialCarNumber: billingProvider.carNumber,
        initialComment: billingProvider.orderComment,
        initialDeliveryDate: billingProvider.deliveryDateString,
        initialDeliveryTime: billingProvider.deliveryTimeString,
        onDeliveryMethodSelected: (method, methodId, carNumber, comment,
            deliveryDate, deliveryTime, address) {
          billingProvider.setDeliveryMethod(method, methodId);
          billingProvider.setCarNumber(carNumber);
          billingProvider.setOrderComment(comment);
          billingProvider.setDeliveryDateString(deliveryDate);
          billingProvider.setDeliveryTimeString(deliveryTime);
        },
      ),
    );
  }

  void _completeOrder(BuildContext context, BillingProvider billingProvider,
      LocalProductProvider localProvider, double grandTotal) {
    if (billingProvider.mobileNumberTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter customer name'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    if (!billingProvider.isCashSelected &&
        !billingProvider.isCardSelected &&
        !billingProvider.isUpiSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one payment method'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    double totalPaid = billingProvider.totalPaidAmount;
    if (totalPaid < grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Paid amount is less than the total amount'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    // Create order data for processing
    billingProvider.createOrderData();
    _showOrderConfirmationDialog(
        context, billingProvider, grandTotal, totalPaid);
  }

  void _showOrderConfirmationDialog(BuildContext context,
      BillingProvider billingProvider, double grandTotal, double totalPaid) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Completed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryRow(
                  'Customer:', billingProvider.mobileNumberTextController.text),
              _buildSummaryRow('Delivery:', billingProvider.deliveryMethod),
              _buildSummaryRow('Total:', '${grandTotal.toStringAsFixed(2)}'),
              _buildSummaryRow('Paid:', '${totalPaid.toStringAsFixed(2)}'),
              _buildSummaryRow(
                'Balance:',
                '${billingProvider.balanceAmount.toStringAsFixed(2)}',
                textColor: billingProvider.balanceAmount >= 0
                    ? Colors.green
                    : Colors.red,
              ),
              if (billingProvider.isCouponApplied)
                _buildSummaryRow('Coupon:', billingProvider.couponCode),
              const SizedBox(height: 16),
              if (billingProvider.isCashSelected &&
                  billingProvider.cashAmountController.text.isNotEmpty)
                _buildSummaryRow(
                    'Cash:', '${billingProvider.cashAmountController.text}'),
              if (billingProvider.isCardSelected &&
                  billingProvider.cardAmountController.text.isNotEmpty)
                _buildSummaryRow(
                    'Card:', '${billingProvider.cardAmountController.text}'),
              if (billingProvider.isUpiSelected &&
                  billingProvider.upiAmountController.text.isNotEmpty)
                _buildSummaryRow(
                    'UPI:', '${billingProvider.upiAmountController.text}'),
              if (billingProvider.transactionNumberController.text.isNotEmpty)
                _buildSummaryRow('Transaction Ref:',
                    billingProvider.transactionNumberController.text),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                    child: const Text('PRINT RECEIPT'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
