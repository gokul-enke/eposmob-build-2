import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'build_container_box.dart';

enum SimplePaymentType { cash, card, upi }

class SimplePaymentData {
  final SimplePaymentType? primaryMethod;
  final SimplePaymentType? secondaryMethod;
  final String primaryAmount;
  final String secondaryAmount;

  SimplePaymentData({
    this.primaryMethod,
    this.secondaryMethod,
    this.primaryAmount = '',
    this.secondaryAmount = '',
  });

  bool get hasPaymentMethods => primaryMethod != null || secondaryMethod != null;
  
  double get totalAmount {
    double primary = double.tryParse(primaryAmount) ?? 0;
    double secondary = double.tryParse(secondaryAmount) ?? 0;
    return primary + secondary;
  }
}

/// A simplified payment selector component that supports the most common combinations:
/// - Cash only
/// - Cash + UPI
/// - Cash + Card
/// Maximum 2 payment methods can be selected at once
class BuildSimplePaymentSelector extends StatefulWidget {
  final String title;
  final List<SimplePaymentType> availableMethods;
  final Function(SimplePaymentData) onPaymentChanged;
  final SimplePaymentData? initialData;
  final bool showTotalAmount;
  final double? expectedAmount;

  const BuildSimplePaymentSelector({
    Key? key,
    this.title = "Select Payment Method",
    this.availableMethods = const [
      SimplePaymentType.cash,
      SimplePaymentType.card,
      SimplePaymentType.upi,
    ],
    required this.onPaymentChanged,
    this.initialData,
    this.showTotalAmount = false,
    this.expectedAmount,
  }) : super(key: key);

  @override
  State<BuildSimplePaymentSelector> createState() =>
      _BuildSimplePaymentSelectorState();
}

class _BuildSimplePaymentSelectorState extends State<BuildSimplePaymentSelector> {
  SimplePaymentType? primaryMethod;
  SimplePaymentType? secondaryMethod;
  final TextEditingController primaryAmountController = TextEditingController();
  final TextEditingController secondaryAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    if (widget.initialData != null) {
      primaryMethod = widget.initialData!.primaryMethod;
      secondaryMethod = widget.initialData!.secondaryMethod;
      primaryAmountController.text = widget.initialData!.primaryAmount;
      secondaryAmountController.text = widget.initialData!.secondaryAmount;
    }
  }

  @override
  void dispose() {
    primaryAmountController.dispose();
    secondaryAmountController.dispose();
    super.dispose();
  }

  String _getMethodName(SimplePaymentType method) {
    switch (method) {
      case SimplePaymentType.cash:
        return 'Cash';
      case SimplePaymentType.card:
        return 'Card';
      case SimplePaymentType.upi:
        return 'UPI';
    }
  }

  IconData _getMethodIcon(SimplePaymentType method) {
    switch (method) {
      case SimplePaymentType.cash:
        return Icons.money;
      case SimplePaymentType.card:
        return Icons.credit_card;
      case SimplePaymentType.upi:
        return Icons.qr_code;
    }
  }

  Color _getMethodColor(SimplePaymentType method) {
    switch (method) {
      case SimplePaymentType.cash:
        return ColorManager.kButtonGreen;
      case SimplePaymentType.card:
        return ColorManager.kButtonBlue;
      case SimplePaymentType.upi:
        return ColorManager.kPrimaryColor;
    }
  }

  void _selectPaymentMethod(SimplePaymentType method) {
    setState(() {
      if (primaryMethod == method) {
        // Deselecting primary method
        primaryMethod = secondaryMethod;
        secondaryMethod = null;
        primaryAmountController.text = secondaryAmountController.text;
        secondaryAmountController.clear();
      } else if (secondaryMethod == method) {
        // Deselecting secondary method
        secondaryMethod = null;
        secondaryAmountController.clear();
      } else {
        // Selecting new method
        if (primaryMethod == null) {
          primaryMethod = method;
        } else if (secondaryMethod == null) {
          secondaryMethod = method;
        } else {
          // Replace secondary with new selection
          secondaryMethod = method;
          secondaryAmountController.clear();
        }
      }
    });
    _notifyChange();
  }

  void _notifyChange() {
    widget.onPaymentChanged(SimplePaymentData(
      primaryMethod: primaryMethod,
      secondaryMethod: secondaryMethod,
      primaryAmount: primaryAmountController.text,
      secondaryAmount: secondaryAmountController.text,
    ));
  }

  bool _isMethodSelected(SimplePaymentType method) {
    return primaryMethod == method || secondaryMethod == method;
  }

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Payment method buttons
          Row(
            children: widget.availableMethods.map((method) {
              bool isSelected = _isMethodSelected(method);
              Color methodColor = _getMethodColor(method);
              
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: method != widget.availableMethods.last ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => _selectPaymentMethod(method),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected ? methodColor : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? methodColor : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: methodColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getMethodIcon(method),
                            color: isSelected ? Colors.white : methodColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getMethodName(method),
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.27,
                              isSelected ? Colors.white : methodColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Amount input fields
          if (primaryMethod != null || secondaryMethod != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (primaryMethod != null)
                  Expanded(
                    child: _buildAmountInput(
                      method: primaryMethod!,
                      controller: primaryAmountController,
                      placeholder: 'Enter ${_getMethodName(primaryMethod!)} Amount',
                    ),
                  ),
                if (primaryMethod != null && secondaryMethod != null)
                  const SizedBox(width: 12),
                if (secondaryMethod != null)
                  Expanded(
                    child: _buildAmountInput(
                      method: secondaryMethod!,
                      controller: secondaryAmountController,
                      placeholder: 'Enter ${_getMethodName(secondaryMethod!)} Amount',
                    ),
                  ),
              ],
            ),
          ],
          
          // Total amount display
          if (widget.showTotalAmount && (primaryMethod != null || secondaryMethod != null)) ...[
            const SizedBox(height: 12),
            _buildTotalDisplay(),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountInput({
    required SimplePaymentType method,
    required TextEditingController controller,
    required String placeholder,
  }) {
    return BuildBoxShadowContainer(
      circleRadius: 8,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.grey.shade500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: Icon(
            Icons.currency_rupee,
            color: _getMethodColor(method),
            size: 18,
          ),
        ),
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.27,
          ColorManager.textColor,
        ),
        onChanged: (value) => _notifyChange(),
      ),
    );
  }

  Widget _buildTotalDisplay() {
    double primaryAmount = double.tryParse(primaryAmountController.text) ?? 0;
    double secondaryAmount = double.tryParse(secondaryAmountController.text) ?? 0;
    double total = primaryAmount + secondaryAmount;
    
    Color totalColor = widget.expectedAmount != null
        ? (total == widget.expectedAmount ? ColorManager.kSuccessColor : ColorManager.kErrorColor)
        : ColorManager.kPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: totalColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: totalColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: ₹${total.toStringAsFixed(2)}',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              totalColor,
            ),
          ),
          if (widget.expectedAmount != null) ...[
            Text(
              'Expected: ₹${widget.expectedAmount!.toStringAsFixed(2)}',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                Colors.grey.shade600,
              ),
            ),
            Icon(
              total == widget.expectedAmount ? Icons.check_circle : Icons.error,
              color: totalColor,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}
