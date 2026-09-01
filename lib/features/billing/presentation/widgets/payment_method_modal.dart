import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/features/billing/controllers/billing_desktop_payment_controller.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/payment_auto_fill_helper.dart';
import 'package:pos_machine/features/billing/domain/payment_validation.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

class PaymentMethodModal extends StatefulWidget {
  final bool initialIsCashSelected;
  final bool initialIsCardSelected;
  final bool initialIsUpiSelected;
  final bool initialIsCodSelected;
  final bool initialIsDebitSelected;
  final bool initialToCustomerCreditEnabled;
  final String initialCashAmount;
  final String initialCardAmount;
  final String initialUpiAmount;
  final String initialCodAmount;
  final String initialDebitAmount;
  final String initialTransactionNumber;
  // Pre-entered amounts for dynamic/extra methods (methodId -> amount string),
  // used when re-opening the modal for an order that already used them.
  final Map<String, String>? initialExtraAmounts;
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
    // Dynamic methods beyond the four typed ones (e.g. Cheque, Wallet,
    // Bank Transfer). Keyed by payment-method id (as String).
    //   extraMethodAmounts: methodId -> entered amount string ("" when none)
    //   extraMethodValues:  methodId -> method value/name (e.g. "CHEQUE")
    Map<String, String>? extraMethodAmounts,
    Map<String, String>? extraMethodValues,
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
    this.initialToCustomerCreditEnabled = false,
    required this.initialCashAmount,
    required this.initialCardAmount,
    required this.initialUpiAmount,
    this.initialCodAmount = "",
    required this.initialDebitAmount,
    required this.initialTransactionNumber,
    this.initialExtraAmounts,
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
  static const _desktopController = BillingDesktopPaymentController();

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
  List<PaymentMethod> _enabledMethods = [];
  bool _isLoadingPaymentMethods = false;

  // Dynamic collected methods (non-core) keyed by backend id.
  final Map<String, TextEditingController> _extraControllers = {};
  final Map<String, FocusNode> _extraFocusNodes = {};
  final Map<String, bool> _extraSelected = {};
  final Map<String, VoidCallback> _extraListeners = {};

  // Credit option (visual only, for sales staff)
  bool isCreditSelected = false;
  bool _creditSaleManuallyDisabled = false;
  late TextEditingController creditAmountController;
  bool _isApplying = false;

  // Pristine-switch tracking: when the user selects a new method without having
  // touched the auto-filled one, we deselect the old method and move the full
  // amount to the new one instead of splitting.
  // We compare controller text at decision time rather than using a touched flag
  // because keyboard-provider side-effects can fire the listener during init.
  String? _pristineMethod;
  String _pristineAmount = '';

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

    // Record which method was auto-filled at open so we can switch away from it
    // if the user picks a different method without changing the amount.
    if (isCashSelected && cashAmountController.text.isNotEmpty) {
      _pristineMethod = 'cash';
      _pristineAmount = cashAmountController.text;
    } else if (isCardSelected && cardAmountController.text.isNotEmpty) {
      _pristineMethod = 'card';
      _pristineAmount = cardAmountController.text;
    } else if (isUpiSelected && upiAmountController.text.isNotEmpty) {
      _pristineMethod = 'upi';
      _pristineAmount = upiAmountController.text;
    } else if (isCodSelected && codAmountController.text.isNotEmpty) {
      _pristineMethod = 'cod';
      _pristineAmount = codAmountController.text;
    }

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

    // Restore DEBIT either as a credit sale or as excess allocated to the
    // customer's credit account. These are separate accounting operations.
    final initDebit = double.tryParse(widget.initialDebitAmount) ?? 0.0;
    if (widget.initialToCustomerCreditEnabled) {
      toCustomerCreditEnabled = true;
      if (initDebit > 0) {
        toCustomerCreditController.text = initDebit.toStringAsFixed(2);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateBalance());
    } else if (widget.initialIsDebitSelected && initDebit > 0) {
      isCreditSelected = true;
      creditAmountController.text = initDebit.toStringAsFixed(2);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_syncCreditAmountWithRemaining);
      _notifyChanges();
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

  /// Dynamic collected methods from the backend list (non CASH/CARD/UPI/COD).
  Iterable<PaymentMethod> get _dynamicCollectedMethods => _enabledMethods.where(
        (m) =>
            m.behavior == PaymentBehavior.collected &&
            !_desktopController.isCoreCollectedCode(m.code),
      );

  List<DesktopPaymentRow> get _desktopRows => _desktopController.modalRows(
        methods: _enabledMethods,
        toCustomerCreditEnabled: toCustomerCreditEnabled,
        isSelected: _isCodeSelected,
        controllerFor: _controllerForCode,
        focusNodeFor: _focusNodeForCode,
        rowKeyFor: _rowKeyForCode,
      );

  String _rowKeyForCode(String code) {
    switch (code.toUpperCase()) {
      case 'CASH':
        return 'cash';
      case 'CARD':
        return 'card';
      case 'UPI':
        return 'upi';
      case 'COD':
        return 'cod';
      case 'DEBIT':
      case 'CREDIT':
        return 'credit';
      default:
        return _extraMethodKey(code);
    }
  }

  bool _isCodeSelected(String code, {String? methodId}) {
    switch (code.toUpperCase()) {
      case 'CASH':
        return isCashSelected;
      case 'CARD':
        return isCardSelected;
      case 'UPI':
        return isUpiSelected;
      case 'COD':
        return isCodSelected;
      case 'DEBIT':
      case 'CREDIT':
        return isCreditSelected;
      default:
        final id = methodId ?? code;
        return _extraSelected[id] ?? false;
    }
  }

  TextEditingController _controllerForCode(String code, {String? methodId}) {
    switch (code.toUpperCase()) {
      case 'CASH':
        return cashAmountController;
      case 'CARD':
        return cardAmountController;
      case 'UPI':
        return upiAmountController;
      case 'COD':
        return codAmountController;
      case 'DEBIT':
      case 'CREDIT':
        return creditAmountController;
      default:
        final id = methodId ?? code;
        return _extraControllers[id] ?? TextEditingController();
    }
  }

