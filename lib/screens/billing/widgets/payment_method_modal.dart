import 'dart:async';
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
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:get/get.dart';

class PaymentMethodModal extends StatefulWidget {
  final bool initialIsCashSelected;
  final bool initialIsCardSelected;
  final bool initialIsUpiSelected;
  final bool initialIsCodSelected;
  final bool initialIsDebitSelected;
  final String initialCashAmount;
  final String initialCardAmount;
  final String initialUpiAmount;
  final String initialCodAmount;
  final String initialDebitAmount;
  final String initialTransactionNumber;
  final double cartTotal;
  // Customer previous balance (positive = customer has credit; negative = customer owes)
  final double customerPrevBalance;
  final Function(
    bool isCash,
    bool isCard,
    bool isUpi,
    bool isCod,
    bool isDebit,
    String cashAmount,
    String cardAmount,
    String upiAmount,
    String codAmount,
    String debitAmount,
    String transactionNumber,
    bool toCustomerCredit, {
    String? cashMethodId,
    String? cardMethodId,
    String? upiMethodId,
    String? codMethodId,
  }) onPaymentMethodSelected;
  final VoidCallback?
      onAfterApply; // Optional callback to execute after applying payment methods
  final String? customButtonTitle; // Optional custom button title
  final bool closeOnApply; // Optional flag to control modal closing behavior
  final bool isDefaultCustomer; // Flag to hide previous balance for default customer
  final bool showConfirmButton; // Flag to show/hide the confirm button

  const PaymentMethodModal({
    Key? key,
    required this.initialIsCashSelected,
    required this.initialIsCardSelected,
    required this.initialIsUpiSelected,
    this.initialIsCodSelected = false,
    required this.initialIsDebitSelected,
    required this.initialCashAmount,
    required this.initialCardAmount,
    required this.initialUpiAmount,
    this.initialCodAmount = "",
    required this.initialDebitAmount,
    required this.initialTransactionNumber,
    required this.cartTotal,
    this.customerPrevBalance = 0.0,
    required this.onPaymentMethodSelected,
    this.onAfterApply,
    this.customButtonTitle,
    this.closeOnApply = true,
    this.isDefaultCustomer = false,
    this.showConfirmButton = true,
  }) : super(key: key);


  @override
  State<PaymentMethodModal> createState() => _PaymentMethodModalState();
}

class _PaymentMethodModalState extends State<PaymentMethodModal> {
  late bool isCashSelected;
  late bool isCardSelected;
  late bool isUpiSelected;
  late bool isCodSelected;
  late TextEditingController cashAmountController;
  late TextEditingController cardAmountController;
  late TextEditingController upiAmountController;
  late TextEditingController codAmountController;
  late TextEditingController transactionNumberController;
  late FocusNode cashAmountFocusNode;
  late FocusNode cardAmountFocusNode;
  late FocusNode upiAmountFocusNode;
  late FocusNode codAmountFocusNode;
  late FocusNode toCustomerCreditFocusNode;
  double balanceAmount = 0;
  Timer? _debounceTimer;

  // To Customer Credit toggle and controller
  bool toCustomerCreditEnabled = false;
  late TextEditingController toCustomerCreditController;
  double toCustomerCredit = 0.0;

