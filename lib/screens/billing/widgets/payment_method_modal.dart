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
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

class PaymentMethodModal extends StatefulWidget {
  final bool initialIsCashSelected;
  final bool initialIsCardSelected;
  final bool initialIsUpiSelected;
  final bool initialIsDebitSelected;
  final String initialCashAmount;
  final String initialCardAmount;
  final String initialUpiAmount;
  final String initialDebitAmount;
  final String initialTransactionNumber;
  final double cartTotal;
  final Function(bool, bool, bool, bool, String, String, String, String, String)
      onPaymentMethodSelected;

  const PaymentMethodModal({
    Key? key,
    required this.initialIsCashSelected,
    required this.initialIsCardSelected,
    required this.initialIsUpiSelected,
    required this.initialIsDebitSelected,
    required this.initialCashAmount,
    required this.initialCardAmount,
    required this.initialUpiAmount,
    required this.initialDebitAmount,
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
  late bool isDebitSelected;
  late TextEditingController cashAmountController;
  late TextEditingController cardAmountController;
  late TextEditingController upiAmountController;
  late TextEditingController debitAmountController;
  late TextEditingController transactionNumberController;
  late FocusNode cashAmountFocusNode;
  late FocusNode cardAmountFocusNode;
  late FocusNode upiAmountFocusNode;
  late FocusNode debitAmountFocusNode;
  double balanceAmount = 0;

  @override
  void initState() {
    super.initState();

    // Use existing selections without any defaults - let user select manually
    isCashSelected = widget.initialIsCashSelected;
    isCardSelected = widget.initialIsCardSelected;
    isUpiSelected = widget.initialIsUpiSelected;
    isDebitSelected = widget.initialIsDebitSelected;

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
    debitAmountController = TextEditingController(
        text:
            widget.initialDebitAmount.isEmpty || widget.initialDebitAmount == "0"
                ? ""
                : widget.initialDebitAmount);
    
    transactionNumberController =
        TextEditingController(text: widget.initialTransactionNumber);

    // Initialize focus nodes
    cashAmountFocusNode = FocusNode();
    cardAmountFocusNode = FocusNode();
    upiAmountFocusNode = FocusNode();
    debitAmountFocusNode = FocusNode();

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

    debitAmountFocusNode.addListener(() {
      if (debitAmountFocusNode.hasFocus && debitAmountController.text.isNotEmpty) {
        debitAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: debitAmountController.text.length,
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
    debitAmountController.addListener(
        () => _handleAmountControllerChange('debit', debitAmountController));
  }

  @override
  void dispose() {
    cashAmountController.removeListener(
        () => _handleAmountControllerChange('cash', cashAmountController));
    cardAmountController.removeListener(
        () => _handleAmountControllerChange('card', cardAmountController));
    upiAmountController.removeListener(
        () => _handleAmountControllerChange('upi', upiAmountController));
    debitAmountController.removeListener(
        () => _handleAmountControllerChange('debit', debitAmountController));
    cashAmountController.dispose();
    cardAmountController.dispose();
    upiAmountController.dispose();
    debitAmountController.dispose();
    transactionNumberController.dispose();
    cashAmountFocusNode.dispose();
    cardAmountFocusNode.dispose();
    upiAmountFocusNode.dispose();
    debitAmountFocusNode.dispose();
    super.dispose();
  }

  void _calculateBalance() {
    // For balance calculation, only include actual cash payments (not debit/store credit)
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double actualCashPaid = cashAmount + cardAmount + upiAmount;
    
    double balance = actualCashPaid - widget.cartTotal;
    if (balance < 0) {
      balance = 0.0;
    }
    setState(() {
      balanceAmount = balance;
      // Update the balance field to match the calculated balance
    });
  }

  double _getTotalPaidAmount() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double debitAmount = double.tryParse(debitAmountController.text) ?? 0.0;
    // Include debit amount in total paid for display purposes (total transaction value)
    // Note: Balance calculation uses separate logic excluding debit
    return cashAmount + cardAmount + upiAmount + debitAmount;
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
        case 'debit':
          isDebitSelected = !isDebitSelected;
          if (!isDebitSelected) {
            debitAmountController.clear();
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
          case 'debit':
            isDebitSelected = true;
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
          case 'debit':
            isDebitSelected = false;
            break;
        }
      }
    });

    // Don't recalculate if this is the balance field being updated by calculation
    if (label != 'balance') {
      _calculateBalance();
    }
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

            const SizedBox(height: 15),

            // Debit Payment
            _buildModalPaymentRow(
              isSelected: isDebitSelected,
              icon: ImageAssets.creditCardIcon,
              label: 'Debit',
              controller: debitAmountController,
              focusNode: debitAmountFocusNode,
              size: size,
              onToggle: () => _togglePaymentMethod('debit'),
            ),

            const SizedBox(height: 15),

            // Transaction Reference Field - Show only if Card, UPI, or Debit is selected
            if (isCardSelected || isUpiSelected || isDebitSelected) ...[
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
                  isDebitSelected,
                  cashAmountController.text,
                  cardAmountController.text,
                  upiAmountController.text,
                  debitAmountController.text,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            blurRadius: 4,
            circleRadius: 5,
            height: size.height * .06, // Match text field height
            width: 100, // Fixed width for alignment
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WebsafeSvg.asset(
                  icon,
                  width: 14,
                  height: 14,
                  color: isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                  fit: BoxFit.none,
                ),
                const SizedBox(width: 6),
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
            hintText: label == 'Balance' ? 'Auto-calculated' : 'Enter $label amount',
            keyboardType: TextInputType.number,
            focusNode: focusNode,
            readOnly: label == 'Balance', // Make balance field read-only
            onTap: label == 'Balance' ? null : () {
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
