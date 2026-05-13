import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
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
import 'package:pos_machine/helpers/payment_auto_fill_helper.dart';

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
  final bool
      isDefaultCustomer; // Flag to hide previous balance for default customer
  final bool showConfirmButton; // Flag to show/hide the confirm button
  final bool showAsDialog;
  final bool showShadow;
  final bool fullWidth;

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
    this.showAsDialog = true,
    this.showShadow = true,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  State<PaymentMethodModal> createState() => _PaymentMethodModalState();
}

class _PaymentMethodModalState extends State<PaymentMethodModal> {
  late bool isCashSelected;
  late bool isCardSelected;
  late bool isUpiSelected;
  late bool isCodSelected;

  /// Identifier of the payment-method tile that currently has keyboard
  /// focus (`'cash' | 'card' | 'upi' | 'cod' | 'credit'`), or null when
  /// no payment tile is focused. Drives the visible orange focus ring
  /// rendered around the focused tile in [_buildModalPaymentRow].
  String? _focusedPaymentKey;
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
  late FocusNode transactionNumberFocusNode;
  double balanceAmount = 0;
  Timer? _debounceTimer;

  late VoidCallback _cashAmountListener;
  late VoidCallback _cardAmountListener;
  late VoidCallback _upiAmountListener;
  late VoidCallback _codAmountListener;
  late VoidCallback _toCustomerCreditListener;

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

  // Credit option (visual only, for sales staff)
  bool isCreditSelected = false;
  late TextEditingController creditAmountController;
  bool _isApplying = false;

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
    transactionNumberFocusNode = FocusNode();

    // Initialize To Customer Credit controller
    toCustomerCreditController = TextEditingController();

