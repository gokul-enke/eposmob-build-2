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
  // Customer previous balance (positive = customer has credit; negative = customer owes)
  final double customerPrevBalance;
  final Function(bool, bool, bool, bool, String, String, String, String, String,
      bool) onPaymentMethodSelected;

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
    this.customerPrevBalance = 0.0,
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
  late FocusNode toCustomerCreditFocusNode;
  double balanceAmount = 0;
  // To Customer Credit toggle and controller
  bool toCustomerCreditEnabled = false;
  late TextEditingController toCustomerCreditController;
  double toCustomerCredit = 0.0;

  @override
  void initState() {
    super.initState();

    // Use existing selections without any defaults - let user select manually
    isCashSelected = widget.initialIsCashSelected;
    isCardSelected = widget.initialIsCardSelected;
    isUpiSelected = widget.initialIsUpiSelected;

    // Initialize controllers - handle auto-filled values properly
    cashAmountController = TextEditingController(
        text: widget.initialCashAmount.isEmpty
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
    // Debit field removed. We'll map To Customer Credit to debit in the callback only.
    
    transactionNumberController =
        TextEditingController(text: widget.initialTransactionNumber);

    // Initialize focus nodes
    cashAmountFocusNode = FocusNode();
    cardAmountFocusNode = FocusNode();
    upiAmountFocusNode = FocusNode();
    toCustomerCreditFocusNode = FocusNode();

    // Initialize To Customer Credit controller
    toCustomerCreditController = TextEditingController();

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

    // To Customer Credit focus listener
    toCustomerCreditFocusNode.addListener(() {
      if (toCustomerCreditFocusNode.hasFocus && toCustomerCreditController.text.isNotEmpty) {
        toCustomerCreditController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: toCustomerCreditController.text.length,
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
    toCustomerCreditController.addListener(
        () => _handleAmountControllerChange('toCustomerCredit', toCustomerCreditController));

    // If there is an initial debit value (>0), reflect it as To Customer Credit
    final initDebit = double.tryParse(widget.initialDebitAmount) ?? 0.0;
    if (initDebit > 0) {
      toCustomerCreditEnabled = true;
      toCustomerCreditController.text = initDebit.toStringAsFixed(2);
      // Keep debit selection as provided by parent but ensure consistency in display
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateBalance());
    }

    // Auto-focus cash field if it was auto-filled and cash is selected
    if (widget.initialIsCashSelected && cashAmountController.text.isNotEmpty) {
      // Check if this looks like an auto-filled amount (cart total)
      final cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
      if (cashAmount > 0 && cashAmount == widget.cartTotal) {
        // This appears to be auto-filled, focus and select the text
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            cashAmountFocusNode.requestFocus();
            cashAmountController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: cashAmountController.text.length,
            );
          }
        });
      }
    }
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
    toCustomerCreditFocusNode.dispose();
    toCustomerCreditController.removeListener(
        () => _handleAmountControllerChange('toCustomerCredit', toCustomerCreditController));
    toCustomerCreditController.dispose();
    super.dispose();
  }

  // Base balance calculation with toggle consideration
  double _computeBaseBalance() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount;
    
    double netDue;
    if (toCustomerCreditEnabled) {
      // Toggle ON: Include previous balance in calculation
      // Positive balance = customer has credit, Negative = customer owes
      netDue = widget.cartTotal - widget.customerPrevBalance;
    } else {
      // Toggle OFF: Ignore previous balance completely
      netDue = widget.cartTotal;
    }
    
    double balance = totalCollected - netDue;
    return balance > 0 ? balance : 0.0;
  }

  // Get the actual posting amounts for each payment method
  Map<String, double> _getPostingAmounts() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount;
    
    double netDue;
    if (toCustomerCreditEnabled) {
      // Toggle ON: Include previous balance
      netDue = widget.cartTotal - widget.customerPrevBalance;
    } else {
      // Toggle OFF: Only current purchase
      netDue = widget.cartTotal;
    }
    
    double balance = totalCollected - netDue;
    
    // Calculate posting amounts
    Map<String, double> postingAmounts = {
      'cash': 0.0,
      'card': 0.0,
      'upi': 0.0,
      'toCustomerCredit': 0.0,
      'balance': 0.0,
    };
    
    if (balance <= 0) {
      // Not enough collected - all goes to settle purchase/dues
      postingAmounts['cash'] = cashAmount;
      postingAmounts['card'] = cardAmount;
      postingAmounts['upi'] = upiAmount;
      
      // For Toggle ON case with insufficient funds, calculate partial credit settlement
      if (toCustomerCreditEnabled && widget.customerPrevBalance < 0) {
        // Customer owes money, partial payment reduces the debt
        double remainingDebt = netDue - totalCollected;
        postingAmounts['toCustomerCredit'] = widget.customerPrevBalance + remainingDebt;
      } else {
        postingAmounts['toCustomerCredit'] = 0.0;
      }
      postingAmounts['balance'] = 0.0;
    } else {
      // Extra money collected
      double toCredit = 0.0;
      if (toCustomerCreditEnabled) {
        toCredit = toCustomerCredit; // Amount specified for customer credit
      }
      
      double cashBalance = balance - toCredit;
      if (cashBalance < 0) {
        cashBalance = 0.0;
        toCredit = balance; // Can't give more credit than available
      }
      
      // Post the minimum required to settle the purchase
      double amountToSettle = netDue;
      
      // Distribute settlement across payment methods proportionally
      if (totalCollected > 0) {
        double cashPortion = (cashAmount / totalCollected) * amountToSettle;
        double cardPortion = (cardAmount / totalCollected) * amountToSettle;
        double upiPortion = (upiAmount / totalCollected) * amountToSettle;
        
        postingAmounts['cash'] = cashPortion;
        postingAmounts['card'] = cardPortion;
        postingAmounts['upi'] = upiPortion;
      } else {
        postingAmounts['cash'] = 0.0;
        postingAmounts['card'] = 0.0;
        postingAmounts['upi'] = 0.0;
      }
      
      postingAmounts['toCustomerCredit'] = toCredit;
      postingAmounts['balance'] = cashBalance;
    }
    
    return postingAmounts;
  }

  void _calculateBalance() {
    debugPrint('🧮 === CALCULATE BALANCE START ===');
    
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount;
    
    double cashBal = 0.0;
    
    if (toCustomerCreditEnabled) {
      debugPrint('🔛 Toggle is ON - Calculating with customer credit consideration');
      
      if (widget.customerPrevBalance < 0) {
        // Customer has debt - use transaction excess logic for consistency with auto-fill
        debugPrint('💳 Customer has debt - using transaction excess logic');
        final transactionExcess = totalCollected - widget.cartTotal;
        debugPrint('💰 Transaction excess: ₹${transactionExcess.toStringAsFixed(2)}');
        
        if (transactionExcess > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = toCustomerCredit;
          
          // Clamp customer credit to available excess
          if (actualCustomerCredit > transactionExcess) {
            actualCustomerCredit = transactionExcess;
            debugPrint('  - Clamped customer credit to transaction excess: ₹${actualCustomerCredit.toStringAsFixed(2)}');
          }
          
          // Cash balance = transaction excess - customer credit
          cashBal = transactionExcess - actualCustomerCredit;
          debugPrint('  - Cash Balance = Transaction Excess (₹${transactionExcess.toStringAsFixed(2)}) - Customer Credit (₹${actualCustomerCredit.toStringAsFixed(2)}) = ₹${cashBal.toStringAsFixed(2)}');
        } else {
          cashBal = 0.0;
          debugPrint('  - No transaction excess, cash balance = 0');
        }
      } else {
        // Customer has positive/zero balance - use Net Due logic
        debugPrint('💵 Customer has credit/zero balance - using Net Due logic');
        // Net Due = Purchase Total - Customer Previous Balance
        double netDue = widget.cartTotal - widget.customerPrevBalance;
        debugPrint('💰 Net Due calculation:');
        debugPrint('  - Purchase Total: ₹${widget.cartTotal.toStringAsFixed(2)}');
        debugPrint('  - Customer Prev Balance: ₹${widget.customerPrevBalance.toStringAsFixed(2)}');
        debugPrint('  - Net Due: ₹${netDue.toStringAsFixed(2)}');
        
        // Available balance = Total Collected - Net Due
        double availableBalance = totalCollected - netDue;
        debugPrint('  - Total Collected: ₹${totalCollected.toStringAsFixed(2)}');
        debugPrint('  - Available Balance: ₹${availableBalance.toStringAsFixed(2)}');
        
        if (availableBalance > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = toCustomerCredit;
          
          // Clamp customer credit to available balance
          if (actualCustomerCredit > availableBalance) {
            actualCustomerCredit = availableBalance;
            debugPrint('  - Clamped customer credit to available balance: ₹${actualCustomerCredit.toStringAsFixed(2)}');
          }
          
          // Cash balance = available balance - customer credit
          cashBal = availableBalance - actualCustomerCredit;
          debugPrint('  - Cash Balance = Available Balance (₹${availableBalance.toStringAsFixed(2)}) - Customer Credit (₹${actualCustomerCredit.toStringAsFixed(2)}) = ₹${cashBal.toStringAsFixed(2)}');
        } else {
          cashBal = 0.0;
          debugPrint('  - No available balance, cash balance = 0');
        }
      }
    } else {
      debugPrint('🔴 Toggle is OFF - Using simple calculation');
      // Toggle OFF: Simple calculation without previous balance
      cashBal = totalCollected - widget.cartTotal;
      debugPrint('  - Cash Balance = Total Collected (₹${totalCollected.toStringAsFixed(2)}) - Cart Total (₹${widget.cartTotal.toStringAsFixed(2)}) = ₹${cashBal.toStringAsFixed(2)}');
    }
    
    // Clamp cash balance to never show negative values in UI
    // Negative balance means insufficient payment, but cash drawer can't give negative money
    if (cashBal < 0) {
      debugPrint('🚫 Clamping negative cash balance (₹${cashBal.toStringAsFixed(2)}) to 0 for UI display');
      cashBal = 0.0;
    }
    
    debugPrint('💵 Final cash balance: ₹${cashBal.toStringAsFixed(2)}');
    
    setState(() {
      balanceAmount = cashBal;
    });
    
    debugPrint('🧮 === CALCULATE BALANCE END ===\n');
  }

  double _getTotalPaidAmount() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    // Total Paid = amounts actually collected now (cash + card + UPI)
    return cashAmount + cardAmount + upiAmount;
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
      // Check if field has any text (including "0") to determine selection
      bool hasValue = controller.text.isNotEmpty;
      
      if (hasValue) {
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
          case 'toCustomerCredit':
            // Store the raw amount without clamping during editing
            toCustomerCredit = amount;
            break;
        }
      } else {
        // Only deselect when field is completely empty
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
          case 'toCustomerCredit':
            toCustomerCredit = 0.0;
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

            const SizedBox(height: 10),

            // Extended Summary
            BuildPaymentRow(
              amount: 'INR ${_getTotalPaidAmount().toStringAsFixed(2)}',
              title: 'Total Paid',
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.18,
                ColorManager.kPrimaryColor,
              ),
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s15,
                0.23,
                ColorManager.kPrimaryColor,
              ),
              color: ColorManager.kPrimaryColor,
            ),


            BuildPaymentRow(
              amount: 'INR ${widget.cartTotal.toStringAsFixed(2)}',
              title: 'Purchase Total',
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                ColorManager.textColor,
              ),
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s15,
                0.20,
                ColorManager.textColor,
              ),
              color: ColorManager.textColor,
            ),

            BuildPaymentRow(
              amount: _formatSigned(widget.customerPrevBalance),
              title: 'Customer Prev Balance',
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                widget.customerPrevBalance >= 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColorRed,
              ),
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s15,
                0.20,
                widget.customerPrevBalance >= 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColorRed,
              ),
              color: widget.customerPrevBalance >= 0
                  ? ColorManager.kButtonGreen
                  : ColorManager.textColorRed,
            ),

            const SizedBox(height: 8),
            const Divider(thickness: 1),
            const SizedBox(height: 8),

            // To Customer Credit - toggle + optional input
            Row(
              children: [
                Text(
                  'To Customer Credit',
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s14,
                    0.20,
                    ColorManager.kPrimaryColor,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: toCustomerCreditEnabled,
                  activeColor: ColorManager.kPrimaryColor,
                  onChanged: (value) {
                    setState(() {
                      debugPrint('=== TOGGLE TO CUSTOMER CREDIT ===');
                      debugPrint('Toggle value changed to: $value');
                      
                      toCustomerCreditEnabled = value;
                      if (toCustomerCreditEnabled) {
                        debugPrint('📈 TOGGLE ON - Enabling customer credit functionality');
                        
                        // Calculate current state
                        final currentBaseBalance = _computeBaseBalance();
                        final cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
                        final cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
                        final upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
                        final totalCollected = cashAmount + cardAmount + upiAmount;
                        final netDueWithToggle = widget.cartTotal - widget.customerPrevBalance;
                        final netDueWithoutToggle = widget.cartTotal;
                        
                        debugPrint('💰 Current Payment State:');
                        debugPrint('  - Cash: ₹${cashAmount.toStringAsFixed(2)}');
                        debugPrint('  - Card: ₹${cardAmount.toStringAsFixed(2)}');
                        debugPrint('  - UPI: ₹${upiAmount.toStringAsFixed(2)}');
                        debugPrint('  - Total Collected: ₹${totalCollected.toStringAsFixed(2)}');
                        debugPrint('');
                        debugPrint('🎯 Purchase & Balance Info:');
                        debugPrint('  - Purchase Total: ₹${widget.cartTotal.toStringAsFixed(2)}');
                        debugPrint('  - Customer Prev Balance: ₹${widget.customerPrevBalance.toStringAsFixed(2)}');
                        debugPrint('  - Net Due (Toggle OFF): ₹${netDueWithoutToggle.toStringAsFixed(2)}');
                        debugPrint('  - Net Due (Toggle ON): ₹${netDueWithToggle.toStringAsFixed(2)}');
                        debugPrint('  - Available Cash Balance: ₹${currentBaseBalance.toStringAsFixed(2)}');
                        debugPrint('');
                        
                        // Auto-fill logic with debt settlement priority
                        // Calculate transaction excess (money beyond purchase total)
                        final transactionExcess = totalCollected - widget.cartTotal;
                        
                        if (transactionExcess > 0) {
                          double prefillAmount;
                          
                          if (widget.customerPrevBalance < 0) {
                            // Customer owes money - prioritize debt settlement
                            final customerDebt = widget.customerPrevBalance.abs(); // Convert negative to positive
                            
                            debugPrint('💳 DEBT SETTLEMENT PRIORITY:');
                            debugPrint('  - Customer Debt: ₹${customerDebt.toStringAsFixed(2)}');
                            debugPrint('  - Transaction Excess: ₹${transactionExcess.toStringAsFixed(2)}');
                            debugPrint('  - Available Base Balance: ₹${currentBaseBalance.toStringAsFixed(2)}');
                            
                            if (customerDebt <= transactionExcess) {
                              // Can settle full debt from transaction excess - auto-fill with debt amount
                              prefillAmount = customerDebt;
                              debugPrint('  - Auto-filling with debt amount: ₹${prefillAmount.toStringAsFixed(2)} (can settle full debt)');
                            } else {
                              // Can't settle full debt - auto-fill with available transaction excess
                              prefillAmount = transactionExcess;
                              debugPrint('  - Auto-filling with transaction excess: ₹${prefillAmount.toStringAsFixed(2)} (partial debt settlement)');
                            }
                          } else {
                            // Customer has positive/zero balance - use available base balance as before
                            prefillAmount = currentBaseBalance;
                            debugPrint('  - Customer has credit/zero balance - auto-filling with base balance: ₹${prefillAmount.toStringAsFixed(2)}');
                          }
                          
                          toCustomerCreditController.text = prefillAmount.toStringAsFixed(2);
                          toCustomerCredit = prefillAmount;
                          debugPrint('✅ Auto-filled toCustomerCredit: ₹${prefillAmount.toStringAsFixed(2)}');
                        } else {
                          toCustomerCreditController.clear();
                          toCustomerCredit = 0.0;
                          debugPrint('ℹ️ No excess money available - field left empty');
                        }
                      } else {
                        debugPrint('📉 TOGGLE OFF - Disabling customer credit functionality');
                        debugPrint('  - Clearing toCustomerCredit field');
                        debugPrint('  - All excess money will go to cash balance');
                        
                        toCustomerCreditController.clear();
                        toCustomerCredit = 0.0;
                      }
                      
                      debugPrint('');
                      _calculateBalance();
                      debugPrint('=== END TOGGLE OPERATION ===\n');
                    });
                  },
                ),
              ],
            ),
            if (toCustomerCreditEnabled) ...[
              const SizedBox(height: 8),
              buildColumnWidgetForTextFields(
                controller: toCustomerCreditController,
                size: size,
                width: 600,
                height: size.height * .06,
                hintText: 'Enter amount to add as customer credit',
                focusNode: toCustomerCreditFocusNode,
                onTap: () {
                  Provider.of<KeyboardProvider>(context, listen: false).show(
                    'number',
                    toCustomerCreditController,
                    replaceOnFirstInput: true,
                  );
                },
                onchanged: (value) => _handleAmountControllerChange('toCustomerCredit', toCustomerCreditController),
              ),
              const SizedBox(height: 12),
            ],

            BuildPaymentRow(
              amount: 'INR ${balanceAmount.toStringAsFixed(2)}',
              title: 'Cash Balance',
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                balanceAmount > 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColor,
              ),
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s15,
                0.23,
                balanceAmount > 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColor,
              ),
              color: balanceAmount > 0
                  ? ColorManager.kButtonGreen
                  : ColorManager.textColor,
            ),

            const SizedBox(height: 20),
            CustomRoundButton(
              title: "Apply Payment Methods",
              fct: () {
                // Map To Customer Credit to legacy debit params for callback compatibility
                final double mappedCredit = double.tryParse(toCustomerCreditController.text) ?? 0.0;
                final bool mappedIsDebitSelected = toCustomerCreditEnabled && mappedCredit > 0;
                final String mappedDebitAmount = mappedIsDebitSelected
                    ? mappedCredit.toStringAsFixed(2)
                    : '';

                widget.onPaymentMethodSelected(
                  isCashSelected,
                  isCardSelected,
                  isUpiSelected,
                  mappedIsDebitSelected,
                  cashAmountController.text,
                  cardAmountController.text,
                  upiAmountController.text,
                  mappedDebitAmount,
                  transactionNumberController.text,
                  toCustomerCreditEnabled,
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
            readOnly: label == 'Balance',
            onTap: (label == 'Balance') ? null : () {
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

  Widget _buildPostingPreview() {
    Map<String, double> postingAmounts = _getPostingAmounts();
    
    return Container(
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
            'Posting Preview',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostingRow('Cash Posted:', postingAmounts['cash']!),
                    _buildPostingRow('Card Posted:', postingAmounts['card']!),
                    _buildPostingRow('UPI Posted:', postingAmounts['upi']!),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostingRow('To Customer Credit:', postingAmounts['toCustomerCredit']!, 
                        color: ColorManager.kButtonGreen),
                    _buildPostingRow('Cash Balance:', postingAmounts['balance']!, 
                        color: ColorManager.kButtonGreen),
                    _buildNetDueRow(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostingRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.14,
              color ?? ColorManager.textColor,
            ),
          ),
          Text(
            'INR ${amount.toStringAsFixed(2)}',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.14,
              color ?? ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetDueRow() {
    double netDue;
    if (toCustomerCreditEnabled) {
      netDue = widget.cartTotal - widget.customerPrevBalance;
    } else {
      netDue = widget.cartTotal;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Net Due:',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.14,
              ColorManager.kPrimaryColor,
            ),
          ),
          Text(
            'INR ${netDue.toStringAsFixed(2)}',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.14,
              ColorManager.kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxCreditHelper() {
    final cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    final cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    final upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    final totalCollected = cashAmount + cardAmount + upiAmount;
    
    // Calculate different credit scenarios
    final currentTransactionExcess = totalCollected - widget.cartTotal;
    final maxPossibleCredit = _computeBaseBalance(); // This includes previous balance effects
    final customerOwesAmount = widget.customerPrevBalance < 0 ? widget.customerPrevBalance.abs() : 0.0;
    
    debugPrint('🎯 MAX CREDIT HELPER CALCULATIONS:');
    debugPrint('  - Current Transaction Excess: ₹${currentTransactionExcess.toStringAsFixed(2)}');
    debugPrint('  - Max Possible Credit (with prev balance): ₹${maxPossibleCredit.toStringAsFixed(2)}');
    debugPrint('  - Customer Owes: ₹${customerOwesAmount.toStringAsFixed(2)}');
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Credit Options:',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.14,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Maximum possible credit button (main option)
              if (maxPossibleCredit > 0) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        toCustomerCreditController.text = maxPossibleCredit.toStringAsFixed(2);
                        toCustomerCredit = maxPossibleCredit;
                        debugPrint('📱 Quick fill: All available balance ₹${maxPossibleCredit.toStringAsFixed(2)}');
                        _calculateBalance();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: ColorManager.kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: ColorManager.kPrimaryColor),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'All Available',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s9,
                              0.10,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                          Text(
                            '₹${maxPossibleCredit.toStringAsFixed(2)}',
                            style: buildCustomStyle(
                              FontWeightManager.bold,
                              FontSize.s11,
                              0.12,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              
              // Cash Balance display (read-only)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Cash Balance',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s9,
                          0.10,
                          Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '₹${balanceAmount.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s11,
                          0.12,
                          balanceAmount > 0 ? ColorManager.kButtonGreen : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSigned(double value) {
    final sign = value >= 0 ? '+' : '-';
    final absVal = value.abs().toStringAsFixed(2);
    return '$sign$absVal';
  }
}
