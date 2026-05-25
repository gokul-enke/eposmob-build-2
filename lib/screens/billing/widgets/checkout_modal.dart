import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart'; // Re-enabled for .tr translations
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/delivery_method.dart';
// import 'package:pos_machine/resources/color_manager.dart'; // Unused
import 'package:pos_machine/resources/font_manager.dart';
// import 'package:pos_machine/resources/style_manager.dart'; // Unused
import 'package:pos_machine/screens/billing/widgets/coupon_modal.dart';
import 'package:pos_machine/screens/billing/widgets/payment_method_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/resources/color_manager.dart'; // Re-added for delivery modal components
import 'package:pos_machine/resources/style_manager.dart'; // Re-added for delivery modal components
import 'package:pos_machine/components/build_dialog_box.dart'; // For showScaffoldError
import 'package:pos_machine/helpers/payment_auto_fill_helper.dart';

enum CheckoutModalMode {
  checkout,
  selectionOnly,
}

class CheckoutModal extends StatefulWidget {
  final double cartTotal;
  final List<CustomerListModelData> availableCustomers;
  final CustomerListModelData? selectedCustomer;
  final CheckoutModalMode mode;
  final String title;

  // Payment Modal State
  final bool hasOpenedPaymentModalOnce;

  // Delivery State (Optional)
  final bool enableDelivery;
  final String deliveryMethod;
  final String deliveryMethodId;
  final String carNumber;
  final String deliveryComment;
  final String deliveryAddress;
  final String? deliveryDate;
  final String? deliveryTime;
  final double initialDeliveryCharge;

  // Payment State
  final bool isCashSelected;
  final bool isCardSelected;
  final bool isUpiSelected;
  final bool isCodSelected;
  final bool isDebitSelected;
  final String cashAmount;
  final String cardAmount;
  final String upiAmount;
  final String codAmount;
  final String debitAmount;
  final String transactionNumber;
  final bool toCustomerCreditEnabled;
  final double toCustomerCreditAmount;
  final String? cashMethodId;
  final String? cardMethodId;
  final String? upiMethodId;
  final String? codMethodId;

  // Discount State
  final String couponCode;
  final double flatDiscount;
  final double percentageDiscount;
  final bool isCouponApplied;
  final String confirmButtonTitle;
  final String printButtonTitle;
  final bool requireCheckoutCompletion;
  final bool isQuotationMode;
  final bool requireSavedCustomer;
  final DateTime? initialQuotationDate;
  final DateTime? initialQuotationExpiryDate;

  // Callbacks
  final Function(CustomerListModelData) onCustomerSelected;
  final Future<CustomerListModelData?> Function(
    String searchQuery, {
    String? initialName,
    String? initialPhone,
  }) onAddNewCustomer;
  final Function(String couponCode, bool isApplied, double flatDiscount,
      double percentageDiscount) onDiscountApplied;

  final Function(String method, String methodId, String carNo, String comment,
      String? date, String? time, String address)? onDeliveryUpdated;
  final Function(double deliveryCharge)? onDeliveryChargeUpdated;

  final Function(
      bool isCash,
      bool isCard,
      bool isUpi,
      bool isCod,
      bool isDebit,
      String cash,
      String card,
      String upi,
      String cod,
      String debit,
      String trans,
      bool toCredit,
      {String? cashMethodId,
      String? cardMethodId,
      String? upiMethodId,
      String? codMethodId}) onPaymentUpdated;
  final Function(DateTime quotationDate, DateTime expiryDate)?
      onQuotationDatesUpdated;

  final Future<void> Function() onConfirmOrder;
  final Future<void> Function() onConfirmAndPrint;

  /// Optional initial step the modal should open at:
  /// 0 = Customer, 1 = Delivery, 2 = Discount, 3 = Payment.
  /// When null, the modal uses its default behavior (step 0, with skip-customer setting).
  final int? initialStep;

  const CheckoutModal({
    super.key,
    required this.cartTotal,
    required this.availableCustomers,
    this.selectedCustomer,
    this.mode = CheckoutModalMode.checkout,
    this.title = 'Finalize Order',
    this.hasOpenedPaymentModalOnce = false,
    required this.isCashSelected,
    required this.isCardSelected,
    required this.isUpiSelected,
    required this.isCodSelected,
    required this.isDebitSelected,
    required this.cashAmount,
    required this.cardAmount,
    required this.upiAmount,
    required this.codAmount,
    required this.debitAmount,
    required this.transactionNumber,
    required this.toCustomerCreditEnabled,
    required this.toCustomerCreditAmount,
    this.cashMethodId,
    this.cardMethodId,
    this.upiMethodId,
    this.codMethodId,
    this.enableDelivery = false,
    this.deliveryMethod = "Store Takeaway",
    this.deliveryMethodId = "",
    this.carNumber = "",
    this.deliveryComment = "",
    this.deliveryAddress = "",
    this.deliveryDate,
    this.deliveryTime,
    this.initialDeliveryCharge = 0.0,
    required this.couponCode,
    required this.flatDiscount,
    required this.percentageDiscount,
    required this.isCouponApplied,
    this.confirmButtonTitle = 'Confirm',
    this.printButtonTitle = 'Confirm & Print',
    this.requireCheckoutCompletion = true,
    this.isQuotationMode = false,
    this.requireSavedCustomer = false,
    this.initialQuotationDate,
    this.initialQuotationExpiryDate,
    required this.onCustomerSelected,
    required this.onAddNewCustomer,
    required this.onDiscountApplied,
    this.onDeliveryUpdated,
    this.onDeliveryChargeUpdated,
    required this.onPaymentUpdated,
    this.onQuotationDatesUpdated,
    required this.onConfirmOrder,
    required this.onConfirmAndPrint,
    this.initialStep,
  });

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  late int _currentStep; // 0: Customer, 1: Delivery, 2: Discount, 3: Payment
  bool _hasEvaluatedSkipCustomerSelection = false;
  bool _isConfirming = false;
  bool _isPrinting = false;
  bool _hasOpenedPaymentModalOnce =
      false; // Track if payment step has been visited
  bool _isAddingCustomer = false;

  // Local state for Customer Search
  String _customerSearchQuery = '';
  List<CustomerListModelData> _allCustomers = [];
  List<CustomerListModelData> _filteredCustomers = [];
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _quotationCustomerNameController =
      TextEditingController();
  final TextEditingController _quotationCustomerPhoneController =
      TextEditingController();
  final FocusNode _customerSearchFocusNode = FocusNode();
  final FocusNode _customerSearchClearFocusNode =
      FocusNode(skipTraversal: true);
  final FocusNode _quotationCustomerNameFocusNode = FocusNode();
  final FocusNode _quotationCustomerPhoneFocusNode = FocusNode();
  final FocusNode _customerListFocusNode = FocusNode();
  int _focusedCustomerIndex = 0;
  // Customer grid uses 3 columns — kept in sync with the GridView delegate
  // below so arrow-key navigation maps cleanly to visual rows.
  static const int _customerGridColumns = 3;
  final Map<String, FocusNode> _deliveryMethodFocusNodes = {};
  final FocusNode _deliveryCarNumberFocusNode = FocusNode();
  final FocusNode _deliveryCommentFocusNode = FocusNode();
  final FocusNode _deliveryAddressFocusNode = FocusNode();

  // Local State to handle Optimistic Updates (Fixes "Not selecting" issues)
  CustomerListModelData? _localSelectedCustomer;
  late double _localFlatDiscount;
  late double _localPercentageDiscount;
  late String _localCouponCode;
  late bool _localIsCouponApplied;

  // Local Delivery State
  late String _lDeliveryMethod;
  late String _lDeliveryMethodId;
  String? _selectedDeliveryPriceId;
  double? _selectedDeliveryCharge;
  late TextEditingController _lCarNumberController;
  late TextEditingController _lCommentController;
  late TextEditingController _lAddressController;
  DateTime? _lSelectedDeliveryDate;
  TimeOfDay? _lSelectedDeliveryTime;

  /// Name of the delivery-method tile that currently has keyboard focus,
  /// or null when none. Drives the orange focus ring on each tile.
  String? _focusedDeliveryMethodName;

  bool get _isSelectionOnly => widget.mode == CheckoutModalMode.selectionOnly;

  // Local Payment State
  late bool _lIsCashSelected;
  late bool _lIsCardSelected;
  late bool _lIsUpiSelected;
  late bool _lIsCodSelected;
  late bool _lIsDebitSelected;
  late String _lCashAmount;
  late String _lCardAmount;
  late String _lUpiAmount;
  late String _lCodAmount;
  late String _lDebitAmount;
  late String _lTransactionNumber;
  late bool _lToCustomerCreditEnabled;
  late DateTime _lQuotationDate;
  late DateTime _lQuotationExpiryDate;

