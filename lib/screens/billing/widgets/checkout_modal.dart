import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Re-enabled for .tr translations
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/delivery_method.dart';
// import 'package:pos_machine/resources/color_manager.dart'; // Unused
import 'package:pos_machine/resources/font_manager.dart';
// import 'package:pos_machine/resources/style_manager.dart'; // Unused
import 'package:pos_machine/screens/billing/widgets/coupon_modal.dart';
import 'package:pos_machine/screens/billing/widgets/payment_method_modal.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/resources/color_manager.dart'; // Re-added for delivery modal components
import 'package:pos_machine/resources/style_manager.dart'; // Re-added for delivery modal components
import 'package:pos_machine/components/build_dialog_box.dart'; // For showScaffoldError

class CheckoutModal extends StatefulWidget {
  final double cartTotal;
  final List<CustomerListModelData> availableCustomers;
  final CustomerListModelData? selectedCustomer;

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

  // Callbacks
  final Function(CustomerListModelData) onCustomerSelected;
  final Future<CustomerListModelData?> Function(String searchQuery)
      onAddNewCustomer;
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

  final Future<void> Function() onConfirmOrder;
  final Future<void> Function() onConfirmAndPrint;

  const CheckoutModal({
    super.key,
    required this.cartTotal,
    required this.availableCustomers,
    this.selectedCustomer,
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
    required this.onCustomerSelected,
    required this.onAddNewCustomer,
    required this.onDiscountApplied,
    this.onDeliveryUpdated,
    this.onDeliveryChargeUpdated,
    required this.onPaymentUpdated,
    required this.onConfirmOrder,
    required this.onConfirmAndPrint,
  });

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  int _currentStep =
      0; // 0: Customer, 1: Discount/Delivery, ... logic updated below
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