    // Initialize Credit amount controller (visual only)
    creditAmountController = TextEditingController();

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
    transactionNumberFocusNode.addListener(() {
      if (transactionNumberFocusNode.hasFocus &&
          transactionNumberController.text.isNotEmpty) {
        transactionNumberController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: transactionNumberController.text.length,
        );
      }
    });

    // Listen for text changes to capture virtual keyboard input
    _cashAmountListener =
        () => _handleAmountControllerChange('cash', cashAmountController);
    _cardAmountListener =
        () => _handleAmountControllerChange('card', cardAmountController);
    _upiAmountListener =
        () => _handleAmountControllerChange('upi', upiAmountController);
    _codAmountListener =
        () => _handleAmountControllerChange('cod', codAmountController);
    _toCustomerCreditListener = () => _handleAmountControllerChange(
        'toCustomerCredit', toCustomerCreditController);

    cashAmountController.addListener(_cashAmountListener);
    cardAmountController.addListener(_cardAmountListener);
    upiAmountController.addListener(_upiAmountListener);
    codAmountController.addListener(_codAmountListener);
    toCustomerCreditController.addListener(_toCustomerCreditListener);

    transactionNumberController.addListener(_debounceNotifyChanges);

    // If there is an initial debit value (>0), reflect it as To Customer Credit
    final initDebit = double.tryParse(widget.initialDebitAmount) ?? 0.0;
    if (initDebit > 0) {
      toCustomerCreditEnabled = true;
      toCustomerCreditController.text = initDebit.toStringAsFixed(2);
      // Keep debit selection as provided by parent but ensure consistency in display
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateBalance());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusInitialSelectedPaymentAmount();
    });
    HardwareKeyboard.instance.addHandler(_onPaymentHardwareKey);
  }

  void _focusInitialSelectedPaymentAmount() {
    if (!mounted) return;

    TextEditingController? controller;
    FocusNode? focusNode;

    if (isCashSelected && cashAmountController.text.isNotEmpty) {
      controller = cashAmountController;
      focusNode = cashAmountFocusNode;
    } else if (isCardSelected && cardAmountController.text.isNotEmpty) {
      controller = cardAmountController;
      focusNode = cardAmountFocusNode;
    } else if (isUpiSelected && upiAmountController.text.isNotEmpty) {
      controller = upiAmountController;
      focusNode = upiAmountFocusNode;
    } else if (isCodSelected && codAmountController.text.isNotEmpty) {
      controller = codAmountController;
      focusNode = codAmountFocusNode;
    } else if (isCashSelected) {
      controller = cashAmountController;
      focusNode = cashAmountFocusNode;
    } else if (isCardSelected) {
      controller = cardAmountController;
      focusNode = cardAmountFocusNode;
    } else if (isUpiSelected) {
      controller = upiAmountController;
      focusNode = upiAmountFocusNode;
    } else if (isCodSelected) {
      controller = codAmountController;
      focusNode = codAmountFocusNode;
    }

    if (controller == null || focusNode == null) return;

    focusNode.requestFocus();
    if (controller.text.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }
    Provider.of<KeyboardProvider>(context, listen: false).show(
      'number',
      controller,
      replaceOnFirstInput: true,
    );
  }

  void _notifyChanges() {
    if (!mounted) {
      return;
    }
    _debounceTimer?.cancel();
    final double creditAmount =
        double.tryParse(creditAmountController.text) ?? 0.0;
    final double mappedCredit =
        double.tryParse(toCustomerCreditController.text) ?? 0.0;
    final bool mappedIsDebitSelected =
        (toCustomerCreditEnabled && mappedCredit > 0) ||
            (isCreditSelected && creditAmount > 0);
    final String mappedDebitAmount = mappedIsDebitSelected
        ? (isCreditSelected && creditAmount > 0
            ? creditAmount.toStringAsFixed(2)
            : mappedCredit.toStringAsFixed(2))
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
    HardwareKeyboard.instance.removeHandler(_onPaymentHardwareKey);
    _debounceTimer?.cancel();
    transactionNumberController.removeListener(_debounceNotifyChanges);
    cashAmountController.removeListener(_cashAmountListener);
    cardAmountController.removeListener(_cardAmountListener);
    upiAmountController.removeListener(_upiAmountListener);
    codAmountController.removeListener(_codAmountListener);
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
    transactionNumberFocusNode.dispose();
    toCustomerCreditController.removeListener(_toCustomerCreditListener);
    toCustomerCreditController.dispose();
    creditAmountController.dispose();
    super.dispose();
  }

  bool _onPaymentHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isControlPressed) return false;

    final digitMap = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit1: 1,
      LogicalKeyboardKey.numpad1: 1,
      LogicalKeyboardKey.digit2: 2,
      LogicalKeyboardKey.numpad2: 2,
      LogicalKeyboardKey.digit3: 3,
      LogicalKeyboardKey.numpad3: 3,
      LogicalKeyboardKey.digit4: 4,
      LogicalKeyboardKey.numpad4: 4,
      LogicalKeyboardKey.digit5: 5,
      LogicalKeyboardKey.numpad5: 5,
    };
    final methodIndex = digitMap[event.logicalKey];
    if (methodIndex != null) {
      _toggleOrFocusPaymentByIndex(methodIndex);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit6 ||
        event.logicalKey == LogicalKeyboardKey.numpad6) {
      if (isCardSelected || isUpiSelected) {
        transactionNumberFocusNode.requestFocus();
        Provider.of<KeyboardProvider>(context, listen: false).show(
          'number',
          transactionNumberController,
          replaceOnFirstInput: true,
        );
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit7 ||
        event.logicalKey == LogicalKeyboardKey.numpad7) {
      _setToCustomerCreditEnabled(!toCustomerCreditEnabled);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit8 ||
        event.logicalKey == LogicalKeyboardKey.numpad8) {
      if (!toCustomerCreditEnabled) {
        _setToCustomerCreditEnabled(true);
      }
      toCustomerCreditFocusNode.requestFocus();
      Provider.of<KeyboardProvider>(context, listen: false).show(
        'number',
        toCustomerCreditController,
        replaceOnFirstInput: true,
      );
      return true;
    }
    return false;
  }

  void _setToCustomerCreditEnabled(bool enabled) {
    setState(() {
      toCustomerCreditEnabled = enabled;
      if (enabled) {
        final currentBaseBalance = _computeBaseBalance();
        final cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
        final cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
        final upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
        final codAmount = double.tryParse(codAmountController.text) ?? 0.0;
        final totalCollected = cashAmount + cardAmount + upiAmount + codAmount;
        final transactionExcess = totalCollected - widget.cartTotal;
        if (transactionExcess > 0) {
          double prefillAmount;
          if (widget.customerPrevBalance < 0) {
            final customerDebt = widget.customerPrevBalance.abs();
            prefillAmount = customerDebt <= transactionExcess
                ? customerDebt
                : transactionExcess;
          } else {
            prefillAmount = currentBaseBalance;
          }
          toCustomerCreditController.text = prefillAmount.toStringAsFixed(2);
          toCustomerCredit = prefillAmount;
        } else {
          toCustomerCreditController.clear();
          toCustomerCredit = 0.0;
        }
      } else {
        toCustomerCreditController.clear();
        toCustomerCredit = 0.0;
      }
      _calculateBalance();
      _debounceNotifyChanges();
    });
  }

  void _focusPaymentFieldByIndex(int index) {
    final List<MapEntry<TextEditingController, FocusNode>> orderedFields = [];
    if (_cashPaymentMethodId != null) {
      orderedFields.add(MapEntry(cashAmountController, cashAmountFocusNode));
    }
    if (_cardPaymentMethodId != null) {
      orderedFields.add(MapEntry(cardAmountController, cardAmountFocusNode));
    }
    if (_upiPaymentMethodId != null) {
      orderedFields.add(MapEntry(upiAmountController, upiAmountFocusNode));
    }
    if (_codPaymentMethodId != null) {
      orderedFields.add(MapEntry(codAmountController, codAmountFocusNode));
    }
    if (orderedFields.isEmpty) return;

    final int target = index.clamp(1, orderedFields.length) - 1;
    final entry = orderedFields[target];
    entry.value.requestFocus();
    if (entry.key.text.isNotEmpty) {
      entry.key.selection = TextSelection(
        baseOffset: 0,
        extentOffset: entry.key.text.length,
      );
    }
    Provider.of<KeyboardProvider>(context, listen: false).show(
      'number',
      entry.key,
      replaceOnFirstInput: true,
    );
  }

  void _toggleOrFocusPaymentByIndex(int index) {
    final orderedTypes = <String>[];
    if (_cashPaymentMethodId != null) orderedTypes.add('cash');
    if (_cardPaymentMethodId != null) orderedTypes.add('card');
    if (_upiPaymentMethodId != null) orderedTypes.add('upi');
    if (_codPaymentMethodId != null) orderedTypes.add('cod');
    if (orderedTypes.isEmpty) return;

    final target = orderedTypes[index.clamp(1, orderedTypes.length) - 1];
    if (_isPaymentTypeSelected(target)) {
      _focusPaymentFieldByIndex(index);
      return;
    }

    _togglePaymentMethod(target);
  }

  bool _isPaymentTypeSelected(String paymentType) {
    switch (paymentType) {
      case 'cash':
        return isCashSelected;
      case 'card':
        return isCardSelected;
      case 'upi':
        return isUpiSelected;
      case 'cod':
        return isCodSelected;
      default:
        return false;
    }
  }

  String? _shortcutForPaymentType(String type) {
    int idx = 0;
    if (_cashPaymentMethodId != null) {
      idx++;
      if (type == 'cash') return 'C+$idx';
    }
    if (_cardPaymentMethodId != null) {
      idx++;
      if (type == 'card') return 'C+$idx';
    }
    if (_upiPaymentMethodId != null) {
      idx++;
      if (type == 'upi') return 'C+$idx';
    }
    if (_codPaymentMethodId != null) {
      idx++;
      if (type == 'cod') return 'C+$idx';
    }
    return null;
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

    // Notify parent with the newly loaded payment method IDs
    // This ensures parent receives IDs as soon as they're available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyChanges();
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

    if (mounted) {
      setState(() {
        balanceAmount = cashBal;
      });
    }

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

  void _autoFillSelectedMethodAmount(String paymentType) {
    TextEditingController? targetController;

    switch (paymentType) {
      case 'cash':
        targetController = cashAmountController;
        break;
      case 'card':
        targetController = cardAmountController;
        break;
      case 'upi':
        targetController = upiAmountController;
        break;
      case 'cod':
        targetController = codAmountController;
        break;
      default:
        return;
    }

    targetController.text = PaymentAutoFillHelper.autoFillSingleMethod(
      paymentType: paymentType,
      currentTargetAmount: targetController.text,
      cashAmount: cashAmountController.text,
      cardAmount: cardAmountController.text,
      upiAmount: upiAmountController.text,
      codAmount: codAmountController.text,
      cartTotal: widget.cartTotal,
    );
  }

  void _syncCreditAmountWithRemaining() {
    if (!isCreditSelected) {
      return;
    }

    final cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    final cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    final upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    final codAmount = double.tryParse(codAmountController.text) ?? 0.0;

    final totalCollected = cashAmount + cardAmount + upiAmount + codAmount;
    final remainingAmount = widget.cartTotal - totalCollected;

    if (remainingAmount > 0) {
      creditAmountController.text = remainingAmount.toStringAsFixed(2);
    } else {
      creditAmountController.clear();
    }
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
        case 'credit':
          isCreditSelected = !isCreditSelected;
          targetSelected = isCreditSelected;
          targetController = creditAmountController;
          targetFocusNode = null;
          if (!isCreditSelected) {
            creditAmountController.clear();
          } else {
            _syncCreditAmountWithRemaining();
          }
          break;
        default:
          return;
      }

      // Handle selection (Toggle ON)
      if (targetSelected) {
        _autoFillSelectedMethodAmount(paymentType);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            targetFocusNode?.requestFocus();
            // Also trigger the keyboard immediately
            if (paymentType != 'credit' && targetController != null) {
              Provider.of<KeyboardProvider>(context, listen: false).show(
                'number',
                targetController,
                replaceOnFirstInput: true,
              );
            }
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

      _syncCreditAmountWithRemaining();

      _calculateBalance();
      _notifyChanges();
    });
  }

  // ---- Utility to handle text changes from any source (hardware or virtual keyboard) ----
  void _handleAmountControllerChange(
      String label, TextEditingController controller) {
    if (!mounted) {
      return;
    }
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

    if (label == 'cash' ||
        label == 'card' ||
        label == 'upi' ||
        label == 'cod') {
      _syncCreditAmountWithRemaining();
    }

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

    Widget content = BuildBoxShadowContainer(
      width: widget.fullWidth ? double.infinity : modalWidth,
      circleRadius: 12,
      color: Colors.white,
      showShadow: widget.showShadow,
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
                if (widget.showAsDialog)
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
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
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
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(10),
                              child: _buildModalPaymentRow(
                                isSelected: isCashSelected,
                                type: 'cash',
                                icon: ImageAssets.cashIcon,
                                label: 'billing.cash'.tr,
                                controller: cashAmountController,
                                focusNode: cashAmountFocusNode,
                                size: size,
                                onToggle: () => _togglePaymentMethod('cash'),
                                shortcutLabel: _shortcutForPaymentType('cash'),
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // Card Payment
                          if (_cardPaymentMethodId != null) ...[
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(20),
                              child: _buildModalPaymentRow(
                                isSelected: isCardSelected,
                                type: 'card',
                                icon: ImageAssets.creditCardIcon,
                                label: 'billing.card'.tr,
                                controller: cardAmountController,
                                focusNode: cardAmountFocusNode,
                                size: size,
                                onToggle: () => _togglePaymentMethod('card'),
                                shortcutLabel: _shortcutForPaymentType('card'),
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // UPI Payment
                          if (_upiPaymentMethodId != null) ...[
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(30),
                              child: _buildModalPaymentRow(
                                isSelected: isUpiSelected,
                                type: 'upi',
                                icon: ImageAssets.creditCardIcon,
                                label: 'billing.upi'.tr,
                                controller: upiAmountController,
                                focusNode: upiAmountFocusNode,
                                size: size,
                                onToggle: () => _togglePaymentMethod('upi'),
                                shortcutLabel: _shortcutForPaymentType('upi'),
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // COD Payment
                          if (_codPaymentMethodId != null) ...[
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(40),
                              child: _buildModalPaymentRow(
                                isSelected: isCodSelected,
                                type: 'cod',
                                icon: ImageAssets.cashIcon,
                                label: 'COD',
                                controller: codAmountController,
                                focusNode: codAmountFocusNode,
                                size: size,
                                onToggle: () => _togglePaymentMethod('cod'),
                                shortcutLabel: _shortcutForPaymentType('cod'),
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // Credit Payment (visual only)
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(50),
                            child: _buildModalPaymentRow(
                              isSelected: isCreditSelected,
                              type: 'credit',
                              icon: ImageAssets.creditCardIcon,
                              label: 'Credit',
                              controller: creditAmountController,
                              focusNode: null,
                              size: size,
                              onToggle: () => _togglePaymentMethod('credit'),
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],

                        // Transaction Reference Field
                        if (isCardSelected || isUpiSelected) ...[
                          const SizedBox(height: 10),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(60),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'billing.transaction_reference'.tr,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s13,
                                        0.16,
                                        ColorManager.textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildShortcutHint('C+6'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                buildColumnWidgetForTextFields(
                                  controller: transactionNumberController,
                                  focusNode: transactionNumberFocusNode,
                                  size: size,
                                  width: double.infinity,
                                  height: size.height * .06,
                                  hintText:
                                      'Enter transaction reference number',
                                  onTap: () {
                                    Provider.of<KeyboardProvider>(context,
                                            listen: false)
                                        .show(
                                      'number',
                                      transactionNumberController,
                                      replaceOnFirstInput: true,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],
                      ],
                    ),
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
                        amount:
                            '$currency ${_getTotalPaidAmount().toStringAsFixed(2)}',
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
                        amount:
                            '$currency ${widget.cartTotal.toStringAsFixed(2)}',
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
                          amount: _formatSignedWithCurrency(
                              widget.customerPrevBalance),
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
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(70),
                        child: Row(
                          children: [
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
                                const SizedBox(width: 8),
                                _buildShortcutHint('C+7'),
                              ],
                            ),
                            const Spacer(),
                            Switch(
                              value: toCustomerCreditEnabled,
                              activeColor: ColorManager.kPrimaryColor,
                              onChanged: (value) {
                                setState(() {
                                  debugPrint(
                                      '=== TOGGLE TO CUSTOMER CREDIT ===');
                                  debugPrint('Toggle value changed to: $value');

                                  toCustomerCreditEnabled = value;
                                  if (toCustomerCreditEnabled) {
                                    debugPrint(
                                        '📈 TOGGLE ON - Enabling customer credit functionality');

                                    // Calculate current state
                                    final currentBaseBalance =
                                        _computeBaseBalance();
                                    final cashAmount = double.tryParse(
                                            cashAmountController.text) ??
                                        0.0;
                                    final cardAmount = double.tryParse(
                                            cardAmountController.text) ??
                                        0.0;
                                    final upiAmount = double.tryParse(
                                            upiAmountController.text) ??
                                        0.0;
                                    final codAmount = double.tryParse(
                                            codAmountController.text) ??
                                        0.0;
                                    final totalCollected = cashAmount +
                                        cardAmount +
                                        upiAmount +
                                        codAmount;

                                    // Auto-fill logic with debt settlement priority
                                    final transactionExcess =
                                        totalCollected - widget.cartTotal;

                                    if (transactionExcess > 0) {
                                      double prefillAmount;

                                      if (widget.customerPrevBalance < 0) {
                                        // Customer owes money - prioritize debt settlement
                                        final customerDebt =
                                            widget.customerPrevBalance.abs();
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
                      ),
                      if (toCustomerCreditEnabled) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _buildShortcutHint('C+8'),
                        ),
                        const SizedBox(height: 6),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(80),
                          child: buildColumnWidgetForTextFields(
                            controller: toCustomerCreditController,
                            size: size,
                            width: double.infinity,
                            height: size.height * .06,
                            hintText: 'Enter amount to add as customer credit',
                            focusNode: toCustomerCreditFocusNode,
                            onTap: () {
                              Provider.of<KeyboardProvider>(context,
                                      listen: false)
                                  .show(
                                'number',
                                toCustomerCreditController,
                                replaceOnFirstInput: true,
                              );
                            },
                            onchanged: (value) => _handleAmountControllerChange(
                                'toCustomerCredit', toCustomerCreditController),
                          ),
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
                        CustomRoundButtonAdvanced(
                          title: widget.customButtonTitle ??
                              'billing.apply_payment_methods'.tr,
                          fct: () {
                            if (_isApplying) return;
                            setState(() {
                              _isApplying = true;
                            });
                            _notifyChanges();
                            if (widget.closeOnApply) {
                              Navigator.of(context).pop();
                            } else {
                              if (widget.onAfterApply != null) {
                                Future.delayed(
                                    const Duration(milliseconds: 100), () {
                                  widget.onAfterApply!();
                                });
                              }
                              if (mounted) {
                                setState(() {
                                  _isApplying = false;
                                });
                              }
                            }
                          },
                          fontSize: FontSize.s14,
                          height: 45,
                          width: double.infinity,
                          isLoading: _isApplying,
                          boxColor: _isApplying ? Colors.grey.shade400 : null,
                          borderColor:
                              _isApplying ? Colors.grey.shade400 : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.showAsDialog) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: content,
      );
    }
    return content;
  }

  Widget _buildModalPaymentRow({
    required bool isSelected,
    required String type,
    required String icon,
    required String label,
    required TextEditingController controller,
    required FocusNode? focusNode,
    required Size size,
    required VoidCallback onToggle,
    String? shortcutLabel,
  }) {
    final bool isFocused = _focusedPaymentKey == type;
    return Row(
      children: [
        // Payment method tile — clickable for selection/deselection.
        // Uses InkWell (instead of GestureDetector) so Enter/Space toggle the
        // method when the tile is keyboard-focused via Tab.
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(5),
            onFocusChange: (focused) {
              setState(() {
                _focusedPaymentKey = focused ? type : null;
              });
            },
            child: BuildBoxShadowContainer(
              border: isFocused
                  ? Border.all(color: Colors.orange, width: 3)
                  : isSelected
                      ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
                      : Border.all(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              blurRadius: isFocused ? 8 : 4,
              circleRadius: 5,
              height: size.height * .06, // Match text field height
              width: 132, // Wider to avoid shortcut badge overflow
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
                  if (shortcutLabel != null) ...[
                    const SizedBox(width: 6),
                    _buildShortcutHint(shortcutLabel),
                  ],
                ],
              ),
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
            hintText: label == 'Balance' || type == 'credit'
                ? 'Auto-calculated'
                : 'Enter $label amount',
            keyboardType: TextInputType.number,
            focusNode: focusNode,
            readOnly: label == 'Balance' || type == 'credit',
            onTap: (type == 'Balance')
                ? null
                : (type == 'credit'
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
                          _autoFillSelectedMethodAmount(type);
                          _notifyChanges();
                        });

                        // Ensure full selection when tapping inside the field
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (controller.text.isNotEmpty &&
                              focusNode != null &&
                              focusNode.hasFocus) {
                            controller.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: controller.text.length,
                            );
                          }
                        });

                        // Show virtual numeric keyboard
                        Provider.of<KeyboardProvider>(context, listen: false)
                            .show(
                          'number',
                          controller,
                          replaceOnFirstInput: true,
                        );
                      }),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutHint(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s10,
          0.10,
          Colors.grey.shade600,
        ),
      ),
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
