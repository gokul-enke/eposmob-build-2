import 'package:flutter/material.dart';

class BillingWidget extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  
  const BillingWidget({super.key, required this.cartItems});

  @override
  State<BillingWidget> createState() => _BillingWidgetState();
}

class _BillingWidgetState extends State<BillingWidget> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  String _paymentMethod = "Cash";
  String _deliveryMethod = "Takeaway";
  bool _couponApplied = false;
  double _balance = 0.0;
  double _discountAmount = 0.0;

  @override
  void dispose() {
    _customerController.dispose();
    _paidAmountController.dispose();
    _discountController.dispose();
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
                                decoration: InputDecoration(
                                  labelText: 'Paid Amount',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  prefixText: '₹ ',
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  setState(() {
                                    final paidAmount = double.tryParse(value) ?? 0.0;
                                    _balance = paidAmount - grandTotal;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryRow(
                                'BALANCE:',
                                '₹${_balance.toStringAsFixed(2)}',
                                textColor: _balance >= 0 ? Colors.green : Colors.red,
                                isBold: true,
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
      // Fixed Bottom Section - Action Buttons
Material(
  elevation: 8,
  child: Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(  // This makes the button take full available width
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Payment Methods
        _buildOptionChip(
          label: 'Cash',
          icon: Icons.money,
          selected: _paymentMethod == "Cash",
          onSelected: (selected) => setState(() => _paymentMethod = "Cash"),
        ),
        _buildOptionChip(
          label: 'Card',
          icon: Icons.credit_card,
          selected: _paymentMethod == "Card",
          onSelected: (selected) => setState(() => _paymentMethod = "Card"),
        ),
        
        // Delivery Methods
        _buildOptionChip(
          label: 'Takeaway',
          icon: Icons.shopping_bag,
          selected: _deliveryMethod == "Takeaway",
          onSelected: (selected) => setState(() => _deliveryMethod = "Takeaway"),
        ),
        _buildOptionChip(
          label: 'Delivery',
          icon: Icons.delivery_dining,
          selected: _deliveryMethod == "Delivery",
          onSelected: (selected) => setState(() => _deliveryMethod = "Delivery"),
        ),
        
        // Coupon
        _buildOptionChip(
          label: _couponApplied ? 'Coupon Applied' : 'Add Coupon',
          icon: _couponApplied ? Icons.discount : Icons.discount_outlined,
          selected: _couponApplied,
          onSelected: (selected) {
            setState(() => _couponApplied = selected);
            if (selected) {
              _showDiscountDialog();
            } else {
              setState(() => _discountAmount = 0.0);
            }
          },
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: selected ? Colors.blue[800] : Colors.grey[800],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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

  void _showDiscountDialog() {
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
            children: [
              const Text(
                'Apply Discount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _discountController,
                decoration: InputDecoration(
                  labelText: 'Discount Amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _discountAmount = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _couponApplied = true;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: const Text(
                      'APPLY',
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

    if (double.tryParse(_paidAmountController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid payment amount'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    // Process the order
    final orderDetails = {
      'customer': _customerController.text,
      'items': widget.cartItems,
      'subtotal': grandTotal - (grandTotal * 0.1),
      'tax': grandTotal * 0.1,
      'total': grandTotal,
      'paid': double.parse(_paidAmountController.text),
      'balance': _balance,
      'paymentMethod': _paymentMethod,
      'deliveryMethod': _deliveryMethod,
      'discount': _discountAmount,
      'timestamp': DateTime.now(),
    };

    // Show confirmation dialog
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
              _buildSummaryRow('Total:', '₹${grandTotal.toStringAsFixed(2)}'),
              _buildSummaryRow('Paid:', '₹${double.parse(_paidAmountController.text).toStringAsFixed(2)}'),
              _buildSummaryRow(
                'Balance:',
                '₹${_balance.toStringAsFixed(2)}',
                textColor: _balance >= 0 ? Colors.green : Colors.red,
              ),
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