  // Payment method IDs from API
  String? _cashPaymentMethodId;
  String? _cardPaymentMethodId;
  String? _upiPaymentMethodId;
  String? _codPaymentMethodId;
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  @override
  void initState() {
    super.initState();

    // Load payment methods from API
    _loadPaymentMethods();

    // Use existing selections without any defaults - let user select manually
    isCashSelected = widget.initialIsCashSelected;
    isCardSelected = widget.initialIsCardSelected;
    isUpiSelected = widget.initialIsUpiSelected;
    isCodSelected = widget.initialIsCodSelected;

    // Initialize controllers - handle auto-filled values properly
    cashAmountController = TextEditingController(
        text: widget.initialCashAmount.isEmpty ? "" : widget.initialCashAmount);
    cardAmountController = TextEditingController(
        text:
            widget.initialCardAmount.isEmpty || widget.initialCardAmount == "0"
                ? ""
                : widget.initialCardAmount);
    upiAmountController = TextEditingController(
        text: widget.initialUpiAmount.isEmpty || widget.initialUpiAmount == "0"
            ? ""
            : widget.initialUpiAmount);
    codAmountController = TextEditingController(
        text: widget.initialCodAmount.isEmpty || widget.initialCodAmount == "0"
            ? ""
            : widget.initialCodAmount);
    // Debit field removed. We'll map To Customer Credit to debit in the callback only.
    // Transaction number
    transactionNumberController =
        TextEditingController(text: widget.initialTransactionNumber);

    // Initialize focus nodes
    cashAmountFocusNode = FocusNode();
    cardAmountFocusNode = FocusNode();
    upiAmountFocusNode = FocusNode();
    codAmountFocusNode = FocusNode();
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
      if (toCustomerCreditFocusNode.hasFocus &&
          toCustomerCreditController.text.isNotEmpty) {
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
    codAmountController.addListener(
        () => _handleAmountControllerChange('cod', codAmountController));
    toCustomerCreditController.addListener(() => _handleAmountControllerChange(
        'toCustomerCredit', toCustomerCreditController));

    transactionNumberController.addListener(_debounceNotifyChanges);

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

  void _notifyChanges() {
    _debounceTimer?.cancel();
    final double mappedCredit =
        double.tryParse(toCustomerCreditController.text) ?? 0.0;
    final bool mappedIsDebitSelected =
        toCustomerCreditEnabled && mappedCredit > 0;
    final String mappedDebitAmount = mappedIsDebitSelected
        ? mappedCredit.toStringAsFixed(2)
        : '';

    widget.onPaymentMethodSelected(
      isCashSelected,
      isCardSelected,
      isUpiSelected,
      isCodSelected,
      mappedIsDebitSelected,
      isCashSelected ? cashAmountController.text : "",
      isCardSelected ? cardAmountController.text : "",
      isUpiSelected ? upiAmountController.text : "",
      isCodSelected ? codAmountController.text : "",
      mappedDebitAmount,
      transactionNumberController.text,
      toCustomerCreditEnabled,
      cashMethodId: _cashPaymentMethodId,
      cardMethodId: _cardPaymentMethodId,
      upiMethodId: _upiPaymentMethodId,
      codMethodId: _codPaymentMethodId,
    );
  }

  void _debounceNotifyChanges() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _notifyChanges();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    transactionNumberController.removeListener(_debounceNotifyChanges);
    cashAmountController.removeListener(
        () => _handleAmountControllerChange('cash', cashAmountController));
    cardAmountController.removeListener(
        () => _handleAmountControllerChange('card', cardAmountController));
    upiAmountController.removeListener(
        () => _handleAmountControllerChange('upi', upiAmountController));
    codAmountController.removeListener(
        () => _handleAmountControllerChange('cod', codAmountController));
    cashAmountController.dispose();
    cardAmountController.dispose();
    upiAmountController.dispose();
    codAmountController.dispose();
    transactionNumberController.dispose();
    cashAmountFocusNode.dispose();
    cardAmountFocusNode.dispose();
    upiAmountFocusNode.dispose();
    codAmountFocusNode.dispose();
    toCustomerCreditFocusNode.dispose();
    toCustomerCreditController.removeListener(() =>
        _handleAmountControllerChange(
            'toCustomerCredit', toCustomerCreditController));
    toCustomerCreditController.dispose();
    super.dispose();
  }

  /// Load payment methods from API and assign IDs
  Future<void> _loadPaymentMethods() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);

    // Check if payment methods are already cached in the provider
    final cachedMethods = masterDataProvider.paymentMethods;
    if (cachedMethods != null && cachedMethods.isNotEmpty) {
      debugPrint(
          '📋 [Payment Modal] Using cached payment methods: ${cachedMethods.length}');
      _assignPaymentMethodIds(cachedMethods);
      return;
    }

    // No cache, fetch from API
    setState(() {
      _isLoadingPaymentMethods = true;
    });