  FocusNode? _focusNodeForCode(String code, {String? methodId}) {
    switch (code.toUpperCase()) {
      case 'CASH':
        return cashAmountFocusNode;
      case 'CARD':
        return cardAmountFocusNode;
      case 'UPI':
        return upiAmountFocusNode;
      case 'COD':
        return codAmountFocusNode;
      case 'DEBIT':
      case 'CREDIT':
        return null;
      default:
        final id = methodId ?? code;
        return _extraFocusNodes[id];
    }
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
      extraMethodAmounts: _buildExtraAmountsMap(),
      extraMethodValues: _buildExtraValuesMap(),
    );
  }

  /// methodId -> entered amount string (only for selected dynamic methods).
  Map<String, String> _buildExtraAmountsMap() {
    final map = <String, String>{};
    for (final method in _dynamicCollectedMethods) {
      final key = method.id.isNotEmpty ? method.id : method.code;
      final selected = _extraSelected[key] ?? false;
      final text = _extraControllers[key]?.text ?? '';
      map[key] = selected ? text : '';
    }
    return map;
  }

  /// methodId -> method code, for every dynamic collected method.
  Map<String, String> _buildExtraValuesMap() {
    final map = <String, String>{};
    for (final method in _dynamicCollectedMethods) {
      final key = method.id.isNotEmpty ? method.id : method.code;
      map[key] = method.code;
    }
    return map;
  }

  PaymentValidationResult _validateBeforeApply() {
    return PaymentValidation.validateForOrder(
      orderTotal: widget.cartTotal,
      toCustomerCreditEnabled: toCustomerCreditEnabled,
      isDefaultCustomer: widget.isDefaultCustomer,
      customerPrevBalance:
          widget.isDefaultCustomer ? 0.0 : widget.customerPrevBalance,
      isCashSelected: isCashSelected,
      isCardSelected: isCardSelected,
      isUpiSelected: isUpiSelected,
      isCodSelected: isCodSelected,
      cashAmount: isCashSelected ? cashAmountController.text : '',
      cardAmount: isCardSelected ? cardAmountController.text : '',
      upiAmount: isUpiSelected ? upiAmountController.text : '',
      codAmount: isCodSelected ? codAmountController.text : '',
      extraAmounts: _buildExtraAmountsMap(),
      isCreditSelected: isCreditSelected,
      creditAmount: isCreditSelected ? creditAmountController.text : '',
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
    _disposeExtraMethods();
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
      if (_desktopController.shouldShowTransactionReference(
        rows: _desktopRows,
        isSelected: _isCodeSelected,
      )) {
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
        final totalCollected = _getTotalCollectedAmount();
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
    final shortcutRows = _desktopController.shortcutRows(_desktopRows);
    if (shortcutRows.isEmpty) return;

    final target = index.clamp(1, shortcutRows.length) - 1;
    final row = shortcutRows[target];
    final focusNode = row.focusNode;
    if (focusNode == null) return;

    focusNode.requestFocus();
    if (row.controller.text.isNotEmpty) {
      row.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: row.controller.text.length,
      );
    }
    Provider.of<KeyboardProvider>(context, listen: false).show(
      'number',
      row.controller,
      replaceOnFirstInput: true,
    );
  }

  void _toggleOrFocusPaymentByIndex(int index) {
    final shortcutRows = _desktopController.shortcutRows(_desktopRows);
    if (shortcutRows.isEmpty) return;

    final target = shortcutRows[index.clamp(1, shortcutRows.length) - 1];
    if (target.selected) {
      _focusPaymentFieldByIndex(index);
      return;
    }

    _togglePaymentMethod(target.rowKey);
  }

  bool _amountsEqual(String a, String b) {
    final da = double.tryParse(a.trim()) ?? 0.0;
    final db = double.tryParse(b.trim()) ?? 0.0;
    return (da - db).abs() < 0.009;
  }

  bool _isFullCartTotal(String amount) {
    return _amountsEqual(amount, widget.cartTotal.toStringAsFixed(2)) ||
        _amountsEqual(amount, widget.cartTotal.toString());
  }

  double _effectiveCustomerPrevBalance() {
    return widget.isDefaultCustomer ? 0.0 : widget.customerPrevBalance;
  }

  /// Money collected at the register from typed + selected extra methods.
  double _getTotalCollectedAmount() {
    var total = 0.0;
    if (isCashSelected) {
      total += double.tryParse(cashAmountController.text) ?? 0.0;
    }
    if (isCardSelected) {
      total += double.tryParse(cardAmountController.text) ?? 0.0;
    }
    if (isUpiSelected) {
      total += double.tryParse(upiAmountController.text) ?? 0.0;
    }
    if (isCodSelected) {
      total += double.tryParse(codAmountController.text) ?? 0.0;
    }
    total += _sumExtraAmounts();
    return total;
  }

  static const _extraMethodKeyPrefix = 'extra_';

  String _extraMethodKey(String methodId) => '$_extraMethodKeyPrefix$methodId';

  String? _extraMethodIdFromKey(String key) {
    if (!key.startsWith(_extraMethodKeyPrefix)) return null;
    return key.substring(_extraMethodKeyPrefix.length);
  }

  TextEditingController? _getControllerForMethodKey(String key) {
    final extraId = _extraMethodIdFromKey(key);
    if (extraId != null) return _extraControllers[extraId];
    switch (key) {
      case 'cash':
        return cashAmountController;
      case 'card':
        return cardAmountController;
      case 'upi':
        return upiAmountController;
      case 'cod':
        return codAmountController;
      default:
        return null;
    }
  }

  TextEditingController? _getPristineController() {
    if (_pristineMethod == null) return null;
    return _getControllerForMethodKey(_pristineMethod!);
  }

  bool _isMethodActive(String methodKey) {
    final extraId = _extraMethodIdFromKey(methodKey);
    if (extraId != null) return _extraSelected[extraId] ?? false;
    return _isPaymentTypeSelected(methodKey);
  }

  void _clearMethod(String methodKey) {
    final extraId = _extraMethodIdFromKey(methodKey);
    if (extraId != null) {
      _extraSelected[extraId] = false;
      _extraControllers[extraId]?.clear();
      return;
    }
    switch (methodKey) {
      case 'cash':
        isCashSelected = false;
        cashAmountController.clear();
        break;
      case 'card':
        isCardSelected = false;
        cardAmountController.clear();
        break;
      case 'upi':
        isUpiSelected = false;
        upiAmountController.clear();
        break;
      case 'cod':
        isCodSelected = false;
        codAmountController.clear();
        break;
    }
  }

  /// When the user picks a new method without editing the auto-filled one,
  /// move the full cart total to the new method and clear the previous one.
  bool _applyPristineSwitch(
    String newMethodKey,
    TextEditingController targetController,
  ) {
    if (newMethodKey == 'credit') return false;
    if (_pristineMethod == null || _pristineMethod == newMethodKey) {
      return false;
    }

    final pristineController = _getPristineController();
    if (pristineController == null || !_isMethodActive(_pristineMethod!)) {
      return false;
    }
    if (!_amountsEqual(pristineController.text, _pristineAmount)) {
      return false;
    }

    _clearMethod(_pristineMethod!);
    targetController.text = widget.cartTotal.toStringAsFixed(2);
    _pristineMethod = newMethodKey;
    _pristineAmount = targetController.text;
    return true;
  }

  void _recordPristineIfFullTotal(
      String methodKey, TextEditingController controller) {
    if (_isFullCartTotal(controller.text)) {
      _pristineMethod = methodKey;
      _pristineAmount = controller.text;
    }
  }

  /// All collected-payment slots that are currently selected (typed + extra).
  List<({String key, TextEditingController controller, FocusNode? focusNode})>
      _listActiveCollectedMethodEntries() {
    final entries = <({
      String key,
      TextEditingController controller,
      FocusNode? focusNode
    })>[];

    if (isCashSelected) {
      entries.add((
        key: 'cash',
        controller: cashAmountController,
        focusNode: cashAmountFocusNode,
      ));
    }
    if (isCardSelected) {
      entries.add((
        key: 'card',
        controller: cardAmountController,
        focusNode: cardAmountFocusNode,
      ));
    }
    if (isUpiSelected) {
      entries.add((
        key: 'upi',
        controller: upiAmountController,
        focusNode: upiAmountFocusNode,
      ));
    }
    if (isCodSelected) {
      entries.add((
        key: 'cod',
        controller: codAmountController,
        focusNode: codAmountFocusNode,
      ));
    }
    for (final method in _dynamicCollectedMethods) {
      final id = method.id.isNotEmpty ? method.id : method.code;
      if (_extraSelected[id] ?? false) {
        entries.add((
          key: _extraMethodKey(id),
          controller: _extraControllers[id]!,
          focusNode: _extraFocusNodes[id],
        ));
      }
    }
    return entries;
  }

  /// Snapshot of entered/collected amounts for every selected method.
  Map<String, String> _buildCollectedAmountsMap() {
    final amounts = <String, String>{};
    if (isCashSelected) amounts['cash'] = cashAmountController.text;
    if (isCardSelected) amounts['card'] = cardAmountController.text;
    if (isUpiSelected) amounts['upi'] = upiAmountController.text;
    if (isCodSelected) amounts['cod'] = codAmountController.text;
    for (final method in _dynamicCollectedMethods) {
      final id = method.id.isNotEmpty ? method.id : method.code;
      if (_extraSelected[id] ?? false) {
        amounts[_extraMethodKey(id)] = _extraControllers[id]?.text ?? '';
      }
    }
    return amounts;
  }

  /// Split-payment fill: add the remaining balance to the newly selected method.
  void _autoFillRemainingForMethod(
    String methodKey,
    TextEditingController controller,
  ) {
    controller.text = PaymentAutoFillHelper.autoFillRemaining(
      targetMethodKey: methodKey,
      targetCurrentAmount: controller.text,
      collectedAmounts: _buildCollectedAmountsMap(),
      cartTotal: widget.cartTotal,
    );
  }

  /// When toggling off leaves exactly one collected method, refill it to the
  /// full cart total (same rule for CASH/CARD/UPI/COD and dynamic methods).
  void _refillIfSingleCollectedMethodRemaining() {
    final active = _listActiveCollectedMethodEntries();
    if (active.length != 1) return;

    final only = active.first;
    only.controller.text = widget.cartTotal.toStringAsFixed(2);
    _recordPristineIfFullTotal(only.key, only.controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      only.focusNode?.requestFocus();
      Provider.of<KeyboardProvider>(context, listen: false).show(
        'number',
        only.controller,
        replaceOnFirstInput: true,
      );
    });
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

  String? _shortcutForRow(DesktopPaymentRow row) {
    final shortcutRows = _desktopController.shortcutRows(_desktopRows);
    final index = shortcutRows.indexWhere((r) => r.rowKey == row.rowKey);
    if (index < 0) return null;
    return _desktopController.shortcutLabelForRow(shortcutRows, index);
  }

  /// Load payment methods from MasterDataProvider (backend-driven list).
  Future<void> _loadPaymentMethods() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);

    final cachedModels = masterDataProvider.paymentMethodModels;
    if (cachedModels != null && cachedModels.isNotEmpty) {
      debugPrint(
          '📋 [Payment Modal] Using cached payment methods: ${cachedModels.length}');
      _applyPaymentMethods(masterDataProvider.enabledSortedPaymentMethods);
      return;
    }

    setState(() {
      _isLoadingPaymentMethods = true;
    });

    try {
      await masterDataProvider.fetchPaymentMethods();
      if (mounted) {
        final methods = masterDataProvider.enabledSortedPaymentMethods;
        debugPrint(
            '📋 [Payment Modal] Loaded payment methods: ${methods.length}');
        _applyPaymentMethods(methods);
      }
    } catch (e) {
      debugPrint('❌ [Payment Modal] Error loading payment methods: $e');
      if (mounted) {
        _applyPaymentMethods(masterDataProvider.enabledSortedPaymentMethods);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPaymentMethods = false;
        });
      }
    }
  }

  /// Apply backend payment methods and wire dynamic method controllers.
  void _applyPaymentMethods(List<PaymentMethod> methods) {
    final preservedExtraAmounts = <String, String>{};
    final preservedExtraSelected = <String, bool>{};
    for (final entry in _extraControllers.entries) {
      preservedExtraAmounts[entry.key] = entry.value.text;
      preservedExtraSelected[entry.key] =
          _extraSelected[entry.key] ?? entry.value.text.isNotEmpty;
    }

    setState(() {
      _enabledMethods = methods;
      _isLoadingPaymentMethods = false;

      _cashPaymentMethodId = null;
      _cardPaymentMethodId = null;
      _upiPaymentMethodId = null;
      _codPaymentMethodId = null;

      for (final method in methods) {
        if (method.id.isEmpty) continue;
        switch (method.code.toUpperCase()) {
          case 'CASH':
            _cashPaymentMethodId = method.id;
            break;
          case 'CARD':
            _cardPaymentMethodId = method.id;
            break;
          case 'UPI':
            _upiPaymentMethodId = method.id;
            break;
          case 'COD':
            _codPaymentMethodId = method.id;
            break;
        }
      }

      _disposeExtraMethods();
      for (final method in methods) {
        if (method.behavior == PaymentBehavior.terminal) continue;
        if (method.behavior == PaymentBehavior.credit) continue;
        if (_desktopController.isCoreCollectedCode(method.code)) continue;

        final key = method.id.isNotEmpty ? method.id : method.code;
        final initialAmount = widget.initialExtraAmounts?[key] ??
            preservedExtraAmounts[key] ??
            '';
        final controller = TextEditingController(text: initialAmount);
        void listener() => _handleExtraAmountChange(key);
        controller.addListener(listener);
        _extraControllers[key] = controller;
        _extraFocusNodes[key] = FocusNode();
        _extraSelected[key] = initialAmount.isNotEmpty
            ? true
            : (preservedExtraSelected[key] ?? false);
        _extraListeners[key] = listener;
        debugPrint('🧾 Dynamic method "${method.code}" ID: $key');
      }

      if (_pristineMethod == null) {
        for (final method in _dynamicCollectedMethods) {
          final key = method.id.isNotEmpty ? method.id : method.code;
          final controller = _extraControllers[key];
          if ((_extraSelected[key] ?? false) &&
              controller != null &&
              controller.text.isNotEmpty) {
            _pristineMethod = _extraMethodKey(key);
            _pristineAmount = controller.text;
            break;
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyChanges();
      }
    });
  }

  // Base balance calculation: always based on current purchase total
  double _computeBaseBalance() {
    final totalCollected = _getTotalCollectedAmount();
    final double netDue = widget.cartTotal;
    final balance = totalCollected - netDue;
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

    final totalCollected = _getTotalCollectedAmount();
    final customerPrevBalance = _effectiveCustomerPrevBalance();
    double cashBal = 0.0;

    if (toCustomerCreditEnabled && !widget.isDefaultCustomer) {
      debugPrint(
          '🔛 Toggle is ON - Calculating with customer credit consideration');

      if (customerPrevBalance < 0) {
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
        double netDue = widget.cartTotal - customerPrevBalance;
        debugPrint('💰 Net Due calculation:');
        debugPrint(
            '  - Purchase Total: ${widget.cartTotal.toStringAsFixed(2)}');
        debugPrint(
            '  - Customer Prev Balance: ${customerPrevBalance.toStringAsFixed(2)}');
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

  double _getTotalPaidAmount() => _getTotalCollectedAmount();

  /// Sum of amounts on selected dynamic/extra payment methods only.
  double _sumExtraAmounts() {
    double total = 0.0;
    for (final entry in _extraControllers.entries) {
      if (!(_extraSelected[entry.key] ?? false)) continue;
      total += double.tryParse(entry.value.text) ?? 0.0;
    }
    return total;
  }

  void _disposeExtraMethods() {
    for (final entry in _extraControllers.entries) {
      final listener = _extraListeners[entry.key];
      if (listener != null) entry.value.removeListener(listener);
      entry.value.dispose();
    }
    for (final node in _extraFocusNodes.values) {
      node.dispose();
    }
    _extraControllers.clear();
    _extraFocusNodes.clear();
    _extraSelected.clear();
    _extraListeners.clear();
  }

  /// Text-change handler for a dynamic/extra method field. Mirrors the typed
  /// methods: typing a value auto-selects the method, recalculates balance and
  /// notifies the parent.
  void _handleExtraAmountChange(String methodId) {
    if (!mounted) return;
    final controller = _extraControllers[methodId];
    if (controller == null) return;
    setState(() {
      if (controller.text.isNotEmpty) {
        _extraSelected[methodId] = true;
      }
    });
    _calculateBalance();
    _syncCreditAmountWithRemaining();
    _debounceNotifyChanges();
  }

  /// CASH/CARD/UPI/COD so switching methods moves the full total cleanly.
  void _toggleExtraMethod(String methodId) {
    final controller = _extraControllers[methodId];
    final focusNode = _extraFocusNodes[methodId];
    if (controller == null) return;

    final methodKey = _extraMethodKey(methodId);
    final wasSelected = _extraSelected[methodId] ?? false;

    setState(() {
      if (wasSelected) {
        _extraSelected[methodId] = false;
        controller.clear();
        if (_pristineMethod == methodKey) {
          _pristineMethod = null;
          _pristineAmount = '';
        }
        _refillIfSingleCollectedMethodRemaining();
      } else {
        _extraSelected[methodId] = true;
        final didPristineSwitch = _applyPristineSwitch(methodKey, controller);
        if (!didPristineSwitch) {
          _autoFillRemainingForMethod(methodKey, controller);
        }
        _recordPristineIfFullTotal(methodKey, controller);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          focusNode?.requestFocus();
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
        });
      }
      _calculateBalance();
      _notifyChanges();
    });
  }

  void _autoFillSelectedMethodAmount(String paymentType) {
    final controller = _getControllerForMethodKey(paymentType);
    if (controller == null) return;
    _autoFillRemainingForMethod(paymentType, controller);
  }

  void _syncCreditAmountWithRemaining() {
    // Any unpaid remainder is automatically treated as a credit sale.
    // `To Customer Credit` is a separate flow for allocating excess payment.
    final totalCollected = _getTotalCollectedAmount();
    if (toCustomerCreditEnabled && totalCollected <= widget.cartTotal) {
      toCustomerCreditEnabled = false;
      toCustomerCreditController.clear();
      toCustomerCredit = 0.0;
    }

    final creditRemainder = PaymentAutoFillHelper.autoCreditRemainder(
      cartTotal: widget.cartTotal,
      totalCollected: totalCollected,
      toCustomerCreditEnabled: toCustomerCreditEnabled,
    );
    if (creditRemainder == null) {
      return;
    }

    if (creditRemainder.isNotEmpty && !_creditSaleManuallyDisabled) {
      isCreditSelected = true;
      creditAmountController.text = creditRemainder;
    } else {
      isCreditSelected = false;
      creditAmountController.clear();
      if (creditRemainder.isEmpty) {
        _creditSaleManuallyDisabled = false;
      }
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
          _creditSaleManuallyDisabled = !isCreditSelected;
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
        if (paymentType != 'credit') {
          final didPristineSwitch =
              _applyPristineSwitch(paymentType, targetController);
          if (!didPristineSwitch) {
            _autoFillSelectedMethodAmount(paymentType);
          }
          _recordPristineIfFullTotal(paymentType, targetController);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            targetFocusNode?.requestFocus();
            if (targetController != null && targetController.text.isNotEmpty) {
              targetController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: targetController.text.length,
              );
            }
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
      // Handle deselection (Toggle OFF) — refill sole remaining method to total.
      else if (paymentType != 'credit') {
        _refillIfSingleCollectedMethodRemaining();
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

  Widget _buildCheckoutPaymentExperience(
    BuildContext context,
    Size size,
    String currency,
    bool isDense,
  ) {
    final collectedRows = _desktopRows
        .where((row) => row.method.behavior == PaymentBehavior.collected)
        .toList();
    final totalCollected = _getTotalCollectedAmount();
    final outstanding =
        (widget.cartTotal - totalCollected).clamp(0.0, double.infinity);
    final excess =
        (totalCollected - widget.cartTotal).clamp(0.0, double.infinity);
    final canStoreCustomerCredit = !widget.isDefaultCustomer;
    final showReference = _desktopController.shouldShowTransactionReference(
      rows: _desktopRows,
      isSelected: _isCodeSelected,
    );

    return BuildBoxShadowContainer(
      width: double.infinity,
      circleRadius: 10,
      color: Colors.white,
      showShadow: widget.showShadow,
      padding: EdgeInsets.all(isDense ? 12 : 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCheckoutSectionHeader(
                      step: 1,
                      title: 'Payment',
                      subtitle: 'Enter received amounts',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const ValueKey('clear_payments_button'),
                            onPressed: _clearAllCollectedPayments,
                            tooltip: 'billing.clear_payments'.tr,
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            color: Colors.grey.shade600,
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('exact_cash_button'),
                            onPressed: _fillExactCash,
                            icon: const Icon(Icons.payments_outlined, size: 15),
                            label: Text('billing.exact_cash'.tr),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ColorManager.kPrimaryColor,
                              side:
                                  BorderSide(color: ColorManager.kPrimaryColor),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingPaymentMethods)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (collectedRows.isEmpty)
                      _buildCheckoutEmptyState('No payment methods available')
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < collectedRows.length;
                                index++) ...[
                              FocusTraversalOrder(
                                order: NumericFocusOrder((index + 1) * 10.0),
                                child: _buildCheckoutPaymentRow(
                                  collectedRows[index],
                                  currency,
                                  isDense,
                                ),
                              ),
                              if (index != collectedRows.length - 1)
                                const Divider(
                                    height: 1, color: Color(0xFFE2E8F0)),
                            ],
                          ],
                        ),
                      ),
                    if (showReference) ...[
                      const SizedBox(height: 12),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(60),
                        child: _buildCheckoutReferenceField(size, isDense),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    _buildCheckoutSectionHeader(
                      step: 2,
                      title: 'Remaining Amount',
                      subtitle: '(Auto calculated)',
                    ),
                    const SizedBox(height: 10),
                    _buildCustomerAccountAction(
                      title: 'Sell on Credit (Amount Due)',
                      subtitle: widget.isDefaultCustomer
                          ? 'Record the unpaid amount as due'
                          : 'Add the unpaid amount to the customer account',
                      amount: outstanding,
                      currency: currency,
                      value: isCreditSelected,
                      enabled: outstanding > 0,
                      showSwitch: true,
                      color: const Color(0xFFF59E0B),
                      background: const Color(0xFFFFFBEB),
                      icon: Icons.receipt_long_outlined,
                      onChanged: (_) => _togglePaymentMethod('credit'),
                    ),
                    if (outstanding > 0) ...[
                      const SizedBox(height: 8),
                      _buildCheckoutAccountNote(
                        Icons.info_outline,
                        widget.isDefaultCustomer
                            ? '$currency ${outstanding.toStringAsFixed(2)} will be '
                                'recorded as amount due.'
                            : '$currency ${outstanding.toStringAsFixed(2)} will be '
                                'added to the customer\'s outstanding balance.',
                        const Color(0xFFF59E0B),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    _buildCheckoutSectionHeader(
                      step: 3,
                      title: 'Excess Amount',
                      subtitle: '(If any)',
                    ),
                    const SizedBox(height: 10),
                    _buildCustomerAccountAction(
                      title: 'Excess Amount',
                      subtitle: canStoreCustomerCredit
                          ? 'Will be created as customer account credit'
                          : 'Select a customer to store account credit',
                      amount: excess,
                      currency: currency,
                      value: canStoreCustomerCredit &&
                          excess > 0 &&
                          toCustomerCreditEnabled,
                      enabled: canStoreCustomerCredit && excess > 0,
                      color: ColorManager.kPrimaryColor,
                      background: const Color(0xFFEFF6FF),
                      icon: Icons.account_balance_wallet_outlined,
                      shortcut: 'C+7',
                      amountShortcut: 'C+8',
                      amountController: toCustomerCreditEnabled
                          ? toCustomerCreditController
                          : null,
                      amountFocusNode: toCustomerCreditFocusNode,
                      onAmountTap: () {
                        Provider.of<KeyboardProvider>(context, listen: false)
                            .show(
                          'number',
                          toCustomerCreditController,
                          replaceOnFirstInput: true,
                        );
                      },
                      onChanged: (value) => _setToCustomerCreditEnabled(value),
                    ),
                    if (excess > 0 && canStoreCustomerCredit) ...[
                      const SizedBox(height: 8),
                      _buildCheckoutAccountNote(
                        Icons.info_outline,
                        toCustomerCreditEnabled
                            ? '$currency ${toCustomerCredit.toStringAsFixed(2)} will '
                                'be stored as customer account credit.'
                            : '$currency ${excess.toStringAsFixed(2)} will be returned '
                                'as change unless customer credit is enabled.',
                        ColorManager.kPrimaryColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!widget.showConfirmButton) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutSectionHeader({
    required int step,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s10,
              0.10,
              Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s14,
                  0.18,
                  ColorManager.kPrimaryColor,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s10,
                    0.12,
                    Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildCheckoutPaymentRow(
    DesktopPaymentRow row,
    String currency,
    bool isDense,
  ) {
    final isFocused = _focusedPaymentKey == row.rowKey;
    final shortcut = _shortcutForRow(row);
    final borderColor = isFocused
        ? Colors.orange
        : row.selected
            ? ColorManager.kPrimaryColor
            : Colors.transparent;

    void toggle() {
      if (row.methodId != null &&
          !_desktopController.isCoreCollectedCode(row.code)) {
        _toggleExtraMethod(row.methodId!);
      } else {
        _togglePaymentMethod(row.rowKey);
      }
    }

    void focusAmount() {
      if (!row.selected) {
        toggle();
        return;
      }
      final focusNode = row.focusNode;
      if (focusNode == null) return;
      focusNode.requestFocus();
      if (row.controller.text.isNotEmpty) {
        row.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: row.controller.text.length,
        );
      }
      Provider.of<KeyboardProvider>(context, listen: false).show(
        'number',
        row.controller,
        replaceOnFirstInput: true,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: isDense ? 44 : 48,
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: row.selected
            ? ColorManager.kPrimaryColor.withValues(alpha: 0.035)
            : Colors.white,
        border: Border.all(color: borderColor, width: row.selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            key: ValueKey('payment_method_${row.rowKey}'),
            onTap: toggle,
            onFocusChange: (focused) {
              if (!mounted) return;
              setState(() => _focusedPaymentKey = focused ? row.rowKey : null);
            },
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: isDense ? 145 : 175,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: row.selected
                          ? ColorManager.kPrimaryColor.withValues(alpha: 0.10)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: WebsafeSvg.asset(
                      row.iconAsset,
                      width: 15,
                      height: 15,
                      colorFilter: ColorFilter.mode(
                        row.selected
                            ? ColorManager.kPrimaryColor
                            : Colors.grey.shade600,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s11,
                        0.14,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  if (shortcut != null) ...[
                    const SizedBox(width: 6),
                    _buildShortcutHint(shortcut),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: ValueKey('payment_amount_${row.rowKey}'),
              controller: row.controller,
              focusNode: row.focusNode,
              readOnly: row.readOnly,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              cursorColor: ColorManager.kPrimaryColor,
              onTap: row.readOnly ? null : focusAmount,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Enter amount',
                hintStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s10,
                  0.12,
                  Colors.grey.shade500,
                ),
                suffixText: currency,
                suffixStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.12,
                  Colors.grey.shade600,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(
                    color: ColorManager.kPrimaryColor,
                    width: 1.5,
                  ),
                ),
              ),
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.14,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutReferenceField(Size size, bool isDense) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'billing.transaction_reference'.tr,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s11,
                0.14,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '(optional)',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s10,
                0.12,
                Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            _buildShortcutHint('C+6'),
          ],
        ),
        const SizedBox(height: 6),
        buildColumnWidgetForTextFields(
          controller: transactionNumberController,
          focusNode: transactionNumberFocusNode,
          size: size,
          width: double.infinity,
          height: isDense ? 40 : 44,
          margin: EdgeInsets.zero,
          hintText: 'Enter transaction reference number',
          onTap: () {
            Provider.of<KeyboardProvider>(context, listen: false).show(
              'number',
              transactionNumberController,
              replaceOnFirstInput: true,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomerAccountAction({
    required String title,
    required String subtitle,
    required double amount,
    required String currency,
    required bool value,
    required bool enabled,
    required Color color,
    required Color background,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    bool showSwitch = true,
    String? shortcut,
    String? amountShortcut,
    TextEditingController? amountController,
    FocusNode? amountFocusNode,
    VoidCallback? onAmountTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? background : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              enabled ? color.withValues(alpha: 0.45) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? color.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 17,
              color: enabled ? color : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s11,
                          0.14,
                          enabled
                              ? ColorManager.textColor
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (shortcut != null) ...[
                      const SizedBox(width: 6),
                      _buildShortcutHint(shortcut),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s9,
                    0.11,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (showSwitch)
            Switch(
              key: ValueKey(
                title.startsWith('Sell on Credit')
                    ? 'sell_on_credit_toggle'
                    : 'excess_credit_toggle',
              ),
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: value ? color : null,
            )
          else
            Semantics(
              label: value
                  ? 'Sell on credit is automatically applied'
                  : 'No credit sale is needed',
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      value
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                      size: 14,
                      color: value ? color : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      value ? 'Auto' : 'None',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s10,
                        0.12,
                        value ? color : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (amountController != null && value)
            SizedBox(
              width: 132,
              height: 48,
              child: TextFormField(
                key: const ValueKey('excess_credit_amount'),
                controller: amountController,
                focusNode: amountFocusNode,
                onTap: onAmountTap,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                textAlignVertical: TextAlignVertical.center,
                cursorColor: color,
                decoration: InputDecoration(
                  isDense: false,
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s10,
                          0.12,
                          Colors.grey.shade700,
                        ),
                      ),
                      if (amountShortcut != null) ...[
                        const SizedBox(width: 6),
                        _buildShortcutHint(amountShortcut),
                      ],
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: color.withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                ),
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s12,
                  0.12,
                  color,
                ),
              ),
            )
          else
            SizedBox(
              width: 92,
              child: Text(
                '${amount.toStringAsFixed(2)} $currency',
                textAlign: TextAlign.right,
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s11,
                  0.14,
                  enabled ? color : Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckoutAccountNote(IconData icon, String message, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s9,
              0.11,
              Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.14,
          Colors.grey.shade600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final isDenseEmbedded =
        widget.fullWidth && (size.width <= 1100 || size.height <= 800);

    if (widget.fullWidth) {
      return _buildCheckoutPaymentExperience(
        context,
        size,
        currency,
        isDenseEmbedded,
      );
    }

    // Calculate width: 85% of screen width, clamped between 550 and 900
    double modalWidth = size.width * 0.85;
    if (modalWidth > 900) modalWidth = 900;
    if (modalWidth < 550) modalWidth = 550;

    Widget content = BuildBoxShadowContainer(
      width: widget.fullWidth ? double.infinity : modalWidth,
      circleRadius: 12,
      color: Colors.white,
      showShadow: widget.showShadow,
      padding: EdgeInsets.all(isDenseEmbedded ? 16 : 20),
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
            SizedBox(height: isDenseEmbedded ? 14 : 20),

            // Two-Column Layout
            () {
              final isMobilePayment = MediaQuery.of(context).size.width < 600;

              final leftColumnContent = FocusTraversalGroup(
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
                    else if (_enabledMethods.isEmpty)
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
                      Padding(
                        padding:
                            EdgeInsets.only(bottom: isDenseEmbedded ? 10 : 14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon:
                                  const Icon(Icons.payments_outlined, size: 16),
                              label: Text('billing.exact_cash'.tr),
                              onPressed: _fillExactCash,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: Text('billing.clear_payments'.tr),
                              onPressed: _clearAllCollectedPayments,
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < _desktopRows.length; i++) ...[
                        FocusTraversalOrder(
                          order: NumericFocusOrder((i + 1) * 10.0),
                          child: _buildRowFromDesktopItem(
                            _desktopRows[i],
                            size,
                          ),
                        ),
                        SizedBox(height: isDenseEmbedded ? 10 : 15),
                      ],
                    ],

                    // Transaction Reference Field
                    if (_desktopController.shouldShowTransactionReference(
                      rows: _desktopRows,
                      isSelected: _isCodeSelected,
                    )) ...[
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
                              hintText: 'Enter transaction reference number',
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
              );

              final rightColumnContent = Column(
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
                      amount:
                          _formatSignedWithCurrency(widget.customerPrevBalance),
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
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'billing.to_customer_credit'.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    isDenseEmbedded
                                        ? FontSize.s12
                                        : FontSize.s14,
                                    0.20,
                                    ColorManager.kPrimaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildShortcutHint('C+7'),
                            ],
                          ),
                        ),
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

                                final currentBaseBalance =
                                    _computeBaseBalance();
                                final totalCollected =
                                    _getTotalCollectedAmount();
                                final transactionExcess =
                                    totalCollected - widget.cartTotal;
                                final customerPrevBalance =
                                    _effectiveCustomerPrevBalance();

                                if (transactionExcess > 0) {
                                  double prefillAmount;

                                  if (customerPrevBalance < 0) {
                                    final customerDebt =
                                        customerPrevBalance.abs();
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
                          Provider.of<KeyboardProvider>(context, listen: false)
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

                        final validation = _validateBeforeApply();
                        if (!validation.isValid) {
                          showScaffoldError(
                            context: context,
                            message: validation.message ??
                                'Please configure payment before confirm',
                          );
                          return;
                        }

                        setState(() {
                          _isApplying = true;
                        });
                        _notifyChanges();
                        if (widget.closeOnApply) {
                          Navigator.of(context).pop();
                        } else {
                          if (widget.onAfterApply != null) {
                            Future.delayed(const Duration(milliseconds: 100),
                                () {
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
                      borderColor: _isApplying ? Colors.grey.shade400 : null,
                    ),
                ],
              );

              if (isMobilePayment) {
                return Column(
                  children: [
                    leftColumnContent,
                    SizedBox(height: isDenseEmbedded ? 12 : 20),
                    const Divider(thickness: 1),
                    SizedBox(height: isDenseEmbedded ? 12 : 20),
                    rightColumnContent,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftColumnContent),
                  SizedBox(width: isDenseEmbedded ? 18 : 30),
                  Expanded(child: rightColumnContent),
                ],
              );
            }(),
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

  void _fillExactCash() {
    _desktopController.fillExactCash(
      cartTotal: widget.cartTotal,
      setSelected: (code, selected) {
        switch (code.toUpperCase()) {
          case 'CASH':
            isCashSelected = selected;
            break;
          case 'CARD':
            isCardSelected = selected;
            break;
          case 'UPI':
            isUpiSelected = selected;
            break;
          case 'COD':
            isCodSelected = selected;
            break;
        }
      },
      cashController: cashAmountController,
      setPristine: (key, amount) {
        _pristineMethod = key;
        _pristineAmount = amount ?? '';
      },
      clearOthers: () {
        isCardSelected = false;
        isUpiSelected = false;
        isCodSelected = false;
        isCreditSelected = false;
        cardAmountController.clear();
        upiAmountController.clear();
        codAmountController.clear();
        creditAmountController.clear();
        for (final id in _extraSelected.keys.toList()) {
          _extraSelected[id] = false;
          _extraControllers[id]?.clear();
        }
        toCustomerCreditEnabled = false;
        toCustomerCreditController.clear();
        toCustomerCredit = 0.0;
      },
    );
    setState(() {
      _calculateBalance();
      _notifyChanges();
    });
  }

  void _clearAllCollectedPayments() {
    setState(() {
      _desktopController.clearAllCollectedPayments(
        rows: _desktopRows,
        setSelected: (code, selected) {
          switch (code.toUpperCase()) {
            case 'CASH':
              isCashSelected = selected;
              break;
            case 'CARD':
              isCardSelected = selected;
              break;
            case 'UPI':
              isUpiSelected = selected;
              break;
            case 'COD':
              isCodSelected = selected;
              break;
          }
        },
        clearExtra: (methodId) {
          _extraSelected[methodId] = false;
        },
      );
      isCreditSelected = false;
      creditAmountController.clear();
      _pristineMethod = null;
      _pristineAmount = '';
      _syncCreditAmountWithRemaining();
      _calculateBalance();
      _notifyChanges();
    });
  }

  Widget _buildRowFromDesktopItem(DesktopPaymentRow row, Size size) {
    VoidCallback onToggle;
    if (row.methodId != null &&
        !_desktopController.isCoreCollectedCode(row.code)) {
      onToggle = () => _toggleExtraMethod(row.methodId!);
    } else {
      onToggle = () => _togglePaymentMethod(row.rowKey);
    }

    return _buildModalPaymentRow(
      isSelected: row.selected,
      type: row.rowKey,
      icon: row.iconAsset,
      label: row.label,
      controller: row.controller,
      focusNode: row.focusNode,
      size: size,
      readOnly: row.readOnly,
      onToggle: onToggle,
      shortcutLabel: row.method.behavior == PaymentBehavior.collected
          ? _shortcutForRow(row)
          : null,
    );
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
    bool readOnly = false,
  }) {
    final bool isFocused = _focusedPaymentKey == type;
    final isDenseEmbedded =
        widget.fullWidth && (size.width <= 1100 || size.height <= 800);
    final isMobilePayment = MediaQuery.of(context).size.width < 600;
    final cardWidth =
        isMobilePayment ? 90.0 : (isDenseEmbedded ? 118.0 : 132.0);

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
              padding: EdgeInsets.symmetric(
                horizontal: isDenseEmbedded ? 6 : 8,
                vertical: isDenseEmbedded ? 5 : 6,
              ),
              blurRadius: isFocused ? 8 : 4,
              circleRadius: 5,
              height: size.height * .06, // Match text field height
              width: cardWidth,
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
                  SizedBox(width: isDenseEmbedded ? 4 : 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        isDenseEmbedded ? FontSize.s10 : FontSize.s11,
                        0.12,
                        isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                      ),
                    ),
                  ),
                  if (shortcutLabel != null) ...[
                    SizedBox(width: isDenseEmbedded ? 4 : 6),
                    _buildShortcutHint(shortcutLabel),
                  ],
                ],
              ),
            ),
          ),
        ),

        SizedBox(
            width: isMobilePayment ? 6.0 : (isDenseEmbedded ? 10.0 : 15.0)),

        // Amount input field - always visible
        Expanded(
          child: buildColumnWidgetForTextFields(
            controller: controller,
            size: size,
            height: size.height * .06,
            width: double.infinity,
            hintText: readOnly || type == 'credit'
                ? 'Auto-calculated'
                : 'Enter $label amount',
            keyboardType: TextInputType.number,
            focusNode: focusNode,
            readOnly: readOnly || type == 'credit',
            onTap: readOnly
                ? null
                : (type == 'credit'
                    ? null
                    : () {
                        setState(() {
                          final extraId = _extraMethodIdFromKey(type);
                          if (extraId != null) {
                            final wasSelected =
                                _extraSelected[extraId] ?? false;
                            _extraSelected[extraId] = true;
                            final didSwitch = !wasSelected &&
                                _applyPristineSwitch(type, controller);
                            if (!didSwitch) {
                              _autoFillRemainingForMethod(type, controller);
                            }
                            _recordPristineIfFullTotal(type, controller);
                          } else {
                            if (type == 'cash') {
                              isCashSelected = true;
                            } else if (type == 'card') {
                              isCardSelected = true;
                            } else if (type == 'upi') {
                              isUpiSelected = true;
                            } else if (type == 'cod') {
                              isCodSelected = true;
                            }

                            if (type != 'credit') {
                              final didSwitch =
                                  _applyPristineSwitch(type, controller);
                              if (!didSwitch) {
                                _autoFillSelectedMethodAmount(type);
                              }
                              _recordPristineIfFullTotal(type, controller);
                            }
                          }
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