  String _initialForName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'U';
    }
    return trimmed[0].toUpperCase();
  }

  TimeOfDay? _parseDeliveryTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final twentyFourHour = RegExp(r'^(\d{1,2}):(\d{2})$');
    final twelveHour = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');

    final twentyFourMatch = twentyFourHour.firstMatch(trimmed);
    if (twentyFourMatch != null) {
      final hour = int.tryParse(twentyFourMatch.group(1) ?? '');
      final minute = int.tryParse(twentyFourMatch.group(2) ?? '');
      if (hour != null && minute != null && hour >= 0 && hour <= 23) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    final twelveMatch = twelveHour.firstMatch(trimmed);
    if (twelveMatch != null) {
      final hourRaw = int.tryParse(twelveMatch.group(1) ?? '');
      final minute = int.tryParse(twelveMatch.group(2) ?? '');
      final meridian = (twelveMatch.group(3) ?? '').toUpperCase();
      if (hourRaw != null && minute != null && hourRaw >= 1 && hourRaw <= 12) {
        var hour = hourRaw % 12;
        if (meridian == 'PM') {
          hour += 12;
        }
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentStep = _resolveInitialStep(widget.initialStep);
    debugPrint(
        "⌨️ [CheckoutModal] initState | customer=${widget.selectedCustomer?.id} | enableDelivery=${widget.enableDelivery} | paymentVisited=${widget.hasOpenedPaymentModalOnce} | initialStep=${widget.initialStep} | resolvedStep=$_currentStep");
    _allCustomers = List<CustomerListModelData>.from(widget.availableCustomers);
    _filteredCustomers = List<CustomerListModelData>.from(_allCustomers);

    // Initialize Local State from Widget Props
    _localSelectedCustomer = widget.selectedCustomer;
    _localFlatDiscount = widget.flatDiscount;
    _localPercentageDiscount = widget.percentageDiscount;
    _localCouponCode = widget.couponCode;
    _localIsCouponApplied = widget.isCouponApplied;
    _hasOpenedPaymentModalOnce =
        widget.hasOpenedPaymentModalOnce; // Initialize from parent

    // Initialize Local Delivery State
    _lDeliveryMethod = widget.deliveryMethod;
    _lDeliveryMethodId = widget.deliveryMethodId;
    _selectedDeliveryCharge = widget.initialDeliveryCharge;
    _lCarNumberController = TextEditingController(text: widget.carNumber);
    _lCommentController = TextEditingController(text: widget.deliveryComment);
    _lAddressController = TextEditingController(text: widget.deliveryAddress);
    if (widget.deliveryDate != null && widget.deliveryDate!.isNotEmpty) {
      _lSelectedDeliveryDate = DateTime.tryParse(widget.deliveryDate!);
    }
    if (widget.deliveryTime != null && widget.deliveryTime!.isNotEmpty) {
      _lSelectedDeliveryTime = _parseDeliveryTime(widget.deliveryTime!);
    }

    _lIsCashSelected = widget.isCashSelected;
    _lIsCardSelected = widget.isCardSelected;
    _lIsUpiSelected = widget.isUpiSelected;
    _lIsCodSelected = widget.isCodSelected;
    _lIsDebitSelected = widget.isDebitSelected;
    _lCashAmount = widget.cashAmount;
    _lCardAmount = widget.cardAmount;
    _lUpiAmount = widget.upiAmount;
    _lCodAmount = widget.codAmount;
    _lDebitAmount = widget.debitAmount;
    _lTransactionNumber = widget.transactionNumber;
    _lToCustomerCreditEnabled = widget.toCustomerCreditEnabled;
    _lQuotationDate = widget.initialQuotationDate ?? DateTime.now();
    _lQuotationExpiryDate = widget.initialQuotationExpiryDate ??
        _lQuotationDate.add(const Duration(days: 30));
    if (_lQuotationExpiryDate.isBefore(_lQuotationDate)) {
      _lQuotationExpiryDate = _lQuotationDate.add(const Duration(days: 30));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDefaultPaymentMethod();
      _requestCurrentStepFocus();
    });
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    debugPrint("⌨️ [CheckoutModal] Hardware keyboard handler registered");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyInitialStepFromSettings();
  }

  int _resolveInitialStep(int? requested) {
    if (requested == null) return 0;
    if (requested < 0 || requested > 3) return 0;
    if (requested == 1 && !widget.enableDelivery) return 0;
    if (widget.isQuotationMode && requested == 3) return 0;
    return requested;
  }

  void _applyInitialStepFromSettings() {
    if (_hasEvaluatedSkipCustomerSelection) {
      return;
    }
    // Respect explicit caller-provided initial step (e.g. F3/F4/F5/F10 on billing page).
    if (widget.initialStep != null) {
      _hasEvaluatedSkipCustomerSelection = true;
      return;
    }

    final appSettings = Provider.of<AppSettingsProvider>(context).appSettings;
    if (appSettings == null) {
      return;
    }

    _hasEvaluatedSkipCustomerSelection = true;
    if (appSettings.skipCustomerSelection &&
        !widget.isQuotationMode &&
        mounted &&
        _currentStep != 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentStep = 3;
        });
        _requestCurrentStepFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CheckoutModal oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.availableCustomers != widget.availableCustomers) {
      final previousSelectedId = _localSelectedCustomer?.id;
      _allCustomers =
          List<CustomerListModelData>.from(widget.availableCustomers);

      if (_customerSearchQuery.isEmpty) {
        _filteredCustomers = List<CustomerListModelData>.from(_allCustomers);
      } else {
        final query = _customerSearchQuery;
        _filteredCustomers = _allCustomers.where((customer) {
          final name = (customer.name ?? '').toLowerCase();
          final phone = (customer.phone ?? '').toLowerCase();
          final altPhone = (customer.altPhone ?? '').toLowerCase();
          return name.contains(query) ||
              phone.contains(query) ||
              altPhone.contains(query);
        }).toList();
      }

      if (previousSelectedId != null) {
        for (final customer in _allCustomers) {
          if (customer.id == previousSelectedId) {
            _localSelectedCustomer = customer;
            break;
          }
        }
      }
    }
  }

  void _applyDefaultPaymentMethod() {
    if (widget.isQuotationMode) {
      return;
    }

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);

    // Only set default if no method is currently selected
    if (_lIsCashSelected ||
        _lIsCardSelected ||
        _lIsUpiSelected ||
        _lIsCodSelected ||
        _lIsDebitSelected) {
      return;
    }

    final defaultPayment =
        appSettingsProvider.appSettings?.defaultPaymentMethod;
    if (defaultPayment != null && defaultPayment.isNotEmpty) {
      debugPrint(
          "💰 [CheckoutModal] Applying default payment method: $defaultPayment");
      setState(() {
        _lIsCashSelected = defaultPayment.toUpperCase() == 'CASH';
        _lIsCardSelected = defaultPayment.toUpperCase() == 'CARD';
        _lIsUpiSelected = defaultPayment.toUpperCase() == 'UPI';
        _lIsCodSelected = defaultPayment.toUpperCase() == 'COD';
      });
    }
  }

  @override
  void dispose() {
    debugPrint(
        "⌨️ [CheckoutModal] dispose | step=$_currentStep | paymentVisited=$_hasOpenedPaymentModalOnce");
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _customerSearchController.dispose();
    _quotationCustomerNameController.dispose();
    _quotationCustomerPhoneController.dispose();
    _customerSearchFocusNode.dispose();
    _customerSearchClearFocusNode.dispose();
    _quotationCustomerNameFocusNode.dispose();
    _quotationCustomerPhoneFocusNode.dispose();
    _customerListFocusNode.dispose();
    for (final focusNode in _deliveryMethodFocusNodes.values) {
      focusNode.dispose();
    }
    _deliveryMethodFocusNodes.clear();
    _deliveryCarNumberFocusNode.dispose();
    _deliveryCommentFocusNode.dispose();
    _deliveryAddressFocusNode.dispose();
    _lCarNumberController.dispose();
    _lCommentController.dispose();
    _lAddressController.dispose();
    super.dispose();
  }

  void _requestCurrentStepFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isAddingCustomer) return;
      switch (_currentStep) {
        case 0:
          _customerSearchFocusNode.requestFocus();
          break;
        case 1:
          if (widget.enableDelivery) {
            final focusNode = _selectedDeliveryMethodFocusNode();
            if (focusNode != null) {
              focusNode.requestFocus();
            }
          }
          break;
      }
    });
  }

  String _deliveryMethodFocusKey(DeliveryMethod method) =>
      method.id.isNotEmpty ? method.id : method.name;

  FocusNode _deliveryMethodFocusNodeFor(DeliveryMethod method) {
    final key = _deliveryMethodFocusKey(method);
    return _deliveryMethodFocusNodes.putIfAbsent(key, () => FocusNode());
  }

  FocusNode? _selectedDeliveryMethodFocusNode() {
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);

    for (final method in deliveryMethodsProvider.deliveryMethods) {
      final matchesById =
          _lDeliveryMethodId.isNotEmpty && method.id == _lDeliveryMethodId;
      final matchesByName = method.name == _lDeliveryMethod;
      if (matchesById || matchesByName) {
        return _deliveryMethodFocusNodeFor(method);
      }
    }

    if (deliveryMethodsProvider.deliveryMethods.isEmpty) {
      return null;
    }
    return _deliveryMethodFocusNodeFor(
        deliveryMethodsProvider.deliveryMethods.first);
  }

  bool _onHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;

    debugPrint(
        "⌨️ [CheckoutModal] key=${event.logicalKey.debugName} | step=$_currentStep | customer=${_localSelectedCustomer?.id} | canConfirm=$_canConfirmOrPrint | canPrint=$_canPrint | paymentVisited=$_hasOpenedPaymentModalOnce");

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      debugPrint("⌨️ [CheckoutModal] Handling Esc -> close modal");
      Navigator.of(context).pop();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      debugPrint("⌨️ [CheckoutModal] Handling F2 -> confirm");
      if (_isSelectionOnly) {
        _closeSelectionOnlyModal();
      } else if (_canConfirmOrPrint && !_isConfirming) {
        _handleConfirm();
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f3) {
      debugPrint("⌨️ [CheckoutModal] Handling F3 -> customer step");
      _goToStep(0);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f4) {
      debugPrint("⌨️ [CheckoutModal] Handling F4 -> delivery step");
      if (widget.enableDelivery) _goToStep(1);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      debugPrint("⌨️ [CheckoutModal] Handling F5 -> payment step");
      if (!widget.isQuotationMode) {
        _goToStep(3);
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f6) {
      debugPrint("⌨️ [CheckoutModal] Handling F6 -> print");
      if (_canPrint && !_isPrinting) _handlePrint();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f8) {
      debugPrint("⌨️ [CheckoutModal] Handling F8 -> confirm");
      if (_canConfirmOrPrint && !_isConfirming) _handleConfirm();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f9) {
      debugPrint("⌨️ [CheckoutModal] Handling F9 -> print");
      if (_canPrint && !_isPrinting) _handlePrint();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f10) {
      debugPrint("⌨️ [CheckoutModal] Handling F10 -> discount step");
      _goToStep(2);
      return true;
    }
    return false;
  }

  void _nextStep() {
    // Logic to skip delivery step if not enabled
    int next = _currentStep + 1;
    if (!widget.enableDelivery && next == 1) {
      next = 2; // Skip delivery
    }

    final maxStep = widget.isQuotationMode ? 2 : 3;

    // Max steps logic: 0(Cust) -> 1(Del) -> 2(Disc) -> 3(Pay)
    // If delivery disabled: 0(Cust) -> 2(Disc) -> 3(Pay)

    // Original was 0,1,2,3. Now expanding.
    if (next <= maxStep) {
      setState(() {
        _currentStep = next;
      });
      _requestCurrentStepFocus();
    }
  }

  void _previousStep() {
    int prev = _currentStep - 1;
    if (!widget.enableDelivery && prev == 1) {
      prev = 0; // Skip delivery going back
    }
    if (prev >= 0) {
      setState(() {
        _currentStep = prev;
      });
      _requestCurrentStepFocus();
    }
  }

  void _goToStep(int step) {
    if (_isAddingCustomer) return;
    if (_isSelectionOnly && step != _currentStep) return;
    if (!widget.enableDelivery && step == 1) return;
    if (widget.isQuotationMode && step == 3) return;
    if (step >= 0 && step <= 3) {
      setState(() {
        _currentStep = step;
      });
      _requestCurrentStepFocus();
    }
  }

  double _getFreeDeliveryMinimumAmount() {
    final settings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final rawValue = settings?.freeDeliveryMinimumAmount.trim() ?? '';
    return double.tryParse(rawValue) ?? 0.0;
  }

  double _getCurrentNetAmount() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    return localProductProvider.priceSummary?.netTotal ?? widget.cartTotal;
  }

  bool _isfreeDeliveryMinimumAmount() {
    final settings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    return settings?.freeDeliveryEnabled ?? false;
  }

  bool _shouldApplyDeliveryCharge() {
    if (!_isfreeDeliveryMinimumAmount()) {
      return false;
    }

    final minimumAmount = _getFreeDeliveryMinimumAmount();
    if (minimumAmount <= 0) {
      return true;
    }
    return _getCurrentNetAmount() < minimumAmount;
  }

  double _getEffectiveDeliveryCharge() {
    if (!_shouldApplyDeliveryCharge()) {
      return 0.0;
    }

    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);

    DeliveryMethod? selectedMethod;
    if (_lDeliveryMethod.isNotEmpty || _lDeliveryMethodId.isNotEmpty) {
      for (final method in deliveryMethodsProvider.deliveryMethods) {
        if ((_lDeliveryMethodId.isNotEmpty &&
                method.id == _lDeliveryMethodId) ||
            method.name == _lDeliveryMethod) {
          selectedMethod = method;
          break;
        }
      }
    }

    return _selectedDeliveryCharge ?? selectedMethod?.basePrice ?? 0.0;
  }

  void _selectDeliveryMethod(
    DeliveryMethod method, {
    required bool shouldApplyDeliveryCharge,
  }) {
    setState(() {
      _lDeliveryMethod = method.name;
      _lDeliveryMethodId = method.id;
      if (method.prices.isEmpty) {
        _selectedDeliveryPriceId = null;
        _selectedDeliveryCharge = 0.0;
      } else {
        final existingById = method.prices
            .where((p) => p.id == _selectedDeliveryPriceId)
            .toList();
        if (existingById.isNotEmpty) {
          _selectedDeliveryCharge = existingById.first.price;
        } else {
          final existingByCharge = _selectedDeliveryCharge == null
              ? <DeliveryPrice>[]
              : method.prices
                  .where(
                      (p) => (p.price - _selectedDeliveryCharge!).abs() < 0.001)
                  .toList();

          if (existingByCharge.isNotEmpty) {
            _selectedDeliveryPriceId = existingByCharge.first.id;
            _selectedDeliveryCharge = existingByCharge.first.price;
          } else {
            _selectedDeliveryPriceId = method.prices.first.id;
            _selectedDeliveryCharge = method.prices.first.price;
          }
        }
      }

      if (!shouldApplyDeliveryCharge) {
        _selectedDeliveryCharge = 0.0;
      }
    });
    _handleDeliveryUpdate();
  }

  void _handleDeliveryUpdate() {
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    double resolvedCharge = _selectedDeliveryCharge ?? 0.0;

    if (_lDeliveryMethod.isNotEmpty &&
        (_selectedDeliveryCharge == null || _selectedDeliveryCharge! <= 0)) {
      for (final method in deliveryMethodsProvider.deliveryMethods) {
        if (method.name == _lDeliveryMethod ||
            method.id == _lDeliveryMethodId) {
          resolvedCharge = method.basePrice ?? 0.0;
          break;
        }
      }
    }

    if (!_shouldApplyDeliveryCharge()) {
      resolvedCharge = 0.0;
    }

    if (widget.onDeliveryUpdated != null) {
      final dateValue = _lSelectedDeliveryDate != null
          ? _lSelectedDeliveryDate!.toIso8601String()
          : '';
      final timeValue = _lSelectedDeliveryTime != null
          ? '${_lSelectedDeliveryTime!.hour.toString().padLeft(2, '0')}:${_lSelectedDeliveryTime!.minute.toString().padLeft(2, '0')}'
          : '';
      widget.onDeliveryUpdated!(
        _lDeliveryMethod,
        _lDeliveryMethodId,
        _lCarNumberController.text,
        _lCommentController.text,
        dateValue,
        timeValue,
        _lAddressController.text,
      );
    }

    if (widget.onDeliveryChargeUpdated != null) {
      widget.onDeliveryChargeUpdated!(resolvedCharge);
    }
  }

  // --- Step 1: Customer Logic ---
  void _filterCustomers(String query) {
    setState(() {
      _customerSearchQuery = query.toLowerCase();
      _focusedCustomerIndex = 0;
      if (_customerSearchQuery.isEmpty) {
        _filteredCustomers = List<CustomerListModelData>.from(_allCustomers);
      } else {
        _filteredCustomers = _allCustomers.where((customer) {
          final name = (customer.name ?? '').toLowerCase();
          final phone = (customer.phone ?? '').toLowerCase();
          final altPhone = (customer.altPhone ?? '').toLowerCase();
          return name.contains(_customerSearchQuery) ||
              phone.contains(_customerSearchQuery) ||
              altPhone.contains(_customerSearchQuery);
        }).toList();
      }
    });
  }

  // Handle local state update + parent callback
  void _handleCustomerSelection(CustomerListModelData customer) {
    setState(() {
      _localSelectedCustomer = customer;
      _quotationCustomerNameController.clear();
      _quotationCustomerPhoneController.clear();
    });
    widget.onCustomerSelected(customer);
    if (!_isSelectionOnly) {
      if (widget.isQuotationMode) {
        _goToStep(widget.enableDelivery ? 1 : 2);
      } else {
        // Auto-move to payment tab after customer selection
        _goToStep(3);
      }
    }
  }

  void _closeSelectionOnlyModal() {
    Navigator.of(context).pop();
  }

  void _handleAddNewCustomer() async {
    if (_isAddingCustomer) return;
    setState(() {
      _isAddingCustomer = true;
    });
    try {
      final quoteOnlyCustomer = _quoteOnlyCustomerForCreation;
      final newCustomer = await widget.onAddNewCustomer(
        _customerSearchQuery,
        initialName: quoteOnlyCustomer?.name,
        initialPhone: quoteOnlyCustomer?.phone,
      );
      if (newCustomer != null && mounted) {
        setState(() {
          _allCustomers.removeWhere((c) => c.id == newCustomer.id);
          _allCustomers.insert(0, newCustomer);
          _filteredCustomers = List<CustomerListModelData>.from(_allCustomers);
          _localSelectedCustomer = newCustomer;
          _customerSearchController.clear();
          _customerSearchQuery = '';
        });
        widget.onCustomerSelected(newCustomer);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingCustomer = false;
        });
      }
    }
  }

  CustomerListModelData? get _quoteOnlyCustomerForCreation {
    final customer = _localSelectedCustomer;
    if (!widget.requireSavedCustomer ||
        customer == null ||
        customer.id != null) {
      return null;
    }
    final name = customer.name?.trim();
    if (name == null || name.isEmpty) return null;
    return customer;
  }

  bool get _hasQuoteOnlyCustomerNeedingSave =>
      _quoteOnlyCustomerForCreation != null;

  void _handleDiscountUpdate(
      String code, bool applied, double flat, double percent) {
    // Unfocus to prevent "FocusNode used after disposed" errors
    FocusScope.of(context).unfocus();

    setState(() {
      _localCouponCode = code;
      _localIsCouponApplied = applied;
      _localFlatDiscount = flat;
      _localPercentageDiscount = percent;
    });
    widget.onDiscountApplied(code, applied, flat, percent);
  }

  void _handlePaymentUpdate(
      bool isCash,
      bool isCard,
      bool isUpi,
      bool isCod,
      bool isDebit,
      String cash,
      String card,
      String upi,
      String cod,
      String debit,
      String trans,
      bool toCredit,
      {String? cashMethodId,
      String? cardMethodId,
      String? upiMethodId,
      String? codMethodId}) {
    setState(() {
      _lIsCashSelected = isCash;
      _lIsCardSelected = isCard;
      _lIsUpiSelected = isUpi;
      _lIsCodSelected = isCod;
      _lIsDebitSelected = isDebit;
      _lCashAmount = cash;
      _lCardAmount = card;
      _lUpiAmount = upi;
      _lCodAmount = cod;
      _lDebitAmount = debit;
      _lTransactionNumber = trans;
      _lToCustomerCreditEnabled = toCredit;
      _hasOpenedPaymentModalOnce = true;
    });
    widget.onPaymentUpdated(isCash, isCard, isUpi, isCod, isDebit, cash, card,
        upi, cod, debit, trans, toCredit,
        cashMethodId: cashMethodId,
        cardMethodId: cardMethodId,
        upiMethodId: upiMethodId,
        codMethodId: codMethodId);
  }

  void _handleQuotationDateUpdate({
    DateTime? quotationDate,
    DateTime? expiryDate,
  }) {
    setState(() {
      if (quotationDate != null) {
        _lQuotationDate = quotationDate;
        if (_lQuotationExpiryDate.isBefore(_lQuotationDate)) {
          _lQuotationExpiryDate = _lQuotationDate.add(const Duration(days: 30));
        }
      }
      if (expiryDate != null) {
        _lQuotationExpiryDate = expiryDate;
      }
    });
    widget.onQuotationDatesUpdated?.call(
      _lQuotationDate,
      _lQuotationExpiryDate,
    );
  }

  bool get _isDenseCheckout {
    final size = MediaQuery.sizeOf(context);
    return size.width <= 1100 || size.height <= 800;
  }

  double get _checkoutPadding => _isDenseCheckout ? 16.0 : 24.0;
  double get _checkoutGap => _isDenseCheckout ? 14.0 : 24.0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * (_isDenseCheckout ? 0.965 : 0.94))
        .clamp(320.0, 1300.0)
        .toDouble();
    final dialogHeight = (screenSize.height * (_isDenseCheckout ? 0.90 : 0.92))
        .clamp(520.0, 850.0)
        .toDouble();

    return Focus(
      autofocus: true,
      canRequestFocus: true,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 8,
        insetPadding: EdgeInsets.symmetric(
          horizontal: _isDenseCheckout ? 8 : 16,
          vertical: _isDenseCheckout ? 12 : 16,
        ),
        child: Stack(
          children: [
            Container(
              width: dialogWidth,
              height: dialogHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTitleHeader(),
                  // Content Area
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                ],
              ),
            ),
            if (_isAddingCustomer)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.white.withOpacity(0.6),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: _isDenseCheckout ? 6 : 10,
        horizontal: _isDenseCheckout ? 18 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            widget.title,
            style: buildCustomStyle(
              FontWeightManager.bold,
              _isDenseCheckout ? FontSize.s18 : FontSize.s20,
              0.25,
              Colors.black87,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      bool hasCustomer, bool hasDiscount, bool hasPayment, bool hasDelivery) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Finalize Order",
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s20,
                    0.25,
                    Colors.black87,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepIndicator(0, 'Customer', Icons.person,
                    isActive: _currentStep == 0, isCompleted: hasCustomer),
                if (widget.enableDelivery) ...[
                  _buildStepConnector(isActive: _currentStep > 0),
                  _buildStepIndicator(1, 'Delivery', Icons.local_shipping,
                      isActive: _currentStep == 1, isCompleted: hasDelivery),
                ],
                _buildStepConnector(
                    isActive: _currentStep > (widget.enableDelivery ? 1 : 0)),
                _buildStepIndicator(2, 'Discount', Icons.discount,
                    isActive: _currentStep == 2, isCompleted: hasDiscount),
                if (!widget.isQuotationMode) ...[
                  _buildStepConnector(isActive: _currentStep > 2),
                  _buildStepIndicator(3, 'Payment', Icons.payment,
                      isActive: _currentStep == 3, isCompleted: hasPayment),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label, IconData icon,
      {required bool isActive, required bool isCompleted}) {
    final primaryColor = const Color(0xFF2563EB);
    final successColor = const Color(0xFF059669);
    final neutralColor = Colors.grey.shade400;

    final color = isActive
        ? primaryColor
        : isCompleted
            ? successColor
            : neutralColor;

    final bgColor = isActive
        ? primaryColor
        : isCompleted
            ? successColor.withValues(alpha: 0.1)
            : Colors.grey.shade100;

    return InkWell(
      onTap: () => _goToStep(stepIndex),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isActive ? 10 : 8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
                border: Border.all(
                    color: isActive
                        ? primaryColor
                        : (isCompleted
                            ? successColor.withValues(alpha: 0.5)
                            : Colors.transparent),
                    width: 2),
              ),
              child: Icon(isCompleted && !isActive ? Icons.check : icon,
                  size: isActive ? 20 : 16,
                  color: isActive ? Colors.white : color),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive
                    ? Colors.black
                    : (isCompleted ? Colors.black87 : Colors.grey.shade500),
                fontSize: isActive ? 16 : 14,
                letterSpacing: isActive ? 0.5 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector({required bool isActive}) {
    return Container(
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildCustomerStep();
      case 1:
        if (widget.enableDelivery) return _buildDeliveryStep();
        return _buildDiscountStep(); // Fallback if manually navigated? actually _goToStep handles skipping
      case 2:
        return _buildDiscountStep();
      case 3:
        return _buildPaymentStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: CUSTOMER ---
  Widget _buildCustomerStep() {
    final hasInternet = context.watch<BillingProvider>().hasInternet;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(_checkoutPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Search, Selected Customer, and List
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Search Bar
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: TextField(
                              controller: _customerSearchController,
                              focusNode: _customerSearchFocusNode,
                              onChanged: _filterCustomers,
                              decoration: InputDecoration(
                                hintText: 'Search by name or phone number...',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade500),
                                prefixIcon: Icon(Icons.search,
                                    color: Colors.grey.shade500),
                                suffixIcon: _customerSearchQuery.isNotEmpty
                                    ? IconButton(
                                        focusNode:
                                            _customerSearchClearFocusNode,
                                        icon: Icon(Icons.clear,
                                            color: Colors.grey.shade500),
                                        onPressed: () {
                                          _customerSearchController.clear();
                                          _filterCustomers('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_hasQuoteOnlyCustomerNeedingSave) ...[
                          _buildQuoteOnlyCustomerBanner(),
                          const SizedBox(height: 8),
                        ],
                        // List
                        Expanded(
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(30),
                            child: _buildCustomerList(),
                          ),
                        ),
                        if (hasInternet) ...[
                          const SizedBox(height: 16),
                          // Add Customer Button (online only)
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(40),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _isAddingCustomer
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                              Colors.grey),
                                        ),
                                      )
                                    : const Icon(Icons.person_add),
                                label: Text(_isAddingCustomer
                                    ? 'Adding...'
                                    : 'Add New Customer'),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: const Color(0xFFECFDF3),
                                  foregroundColor: const Color(0xFF047857),
                                  side: const BorderSide(
                                      color: Color(0xFF34D399)),
                                ),
                                onPressed: _isAddingCustomer
                                    ? null
                                    : _handleAddNewCustomer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: _checkoutGap),
                  const VerticalDivider(width: 1),
                  SizedBox(width: _checkoutGap),
                  // Right: Summary only (no customer card)
                  Expanded(
                    flex: 2,
                    child: _isSelectionOnly
                        ? _buildSelectionOnlySidePanel(
                            icon: Icons.person,
                            title: 'Selected Customer',
                            value:
                                _localSelectedCustomer?.name ?? 'Not selected',
                            supportingText: _selectedCustomerSupportingText(),
                            canDone: _localSelectedCustomer != null,
                          )
                        : Column(
                            children: [
                              Expanded(child: _buildCompactSummary()),
                              _buildFooter(
                                onPrint: _handlePrint,
                                onConfirm: _handleConfirm,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationDatesPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuotationInlineCustomerFields(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuotationDateField(
                  label: 'Quotation Date',
                  date: _lQuotationDate,
                  firstDate: DateTime(2020),
                  onDateSelected: (date) =>
                      _handleQuotationDateUpdate(quotationDate: date),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuotationDateField(
                  label: 'Expiry Date',
                  date: _lQuotationExpiryDate,
                  firstDate: _lQuotationDate,
                  isExpiry: true,
                  onDateSelected: (date) =>
                      _handleQuotationDateUpdate(expiryDate: date),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteOnlyCustomerBanner() {
    final customer = _quoteOnlyCustomerForCreation;
    if (customer == null) return const SizedBox.shrink();

    final phone = customer.phone?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quotation customer is not saved',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    customer.name?.trim(),
                    if (phone != null && phone.isNotEmpty) phone,
                  ].whereType<String>().join(' | '),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78350F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isAddingCustomer ? null : _handleAddNewCustomer,
            icon: _isAddingCustomer
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 16),
            label: Text(_isAddingCustomer ? 'Creating...' : 'Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationInlineCustomerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildQuotationInputField(
                label: 'Customer Name',
                controller: _quotationCustomerNameController,
                focusNode: _quotationCustomerNameFocusNode,
                hintText: 'Customer name',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuotationInputField(
                label: 'Customer Phone',
                controller: _quotationCustomerPhoneController,
                focusNode: _quotationCustomerPhoneFocusNode,
                hintText: 'Customer phone',
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleQuotationInlineCustomerChanged() {
    if (_quotationCustomerNameController.text.trim().isNotEmpty ||
        _quotationCustomerPhoneController.text.trim().isNotEmpty) {
      _localSelectedCustomer = null;
    }
    setState(() {});
  }

  Widget _buildQuotationInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE7F3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            onChanged: (_) => _handleQuotationInlineCustomerChanged(),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hintText,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuotationDateField({
    required String label,
    required DateTime date,
    required DateTime firstDate,
    required ValueChanged<DateTime> onDateSelected,
    bool isExpiry = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickQuotationDate(
              initialDate: date,
              firstDate: firstDate,
              onDateSelected: onDateSelected,
            ),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE7F3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      MaterialLocalizations.of(context).formatMediumDate(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickQuotationDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required ValueChanged<DateTime> onDateSelected,
  }) async {
    final effectiveInitialDate =
        initialDate.isBefore(firstDate) ? firstDate : initialDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: effectiveInitialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Widget _buildCustomerList() {
    if (_filteredCustomers.isEmpty && _customerSearchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No customers found',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final displayCustomers =
        List<CustomerListModelData>.from(_filteredCustomers);
    if (_localSelectedCustomer != null) {
      displayCustomers.removeWhere((c) => c.id == _localSelectedCustomer!.id);
      displayCustomers.insert(0, _localSelectedCustomer!);
    }
    final clampedIndex = displayCustomers.isEmpty
        ? 0
        : _focusedCustomerIndex.clamp(0, displayCustomers.length - 1).toInt();
    final showCustomerType = Provider.of<AppSettingsProvider>(context)
            .appSettings
            ?.companyB2BEnabled ??
        false;

    return Focus(
      focusNode: _customerListFocusNode,
      onFocusChange: (focused) {
        if (focused) {
          setState(() {
            _focusedCustomerIndex = 0;
          });
        }
      },
      onKeyEvent: (node, event) =>
          _handleCustomerListKey(event, displayCustomers),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _customerGridColumns,
          mainAxisSpacing: _isDenseCheckout ? 5 : 6,
          crossAxisSpacing: _isDenseCheckout ? 5 : 6,
          childAspectRatio: _isDenseCheckout ? 3.95 : 3.6,
        ),
        itemCount: displayCustomers.length,
        itemBuilder: (context, index) {
          final customer = displayCustomers[index];
          final isSelected = _localSelectedCustomer?.id == customer.id;
          final isKeyboardFocused =
              _customerListFocusNode.hasFocus && index == clampedIndex;
          final balance = customer.balance ?? 0.0;
          final balanceColor =
              balance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleCustomerSelection(customer),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: _isDenseCheckout ? 7 : 8,
                  vertical: _isDenseCheckout ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB).withOpacity(0.1)
                      : Colors.white,
                  border: Border.all(
                    color: isKeyboardFocused
                        ? const Color(0xFFF59E0B)
                        : (isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade200),
                    width: (isKeyboardFocused || isSelected) ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: _isDenseCheckout ? 24 : 28,
                      height: _isDenseCheckout ? 24 : 28,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _initialForName(customer.name),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: _isDenseCheckout ? 6 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer.name ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: _isDenseCheckout ? 10 : 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (showCustomerType) ...[
                                const SizedBox(width: 4),
                                _buildCustomerTypeBadge(
                                  customer.customerType,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                          if (customer.phone != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    customer.phone!,
                                    style: TextStyle(
                                        fontSize: _isDenseCheckout ? 9 : 10,
                                        color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: balanceColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      balance.toStringAsFixed(2),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: balanceColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xFF2563EB),
                        size: _isDenseCheckout ? 18 : 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handles arrow keys + Enter/Space inside the customer grid. Mirrors the
  /// pattern used by `HorizontalSavedOrdersView._handleOrdersGridKey`.
  KeyEventResult _handleCustomerListKey(
      KeyEvent event, List<CustomerListModelData> customers) {
    if (event is! KeyDownEvent || customers.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.tab) {
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      final currentIndex =
          _focusedCustomerIndex.clamp(0, customers.length - 1).toInt();

      if (isShiftPressed) {
        if (currentIndex == 0) return KeyEventResult.ignored;
        setState(() {
          _focusedCustomerIndex = currentIndex - 1;
        });
      } else {
        if (currentIndex >= customers.length - 1) {
          return KeyEventResult.ignored;
        }
        setState(() {
          _focusedCustomerIndex = currentIndex + 1;
        });
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final index =
          _focusedCustomerIndex.clamp(0, customers.length - 1).toInt();
      _handleCustomerSelection(customers[index]);
      return KeyEventResult.handled;
    }

    int? delta;
    if (key == LogicalKeyboardKey.arrowRight) {
      delta = 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      delta = -1;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      delta = _customerGridColumns;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      delta = -_customerGridColumns;
    }

    if (delta == null) return KeyEventResult.ignored;

    setState(() {
      _focusedCustomerIndex = (_focusedCustomerIndex + delta!)
          .clamp(0, customers.length - 1)
          .toInt();
    });
    return KeyEventResult.handled;
  }

  Widget _buildCustomerTypeBadge(String? customerType, {bool compact = false}) {
    final type = (customerType == null || customerType.trim().isEmpty)
        ? 'B2C'
        : customerType.trim().toUpperCase();
    final isB2B = type == 'B2B';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: isB2B ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isB2B ? Colors.green.shade300 : Colors.blue.shade300,
        ),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: isB2B ? Colors.green.shade700 : Colors.blue.shade700,
        ),
      ),
    );
  }

  // --- STEP 1.5: DELIVERY ---
  Widget _buildDeliveryStep() {
    Size size = MediaQuery.of(context).size;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(_checkoutPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Delivery Options
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Consumer<DeliveryMethodsProvider>(
                        builder: (context, provider, child) {
                          final appSettings = Provider.of<AppSettingsProvider>(
                                  context,
                                  listen: false)
                              .appSettings;
                          final isDeliveryChargeDataEnabled =
                              appSettings?.freeDeliveryEnabled ?? false;
                          final currency = appSettings?.currency ?? 'SAR';
                          final minimumAmount = double.tryParse(appSettings
                                      ?.freeDeliveryMinimumAmount
                                      .trim() ??
                                  '') ??
                              0.0;
                          final localProductProvider =
                              Provider.of<LocalProductProvider>(context,
                                  listen: false);
                          final netAmount =
                              localProductProvider.priceSummary?.netTotal ??
                                  widget.cartTotal;
                          final shouldApplyDeliveryCharge =
                              isDeliveryChargeDataEnabled &&
                                  (minimumAmount <= 0
                                      ? true
                                      : netAmount < minimumAmount);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'delivery.delivery_methods'.tr,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s16,
                                  0.21,
                                  ColorManager.kPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Arrow keys navigate between delivery method
                              // tiles via Flutter's built-in focus traversal.
                              // Tab/Shift+Tab also work via FocusTraversalOrder.
                              Shortcuts(
                                shortcuts: const <ShortcutActivator, Intent>{
                                  SingleActivator(LogicalKeyboardKey.arrowLeft):
                                      PreviousFocusIntent(),
                                  SingleActivator(
                                          LogicalKeyboardKey.arrowRight):
                                      NextFocusIntent(),
                                  SingleActivator(LogicalKeyboardKey.arrowUp):
                                      PreviousFocusIntent(),
                                  SingleActivator(LogicalKeyboardKey.arrowDown):
                                      NextFocusIntent(),
                                },
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children:
                                      provider.deliveryMethods.map((method) {
                                    final methodIndex = provider.deliveryMethods
                                        .indexOf(method);
                                    final isSelected =
                                        _lDeliveryMethod == method.name;
                                    final isFocused =
                                        _focusedDeliveryMethodName ==
                                            method.name;
                                    return FocusTraversalOrder(
                                      order: NumericFocusOrder(
                                          10 + methodIndex.toDouble()),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                          focusNode:
                                              _deliveryMethodFocusNodeFor(
                                                  method),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onFocusChange: (focused) {
                                            setState(() {
                                              _focusedDeliveryMethodName =
                                                  focused ? method.name : null;
                                            });
                                            if (focused &&
                                                _lDeliveryMethod !=
                                                    method.name) {
                                              _selectDeliveryMethod(
                                                method,
                                                shouldApplyDeliveryCharge:
                                                    shouldApplyDeliveryCharge,
                                              );
                                            }
                                          },
                                          onTap: () {
                                            _selectDeliveryMethod(
                                              method,
                                              shouldApplyDeliveryCharge:
                                                  shouldApplyDeliveryCharge,
                                            );
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            width: 118,
                                            height: 104,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? ColorManager.kPrimaryColor
                                                      .withOpacity(0.05)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isFocused
                                                    ? Colors.orange
                                                    : isSelected
                                                        ? ColorManager
                                                            .kPrimaryColor
                                                        : Colors.grey.shade200,
                                                width: isFocused
                                                    ? 3
                                                    : (isSelected ? 2 : 1),
                                              ),
                                              boxShadow: isFocused
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.orange
                                                            .withOpacity(0.35),
                                                        blurRadius: 8,
                                                        spreadRadius: 1,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  method.name ==
                                                          "Store Takeaway"
                                                      ? Icons.store
                                                      : method.name ==
                                                              "Car Delivery"
                                                          ? Icons.car_rental
                                                          : method.name ==
                                                                  "Door Delivery"
                                                              ? Icons
                                                                  .doorbell_outlined
                                                              : Icons
                                                                  .local_shipping,
                                                  size: 22,
                                                  color: isSelected
                                                      ? ColorManager
                                                          .kPrimaryColor
                                                      : Colors.grey.shade700,
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  method.name.tr,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: buildCustomStyle(
                                                    isSelected
                                                        ? FontWeightManager
                                                            .semiBold
                                                        : FontWeightManager
                                                            .medium,
                                                    FontSize.s11,
                                                    0.0,
                                                    isSelected
                                                        ? ColorManager
                                                            .kPrimaryColor
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                if (isDeliveryChargeDataEnabled) ...[
                                                  const SizedBox(height: 5),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF059669)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Text(
                                                      method.prices
                                                                  .isNotEmpty &&
                                                              shouldApplyDeliveryCharge
                                                          ? (() {
                                                              if (!isSelected) {
                                                                return '$currency ${method.basePrice?.toStringAsFixed(2) ?? '0.00'}';
                                                              }

                                                              final selectedById = method
                                                                  .prices
                                                                  .where((p) =>
                                                                      p.id ==
                                                                      _selectedDeliveryPriceId)
                                                                  .toList();
                                                              if (selectedById
                                                                  .isNotEmpty) {
                                                                return '$currency ${selectedById.first.price.toStringAsFixed(2)}';
                                                              }

                                                              if (_selectedDeliveryCharge !=
                                                                  null) {
                                                                return '$currency ${_selectedDeliveryCharge!.toStringAsFixed(2)}';
                                                              }

                                                              return '$currency ${method.basePrice?.toStringAsFixed(2) ?? '0.00'}';
                                                            })()
                                                          : 'free'.tr,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .semiBold,
                                                        FontSize.s9,
                                                        0.0,
                                                        const Color(0xFF059669),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              if (_lDeliveryMethod.isNotEmpty &&
                                  isDeliveryChargeDataEnabled) ...[
                                const SizedBox(height: 12),
                                Builder(builder: (context) {
                                  DeliveryMethod? selectedMethod;
                                  for (final method
                                      in provider.deliveryMethods) {
                                    if (method.name == _lDeliveryMethod) {
                                      selectedMethod = method;
                                      break;
                                    }
                                  }

                                  final selectedDeliveryMethod = selectedMethod;

                                  if (selectedDeliveryMethod == null ||
                                      selectedDeliveryMethod.prices.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  if (!shouldApplyDeliveryCharge) {
                                    return Text(
                                      minimumAmount > 0
                                          ? 'Free delivery applied for orders above $currency ${minimumAmount.toStringAsFixed(2)}'
                                          : 'free'.tr,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s11,
                                        0.12,
                                        const Color(0xFF059669),
                                      ),
                                    );
                                  }

                                  final effectiveSelectedPriceId = (() {
                                    if (_selectedDeliveryPriceId != null) {
                                      final exists = selectedDeliveryMethod
                                          .prices
                                          .any((p) =>
                                              p.id == _selectedDeliveryPriceId);
                                      if (exists)
                                        return _selectedDeliveryPriceId!;
                                    }

                                    if (_selectedDeliveryCharge != null) {
                                      for (final price
                                          in selectedDeliveryMethod.prices) {
                                        if ((price.price -
                                                    _selectedDeliveryCharge!)
                                                .abs() <
                                            0.001) {
                                          return price.id;
                                        }
                                      }
                                    }

                                    return selectedDeliveryMethod
                                        .prices.first.id;
                                  })();

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Delivery charges',
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.12,
                                          Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: selectedDeliveryMethod.prices
                                            .map((price) {
                                          final isPriceSelected = price.id ==
                                              effectiveSelectedPriceId;

                                          return OutlinedButton(
                                            onPressed: () {
                                              setState(() {
                                                _selectedDeliveryPriceId =
                                                    price.id;
                                                _selectedDeliveryCharge =
                                                    price.price;
                                              });
                                              _handleDeliveryUpdate();
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: isPriceSelected
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF059669),
                                                width:
                                                    isPriceSelected ? 2 : 1.5,
                                              ),
                                              backgroundColor: isPriceSelected
                                                  ? const Color(0xFF059669)
                                                  : Colors.white,
                                              foregroundColor: isPriceSelected
                                                  ? Colors.white
                                                  : const Color(0xFF059669),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                              minimumSize: const Size(0, 44),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  const VisualDensity(
                                                      horizontal: 0,
                                                      vertical: 0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: Text(
                                              '$currency ${price.price.toStringAsFixed(2)}',
                                              style: buildCustomStyle(
                                                FontWeightManager.bold,
                                                FontSize.s12,
                                                0.0,
                                                isPriceSelected
                                                    ? Colors.white
                                                    : const Color(0xFF059669),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                              if (Provider.of<AppSettingsProvider>(context,
                                          listen: false)
                                      .appSettings
                                      ?.askDeliveryDate ==
                                  true) ...[
                                const SizedBox(height: 20),
                                Text('billing.enter_car_number'.tr,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.12,
                                        Colors.black)),
                                CalendarPickerTableCell(
                                  initialDate: _lSelectedDeliveryDate,
                                  onDateSelected: (date) {
                                    setState(() {
                                      _lSelectedDeliveryDate = date;
                                    });
                                    _handleDeliveryUpdate();
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text('common.select'.tr,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.12,
                                        Colors.black)),
                                TimePickerTableCell(
                                  initialTime: _lSelectedDeliveryTime,
                                  onTimeSelected: (time) {
                                    setState(() {
                                      _lSelectedDeliveryTime = time;
                                    });
                                    _handleDeliveryUpdate();
                                  },
                                ),
                              ],
                              const SizedBox(height: 30),
                              if (_lDeliveryMethod == "Car Delivery") ...[
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(60),
                                  child: buildColumnWidgetForTextFields(
                                    controller: _lCarNumberController,
                                    focusNode: _deliveryCarNumberFocusNode,
                                    size: size,
                                    height: 50,
                                    hintText: 'Car Number:',
                                    width: double.infinity,
                                    margin: EdgeInsets.zero,
                                    onTap: () {
                                      Provider.of<KeyboardProvider>(context,
                                              listen: false)
                                          .show('text', _lCarNumberController,
                                              replaceOnFirstInput: true);
                                    },
                                    onchanged: (_) => _handleDeliveryUpdate(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(70),
                                child: buildColumnWidgetForTextFields(
                                  controller: _lCommentController,
                                  focusNode: _deliveryCommentFocusNode,
                                  size: size,
                                  height: 50,
                                  hintText: 'Comment:',
                                  width: double.infinity,
                                  margin: EdgeInsets.zero,
                                  onTap: () {
                                    Provider.of<KeyboardProvider>(context,
                                            listen: false)
                                        .show('text', _lCommentController,
                                            replaceOnFirstInput: true);
                                  },
                                  onchanged: (_) => _handleDeliveryUpdate(),
                                ),
                              ),
                              if (_lDeliveryMethod == "Door Delivery") ...[
                                const SizedBox(height: 10),
                                Consumer<CustomerSelectionProvider>(
                                  builder: (context, customerProvider, child) {
                                    if (!customerProvider.hasSelectedCustomer ||
                                        customerProvider
                                                .selectedCustomer!.addresses ==
                                            null ||
                                        customerProvider.selectedCustomer!
                                            .addresses!.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Choose an address:',
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.12,
                                            Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: customerProvider
                                              .selectedCustomer!.addresses!
                                              .map((Address address) {
                                            return Material(
                                              color: Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () {
                                                  setState(() {
                                                    String fullAddress =
                                                        "${address.address}, ${address.city}";
                                                    _lAddressController.text =
                                                        fullAddress;
                                                  });
                                                  _handleDeliveryUpdate();
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    color: Colors.grey.shade50,
                                                  ),
                                                  child: Text(
                                                    "${address.address}, ${address.city}",
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.regular,
                                                      FontSize.s12,
                                                      0.12,
                                                      Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(90),
                                  child: buildColumnWidgetForTextFields(
                                    controller: _lAddressController,
                                    focusNode: _deliveryAddressFocusNode,
                                    size: size,
                                    height: 50,
                                    hintText: 'Address:',
                                    width: double.infinity,
                                    margin: EdgeInsets.zero,
                                    onTap: () {
                                      Provider.of<KeyboardProvider>(context,
                                              listen: false)
                                          .show('text', _lAddressController,
                                              replaceOnFirstInput: true);
                                    },
                                    onchanged: (_) => _handleDeliveryUpdate(),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: _checkoutGap),
                  const VerticalDivider(width: 1),
                  SizedBox(width: _checkoutGap),
                  // Right: Summary
                  Expanded(
                    flex: 2,
                    child: _isSelectionOnly
                        ? _buildSelectionOnlySidePanel(
                            icon: Icons.local_shipping,
                            title: 'Selected Delivery',
                            value: _lDeliveryMethod.isNotEmpty
                                ? _lDeliveryMethod
                                : 'Not selected',
                            supportingText: _lDeliveryMethodId.isNotEmpty
                                ? 'Method ID: $_lDeliveryMethodId'
                                : null,
                            canDone: _lDeliveryMethodId.isNotEmpty ||
                                _lDeliveryMethod.isNotEmpty,
                          )
                        : Column(
                            children: [
                              Expanded(child: _buildCompactSummary()),
                              _buildFooter(
                                onPrint: _handlePrint,
                                onConfirm: _handleConfirm,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: DISCOUNT ---
  Widget _buildDiscountStep() {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(_checkoutPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Discount Options
                  Expanded(
                    flex: 3,
                    child: RestaurantCouponModalWrapper(
                      orderSubTotal: widget.cartTotal,
                      initialCouponCode: _localCouponCode,
                      initialFlatDiscount: _localFlatDiscount,
                      initialPercentageDiscount: _localPercentageDiscount,
                      isCouponApplied: _localIsCouponApplied,
                      showAsDialog: false,
                      showSkipButton: !widget.isQuotationMode,
                      onSkip: () => _goToStep(3),
                      showShadow: false,
                      fullWidth: true,
                      onCouponAction: (code, applied,
                          {flatDiscount, percentageDiscount}) {
                        final newFlatDiscount = flatDiscount ?? 0.0;
                        final newPercentageDiscount = percentageDiscount ?? 0.0;
                        final oldDiscountAmount = _localFlatDiscount +
                            (widget.cartTotal * _localPercentageDiscount / 100);
                        final oldEffectiveTotal =
                            widget.cartTotal - oldDiscountAmount;
                        final newDiscountAmount = newFlatDiscount +
                            (widget.cartTotal * newPercentageDiscount / 100);
                        final newEffectiveTotal =
                            widget.cartTotal - newDiscountAmount;

                        final remapped =
                            PaymentAutoFillHelper.remapAmountsAfterDiscount(
                          isCashSelected: _lIsCashSelected,
                          isCardSelected: _lIsCardSelected,
                          isUpiSelected: _lIsUpiSelected,
                          isCodSelected: _lIsCodSelected,
                          cashAmount: _lCashAmount,
                          cardAmount: _lCardAmount,
                          upiAmount: _lUpiAmount,
                          codAmount: _lCodAmount,
                          oldEffectiveTotal: oldEffectiveTotal,
                          newEffectiveTotal: newEffectiveTotal,
                        );

                        _handleDiscountUpdate(code, applied, newFlatDiscount,
                            newPercentageDiscount);

                        if (remapped.cash != _lCashAmount ||
                            remapped.card != _lCardAmount ||
                            remapped.upi != _lUpiAmount ||
                            remapped.cod != _lCodAmount) {
                          _handlePaymentUpdate(
                              _lIsCashSelected,
                              _lIsCardSelected,
                              _lIsUpiSelected,
                              _lIsCodSelected,
                              _lIsDebitSelected,
                              remapped.cash,
                              remapped.card,
                              remapped.upi,
                              remapped.cod,
                              _lDebitAmount,
                              _lTransactionNumber,
                              _lToCustomerCreditEnabled,
                              cashMethodId: widget.cashMethodId,
                              cardMethodId: widget.cardMethodId,
                              upiMethodId: widget.upiMethodId,
                              codMethodId: widget.codMethodId);
                        }

                        _nextStep();
                      },
                    ),
                  ),
                  SizedBox(width: _checkoutGap),
                  const VerticalDivider(width: 1),
                  SizedBox(width: _checkoutGap),
                  // Right: Summary
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(child: _buildCompactSummary()),
                        _buildFooter(
                          onPrint: _handlePrint,
                          onConfirm: _handleConfirm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: PAYMENT ---
  Widget _buildPaymentStep() {
    final discountAmount = _localFlatDiscount +
        (widget.cartTotal * _localPercentageDiscount / 100);
    final effectiveTotal =
        (widget.cartTotal - discountAmount) + _getEffectiveDeliveryCharge();

    final bool anyMethodSelected = _lIsCashSelected ||
        _lIsCardSelected ||
        _lIsUpiSelected ||
        _lIsCodSelected;
    final double totalPaid = (double.tryParse(_lCashAmount) ?? 0) +
        (double.tryParse(_lCardAmount) ?? 0) +
        (double.tryParse(_lUpiAmount) ?? 0) +
        (double.tryParse(_lCodAmount) ?? 0);

    final bool needsAutoFill = !anyMethodSelected || totalPaid == 0;

    final bool shouldAutoFillCash =
        (!anyMethodSelected && _lCashAmount.isEmpty) ||
            (_lIsCashSelected && totalPaid == 0);
    final bool shouldAutoFillCard =
        _lIsCardSelected && totalPaid == 0 && !shouldAutoFillCash;
    final bool shouldAutoFillUpi = _lIsUpiSelected &&
        totalPaid == 0 &&
        !shouldAutoFillCash &&
        !shouldAutoFillCard;
    final bool shouldAutoFillCod = _lIsCodSelected &&
        totalPaid == 0 &&
        !shouldAutoFillCash &&
        !shouldAutoFillCard &&
        !shouldAutoFillUpi;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(_checkoutPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Payment Options
                  Expanded(
                    flex: 3,
                    child: PaymentMethodModal(
                      initialIsCashSelected:
                          shouldAutoFillCash ? true : _lIsCashSelected,
                      initialIsCardSelected:
                          shouldAutoFillCard ? true : _lIsCardSelected,
                      initialIsUpiSelected:
                          shouldAutoFillUpi ? true : _lIsUpiSelected,
                      initialIsCodSelected:
                          shouldAutoFillCod ? true : _lIsCodSelected,
                      initialIsDebitSelected: _lIsDebitSelected,
                      initialCashAmount: shouldAutoFillCash
                          ? effectiveTotal.toStringAsFixed(2)
                          : _lCashAmount,
                      initialCardAmount: shouldAutoFillCard
                          ? effectiveTotal.toStringAsFixed(2)
                          : _lCardAmount,
                      initialUpiAmount: shouldAutoFillUpi
                          ? effectiveTotal.toStringAsFixed(2)
                          : _lUpiAmount,
                      initialCodAmount: shouldAutoFillCod
                          ? effectiveTotal.toStringAsFixed(2)
                          : _lCodAmount,
                      initialDebitAmount: _lDebitAmount,
                      initialTransactionNumber: _lTransactionNumber,
                      cartTotal: effectiveTotal,
                      customerPrevBalance:
                          _localSelectedCustomer?.balance ?? 0.0,
                      isDefaultCustomer: Provider.of<CustomerSelectionProvider>(
                              context,
                              listen: false)
                          .isDefaultCustomer,
                      customButtonTitle: "Confirm Payment Selection",
                      closeOnApply: false,
                      showConfirmButton: false,
                      showAsDialog: false,
                      showShadow: false,
                      fullWidth: true,
                      onPaymentMethodSelected: (isCash, isCard, isUpi, isCod,
                          isDebit, cash, card, upi, cod, debit, trans, toCredit,
                          {cashMethodId,
                          cardMethodId,
                          upiMethodId,
                          codMethodId}) {
                        _handlePaymentUpdate(
                            isCash,
                            isCard,
                            isUpi,
                            isCod,
                            isDebit,
                            cash,
                            card,
                            upi,
                            cod,
                            debit,
                            trans,
                            toCredit,
                            cashMethodId: cashMethodId,
                            cardMethodId: cardMethodId,
                            upiMethodId: upiMethodId,
                            codMethodId: codMethodId);
                        _nextStep();
                      },
                    ),
                  ),
                  SizedBox(width: _checkoutGap),
                  const VerticalDivider(width: 1),
                  SizedBox(width: _checkoutGap),
                  // Right: Summary
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(child: _buildCompactSummary()),
                        _buildFooter(
                          onPrint: _handlePrint,
                          onConfirm: _handleConfirm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleConfirm() async {
    if (_isConfirming) return;
    _syncQuotationInlineCustomer();
    setState(() => _isConfirming = true);
    try {
      await widget.onConfirmOrder();
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _handlePrint() async {
    if (_isPrinting) return;
    _syncQuotationInlineCustomer();
    setState(() => _isPrinting = true);
    try {
      await widget.onConfirmAndPrint();
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _syncQuotationInlineCustomer() {
    if (!widget.isQuotationMode) return;
    final name = _quotationCustomerNameController.text.trim();
    final phone = _quotationCustomerPhoneController.text.trim();
    if (name.isEmpty) return;

    final inlineCustomer = CustomerListModelData(
      name: name,
      phone: phone.isEmpty ? null : phone,
      customerType: 'new',
      balance: 0,
    );
    _localSelectedCustomer = inlineCustomer;
    widget.onCustomerSelected(inlineCustomer);
  }

  Widget _buildSummaryRow(String label, double amount, Color color,
      {bool isBold = false, bool large = false, Color? labelColor}) {
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'SAR';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: large
                  ? (_isDenseCheckout ? 15 : 16)
                  : (_isDenseCheckout ? 13 : 14),
              color: labelColor ?? (isBold ? Colors.black : Colors.black87),
            )),
        Text(
            '${amount < 0 ? "-" : ""}$currency ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: large
                    ? (_isDenseCheckout ? 17 : 18)
                    : (_isDenseCheckout ? 13 : 14),
                color: color)),
      ],
    );
  }

  Widget _buildDeliveryChargeRow() {
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'SAR';

    final effectiveDeliveryCharge = _getEffectiveDeliveryCharge();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Delivery Charge',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: _isDenseCheckout ? 13 : 14,
              color: Colors.black87,
            )),
        Text('$currency ${effectiveDeliveryCharge.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: _isDenseCheckout ? 13 : 14,
                color: effectiveDeliveryCharge > 0
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF059669))),
      ],
    );
  }

  bool _hasPaymentMethod() {
    return _lIsCashSelected ||
        _lIsCardSelected ||
        _lIsUpiSelected ||
        _lIsCodSelected ||
        _lIsDebitSelected;
  }

  // Check if Confirm button should be enabled
  bool get _canConfirmOrPrint {
    if (widget.isQuotationMode) {
      return _hasQuotationCustomer &&
          !_lQuotationExpiryDate.isBefore(_lQuotationDate);
    }

    if (!widget.requireCheckoutCompletion) {
      return true;
    }

    if (_hasQuoteOnlyCustomerNeedingSave) {
      return false;
    }

    return _localSelectedCustomer != null &&
        _hasOpenedPaymentModalOnce &&
        _hasPaymentMethod();
  }

  // Check if Print button should be enabled (always requires payment tab visited)
  bool get _canPrint {
    if (widget.isQuotationMode) {
      return _canConfirmOrPrint;
    }

    if (_hasQuoteOnlyCustomerNeedingSave) {
      return false;
    }

    return _localSelectedCustomer != null &&
        _hasOpenedPaymentModalOnce &&
        _hasPaymentMethod();
  }

  String _disabledActionMessage() {
    if (widget.isQuotationMode) {
      if (!_hasQuotationCustomer) {
        return 'Please select a customer before creating quotation';
      }
      if (_lQuotationExpiryDate.isBefore(_lQuotationDate)) {
        return 'Expiry date cannot be before quotation date';
      }
      return 'Unable to create quotation';
    }
    if (_hasQuoteOnlyCustomerNeedingSave) {
      return 'Create or select a saved customer before confirming';
    }
    return widget.requireCheckoutCompletion
        ? 'Please configure payment before confirm'
        : 'Unable to proceed';
  }

  bool get _hasQuotationCustomer {
    final customer = _localSelectedCustomer;
    if (customer?.id != null) return true;
    return _hasInlineQuotationCustomer;
  }

  bool get _hasInlineQuotationCustomer {
    return _quotationCustomerNameController.text.trim().isNotEmpty;
  }

  String get _quotationCustomerDisplayName {
    if (_hasInlineQuotationCustomer) {
      return _quotationCustomerNameController.text.trim();
    }
    return _localSelectedCustomer?.name ?? 'Not Selected';
  }

  String? _selectedCustomerSupportingText() {
    final customer = _localSelectedCustomer;
    if (customer == null) return null;

    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'SAR';
    final lines = <String>[];
    final phone = customer.phone?.trim();

    if (phone != null && phone.isNotEmpty) {
      lines.add(phone);
    }
    lines.add(
        'Balance: $currency ${(customer.balance ?? 0.0).toStringAsFixed(2)}');

    return lines.join('\n');
  }

  Widget _buildSelectionOnlySidePanel({
    required IconData icon,
    required String title,
    required String value,
    String? supportingText,
    required bool canDone,
  }) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (supportingText != null &&
                    supportingText.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    supportingText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _closeSelectionOnlyModal,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: canDone ? _closeSelectionOnlyModal : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter({
    VoidCallback? onBack,
    VoidCallback? onNext,
    String nextLabel = 'Next',
    bool isNextEnabled = true,
    VoidCallback? onPrint,
    VoidCallback? onConfirm,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        _isDenseCheckout ? 8 : 12,
        widget.isQuotationMode ? 0 : (_isDenseCheckout ? 8 : 12),
        _isDenseCheckout ? 8 : 12,
        0,
      ),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                Expanded(
                  child: CustomRoundButtonWithIconAdvanced(
                    title: 'Back',
                    fct: onBack,
                    size: MediaQuery.of(context).size,
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                    height: _isDenseCheckout ? 44 : 48,
                    width: double.infinity,
                    fontSize: _isDenseCheckout ? FontSize.s12 : FontSize.s14,
                    boxColor: const Color(0xFF64748B),
                    borderColor: const Color(0xFF64748B),
                    radius: 12,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Confirm button (optional)
              if (onConfirm != null)
                Expanded(
                  child: Opacity(
                    opacity: _canConfirmOrPrint ? 1.0 : 0.5,
                    child: CustomRoundButtonWithIconAdvanced(
                      title: widget.confirmButtonTitle,
                      isLoading: _isConfirming,
                      shortcutLabel: 'F2',
                      fct: _canConfirmOrPrint
                          ? onConfirm
                          : () {
                              // Auto-navigate to payment tab and show feedback
                              if (!widget.isQuotationMode) {
                                _goToStep(3);
                              }
                              showScaffoldError(
                                context: context,
                                message: _disabledActionMessage(),
                              );
                            },
                      size: MediaQuery.of(context).size,
                      icon: const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                      height: _isDenseCheckout ? 44 : 48,
                      width: double.infinity,
                      fontSize: _isDenseCheckout ? FontSize.s12 : FontSize.s14,
                      boxColor: _canConfirmOrPrint
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade400,
                      borderColor: _canConfirmOrPrint
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade400,
                      radius: 12,
                    ),
                  ),
                ),
              if (onConfirm != null && onPrint != null)
                const SizedBox(width: 12),
              // Print Bill button (optional)
              if (onPrint != null)
                Expanded(
                  child: Opacity(
                    opacity: _canPrint ? 1.0 : 0.5,
                    child: CustomRoundButtonWithIconAdvanced(
                      title: widget.printButtonTitle,
                      isLoading: _isPrinting,
                      shortcutLabel: 'F6',
                      fct: _canPrint
                          ? onPrint
                          : () {
                              // Auto-navigate to payment tab and show feedback
                              if (!widget.isQuotationMode) {
                                _goToStep(3);
                              }
                              showScaffoldError(
                                context: context,
                                message: widget.isQuotationMode
                                    ? _disabledActionMessage()
                                    : 'Please configure payment before printing',
                              );
                            },
                      size: MediaQuery.of(context).size,
                      icon: const Icon(Icons.print,
                          color: Colors.white, size: 20),
                      height: _isDenseCheckout ? 44 : 48,
                      width: double.infinity,
                      fontSize: _isDenseCheckout ? FontSize.s12 : FontSize.s14,
                      boxColor: _canPrint
                          ? const Color(0xFF059669)
                          : Colors.grey.shade400,
                      borderColor: _canPrint
                          ? const Color(0xFF059669)
                          : Colors.grey.shade400,
                      textColor: Colors.white,
                      radius: 12,
                    ),
                  ),
                ),
              // Next button (optional)
              if (onNext != null)
                Expanded(
                  child: CustomRoundButtonWithIconAdvanced(
                    title: nextLabel,
                    fct: isNextEnabled ? onNext : () {},
                    size: MediaQuery.of(context).size,
                    icon: const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 20),
                    height: _isDenseCheckout ? 44 : 48,
                    width: double.infinity,
                    fontSize: _isDenseCheckout ? FontSize.s12 : FontSize.s14,
                    boxColor: isNextEnabled
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade400,
                    borderColor: isNextEnabled
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade400,
                    radius: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Compact summary widget shown on right side of all steps
  Widget _buildCompactSummary() {
    return Consumer2<LocalProductProvider, AppSettingsProvider>(
      builder: (context, localProductProvider, appSettingsProvider, child) {
        final priceSummary = localProductProvider.priceSummary;
        if (priceSummary == null) return const SizedBox.shrink();

        // Use the provider's totals directly for accuracy and consistency
        final subTotal = priceSummary.originalSubTotal;
        final discountAmount = priceSummary.discount;
        final taxAmount = priceSummary.totalTax;

        // Final effective total (rounded if enabled)
        final baseEffectiveTotal =
            appSettingsProvider.appSettings?.priceRoundOff == true
                ? AmountHelper.roundOffAmount(priceSummary.netTotal)
                : priceSummary.netTotal;
        final effectiveTotal =
            baseEffectiveTotal + _getEffectiveDeliveryCharge();

        final totalPaid = (double.tryParse(_lCashAmount) ?? 0) +
            (double.tryParse(_lCardAmount) ?? 0) +
            (double.tryParse(_lUpiAmount) ?? 0) +
            (double.tryParse(_lCodAmount) ?? 0);

        final prevBalance = _localSelectedCustomer?.balance ?? 0.0;
        final creditAmount = double.tryParse(_lDebitAmount) ?? 0.0;

        // Match PaymentMethodModal logic for change calculation
        double rawBalance = 0.0;
        if (prevBalance < 0) {
          // Customer owes money
          final transactionExcess = totalPaid - effectiveTotal;
          rawBalance = transactionExcess - creditAmount;
        } else {
          // Customer has credit or zero balance
          final netDue = effectiveTotal - prevBalance;
          rawBalance = totalPaid - netDue - creditAmount;
        }

        final displayBalance = rawBalance < 0 ? 0.0 : rawBalance;

        final bool hasCustomer = widget.isQuotationMode
            ? _hasQuotationCustomer
            : _localSelectedCustomer != null &&
                !_hasQuoteOnlyCustomerNeedingSave;
        final bool hasPayment = !widget.isQuotationMode && _hasPaymentMethod();
        final bool hasDiscount = _localIsCouponApplied ||
            _localFlatDiscount > 0 ||
            _localPercentageDiscount > 0;
        final bool hasDelivery = _lDeliveryMethod.isNotEmpty;

        return Column(
          children: [
            // Status Checklist (clickable to navigate)
            LayoutBuilder(builder: (context, constraints) {
              final tileSpacing = _isDenseCheckout ? 8.0 : 10.0;
              final tileWidth = (constraints.maxWidth - tileSpacing) / 2;
              final tileHeight = _isDenseCheckout ? 72.0 : 92.0;
              final tiles = <Widget>[
                _buildClickableCheckItem(
                  'Customer',
                  _hasQuoteOnlyCustomerNeedingSave
                      ? 'Create customer'
                      : widget.isQuotationMode
                          ? _quotationCustomerDisplayName
                          : (_localSelectedCustomer?.name ?? 'Not Selected'),
                  hasCustomer,
                  Icons.person_outline,
                  0,
                  customer: _localSelectedCustomer,
                ),
                if (widget.enableDelivery)
                  _buildClickableCheckItem(
                    'Delivery',
                    _lDeliveryMethod,
                    hasDelivery,
                    Icons.local_shipping_outlined,
                    1,
                  ),
                _buildClickableCheckItem(
                  'Discount',
                  hasDiscount
                      ? (_localPercentageDiscount > 0
                          ? '${_localPercentageDiscount.toStringAsFixed(0)}%'
                          : _localFlatDiscount.toStringAsFixed(2))
                      : 'Not Applied',
                  hasDiscount,
                  Icons.discount_outlined,
                  2,
                ),
                if (!widget.isQuotationMode)
                  _buildClickableCheckItem(
                    'Payment',
                    _hasPaymentMethod() ? 'Configured' : 'Not Configured',
                    hasPayment,
                    Icons.payment_outlined,
                    3,
                  ),
              ];

              return Wrap(
                spacing: tileSpacing,
                runSpacing: tileSpacing,
                children: tiles
                    .map(
                      (tile) => SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            }),
            SizedBox(height: _isDenseCheckout ? 10 : 16),
            // Order Summary
            Flexible(
              fit: widget.isQuotationMode ? FlexFit.loose : FlexFit.tight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isDenseCheckout ? 14 : 20,
                      vertical: _isDenseCheckout ? 14 : 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        primary: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: _isDenseCheckout ? 16 : 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: _isDenseCheckout ? 8 : 12),
                            _buildSummaryRow(
                                'Net Amount', subTotal, Colors.black),
                            SizedBox(height: _isDenseCheckout ? 7 : 10),
                            _buildSummaryRow('Discount', -discountAmount,
                                const Color(0xFFEF4444),
                                labelColor: const Color(0xFFEF4444)),
                            SizedBox(height: _isDenseCheckout ? 7 : 10),
                            _buildSummaryRow(
                                'Tax', taxAmount, const Color(0xFF64748B),
                                labelColor: const Color(0xFF64748B)),
                            if (hasDelivery &&
                                _isfreeDeliveryMinimumAmount()) ...[
                              SizedBox(height: _isDenseCheckout ? 7 : 10),
                              _buildDeliveryChargeRow(),
                            ],
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: _isDenseCheckout ? 10 : 16),
                              child: Divider(
                                  height: 1,
                                  thickness: 1.5,
                                  color: Color(0xFFF1F5F9)),
                            ),
                            _buildSummaryRow('Total Payable', effectiveTotal,
                                const Color(0xFF2563EB),
                                isBold: true,
                                large: true,
                                labelColor: const Color(0xFF2563EB)),
                            if (_localSelectedCustomer != null) ...[
                              SizedBox(height: _isDenseCheckout ? 7 : 10),
                              _buildSummaryRow(
                                  'Cust. Prev. Balance',
                                  prevBalance,
                                  prevBalance >= 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                  labelColor: prevBalance >= 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626)),
                            ],
                            if (!widget.isQuotationMode) ...[
                              SizedBox(height: _isDenseCheckout ? 7 : 10),
                              _buildSummaryRow(
                                  'Total Paid', totalPaid, Colors.black),
                              SizedBox(height: _isDenseCheckout ? 7 : 10),
                              _buildSummaryRow('Balance', displayBalance,
                                  const Color(0xFF059669),
                                  labelColor: const Color(0xFF059669)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.isQuotationMode) ...[
                    SizedBox(height: _isDenseCheckout ? 10 : 16),
                    _buildQuotationDatesPanel(),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Clickable checklist item that navigates to the corresponding step
  Widget _buildClickableCheckItem(String title, String subtitle,
      bool isCompleted, IconData icon, int stepIndex,
      {CustomerListModelData? customer}) {
    final isCurrentStep = _currentStep == stepIndex;
    final shortcutLabel = _shortcutLabelForStep(stepIndex);
    final showCustomerType = Provider.of<AppSettingsProvider>(context)
            .appSettings
            ?.companyB2BEnabled ??
        false;
    final customerBalance = customer?.balance ?? 0.0;
    final customerBalanceColor = customerBalance >= 0
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);
    final customerNameLength = customer?.name?.trim().length ?? subtitle.length;
    final customerTitleFontSize = customer == null
        ? (_isDenseCheckout ? 12.0 : 14.0)
        : customerNameLength > 24
            ? 10.5
            : customerNameLength > 18
                ? 11.5
                : customerNameLength > 12
                    ? 12.5
                    : 13.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isCurrentStep
            ? const Color(0xFF2563EB)
            : isCompleted
                ? const Color(0xFFF0FDF4)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentStep
              ? const Color(0xFF1D4ED8)
              : isCompleted
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentStep
                ? const Color(0xFF2563EB).withOpacity(0.2)
                : isCompleted
                    ? const Color(0xFF22C55E).withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goToStep(stepIndex),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            height: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: _isDenseCheckout ? 7 : 12,
              horizontal: _isDenseCheckout ? 10 : 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (customer == null) ...[
                  Container(
                    width: _isDenseCheckout ? 28 : 36,
                    height: _isDenseCheckout ? 28 : 36,
                    decoration: BoxDecoration(
                      color: isCurrentStep
                          ? Colors.white.withOpacity(0.15)
                          : isCompleted
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : icon,
                      color: isCurrentStep
                          ? Colors.white
                          : isCompleted
                              ? const Color(0xFF166534)
                              : const Color(0xFF64748B),
                      size: _isDenseCheckout ? 17 : 20,
                    ),
                  ),
                  SizedBox(width: _isDenseCheckout ? 10 : 14),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer != null ? subtitle : title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: customerTitleFontSize,
                          letterSpacing: 0.2,
                          color: isCurrentStep
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (customer == null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: _isDenseCheckout ? 10 : 12,
                            color: isCurrentStep
                                ? Colors.white.withOpacity(0.85)
                                : isCompleted
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                            fontWeight: isCurrentStep
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (customer != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (showCustomerType) ...[
                              _buildCustomerTypeBadge(
                                customer.customerType,
                                compact: true,
                              ),
                              const SizedBox(width: 2),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCurrentStep
                                      ? Colors.white24
                                      : customerBalanceColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Bal: ${customerBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isCurrentStep
                                        ? Colors.white
                                        : customerBalanceColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (shortcutLabel.isNotEmpty) ...[
                  SizedBox(width: _isDenseCheckout ? 5 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isDenseCheckout ? 6 : 8,
                      vertical: _isDenseCheckout ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentStep
                          ? Colors.white.withOpacity(0.18)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrentStep
                            ? Colors.white.withOpacity(0.35)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      shortcutLabel,
                      style: TextStyle(
                        fontSize: _isDenseCheckout ? 10 : 11,
                        fontWeight: FontWeight.w800,
                        color: isCurrentStep
                            ? Colors.white
                            : const Color(0xFF2563EB),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortcutLabelForStep(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return 'F3';
      case 1:
        return 'F4';
      case 2:
        return 'F10';
      case 3:
        return 'F5';
      default:
        return '';
    }
  }
}

// Wrapper for Coupon Modal reuse
class RestaurantCouponModalWrapper extends StatefulWidget {
  final double orderSubTotal;
  final String initialCouponCode;
  final double initialFlatDiscount;
  final double initialPercentageDiscount;
  final bool isCouponApplied;
  final Function(String, bool,
      {double? flatDiscount, double? percentageDiscount}) onCouponAction;
  final bool showAsDialog;
  final bool showSkipButton;
  final VoidCallback? onSkip;
  final bool showShadow;
  final bool fullWidth;

  const RestaurantCouponModalWrapper({
    super.key,
    required this.orderSubTotal,
    required this.initialCouponCode,
    required this.initialFlatDiscount,
    required this.initialPercentageDiscount,
    required this.isCouponApplied,
    required this.onCouponAction,
    this.showAsDialog = true,
    this.showSkipButton = false,
    this.onSkip,
    this.showShadow = true,
    this.fullWidth = false,
  });

  @override
  State<RestaurantCouponModalWrapper> createState() =>
      _RestaurantCouponModalWrapperState();
}

class _RestaurantCouponModalWrapperState
    extends State<RestaurantCouponModalWrapper> {
  late MockLocalProductProvider _mockProvider;

  @override
  void initState() {
    super.initState();
    _mockProvider = MockLocalProductProvider(
      orderSubTotal: widget.orderSubTotal,
      initialFlatDiscount: widget.initialFlatDiscount,
      initialPercentageDiscount: widget.initialPercentageDiscount,
      initialCouponCode: widget.initialCouponCode,
    );
  }

  @override
  void didUpdateWidget(RestaurantCouponModalWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFlatDiscount != oldWidget.initialFlatDiscount ||
        widget.initialPercentageDiscount !=
            oldWidget.initialPercentageDiscount ||
        widget.initialCouponCode != oldWidget.initialCouponCode ||
        widget.orderSubTotal != oldWidget.orderSubTotal) {
      // Update mock provider when props change (handling local state updates from parent)
      _mockProvider.updateValues(
        orderSubTotal: widget.orderSubTotal,
        flatDiscount: widget.initialFlatDiscount,
        percentageDiscount: widget.initialPercentageDiscount,
        couponCode: widget.initialCouponCode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LocalProductProvider>.value(
      value: _mockProvider,
      child: CouponModal(
        subTotal: widget.orderSubTotal,
        initialCouponCode: widget.initialCouponCode,
        initialFlatDiscount: widget.initialFlatDiscount,
        initialPercentageDiscount: widget.initialPercentageDiscount,
        isCouponApplied: widget.isCouponApplied,
        onCouponAction: widget.onCouponAction,
        closeOnApply: false,
        showAsDialog: widget.showAsDialog,
        showSkipButton: widget.showSkipButton,
        onSkip: widget.onSkip,
        showShadow: widget.showShadow,
        fullWidth: widget.fullWidth,
      ),
    );
  }
}

// Mock LocalProductProvider that provides the interface needed by CouponModal
class MockLocalProductProvider extends LocalProductProvider {
  double _orderSubTotal; // Changed from final to mutable
  double _flatDiscount;
  double _percentageDiscount;
  // ignore: unused_field
  String _couponCode;

  MockLocalProductProvider({
    required double orderSubTotal,
    required double initialFlatDiscount,
    required double initialPercentageDiscount,
    required String initialCouponCode,
  })  : _orderSubTotal = orderSubTotal,
        _flatDiscount = initialFlatDiscount,
        _percentageDiscount = initialPercentageDiscount,
        _couponCode = initialCouponCode;

  void updateValues({
    required double orderSubTotal,
    required double flatDiscount,
    required double percentageDiscount,
    required String couponCode,
  }) {
    _orderSubTotal = orderSubTotal;
    _flatDiscount = flatDiscount;
    _percentageDiscount = percentageDiscount;
    _couponCode = couponCode;
    notifyListeners();
  }

  @override
  Map<String, double> getCurrentDiscount() {
    return {
      'flatDiscount': _flatDiscount,
      'percentageDiscount': _percentageDiscount,
    };
  }

  @override
  PriceSummary? get priceSummary {
    final discount =
        (_flatDiscount + (_orderSubTotal * _percentageDiscount / 100));
    return PriceSummary(
      originalSubTotal: _orderSubTotal,
      subTotal: _orderSubTotal,
      discount: discount,
      totalTax: 0.0,
      netPayable: _orderSubTotal - discount,
      netTotal: _orderSubTotal - discount,
    );
  }

  @override
  void applyDiscount({
    required double flatDiscount,
    required double percentageDiscount,
  }) {
    _flatDiscount = flatDiscount;
    _percentageDiscount = percentageDiscount;
    notifyListeners();
  }
}