    try {
      final paymentMethods = await masterDataProvider.fetchPaymentMethods();

      if (mounted && paymentMethods != null) {
        debugPrint(
            '📋 [Payment Modal] Loaded payment methods: ${paymentMethods.length}');
        _assignPaymentMethodIds(paymentMethods);
      }
    } catch (e) {
      debugPrint('❌ [Payment Modal] Error loading payment methods: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPaymentMethods = false;
        });
      }
    }
  }

  /// Assign payment method IDs by matching value field
  void _assignPaymentMethodIds(List<MasterDataValue> methods) {
    // Sort to put CASH first
    final sortedMethods = List<MasterDataValue>.from(methods);
    sortedMethods.sort((a, b) {
      if (a.value.toUpperCase() == 'CASH') return -1;
      if (b.value.toUpperCase() == 'CASH') return 1;
      return a.value.compareTo(b.value);
    });

    setState(() {
      _paymentMethods = sortedMethods;
      _isLoadingPaymentMethods = false;

      // Assign IDs based on value field
      for (final method in sortedMethods) {
        final value = method.value.toUpperCase();
        if (value == 'CASH') {
          _cashPaymentMethodId = method.id.toString();
          debugPrint('💵 CASH ID: $_cashPaymentMethodId');
        } else if (value == 'CARD') {
          _cardPaymentMethodId = method.id.toString();
          debugPrint('💳 CARD ID: $_cardPaymentMethodId');
        } else if (value == 'UPI') {
          _upiPaymentMethodId = method.id.toString();
          debugPrint('📱 UPI ID: $_upiPaymentMethodId');
        } else if (value == 'COD') {
          _codPaymentMethodId = method.id.toString();
          debugPrint('📦 COD ID: $_codPaymentMethodId');
        }
      }
    });
  }

  // Base balance calculation: always based on current purchase total
  double _computeBaseBalance() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(codAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount + codAmount;

    // Net due is always the current purchase total in the modal
    final double netDue = widget.cartTotal;

    double balance = totalCollected - netDue;
    return balance > 0 ? balance : 0.0;
  }

  // Get the actual posting amounts for each payment method
  Map<String, double> _getPostingAmounts() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(codAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount + codAmount;

    // Net due is always the current purchase total in the modal
    final double netDue = widget.cartTotal;

    double balance = totalCollected - netDue;

    // Calculate posting amounts
    Map<String, double> postingAmounts = {
      'cash': 0.0,
      'card': 0.0,
      'upi': 0.0,
      'cod': 0.0,
      'toCustomerCredit': 0.0,
      'balance': 0.0,
    };

    if (balance <= 0) {
      // Not enough collected - all goes to settle purchase
      postingAmounts['cash'] = cashAmount;
      postingAmounts['card'] = cardAmount;
      postingAmounts['upi'] = upiAmount;
      postingAmounts['cod'] = codAmount;

      // No extra for credit/balance when underpaid
      postingAmounts['toCustomerCredit'] = 0.0;
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
        double codPortion = (codAmount / totalCollected) * amountToSettle;

        postingAmounts['cash'] = cashPortion;
        postingAmounts['card'] = cardPortion;
        postingAmounts['upi'] = upiPortion;
        postingAmounts['cod'] = codPortion;
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
    double codAmount = double.tryParse(codAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount + codAmount;

    double cashBal = 0.0;

    if (toCustomerCreditEnabled) {
      debugPrint(
          '🔛 Toggle is ON - Calculating with customer credit consideration');

      if (widget.customerPrevBalance < 0) {
        // Customer has debt - use transaction excess logic for consistency with auto-fill
        debugPrint('💳 Customer has debt - using transaction excess logic');
        final transactionExcess = totalCollected - widget.cartTotal;
        debugPrint(
            '💰 Transaction excess: ${transactionExcess.toStringAsFixed(2)}');

        if (transactionExcess > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = toCustomerCredit;

          // Clamp customer credit to available excess
          if (actualCustomerCredit > transactionExcess) {
            actualCustomerCredit = transactionExcess;
            debugPrint(
                '  - Clamped customer credit to transaction excess: ${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = transaction excess - customer credit
          cashBal = transactionExcess - actualCustomerCredit;
          debugPrint(
              '  - Cash Balance = Transaction Excess (${transactionExcess.toStringAsFixed(2)}) - Customer Credit (${actualCustomerCredit.toStringAsFixed(2)}) = ${cashBal.toStringAsFixed(2)}');
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
        debugPrint(
            '  - Purchase Total: ${widget.cartTotal.toStringAsFixed(2)}');
        debugPrint(
            '  - Customer Prev Balance: ${widget.customerPrevBalance.toStringAsFixed(2)}');
        debugPrint('  - Net Due: ${netDue.toStringAsFixed(2)}');

        // Available balance = Total Collected - Net Due
        double availableBalance = totalCollected - netDue;
        debugPrint('  - Total Collected: ${totalCollected.toStringAsFixed(2)}');
        debugPrint(
            '  - Available Balance: ${availableBalance.toStringAsFixed(2)}');

        if (availableBalance > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = toCustomerCredit;

          // Clamp customer credit to available balance
          if (actualCustomerCredit > availableBalance) {
            actualCustomerCredit = availableBalance;
            debugPrint(
                '  - Clamped customer credit to available balance: ${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = available balance - customer credit
          cashBal = availableBalance - actualCustomerCredit;
          debugPrint(
              '  - Cash Balance = Available Balance (${availableBalance.toStringAsFixed(2)}) - Customer Credit (${actualCustomerCredit.toStringAsFixed(2)}) = ${cashBal.toStringAsFixed(2)}');
        } else {
          cashBal = 0.0;
          debugPrint('  - No available balance, cash balance = 0');
        }
      }
    } else {
      debugPrint('🔴 Toggle is OFF - Using simple calculation');
      // Toggle OFF: Simple calculation without previous balance
      cashBal = totalCollected - widget.cartTotal;
      debugPrint(
          '  - Cash Balance = Total Collected (${totalCollected.toStringAsFixed(2)}) - Cart Total (${widget.cartTotal.toStringAsFixed(2)}) = ${cashBal.toStringAsFixed(2)}');
    }

    // Clamp cash balance to never show negative values in UI
    // Negative balance means insufficient payment, but cash drawer can't give negative money
    if (cashBal < 0) {
      debugPrint(
          '🚫 Clamping negative cash balance (${cashBal.toStringAsFixed(2)}) to 0 for UI display');
      cashBal = 0.0;
    }

    debugPrint('💵 Final cash balance: ${cashBal.toStringAsFixed(2)}');

    setState(() {
      balanceAmount = cashBal;
    });

    debugPrint('🧮 === CALCULATE BALANCE END ===\n');
  }

  double _getTotalPaidAmount() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(codAmountController.text) ?? 0.0;
    // Total Paid = amounts actually collected now (cash + card + UPI + COD)
    return cashAmount + cardAmount + upiAmount + codAmount;
  }

  void _togglePaymentMethod(String paymentType) {
    setState(() {
      bool targetSelected;
      TextEditingController? targetController;
      FocusNode? targetFocusNode;

      switch (paymentType) {
        case 'cash':
          isCashSelected = !isCashSelected;
          targetSelected = isCashSelected;
          targetController = cashAmountController;
          targetFocusNode = cashAmountFocusNode;
          if (!isCashSelected) cashAmountController.clear();
          break;
        case 'card':
          isCardSelected = !isCardSelected;
          targetSelected = isCardSelected;
          targetController = cardAmountController;
          targetFocusNode = cardAmountFocusNode;
          if (!isCardSelected) cardAmountController.clear();
          break;
        case 'upi':
          isUpiSelected = !isUpiSelected;
          targetSelected = isUpiSelected;
          targetController = upiAmountController;
          targetFocusNode = upiAmountFocusNode;
          if (!isUpiSelected) upiAmountController.clear();
          break;
        case 'cod':
          isCodSelected = !isCodSelected;
          targetSelected = isCodSelected;
          targetController = codAmountController;
          targetFocusNode = codAmountFocusNode;
          if (!isCodSelected) codAmountController.clear();
          break;
        default:
          return;
      }

      // Handle selection (Toggle ON)
      if (targetSelected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            targetFocusNode?.requestFocus();
            // Also trigger the keyboard immediately
            Provider.of<KeyboardProvider>(context, listen: false).show(
              'number',
              targetController!,
              replaceOnFirstInput: true,
            );
          }
        });
      }
      // Handle deselection (Toggle OFF) - Auto-fill logic for remaining method
      else {
        // Find remaining active methods
        List<MapEntry<String, TextEditingController>> activeMethods = [];
        if (isCashSelected) {
          activeMethods.add(MapEntry('cash', cashAmountController));
        }
        if (isCardSelected) {
          activeMethods.add(MapEntry('card', cardAmountController));
        }
        if (isUpiSelected) {
          activeMethods.add(MapEntry('upi', upiAmountController));
        }
        if (isCodSelected) {
          activeMethods.add(MapEntry('cod', codAmountController));
        }

        // If exactly one method is left, fill it with the total
        if (activeMethods.length == 1) {
          final remainingMethod = activeMethods.first;
          remainingMethod.value.text = widget.cartTotal.toStringAsFixed(2);

          // Focus and show keyboard for the remaining method
          FocusNode? remainingFocusNode;
          if (isCashSelected) remainingFocusNode = cashAmountFocusNode;
          if (isCardSelected) remainingFocusNode = cardAmountFocusNode;
          if (isUpiSelected) remainingFocusNode = upiAmountFocusNode;
          if (isCodSelected) remainingFocusNode = codAmountFocusNode;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              remainingFocusNode?.requestFocus();
              Provider.of<KeyboardProvider>(context, listen: false).show(
                'number',
                remainingMethod.value,
                replaceOnFirstInput: true,
              );
            }
          });
        }
      }

      _calculateBalance();
      _notifyChanges();
    });
  }

  // ---- Utility to handle text changes from any source (hardware or virtual keyboard) ----
  void _handleAmountControllerChange(
      String label, TextEditingController controller) {
    double amount = double.tryParse(controller.text) ?? 0;

    setState(() {
      // Use the raw text to determine if we should auto-select
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
          case 'cod':
            isCodSelected = true;
            break;
          case 'toCustomerCredit':
            // Store the raw amount without clamping during editing
            toCustomerCredit = amount;
            break;
        }
      } else {
        // Do NOT auto-deselect payment methods when field is empty.
        // Selection should be controlled by the manual toggle (icon click) or explicit onTap.
        if (label == 'toCustomerCredit') {
          toCustomerCredit = 0.0;
        }
      }
    });

    // Don't recalculate if this is the balance field being updated by calculation
    if (label != 'balance') {
      _calculateBalance();
      _debounceNotifyChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';

    // Calculate width: 85% of screen width, clamped between 550 and 900
    double modalWidth = size.width * 0.85;
    if (modalWidth > 900) modalWidth = 900;
    if (modalWidth < 550) modalWidth = 550;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        width: modalWidth,
        circleRadius: 12,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'billing.payment_methods'.tr,
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

              // Two-Column Layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN: Inputs ---
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoadingPaymentMethods)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_paymentMethods.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No payment methods available',
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s14,
                                  0.20,
                                  ColorManager.textColorRed,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          // Cash Payment
                          if (_cashPaymentMethodId != null) ...[
                            _buildModalPaymentRow(
                              isSelected: isCashSelected,
                              type: 'cash',
                              icon: ImageAssets.cashIcon,
                              label: 'billing.cash'.tr,
                              controller: cashAmountController,
                              focusNode: cashAmountFocusNode,
                              size: size,
                              onToggle: () => _togglePaymentMethod('cash'),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // Card Payment
                          if (_cardPaymentMethodId != null) ...[
                            _buildModalPaymentRow(
                              isSelected: isCardSelected,
                              type: 'card',
                              icon: ImageAssets.creditCardIcon,
                              label: 'billing.card'.tr,
                              controller: cardAmountController,
                              focusNode: cardAmountFocusNode,
                              size: size,
                              onToggle: () => _togglePaymentMethod('card'),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // UPI Payment
                          if (_upiPaymentMethodId != null) ...[
                            _buildModalPaymentRow(
                              isSelected: isUpiSelected,
                              type: 'upi',
                              icon: ImageAssets.creditCardIcon,
                              label: 'billing.upi'.tr,
                              controller: upiAmountController,
                              focusNode: upiAmountFocusNode,
                              size: size,
                              onToggle: () => _togglePaymentMethod('upi'),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // COD Payment
                          if (_codPaymentMethodId != null) ...[
                            _buildModalPaymentRow(
                              isSelected: isCodSelected,
                              type: 'cod',
                              icon: ImageAssets.cashIcon,
                              label: 'COD',
                              controller: codAmountController,
                              focusNode: codAmountFocusNode,
                              size: size,
                              onToggle: () => _togglePaymentMethod('cod'),
                            ),
                            const SizedBox(height: 15),
                          ],
                        ],

                        // Transaction Reference Field
                        if (isCardSelected || isUpiSelected) ...[
                          const SizedBox(height: 10),
                          Text(
                            'billing.transaction_reference'.tr,
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
                            width: double.infinity,
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
                      ],
                    ),
                  ),

                  const SizedBox(width: 30),

                  // --- RIGHT COLUMN: Summary & Actions ---
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Extended Summary
                        BuildPaymentRow(
                          amount: '$currency ${_getTotalPaidAmount().toStringAsFixed(2)}',
                          title: 'billing.total_paid'.tr,
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
                          amount: '$currency ${widget.cartTotal.toStringAsFixed(2)}',
                          title: 'billing.purchase_total'.tr,
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

                        // Only show customer previous balance if NOT default customer
                        if (!widget.isDefaultCustomer)
                          BuildPaymentRow(
                            amount: _formatSignedWithCurrency(widget.customerPrevBalance),
                            title: 'billing.customer_prev_balance'.tr,
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

                        // To Customer Credit
                        Row(
                          children: [
                            Text(
                              'billing.to_customer_credit'.tr,
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
                                    debugPrint(
                                        '📈 TOGGLE ON - Enabling customer credit functionality');

                                    // Calculate current state
                                    final currentBaseBalance = _computeBaseBalance();
                                    final cashAmount =
                                        double.tryParse(cashAmountController.text) ?? 0.0;
                                    final cardAmount =
                                        double.tryParse(cardAmountController.text) ?? 0.0;
                                    final upiAmount =
                                        double.tryParse(upiAmountController.text) ?? 0.0;
                                    final codAmount =
                                        double.tryParse(codAmountController.text) ?? 0.0;
                                    final totalCollected =
                                        cashAmount + cardAmount + upiAmount + codAmount;

                                    // Auto-fill logic with debt settlement priority
                                    final transactionExcess =
                                        totalCollected - widget.cartTotal;

                                    if (transactionExcess > 0) {
                                      double prefillAmount;

                                      if (widget.customerPrevBalance < 0) {
                                        // Customer owes money - prioritize debt settlement
                                        final customerDebt = widget.customerPrevBalance.abs();
                                        if (customerDebt <= transactionExcess) {
                                          prefillAmount = customerDebt;
                                        } else {
                                          prefillAmount = transactionExcess;
                                        }
                                      } else {
                                        prefillAmount = currentBaseBalance;
                                      }

                                      toCustomerCreditController.text =
                                          prefillAmount.toStringAsFixed(2);
                                      toCustomerCredit = prefillAmount;
                                    } else {
                                      toCustomerCreditController.clear();
                                      toCustomerCredit = 0.0;
                                    }
                                  } else {
                                    debugPrint(
                                        '📉 TOGGLE OFF - Disabling customer credit functionality');
                                    toCustomerCreditController.clear();
                                    toCustomerCredit = 0.0;
                                  }

                                  debugPrint('');
                                  _calculateBalance();
                                  _notifyChanges();
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
                            width: double.infinity,
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
                            onchanged: (value) => _handleAmountControllerChange(
                                'toCustomerCredit', toCustomerCreditController),
                          ),
                          const SizedBox(height: 12),
                        ],

                        BuildPaymentRow(
                          amount: '$currency ${balanceAmount.toStringAsFixed(2)}',
                          title: 'billing.cash_balance'.tr,
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
                        if (widget.showConfirmButton)
                          CustomRoundButton(
                            title: widget.customButtonTitle ??
                                'billing.apply_payment_methods'.tr,
                            fct: () {
                              _notifyChanges();
                              if (widget.closeOnApply) {
                                Navigator.of(context).pop();
                              }

                              if (widget.onAfterApply != null) {
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  widget.onAfterApply!();
                                });
                              }
                            },
                            fontSize: FontSize.s14,
                            height: 45,
                            width: double.infinity,
                          ),
                      ],
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

  Widget _buildModalPaymentRow({
    required bool isSelected,
    required String type,
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
                  colorFilter: ColorFilter.mode(
                      isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                      BlendMode.srcIn),
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
            hintText:
                label == 'Balance' ? 'Auto-calculated' : 'Enter $label amount',
            keyboardType: TextInputType.number,
            focusNode: focusNode,
            readOnly: label == 'Balance',
            onTap: (type == 'Balance')
                ? null
                : () {
                    // Update selection state if not already selected
                    setState(() {
                      if (type == 'cash')
                        isCashSelected = true;
                      else if (type == 'card')
                        isCardSelected = true;
                      else if (type == 'upi')
                        isUpiSelected = true;
                      else if (type == 'cod') isCodSelected = true;
                      _notifyChanges();
                    });

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
            'billing.posting_preview'.tr,
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
                    _buildPostingRow('COD Posted:', postingAmounts['cod']!),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostingRow('To Customer Credit:',
                        postingAmounts['toCustomerCredit']!,
                        color: ColorManager.kButtonGreen),
                    _buildPostingRow(
                        'Cash Balance:', postingAmounts['balance']!,
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
    final currency = Provider.of<AppSettingsProvider>(context, listen: true)
            .appSettings
            ?.currency ??
        'INR';
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
            '$currency ${amount.toStringAsFixed(2)}',
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
    // Net due display is always based on current purchase
    final double netDue = widget.cartTotal;
    final currency = Provider.of<AppSettingsProvider>(context, listen: true)
            .appSettings
            ?.currency ??
        'INR';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'billing.net_due'.tr + ':',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.14,
              ColorManager.kPrimaryColor,
            ),
          ),
          Text(
            '$currency ${netDue.toStringAsFixed(2)}',
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
    final codAmount = double.tryParse(codAmountController.text) ?? 0.0;
    final totalCollected = cashAmount + cardAmount + upiAmount + codAmount;
    final currency = Provider.of<AppSettingsProvider>(context, listen: true)
            .appSettings
            ?.currency ??
        'INR';

    // Calculate different credit scenarios
    final currentTransactionExcess = totalCollected - widget.cartTotal;
    final maxPossibleCredit =
        _computeBaseBalance(); // This includes previous balance effects
    final customerOwesAmount =
        widget.customerPrevBalance < 0 ? widget.customerPrevBalance.abs() : 0.0;

    debugPrint('🎯 MAX CREDIT HELPER CALCULATIONS:');
    debugPrint(
        '  - Current Transaction Excess: ${currentTransactionExcess.toStringAsFixed(2)}');
    debugPrint(
        '  - Max Possible Credit (with prev balance): ${maxPossibleCredit.toStringAsFixed(2)}');
    debugPrint('  - Customer Owes: ${customerOwesAmount.toStringAsFixed(2)}');

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
            'billing.quick_credit_options'.tr + ':',
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
                        toCustomerCreditController.text =
                            maxPossibleCredit.toStringAsFixed(2);
                        toCustomerCredit = maxPossibleCredit;
                        debugPrint(
                            '📱 Quick fill: All available balance ${maxPossibleCredit.toStringAsFixed(2)}');
                        _calculateBalance();
                        _notifyChanges();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: ColorManager.kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: ColorManager.kPrimaryColor),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'billing.all_available'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s9,
                              0.10,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                          Text(
                            '$currency ${maxPossibleCredit.toStringAsFixed(2)}',
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'billing.cash_balance'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s9,
                          0.10,
                          Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '$currency ${balanceAmount.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s11,
                          0.12,
                          balanceAmount > 0
                              ? ColorManager.kButtonGreen
                              : Colors.grey.shade600,
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

  String _formatSignedWithCurrency(double value) {
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';
    final sign = value >= 0 ? '+' : '-';
    final absVal = value.abs().toStringAsFixed(2);
    return '$sign$currency $absVal';
  }
}
