import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/screens/billing/widgets/coupon_modal.dart';
import 'package:pos_machine/screens/billing/widgets/delivery_method_modal.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';


class BillingWidget extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  
  const BillingWidget({super.key, required this.cartItems});

  @override
  State<BillingWidget> createState() => _BillingWidgetState();
}

class _BillingWidgetState extends State<BillingWidget> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  
  // Payment method modal state variables
  bool _isCashSelected = false;
  bool _isCardSelected = false;
  bool _isUpiSelected = false;
  String _cashAmount = "";
  String _cardAmount = "";
  String _upiAmount = "";
  String _transactionNumber = "";
  
  // Delivery method state variables
  String _deliveryMethod = "Takeaway";
  String _deliveryMethodId = "";
  String _carNumber = "";
  String _comment = "";
  String? _deliveryDate;
  String? _deliveryTime;
  
  // Coupon state variables
  bool _couponApplied = false;
  String _couponCode = "";
  double _discountAmount = 0.0;
  double _balance = 0.0;

  @override
  void dispose() {
    _customerController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.cartItems.fold(0.0, (sum, item) => sum + item['total']);
    final subtotal = totalAmount - _discountAmount;
    final taxAmount = subtotal * 0.1; // Assuming 10% tax
    final grandTotal = subtotal + taxAmount;

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
                  controller: _customerController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                _buildOptionsRow(),
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
                              _buildSummaryRow('Subtotal:', '₹${totalAmount.toStringAsFixed(2)}'),
                              if (_couponApplied) 
                                _buildSummaryRow('Discount:', '-₹${_discountAmount.toStringAsFixed(2)}'),
                              _buildSummaryRow('Tax (10%):', '₹${taxAmount.toStringAsFixed(2)}'),
                              const Divider(height: 24),
                              _buildSummaryRow(
                                'GRAND TOTAL:',
                                '₹${grandTotal.toStringAsFixed(2)}',
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
                                controller: _paidAmountController,
                                readOnly: true, // Make it read-only since payment is handled by modal
                                decoration: InputDecoration(
                                  labelText: 'Paid Amount',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  prefixText: '₹ ',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryRow(
                                'BALANCE:',
                                '₹${_balance.toStringAsFixed(2)}',
                                textColor: _balance >= 0 ? Colors.green : Colors.red,
                                isBold: true,
                              ),
                              const SizedBox(height: 12),
                              if (_transactionNumber.isNotEmpty)
                                _buildSummaryRow(
                                  'Transaction Ref:',
                                  _transactionNumber,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _completeOrder(context, grandTotal),
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
  }

 Widget _buildOptionsRow() {
  return LayoutBuilder(
    builder: (context, constraints) {
      // For screens wider than 600px, use a row layout
      if (constraints.maxWidth > 600) {
        return Row(
          children: _buildButtonChildren(true),
        );
      } else {
        // For narrower screens, use a column layout with full width buttons
        return Column(
          children: _buildButtonChildren(false)
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

List<Widget> _buildButtonChildren(bool isRowLayout) {
  return [
    // Payment Methods Button
    if (isRowLayout) Expanded(child: _buildPaymentButton()) else _buildPaymentButton(),
    
    if (isRowLayout) const SizedBox(width: 8) else const SizedBox.shrink(),
    
    // Delivery Methods Button
    if (isRowLayout) Expanded(child: _buildDeliveryButton()) else _buildDeliveryButton(),
    
    if (isRowLayout) const SizedBox(width: 8) else const SizedBox.shrink(),
    
    // Coupon Button
    if (isRowLayout) Expanded(child: _buildCouponButton()) else _buildCouponButton(),
  ];
}

Widget _buildPaymentButton() {
  return SizedBox(
    width: double.infinity, // Full width on mobile
    child: ElevatedButton(
      onPressed: _showPaymentMethodModal,
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
              _getPaymentMethodSummary(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDeliveryButton() {
  return SizedBox(
    width: double.infinity, // Full width on mobile
    child: ElevatedButton(
      onPressed: _showDeliveryMethodModal,
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
            _deliveryMethod == "Takeaway" 
              ? Icons.shopping_bag 
              : _deliveryMethod == "Car Delivery"
                ? Icons.car_rental
                : Icons.delivery_dining,
            size: 18,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _deliveryMethod,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCouponButton() {
  return SizedBox(
    width: double.infinity, // Full width on mobile
    child: ElevatedButton(
      onPressed: _showCouponModal,
      style: ElevatedButton.styleFrom(
        backgroundColor: _couponApplied ? Colors.purple[100] : Colors.grey[200],
        foregroundColor: _couponApplied ? Colors.purple[800] : Colors.grey[800],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_couponApplied ? Icons.discount : Icons.discount_outlined, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _couponApplied ? 'Coupon Applied' : 'Add Coupon',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSummaryRow(String label, String value, {
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

  String _getPaymentMethodSummary() {
    List<String> methods = [];
    if (_isCashSelected) methods.add('Cash');
    if (_isCardSelected) methods.add('Card');
    if (_isUpiSelected) methods.add('UPI');
    
    if (methods.isEmpty) return 'Payment Methods';
    return methods.join(' + ');
  }

  void _showPaymentMethodModal() {
    final totalAmount = widget.cartItems.fold(0.0, (sum, item) => sum + item['total']);
    final subtotal = totalAmount - _discountAmount;
    final taxAmount = subtotal * 0.1;
    final grandTotal = subtotal + taxAmount;

    showDialog(
      context: context,
      builder: (context) => PaymentMethodModal(
        initialIsCashSelected: _isCashSelected,
        initialIsCardSelected: _isCardSelected,
        initialIsUpiSelected: _isUpiSelected,
        initialCashAmount: _cashAmount,
        initialCardAmount: _cardAmount,
        initialUpiAmount: _upiAmount,
        initialTransactionNumber: _transactionNumber,
        cartTotal: grandTotal,
        onPaymentMethodSelected: (isCash, isCard, isUpi, cashAmt, cardAmt, upiAmt, transNum) {
          setState(() {
            _isCashSelected = isCash;
            _isCardSelected = isCard;
            _isUpiSelected = isUpi;
            _cashAmount = cashAmt;
            _cardAmount = cardAmt;
            _upiAmount = upiAmt;
            _transactionNumber = transNum;
            
            // Calculate total paid amount and update balance
            double totalPaid = _calculateTotalPaid();
            _balance = totalPaid - grandTotal;
            
            // Update paid amount controller
            _paidAmountController.text = totalPaid.toStringAsFixed(2);
          });
        },
      ),
    );
  }

  void _showDeliveryMethodModal() {
    showDialog(
      context: context,
      builder: (context) => DeliveryMethodModal(
        initialDeliveryMethod: _deliveryMethod,
        initialDeliveryMethodId: _deliveryMethodId,
        initialCarNumber: _carNumber,
        initialComment: _comment,
        initialDeliveryDate: _deliveryDate,
        initialDeliveryTime: _deliveryTime,
        onDeliveryMethodSelected: (method, methodId, carNumber, comment, deliveryDate, deliveryTime) {
          setState(() {
            _deliveryMethod = method;
            _deliveryMethodId = methodId;
            _carNumber = carNumber;
            _comment = comment;
            _deliveryDate = deliveryDate;
            _deliveryTime = deliveryTime;
          });
        },
      ),
    );
  }

  void _showCouponModal() {
    showDialog(
      context: context,
      builder: (context) => CouponModal(
        initialCouponCode: _couponCode,
        isCouponApplied: _couponApplied,
        onCouponAction: (couponCode, isApplied) {
          setState(() {
            _couponCode = couponCode;
            _couponApplied = isApplied;
            // For demo purposes, set a fixed discount amount
            // In a real app, you would calculate this based on the coupon code
            _discountAmount = isApplied ? 50.0 : 0.0;
          });
        },
      ),
    );
  }

  double _calculateTotalPaid() {
    double cash = double.tryParse(_cashAmount) ?? 0.0;
    double card = double.tryParse(_cardAmount) ?? 0.0;
    double upi = double.tryParse(_upiAmount) ?? 0.0;
    return cash + card + upi;
  }

  void _completeOrder(BuildContext context, double grandTotal) {
    if (_customerController.text.isEmpty) {
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

    // Check if at least one payment method is selected
    if (!_isCashSelected && !_isCardSelected && !_isUpiSelected) {
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

    // Check if total paid amount is sufficient
    double totalPaid = _calculateTotalPaid();
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

    // Process the order with payment details
    final orderDetails = {
      'customer': _customerController.text,
      'items': widget.cartItems,
      'subtotal': grandTotal - (grandTotal * 0.1),
      'tax': grandTotal * 0.1,
      'total': grandTotal,
      'paid': totalPaid,
      'balance': _balance,
      'paymentMethods': {
        'cash': {'selected': _isCashSelected, 'amount': _cashAmount},
        'card': {'selected': _isCardSelected, 'amount': _cardAmount},
        'upi': {'selected': _isUpiSelected, 'amount': _upiAmount},
      },
      'transactionNumber': _transactionNumber,
      'deliveryMethod': _deliveryMethod,
      'deliveryMethodId': _deliveryMethodId,
      'carNumber': _carNumber,
      'comment': _comment,
      'deliveryDate': _deliveryDate,
      'deliveryTime': _deliveryTime,
      'couponCode': _couponCode,
      'discount': _discountAmount,
      'timestamp': DateTime.now(),
    };

    // Show confirmation dialog
    _showOrderConfirmationDialog(context, grandTotal, totalPaid);
  }

  void _showOrderConfirmationDialog(BuildContext context, double grandTotal, double totalPaid) {
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
              _buildSummaryRow('Customer:', _customerController.text),
              _buildSummaryRow('Delivery:', _deliveryMethod),
              _buildSummaryRow('Total:', '₹${grandTotal.toStringAsFixed(2)}'),
              _buildSummaryRow('Paid:', '₹${totalPaid.toStringAsFixed(2)}'),
              _buildSummaryRow(
                'Balance:',
                '₹${_balance.toStringAsFixed(2)}',
                textColor: _balance >= 0 ? Colors.green : Colors.red,
              ),
              if (_couponApplied)
                _buildSummaryRow('Coupon:', _couponCode),
              const SizedBox(height: 16),
              // Show payment method details
              if (_isCashSelected && _cashAmount.isNotEmpty)
                _buildSummaryRow('Cash:', '₹$_cashAmount'),
              if (_isCardSelected && _cardAmount.isNotEmpty)
                _buildSummaryRow('Card:', '₹$_cardAmount'),
              if (_isUpiSelected && _upiAmount.isNotEmpty)
                _buildSummaryRow('UPI:', '₹$_upiAmount'),
              if (_transactionNumber.isNotEmpty)
                _buildSummaryRow('Transaction Ref:', _transactionNumber),
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
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close billing page
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

// PaymentMethodModal Widget (keep your original code)
class PaymentMethodModal extends StatefulWidget {
  final bool initialIsCashSelected;
  final bool initialIsCardSelected;
  final bool initialIsUpiSelected;
  final String initialCashAmount;
  final String initialCardAmount;
  final String initialUpiAmount;
  final String initialTransactionNumber;
  final double cartTotal;
  final Function(bool, bool, bool, String, String, String, String)
      onPaymentMethodSelected;

  const PaymentMethodModal({
    Key? key,
    required this.initialIsCashSelected,
    required this.initialIsCardSelected,
    required this.initialIsUpiSelected,
    required this.initialCashAmount,
    required this.initialCardAmount,
    required this.initialUpiAmount,
    required this.initialTransactionNumber,
    required this.cartTotal,
    required this.onPaymentMethodSelected,
  }) : super(key: key);

  @override
  State<PaymentMethodModal> createState() => _PaymentMethodModalState();
}

class _PaymentMethodModalState extends State<PaymentMethodModal> {
  late bool isCashSelected;
  late bool isCardSelected;
  late bool isUpiSelected;
  late TextEditingController cashAmountController;
  late TextEditingController cardAmountController;
  late TextEditingController upiAmountController;
  late TextEditingController transactionNumberController;
  late FocusNode cashAmountFocusNode;
  late FocusNode cardAmountFocusNode;
  late FocusNode upiAmountFocusNode;
  double balanceAmount = 0;

  @override
  void initState() {
    super.initState();

    // Always preselect cash as default if no payment methods are currently selected
    bool hasAnySelection = widget.initialIsCashSelected ||
        widget.initialIsCardSelected ||
        widget.initialIsUpiSelected;

    if (!hasAnySelection) {
      // No payment method selected, default to cash
      isCashSelected = true;
      isCardSelected = false;
      isUpiSelected = false;
    } else {
      // Use existing selections
      isCashSelected = widget.initialIsCashSelected;
      isCardSelected = widget.initialIsCardSelected;
      isUpiSelected = widget.initialIsUpiSelected;
    }

    // Initialize controllers - don't fill with "0", use existing values or empty
    cashAmountController = TextEditingController(
        text:
            widget.initialCashAmount.isEmpty || widget.initialCashAmount == "0"
                ? ""
                : widget.initialCashAmount);
    cardAmountController = TextEditingController(
        text:
            widget.initialCardAmount.isEmpty || widget.initialCardAmount == "0"
                ? ""
                : widget.initialCardAmount);
    upiAmountController = TextEditingController(
        text: widget.initialUpiAmount.isEmpty || widget.initialUpiAmount == "0"
            ? ""
            : widget.initialUpiAmount);
    transactionNumberController =
        TextEditingController(text: widget.initialTransactionNumber);

    // Initialize focus nodes
    cashAmountFocusNode = FocusNode();
    cardAmountFocusNode = FocusNode();
    upiAmountFocusNode = FocusNode();

    // Calculate initial balance
    _calculateBalance();

    // Add focus listeners
    cashAmountFocusNode.addListener(() {
      if (cashAmountFocusNode.hasFocus &&
          cashAmountController.text.isNotEmpty) {
        cashAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: cashAmountController.text.length,
        );
      }
    });

    cardAmountFocusNode.addListener(() {
      if (cardAmountFocusNode.hasFocus &&
          cardAmountController.text.isNotEmpty) {
        cardAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: cardAmountController.text.length,
        );
      }
    });

    upiAmountFocusNode.addListener(() {
      if (upiAmountFocusNode.hasFocus && upiAmountController.text.isNotEmpty) {
        upiAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: upiAmountController.text.length,
        );
      }
    });

    // Listen for text changes to capture virtual keyboard input
    cashAmountController.addListener(
        () => _handleAmountControllerChange('cash', cashAmountController));
    cardAmountController.addListener(
        () => _handleAmountControllerChange('card', cardAmountController));
    upiAmountController.addListener(
        () => _handleAmountControllerChange('upi', upiAmountController));
  }

  @override
  void dispose() {
    cashAmountController.removeListener(
        () => _handleAmountControllerChange('cash', cashAmountController));
    cardAmountController.removeListener(
        () => _handleAmountControllerChange('card', cardAmountController));
    upiAmountController.removeListener(
        () => _handleAmountControllerChange('upi', upiAmountController));
    cashAmountController.dispose();
    cardAmountController.dispose();
    upiAmountController.dispose();
    transactionNumberController.dispose();
    cashAmountFocusNode.dispose();
    cardAmountFocusNode.dispose();
    upiAmountFocusNode.dispose();
    super.dispose();
  }

  void _calculateBalance() {
    double totalPaid = _getTotalPaidAmount();
    double balance = totalPaid - widget.cartTotal;
    if (balance < 0) {
      balance = 0.0;
    }
    setState(() {
      balanceAmount = balance;
    });
  }

  double _getTotalPaidAmount() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    return cashAmount + cardAmount + upiAmount;
  }

  void _autoFillPaymentAmount() {
    double totalPaid = _getTotalPaidAmount();
    double remaining = widget.cartTotal - totalPaid;

    if (remaining > 0) {
      // Find the first selected payment method that has no amount and fill it
      if (isCashSelected &&
          (cashAmountController.text.isEmpty ||
              cashAmountController.text == "0")) {
        cashAmountController.text = remaining.toStringAsFixed(2);
      } else if (isCardSelected &&
          (cardAmountController.text.isEmpty ||
              cardAmountController.text == "0")) {
        cardAmountController.text = remaining.toStringAsFixed(2);
      } else if (isUpiSelected &&
          (upiAmountController.text.isEmpty ||
              upiAmountController.text == "0")) {
        upiAmountController.text = remaining.toStringAsFixed(2);
      }
    }
    _calculateBalance();
  }

  void _togglePaymentMethod(String paymentType) {
    setState(() {
      switch (paymentType) {
        case 'cash':
          isCashSelected = !isCashSelected;
          if (!isCashSelected) {
            cashAmountController.clear();
          }
          break;
        case 'card':
          isCardSelected = !isCardSelected;
          if (!isCardSelected) {
            cardAmountController.clear();
          }
          break;
        case 'upi':
          isUpiSelected = !isUpiSelected;
          if (!isUpiSelected) {
            upiAmountController.clear();
          }
          break;
      }
      _calculateBalance();
    });
  }

  // ---- Utility to handle text changes from any source (hardware or virtual keyboard) ----
  void _handleAmountControllerChange(
      String label, TextEditingController controller) {
    double amount = double.tryParse(controller.text) ?? 0;

    setState(() {
      if (amount > 0) {
        switch (label) {
          case 'cash':
            isCashSelected = true;
            break;
          case 'card':
            isCardSelected = true;
            break;
          case 'upi':
            isUpiSelected = true;
            break;
        }
      } else if (amount == 0 && controller.text.isEmpty) {
        switch (label) {
          case 'cash':
            isCashSelected = false;
            break;
          case 'card':
            isCardSelected = false;
            break;
          case 'upi':
            isUpiSelected = false;
            break;
        }
      }
    });

    _calculateBalance();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        width: 550,
        circleRadius: 12,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Methods',
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

            // Cash Payment
            _buildModalPaymentRow(
              isSelected: isCashSelected,
              icon: ImageAssets.cashIcon,
              label: 'Cash',
              controller: cashAmountController,
              focusNode: cashAmountFocusNode,
              size: size,
              onToggle: () => _togglePaymentMethod('cash'),
            ),

            const SizedBox(height: 15),

            // Card Payment
            _buildModalPaymentRow(
              isSelected: isCardSelected,
              icon: ImageAssets.creditCardIcon,
              label: 'Card',
              controller: cardAmountController,
              focusNode: cardAmountFocusNode,
              size: size,
              onToggle: () => _togglePaymentMethod('card'),
            ),

            const SizedBox(height: 15),

            // UPI Payment
            _buildModalPaymentRow(
              isSelected: isUpiSelected,
              icon: ImageAssets.creditCardIcon,
              label: 'UPI',
              controller: upiAmountController,
              focusNode: upiAmountFocusNode,
              size: size,
              onToggle: () => _togglePaymentMethod('upi'),
            ),

            const SizedBox(height: 10),

            // Credit payment (cash = 0)
            Align(
              alignment: Alignment.centerLeft,
              child: CustomRoundButton(
                title: "Credit",
                fct: () {
                  setState(() {
                    // Credit implies cash selected with zero amount
                    isCashSelected = true;
                    isCardSelected = false;
                    isUpiSelected = false;
                    cashAmountController.text = "0";
                    cardAmountController.clear();
                    upiAmountController.clear();
                    _calculateBalance();
                  });
                },
                fontSize: FontSize.s13,
                height: 38,
                width: 120,
                boxColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                textColor: Colors.white,
              ),
            ),

            const SizedBox(height: 15),

            // Transaction Reference Field - Show only if Card or UPI is selected
            if (isCardSelected || isUpiSelected) ...[
              Text(
                'Transaction Reference',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s13,
                  0.16,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 8),
              buildColumnWidgetForTextFields(
                controller: transactionNumberController,
                size: size,
                width: 600,
                height: size.height * .06,
                hintText: 'Enter transaction reference number',
                onTap: () {
                  Provider.of<KeyboardProvider>(context, listen: false).show(
                    'number',
                    transactionNumberController,
                    replaceOnFirstInput: true,
                  );
                },
              ),
              const SizedBox(height: 15),
            ],

            // Payment Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Required: INR ${widget.cartTotal.toStringAsFixed(2)}',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s14,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
                Text(
                  'Total Paid: INR ${_getTotalPaidAmount().toStringAsFixed(2)}',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.18,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            BuildPaymentRow(
              amount: "INR ${balanceAmount.toStringAsFixed(2)}",
              title: "Balance Amount",
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                balanceAmount > 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColorRed,
              ),
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s15,
                0.23,
                balanceAmount > 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColorRed,
              ),
              color: balanceAmount > 0
                  ? ColorManager.kButtonGreen
                  : ColorManager.textColorRed,
            ),

            const SizedBox(height: 20),
            CustomRoundButton(
              title: "Apply Payment Methods",
              fct: () {
                widget.onPaymentMethodSelected(
                  isCashSelected,
                  isCardSelected,
                  isUpiSelected,
                  cashAmountController.text,
                  cardAmountController.text,
                  upiAmountController.text,
                  transactionNumberController.text,
                );
                Navigator.of(context).pop();
              },
              fontSize: FontSize.s14,
              height: 45,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalPaymentRow({
    required bool isSelected,
    required String icon,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Size size,
    required VoidCallback onToggle,
  }) {
    return Row(
      children: [
        // Payment method icon - Now clickable for selection/deselection
        GestureDetector(
          onTap: onToggle,
          child: BuildBoxShadowContainer(
            border: isSelected
                ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
                : Border.all(color: Colors.grey.shade300),
            padding: const EdgeInsets.all(12),
            blurRadius: 4,
            circleRadius: 5,
            width: 90,
            child: Column(
              children: [
                WebsafeSvg.asset(
                  icon,
                  width: 18,
                  height: 18,
                  color: isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                  fit: BoxFit.none,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.12,
                    isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 15),

        // Amount input field - always visible
        Expanded(
          child: buildColumnWidgetForTextFields(
            controller: controller,
            size: size,
            height: size.height * .06,
            hintText: 'Enter $label amount',
            keyboardType: TextInputType.number,
            focusNode: focusNode,
            onTap: () {
              // Ensure full selection when tapping inside the field
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (controller.text.isNotEmpty && focusNode.hasFocus) {
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                }
              });

              // Show virtual numeric keyboard
              Provider.of<KeyboardProvider>(context, listen: false).show(
                'number',
                controller,
                replaceOnFirstInput: true,
              );
            },
            onchanged: (value) =>
                _handleAmountControllerChange(label.toLowerCase(), controller),
          ),
        ),
      ],
    );
  }
}