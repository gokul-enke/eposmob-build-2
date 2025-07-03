import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:websafe_svg/websafe_svg.dart';

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

    // Initialize selection states
    isCashSelected = widget.initialIsCashSelected;
    isCardSelected = widget.initialIsCardSelected;
    isUpiSelected = widget.initialIsUpiSelected;

    // Initialize controllers
    cashAmountController =
        TextEditingController(text: widget.initialCashAmount);
    cardAmountController =
        TextEditingController(text: widget.initialCardAmount);
    upiAmountController = TextEditingController(text: widget.initialUpiAmount);
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
  }

  @override
  void dispose() {
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
      if (isCashSelected && cashAmountController.text.isEmpty) {
        cashAmountController.text = remaining.toStringAsFixed(2);
      } else if (isCardSelected && cardAmountController.text.isEmpty) {
        cardAmountController.text = remaining.toStringAsFixed(2);
      } else if (isUpiSelected && upiAmountController.text.isEmpty) {
        upiAmountController.text = remaining.toStringAsFixed(2);
      }
    }
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
              onToggle: () {
                setState(() {
                  isCashSelected = !isCashSelected;
                  if (!isCashSelected) {
                    cashAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _calculateBalance();
                });
              },
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
              onToggle: () {
                setState(() {
                  isCardSelected = !isCardSelected;
                  if (!isCardSelected) {
                    cardAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _calculateBalance();
                });
              },
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
              onToggle: () {
                setState(() {
                  isUpiSelected = !isUpiSelected;
                  if (!isUpiSelected) {
                    upiAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _calculateBalance();
                });
              },
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
        // Payment method icon (visual indicator only)
        BuildBoxShadowContainer(
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
            onchanged: (value) {
              // Auto-enable/disable based on amount
              double amount = double.tryParse(value ?? '') ?? 0;
              if (amount > 0 && !isSelected) {
                onToggle(); // Enable the payment method
              } else if (amount == 0 && isSelected) {
                onToggle(); // Disable the payment method
              }
              _calculateBalance();
            },
          ),
        ),
      ],
    );
  }
} 