    // Reload payment methods and apply default when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final masterDataProvider =
          Provider.of<MasterDataProvider>(context, listen: false);
      masterDataProvider.fetchPaymentMethods(forceRefresh: true);
      _applyDefaultPaymentMethod();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyInitialStepFromSettings();
  }

  void _applyInitialStepFromSettings() {
    if (_hasEvaluatedSkipCustomerSelection) {
      return;
    }

    final appSettings = Provider.of<AppSettingsProvider>(context).appSettings;
    if (appSettings == null) {
      return;
    }

    _hasEvaluatedSkipCustomerSelection = true;
    if (appSettings.skipCustomerSelection && mounted && _currentStep != 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentStep = 3;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant CheckoutModal oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.availableCustomers != widget.availableCustomers) {
      final previousSelectedId = _localSelectedCustomer?.id;
      _allCustomers = List<CustomerListModelData>.from(widget.availableCustomers);

      if (_customerSearchQuery.isEmpty) {
        _filteredCustomers = List<CustomerListModelData>.from(_allCustomers);
      } else {
        final query = _customerSearchQuery;
        _filteredCustomers = _allCustomers.where((customer) {
          final name = (customer.name ?? '').toLowerCase();
          final phone = (customer.phone ?? '').toLowerCase();
          return name.contains(query) || phone.contains(query);
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
    _customerSearchController.dispose();
    _lCarNumberController.dispose();
    _lCommentController.dispose();
    _lAddressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Logic to skip delivery step if not enabled
    int next = _currentStep + 1;
    if (!widget.enableDelivery && next == 1) {
      next = 2; // Skip delivery
    }

    // Max steps logic: 0(Cust) -> 1(Del) -> 2(Disc) -> 3(Pay)
    // If delivery disabled: 0(Cust) -> 2(Disc) -> 3(Pay)

    // Original was 0,1,2,3. Now expanding.
    if (next <= 3) {
      setState(() {
        _currentStep = next;
      });
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
    }
  }

  void _goToStep(int step) {
    if (_isAddingCustomer) return;
    if (!widget.enableDelivery && step == 1) return;
    if (step >= 0 && step <= 3) {
      setState(() {
        _currentStep = step;
      });
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
        if ((_lDeliveryMethodId.isNotEmpty && method.id == _lDeliveryMethodId) ||
            method.name == _lDeliveryMethod) {
          selectedMethod = method;
          break;
        }
      }
    }

    return _selectedDeliveryCharge ?? selectedMethod?.basePrice ?? 0.0;
  }

  void _handleDeliveryUpdate() {
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    double resolvedCharge = _selectedDeliveryCharge ?? 0.0;

    if (_lDeliveryMethod.isNotEmpty &&
        (_selectedDeliveryCharge == null || _selectedDeliveryCharge! <= 0)) {
      for (final method in deliveryMethodsProvider.deliveryMethods) {
        if (method.name == _lDeliveryMethod || method.id == _lDeliveryMethodId) {
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
      if (_customerSearchQuery.isEmpty) {
        _filteredCustomers = List<CustomerListModelData>.from(_allCustomers);
      } else {
        _filteredCustomers = _allCustomers.where((customer) {
          final name = (customer.name ?? '').toLowerCase();
          final phone = (customer.phone ?? '').toLowerCase();
          return name.contains(_customerSearchQuery) ||
              phone.contains(_customerSearchQuery);
        }).toList();
      }
    });
  }

  // Handle local state update + parent callback
  void _handleCustomerSelection(CustomerListModelData customer) {
    setState(() {
      _localSelectedCustomer = customer;
    });
    widget.onCustomerSelected(customer);
    // Auto-move to payment tab after customer selection
    _goToStep(3);
  }

  void _handleAddNewCustomer() async {
    if (_isAddingCustomer) return;
    setState(() {
      _isAddingCustomer = true;
    });
    try {
      final newCustomer = await widget.onAddNewCustomer(_customerSearchQuery);
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth =
      (screenSize.width * 0.94).clamp(320.0, 1300.0).toDouble();
    final dialogHeight =
      (screenSize.height * 0.92).clamp(520.0, 850.0).toDouble();

    // Determine status for stepper/wizard using LOCAL state
    final hasCustomer = _localSelectedCustomer != null;
    final hasDelivery = _lDeliveryMethod.isNotEmpty; // Simple check
    final hasPayment = _hasPaymentMethod();
    final hasDiscount = _localIsCouponApplied ||
        _localFlatDiscount > 0 ||
        _localPercentageDiscount > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                // Header with Steps
                _buildHeader(
                    hasCustomer, hasDiscount, hasPayment, hasDelivery),

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
                _buildStepConnector(isActive: _currentStep > 2),
                _buildStepIndicator(3, 'Payment', Icons.payment,
                    isActive: _currentStep == 3, isCompleted: hasPayment),
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

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Search, Selected Customer, and List
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _customerSearchController,
                          onChanged: _filterCustomers,
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone number...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon:
                                Icon(Icons.search, color: Colors.grey.shade500),
                            suffixIcon: _customerSearchQuery.isNotEmpty
                                ? IconButton(
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
                      const SizedBox(height: 16),
                      // Selected Customer Card (moved here from right panel)
                      _buildSelectedCustomerCard(),
                      const SizedBox(height: 16),
                      // List
                      Expanded(child: _buildCustomerList()),
                      if (hasInternet) ...[
                        const SizedBox(height: 16),
                        // Add Customer Button (online only)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isAddingCustomer
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.grey),
                                    ),
                                  )
                                : const Icon(Icons.person_add),
                            label: Text(_isAddingCustomer
                                ? 'Adding...'
                                : 'Add New Customer'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFFECFDF3),
                              foregroundColor: const Color(0xFF047857),
                              side: const BorderSide(color: Color(0xFF34D399)),
                            ),
                            onPressed:
                                _isAddingCustomer ? null : _handleAddNewCustomer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                const VerticalDivider(width: 1),
                const SizedBox(width: 24),
                // Right: Summary only (no customer card)
                Expanded(
                  flex: 2,
                  child: _buildCompactSummary(),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(
          onPrint: () async {
            if (_isPrinting) return;
            setState(() => _isPrinting = true);
            try {
              await widget.onConfirmAndPrint();
            } finally {
              if (mounted) setState(() => _isPrinting = false);
            }
          },
          onConfirm: () async {
            if (_isConfirming) return;
            setState(() => _isConfirming = true);
            try {
              await widget.onConfirmOrder();
            } finally {
              if (mounted) setState(() => _isConfirming = false);
            }
          },
        ),
      ],
    );
  }

  // --- STEP 1.5: DELIVERY ---
  Widget _buildDeliveryStep() {
    Size size = MediaQuery.of(context).size;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Delivery Options
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Consumer<DeliveryMethodsProvider>(
                      builder: (context, provider, child) {
                      final appSettings =
                        Provider.of<AppSettingsProvider>(context,
                              listen: false)
                            .appSettings;
                        final isDeliveryChargeDataEnabled =
                          appSettings?.freeDeliveryEnabled ??
                            false;
                      final currency = appSettings?.currency ?? 'SAR';
                      final minimumAmount =
                        double.tryParse(appSettings
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
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: provider.deliveryMethods.map((method) {
                                final isSelected =
                                    _lDeliveryMethod == method.name;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _lDeliveryMethod = method.name;
                                      _lDeliveryMethodId = method.id;
                                      if (method.prices.isEmpty) {
                                        _selectedDeliveryPriceId = null;
                                        _selectedDeliveryCharge = 0.0;
                                      } else {
                                      final existingById = method.prices
                                        .where((p) =>
                                          p.id == _selectedDeliveryPriceId)
                                        .toList();
                                      if (existingById.isNotEmpty) {
                                        _selectedDeliveryCharge =
                                          existingById.first.price;
                                        } else {
                                        final existingByCharge =
                                          _selectedDeliveryCharge == null
                                            ? <DeliveryPrice>[]
                                            : method.prices
                                              .where((p) =>
                                                (p.price -
                                                    _selectedDeliveryCharge!)
                                                  .abs() <
                                                0.001)
                                              .toList();

                                        if (existingByCharge.isNotEmpty) {
                                        _selectedDeliveryPriceId =
                                          existingByCharge.first.id;
                                        _selectedDeliveryCharge =
                                          existingByCharge.first.price;
                                        } else {
                                        _selectedDeliveryPriceId =
                                          method.prices.first.id;
                                        _selectedDeliveryCharge =
                                          method.prices.first.price;
                                        }
                                        }
                                      }

                                      if (!shouldApplyDeliveryCharge) {
                                        _selectedDeliveryCharge = 0.0;
                                      }
                                    });
                                    _handleDeliveryUpdate();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 118,
                                    height: 104,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? ColorManager.kPrimaryColor
                                              .withOpacity(0.05)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? ColorManager.kPrimaryColor
                                            : Colors.grey.shade200,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          method.name == "Store Takeaway"
                                              ? Icons.store
                                              : method.name == "Car Delivery"
                                                  ? Icons.car_rental
                                                  : method.name ==
                                                          "Door Delivery"
                                                      ? Icons.doorbell_outlined
                                                      : Icons.local_shipping,
                                          size: 22,
                                          color: isSelected
                                              ? ColorManager.kPrimaryColor
                                              : Colors.grey.shade700,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          method.name.tr,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: buildCustomStyle(
                                            isSelected
                                                ? FontWeightManager.semiBold
                                                : FontWeightManager.medium,
                                            FontSize.s11,
                                            0.0,
                                            isSelected
                                                ? ColorManager.kPrimaryColor
                                                : Colors.black87,
                                          ),
                                        ),
                                        if (isDeliveryChargeDataEnabled) ...[
                                          const SizedBox(height: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF059669)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              method.prices.isNotEmpty &&
                                                      shouldApplyDeliveryCharge
                                                  ? (() {
                                                      if (!isSelected) {
                                                        return '$currency ${method.basePrice?.toStringAsFixed(2) ?? '0.00'}';
                                                      }

                                                      final selectedById =
                                                          method.prices
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
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: buildCustomStyle(
                                                FontWeightManager.semiBold,
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
                                );
                              }).toList(),
                            ),
                            if (_lDeliveryMethod.isNotEmpty &&
                                isDeliveryChargeDataEnabled) ...[
                              const SizedBox(height: 12),
                              Builder(builder: (context) {
                                DeliveryMethod? selectedMethod;
                                for (final method in provider.deliveryMethods) {
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

                                final effectiveSelectedPriceId =
                                    (() {
                                  if (_selectedDeliveryPriceId != null) {
                                    final exists =
                                        selectedDeliveryMethod.prices.any(
                                        (p) => p.id == _selectedDeliveryPriceId);
                                    if (exists) return _selectedDeliveryPriceId!;
                                  }

                                  if (_selectedDeliveryCharge != null) {
                                    for (final price
                                        in selectedDeliveryMethod.prices) {
                                      if ((price.price - _selectedDeliveryCharge!)
                                              .abs() <
                                          0.001) {
                                        return price.id;
                                      }
                                    }
                                  }

                                  return selectedDeliveryMethod.prices.first.id;
                                })();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      children:
                                            selectedDeliveryMethod.prices
                                              .map((price) {
                                        final isPriceSelected =
                                            price.id == effectiveSelectedPriceId;

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
                                              width: isPriceSelected ? 2 : 1.5,
                                            ),
                                            backgroundColor: isPriceSelected
                                                ? const Color(0xFF059669)
                                                : Colors.white,
                                            foregroundColor: isPriceSelected
                                                ? Colors.white
                                                : const Color(0xFF059669),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                            minimumSize: const Size(0, 44),
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
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
                              buildColumnWidgetForTextFields(
                                controller: _lCarNumberController,
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
                              const SizedBox(height: 10),
                            ],
                            buildColumnWidgetForTextFields(
                              controller: _lCommentController,
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
                                          return GestureDetector(
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
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade300),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color: Colors.grey.shade50,
                                              ),
                                              child: Text(
                                                "${address.address}, ${address.city}",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: buildCustomStyle(
                                                  FontWeightManager.regular,
                                                  FontSize.s12,
                                                  0.12,
                                                  Colors.black87,
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
                              buildColumnWidgetForTextFields(
                                controller: _lAddressController,
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
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                const VerticalDivider(width: 1),
                const SizedBox(width: 24),
                // Right: Summary
                Expanded(
                  flex: 2,
                  child: _buildCompactSummary(),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(
          onBack: _previousStep,
          onPrint: () async {
            if (_isPrinting) return;
            setState(() => _isPrinting = true);
            try {
              await widget.onConfirmAndPrint();
            } finally {
              if (mounted) setState(() => _isPrinting = false);
            }
          },
          onConfirm: () async {
            if (_isConfirming) return;
            setState(() => _isConfirming = true);
            try {
              await widget.onConfirmOrder();
            } finally {
              if (mounted) setState(() => _isConfirming = false);
            }
          },
        ),
      ],
    );
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

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.9,
      ),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredCustomers[index];
        final isSelected = _localSelectedCustomer?.id == customer.id;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleCustomerSelection(customer),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB).withOpacity(0.1)
                    : Colors.white,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedCustomerCard() {
    if (_localSelectedCustomer == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline,
                  size: 28, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Customer Selected',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Select a customer to continue',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final balance = _localSelectedCustomer!.balance ?? 0.0;
    final balanceColor =
        balance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _goToStep(3),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Avatar on left
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initialForName(_localSelectedCustomer!.name),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info in middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localSelectedCustomer!.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_localSelectedCustomer!.phone != null)
                      Text(
                        _localSelectedCustomer!.phone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Balance on right
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: balanceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Balance: ${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: balanceColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: const Color(0xFF2563EB).withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP 2: DISCOUNT ---
  Widget _buildDiscountStep() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                    showSkipButton: true,
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

                      String nextCash = _lCashAmount;
                      String nextCard = _lCardAmount;
                      String nextUpi = _lUpiAmount;
                      String nextCod = _lCodAmount;

                      final bool anySelected = _lIsCashSelected ||
                          _lIsCardSelected ||
                          _lIsUpiSelected ||
                          _lIsCodSelected;

                      final int selectedCount =
                          (_lIsCashSelected ? 1 : 0) +
                              (_lIsCardSelected ? 1 : 0) +
                              (_lIsUpiSelected ? 1 : 0) +
                              (_lIsCodSelected ? 1 : 0);

                      final double cashVal = double.tryParse(_lCashAmount) ?? 0.0;
                      final double cardVal = double.tryParse(_lCardAmount) ?? 0.0;
                      final double upiVal = double.tryParse(_lUpiAmount) ?? 0.0;
                      final double codVal = double.tryParse(_lCodAmount) ?? 0.0;
                      final double totalPaid = cashVal + cardVal + upiVal + codVal;

                      // If nothing is selected, clear stale amounts so Payment tab auto-fill
                      // always uses the freshly discounted total.
                      if (!anySelected) {
                        nextCash = '';
                        nextCard = '';
                        nextUpi = '';
                        nextCod = '';
                      }

                      // If exactly one method is selected and it matched old effective total,
                      // remap it to the new discounted total.
                      if (selectedCount == 1 &&
                          (totalPaid - oldEffectiveTotal).abs() < 0.01) {
                        final remappedAmount = newEffectiveTotal.toStringAsFixed(2);
                        if (_lIsCashSelected) {
                          nextCash = remappedAmount;
                          nextCard = '';
                          nextUpi = '';
                          nextCod = '';
                        } else if (_lIsCardSelected) {
                          nextCash = '';
                          nextCard = remappedAmount;
                          nextUpi = '';
                          nextCod = '';
                        } else if (_lIsUpiSelected) {
                          nextCash = '';
                          nextCard = '';
                          nextUpi = remappedAmount;
                          nextCod = '';
                        } else if (_lIsCodSelected) {
                          nextCash = '';
                          nextCard = '';
                          nextUpi = '';
                          nextCod = remappedAmount;
                        }
                      }

                      _handleDiscountUpdate(code, applied, newFlatDiscount,
                          newPercentageDiscount);

                      if (nextCash != _lCashAmount ||
                          nextCard != _lCardAmount ||
                          nextUpi != _lUpiAmount ||
                          nextCod != _lCodAmount) {
                        _handlePaymentUpdate(
                            _lIsCashSelected,
                            _lIsCardSelected,
                            _lIsUpiSelected,
                            _lIsCodSelected,
                            _lIsDebitSelected,
                            nextCash,
                            nextCard,
                            nextUpi,
                            nextCod,
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
                const SizedBox(width: 24),
                const VerticalDivider(width: 1),
                const SizedBox(width: 24),
                // Right: Summary
                Expanded(
                  flex: 2,
                  child: _buildCompactSummary(),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(
          onBack: _previousStep,
          onPrint: () async {
            if (_isPrinting) return;
            setState(() => _isPrinting = true);
            try {
              await widget.onConfirmAndPrint();
            } finally {
              if (mounted) setState(() => _isPrinting = false);
            }
          },
          onConfirm: () async {
            if (_isConfirming) return;
            setState(() => _isConfirming = true);
            try {
              await widget.onConfirmOrder();
            } finally {
              if (mounted) setState(() => _isConfirming = false);
            }
          },
        ),
      ],
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

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                    customerPrevBalance: _localSelectedCustomer?.balance ?? 0.0,
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
                      _handlePaymentUpdate(isCash, isCard, isUpi, isCod,
                          isDebit, cash, card, upi, cod, debit, trans, toCredit,
                          cashMethodId: cashMethodId,
                          cardMethodId: cardMethodId,
                          upiMethodId: upiMethodId,
                          codMethodId: codMethodId);
                      _nextStep();
                    },
                  ),
                ),
                const SizedBox(width: 24),
                const VerticalDivider(width: 1),
                const SizedBox(width: 24),
                // Right: Summary
                Expanded(
                  flex: 2,
                  child: _buildCompactSummary(),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(
          onBack: _previousStep,
          onPrint: () async {
            if (_isPrinting) return;
            setState(() => _isPrinting = true);
            try {
              await widget.onConfirmAndPrint();
            } finally {
              if (mounted) setState(() => _isPrinting = false);
            }
          },
          onConfirm: () async {
            if (_isConfirming) return;
            setState(() => _isConfirming = true);
            try {
              await widget.onConfirmOrder();
            } finally {
              if (mounted) setState(() => _isConfirming = false);
            }
          },
        ),
      ],
    );
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
              fontSize: large ? 16 : 14,
              color: labelColor ?? (isBold ? Colors.black : Colors.black87),
            )),
        Text(
            '${amount < 0 ? "-" : ""}$currency ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: large ? 18 : 14,
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
              fontSize: 14,
              color: Colors.black87,
            )),
        Text(
            '$currency ${effectiveDeliveryCharge.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
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

  // Check if Confirm and Print buttons should be enabled
  bool get _canConfirmOrPrint {
    if (!widget.requireCheckoutCompletion) {
      return true;
    }

    return _localSelectedCustomer != null &&
        _hasOpenedPaymentModalOnce &&
        _hasPaymentMethod();
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Left side: Spacing to align buttons with right panel (flex 3)
          const Expanded(flex: 3, child: SizedBox.shrink()),

          const SizedBox(width: 24), // Match content gap

          // Right side: Action buttons aligned with the right panel (flex 2)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                // Confirm button (optional)
                if (onConfirm != null)
                  Expanded(
                    child: Opacity(
                      opacity: _canConfirmOrPrint ? 1.0 : 0.5,
                      child: CustomRoundButtonWithIconAdvanced(
                        title: widget.confirmButtonTitle,
                        isLoading: _isConfirming,
                        fct: _canConfirmOrPrint
                            ? onConfirm
                            : () {
                                // Auto-navigate to payment tab and show feedback
                                _goToStep(3);
                                showScaffoldError(
                                  context: context,
                                  message: widget.requireCheckoutCompletion
                                      ? 'Please configure payment before confirm'
                                      : 'Unable to proceed',
                                );
                              },
                        size: MediaQuery.of(context).size,
                        icon: const Icon(Icons.check_circle,
                            color: Colors.white, size: 20),
                        height: 48,
                        width: double.infinity,
                        fontSize: FontSize.s14,
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
                      opacity: _canConfirmOrPrint ? 1.0 : 0.5,
                      child: CustomRoundButtonWithIconAdvanced(
                        title: widget.printButtonTitle,
                        isLoading: _isPrinting,
                        fct: _canConfirmOrPrint
                            ? onPrint
                            : () {
                                // Auto-navigate to payment tab and show feedback
                                _goToStep(3);
                                showScaffoldError(
                                  context: context,
                                  message: widget.requireCheckoutCompletion
                                      ? 'Please configure payment before confirm'
                                      : 'Unable to proceed',
                                );
                              },
                        size: MediaQuery.of(context).size,
                        icon: const Icon(Icons.print,
                            color: Colors.white, size: 20),
                        height: 48,
                        width: double.infinity,
                        fontSize: FontSize.s14,
                        boxColor: _canConfirmOrPrint
                            ? const Color(0xFF059669)
                            : Colors.grey.shade400,
                        borderColor: _canConfirmOrPrint
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
                      height: 48,
                      width: double.infinity,
                      fontSize: FontSize.s14,
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

        final bool hasCustomer = _localSelectedCustomer != null;
        final bool hasPayment = _hasPaymentMethod();
        final bool hasDiscount = _localIsCouponApplied ||
            _localFlatDiscount > 0 ||
            _localPercentageDiscount > 0;
        final bool hasDelivery = _lDeliveryMethod.isNotEmpty;

        return Column(
          children: [
            // Status Checklist (clickable to navigate)
            LayoutBuilder(builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Show Customer item in all tabs
                  SizedBox(
                    width: itemWidth,
                    child: _buildClickableCheckItem(
                      'Customer',
                      _localSelectedCustomer?.name ?? 'Not Selected',
                      hasCustomer,
                      Icons.person_outline,
                      0,
                    ),
                  ),
                  if (widget.enableDelivery)
                    SizedBox(
                      width: itemWidth,
                      child: _buildClickableCheckItem(
                        'Delivery',
                        _lDeliveryMethod,
                        hasDelivery,
                        Icons.local_shipping_outlined,
                        1,
                      ),
                    ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildClickableCheckItem(
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
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildClickableCheckItem(
                      'Payment',
                      _hasPaymentMethod() ? 'Configured' : 'Not Configured',
                      hasPayment,
                      Icons.payment_outlined,
                      3,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            // Order Summary
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
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
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Net Amount', subTotal, Colors.black),
                        const SizedBox(height: 10),
                        _buildSummaryRow('Discount', -discountAmount,
                            const Color(0xFFEF4444),
                            labelColor: const Color(0xFFEF4444)),
                        const SizedBox(height: 10),
                        _buildSummaryRow(
                            'Tax', taxAmount, const Color(0xFF64748B),
                            labelColor: const Color(0xFF64748B)),
                        if (hasDelivery &&
                            _isfreeDeliveryMinimumAmount()) ...[
                          const SizedBox(height: 10),
                          _buildDeliveryChargeRow(),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
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
                          const SizedBox(height: 10),
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
                        const SizedBox(height: 10),
                        _buildSummaryRow('Total Paid', totalPaid, Colors.black),
                        const SizedBox(height: 10),
                        _buildSummaryRow(
                            'Balance', displayBalance, const Color(0xFF059669),
                            labelColor: const Color(0xFF059669)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Clickable checklist item that navigates to the corresponding step
  Widget _buildClickableCheckItem(String title, String subtitle,
      bool isCompleted, IconData icon, int stepIndex) {
    final isCurrentStep = _currentStep == stepIndex;

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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
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
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                          color: isCurrentStep
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrentStep
                              ? Colors.white.withOpacity(0.85)
                              : isCompleted
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF64748B),
                          fontWeight:
                              isCurrentStep ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  isCurrentStep ? Icons.arrow_forward_ios : Icons.chevron_right,
                  color: isCurrentStep ? Colors.white : const Color(0xFFCBD5E1),
                  size: isCurrentStep ? 14 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
