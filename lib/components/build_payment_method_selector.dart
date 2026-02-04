import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'build_container_box.dart';

enum PaymentMethod { cash, card, upi }

class PaymentMethodData {
  final PaymentMethod method;
  final String amount;
  final bool isSelected;

  PaymentMethodData({
    required this.method,
    this.amount = '',
    this.isSelected = false,
  });

  PaymentMethodData copyWith({
    PaymentMethod? method,
    String? amount,
    bool? isSelected,
  }) {
    return PaymentMethodData(
      method: method ?? this.method,
      amount: amount ?? this.amount,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class BuildPaymentMethodSelector extends StatefulWidget {
  final String title;
  final List<PaymentMethod> availableMethods;
  final Map<PaymentMethod, String> initialAmounts;
  final List<PaymentMethod> selectedMethods;
  final Function(List<PaymentMethodData>) onPaymentChanged;
  final bool showAmountInputs;
  final double? totalAmount;
  final bool validateTotalAmount;

  const BuildPaymentMethodSelector({
    Key? key,
    this.title = "Select Payment Method",
    required this.availableMethods,
    this.initialAmounts = const {},
    this.selectedMethods = const [],
    required this.onPaymentChanged,
    this.showAmountInputs = true,
    this.totalAmount,
    this.validateTotalAmount = false,
  }) : super(key: key);

  @override
  State<BuildPaymentMethodSelector> createState() =>
      _BuildPaymentMethodSelectorState();
}

class _BuildPaymentMethodSelectorState
    extends State<BuildPaymentMethodSelector> {
  Map<PaymentMethod, TextEditingController> amountControllers = {};
  List<PaymentMethod> selectedMethods = [];

  @override
  void initState() {
    super.initState();
    selectedMethods = List.from(widget.selectedMethods);

    // Initialize controllers for all available methods
    for (PaymentMethod method in widget.availableMethods) {
      amountControllers[method] = TextEditingController(
        text: widget.initialAmounts[method] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (TextEditingController controller in amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getMethodDisplayName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.upi:
        return 'UPI';
    }
  }

  IconData _getMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.upi:
        return Icons.qr_code;
    }
  }

  Color _getMethodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return ColorManager.kButtonGreen;
      case PaymentMethod.card:
        return ColorManager.kButtonBlue;
      case PaymentMethod.upi:
        return ColorManager.kPrimaryColor;
    }
  }

  void _togglePaymentMethod(PaymentMethod method) {
    setState(() {
      if (selectedMethods.contains(method)) {
        selectedMethods.remove(method);
        amountControllers[method]?.clear();
      } else {
        // Ensure only maximum 2 methods can be selected
        if (selectedMethods.length >= 2) {
          // Remove the first selected method
          PaymentMethod removedMethod = selectedMethods.removeAt(0);
          amountControllers[removedMethod]?.clear();
        }
        selectedMethods.add(method);

        // Auto-focus amount input when method is selected
        if (widget.showAmountInputs) {
          Future.delayed(const Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(FocusNode());
          });
        }
      }
    });
    _notifyPaymentChanged();
  }

  void _notifyPaymentChanged() {
    List<PaymentMethodData> paymentData = selectedMethods.map((method) {
      return PaymentMethodData(
        method: method,
        amount: amountControllers[method]?.text ?? '',
        isSelected: true,
      );
    }).toList();

    widget.onPaymentChanged(paymentData);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (widget.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.title,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s16,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
            ),

          // Payment method selection buttons
          BuildBoxShadowContainer(
            circleRadius: 12,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: widget.availableMethods.map((method) {
                    bool isSelected = selectedMethods.contains(method);
                    Color methodColor = _getMethodColor(method);

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: method != widget.availableMethods.last ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => _togglePaymentMethod(method),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? methodColor : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? methodColor
                                    : Colors.grey.shade300,
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
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getMethodIcon(method),
                                  color:
                                      isSelected ? Colors.white : methodColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getMethodDisplayName(method),
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

                // Amount input fields for selected methods
                if (widget.showAmountInputs && selectedMethods.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: selectedMethods.map((method) {
                      String placeholder =
                          'Enter ${_getMethodDisplayName(method)} Amount';

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: method != selectedMethods.last ? 8 : 0,
                          ),
                          child: BuildBoxShadowContainer(
                            circleRadius: 8,
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextFormField(
                              controller: amountControllers[method],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}')),
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
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                              onChanged: (value) {
                                _notifyPaymentChanged();
                              },
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Total amount validation display
                if (widget.validateTotalAmount &&
                    widget.totalAmount != null &&
                    selectedMethods.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildTotalAmountDisplay(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmountDisplay() {
    double totalEntered = 0;
    for (PaymentMethod method in selectedMethods) {
      String amount = amountControllers[method]?.text ?? '';
      totalEntered += double.tryParse(amount) ?? 0;
    }

    double expectedTotal = widget.totalAmount ?? 0;
    bool isValid = totalEntered == expectedTotal;
    Color statusColor =
        isValid ? ColorManager.kSuccessColor : ColorManager.kErrorColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Entered: ${totalEntered.toStringAsFixed(2)}',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              statusColor,
            ),
          ),
          Text(
            'Expected: ${expectedTotal.toStringAsFixed(2)}',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              Colors.grey.shade600,
            ),
          ),
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: statusColor,
            size: 16,
          ),
        ],
      ),
    );
  }
}
