import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Re-enabled for .tr translations
import 'package:pos_machine/models/customer_list.dart';
// import 'package:pos_machine/resources/color_manager.dart'; // Unused
import 'package:pos_machine/resources/font_manager.dart';
// import 'package:pos_machine/resources/style_manager.dart'; // Unused
import 'package:pos_machine/screens/billing/widgets/coupon_modal.dart';
import 'package:pos_machine/screens/billing/widgets/payment_method_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/resources/color_manager.dart'; // Re-added for delivery modal components
import 'package:pos_machine/resources/style_manager.dart'; // Re-added for delivery modal components

class CheckoutModal extends StatefulWidget {
  final double cartTotal;
  final List<CustomerListModelData> availableCustomers;
  final CustomerListModelData? selectedCustomer;
  
  // Delivery State (Optional)
  final bool enableDelivery;
  final String deliveryMethod;
  final String deliveryMethodId;
  final String carNumber;
  final String deliveryComment;
  final String deliveryAddress;
  final String? deliveryDate;
  final String? deliveryTime;
  
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
  
  // Callbacks
  final Function(CustomerListModelData) onCustomerSelected;
  final Future<CustomerListModelData?> Function(String searchQuery) onAddNewCustomer;
  final Function(
    String couponCode, 
    bool isApplied, 
    double flatDiscount, 
    double percentageDiscount
  ) onDiscountApplied;
  
  final Function(
    String method,
    String methodId,
    String carNo,
    String comment,
    String? date,
    String? time,
    String address
  )? onDeliveryUpdated;

  final Function(
    bool isCash, bool isCard, bool isUpi, bool isCod, bool isDebit,
    String cash, String card, String upi, String cod, String debit,
    String trans, bool toCredit,
    {String? cashMethodId, String? cardMethodId, String? upiMethodId, String? codMethodId}
  ) onPaymentUpdated;
  
  final Future<void> Function() onConfirmOrder;
  final Future<void> Function() onConfirmAndPrint;
  
  const CheckoutModal({
    super.key,
    required this.cartTotal,
    required this.availableCustomers,
    this.selectedCustomer,
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
    required this.couponCode,
    required this.flatDiscount,
    required this.percentageDiscount,
    required this.isCouponApplied,
    required this.onCustomerSelected,
    required this.onAddNewCustomer,
    required this.onDiscountApplied,
    this.onDeliveryUpdated,
    required this.onPaymentUpdated,
    required this.onConfirmOrder,
    required this.onConfirmAndPrint,
  });

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  int _currentStep = 0; // 0: Customer, 1: Discount/Delivery, ... logic updated below
  bool _isConfirming = false;
  bool _isPrinting = false;
  
  // Local state for Customer Search
  String _customerSearchQuery = '';
  List<CustomerListModelData> _filteredCustomers = [];
  final TextEditingController _customerSearchController = TextEditingController();

  // Local State to handle Optimistic Updates (Fixes "Not selecting" issues)
  CustomerListModelData? _localSelectedCustomer;
  late double _localFlatDiscount;
  late double _localPercentageDiscount;
  late String _localCouponCode;
  late bool _localIsCouponApplied;
  
  // Local Delivery State
  late String _lDeliveryMethod;
  late String _lDeliveryMethodId;
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

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.availableCustomers;
    
    // Initialize Local State from Widget Props
    _localSelectedCustomer = widget.selectedCustomer;
    _localFlatDiscount = widget.flatDiscount;
    _localPercentageDiscount = widget.percentageDiscount;
    _localCouponCode = widget.couponCode;
    _localIsCouponApplied = widget.isCouponApplied;
    
    // Initialize Local Delivery State
    _lDeliveryMethod = widget.deliveryMethod;
    _lDeliveryMethodId = widget.deliveryMethodId;
    _lCarNumberController = TextEditingController(text: widget.carNumber);
    _lCommentController = TextEditingController(text: widget.deliveryComment);
    _lAddressController = TextEditingController(text: widget.deliveryAddress);
    if (widget.deliveryDate != null && widget.deliveryDate!.isNotEmpty) {
      _lSelectedDeliveryDate = DateTime.tryParse(widget.deliveryDate!);
    }
    if (widget.deliveryTime != null && widget.deliveryTime!.isNotEmpty) {
      final parts = widget.deliveryTime!.split(":");
      if (parts.length >= 2) {
        _lSelectedDeliveryTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
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
    
    // Max steps logic: 0(Cust) -> 1(Del) -> 2(Disc) -> 3(Pay) -> 4(Rev)
    // If delivery disabled: 0(Cust) -> 2(Disc) -> 3(Pay) -> 4(Rev)
    // Adjusting step indices map:
    // 0: Customer
    // 1: Delivery (Only if widget.enableDelivery)
    // 2: Discount
    // 3: Payment
    // 4: Review
    
    // Original was 0,1,2,3. Now expanding.
    if (next <= 4) {
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
    if (!widget.enableDelivery && step == 1) return;
    if (step >= 0 && step <= 4) {
      setState(() {
        _currentStep = step;
      });
    }
  }

  void _handleDeliveryUpdate() {
    if (widget.onDeliveryUpdated != null) {
      widget.onDeliveryUpdated!(
        _lDeliveryMethod,
        _lDeliveryMethodId,
        _lCarNumberController.text,
        _lCommentController.text,
        _lSelectedDeliveryDate != null ? _lSelectedDeliveryDate!.toIso8601String() : '',
        _lSelectedDeliveryTime != null ? _lSelectedDeliveryTime!.format(context) : '',
        _lAddressController.text,
      );
    }
  }

  // --- Step 1: Customer Logic ---
  void _filterCustomers(String query) {
    setState(() {
      _customerSearchQuery = query.toLowerCase();
      if (_customerSearchQuery.isEmpty) {
        _filteredCustomers = widget.availableCustomers;
      } else {
        _filteredCustomers = widget.availableCustomers.where((customer) {
          final name = (customer.name ?? '').toLowerCase();
          final phone = (customer.phone ?? '').toLowerCase();
          return name.contains(_customerSearchQuery) || phone.contains(_customerSearchQuery);
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
  }
  
  void _handleAddNewCustomer() async {
    final newCustomer = await widget.onAddNewCustomer(_customerSearchQuery);
    if (newCustomer != null) {
      if (mounted) {
         setState(() {
           // Add to local list if not present
           if (!_filteredCustomers.any((c) => c.id == newCustomer.id)) {
             _filteredCustomers.insert(0, newCustomer);
           }
           _localSelectedCustomer = newCustomer;
           _customerSearchController.clear();
           _customerSearchQuery = '';
         });
         // Also update parent
         widget.onCustomerSelected(newCustomer);
      }
    }
  }

  void _handleDiscountUpdate(String code, bool applied, double flat, double percent) {
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
    bool isCash, bool isCard, bool isUpi, bool isCod, bool isDebit,
    String cash, String card, String upi, String cod, String debit,
    String trans, bool toCredit,
    {String? cashMethodId, String? cardMethodId, String? upiMethodId, String? codMethodId}
  ) {
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
    });
    widget.onPaymentUpdated(
      isCash, isCard, isUpi, isCod, isDebit,
      cash, card, upi, cod, debit,
      trans, toCredit,
      cashMethodId: cashMethodId, cardMethodId: cardMethodId, upiMethodId: upiMethodId, codMethodId: codMethodId
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine status for stepper/wizard using LOCAL state
    final hasCustomer = _localSelectedCustomer != null;
    final hasDelivery = _lDeliveryMethod.isNotEmpty; // Simple check
    final hasPayment = _hasPaymentMethod();
    final hasDiscount = _localIsCouponApplied || _localFlatDiscount > 0 || _localPercentageDiscount > 0;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 8,
      child: Container(
        width: 900,
        height: 700,
        clipBehavior: Clip.antiAlias, // Ensure children respect the rounded corners
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
            _buildHeader(hasCustomer, hasDiscount, hasPayment, hasDelivery),
            
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
    );
  }

  Widget _buildHeader(bool hasCustomer, bool hasDiscount, bool hasPayment, bool hasDelivery) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min, // Ensure Row takes minimum necessary width
                children: [
                  _buildStepIndicator(0, 'Customer', Icons.person, isActive: _currentStep == 0, isCompleted: hasCustomer),
                  if (widget.enableDelivery) ...[
                    _buildStepConnector(isActive: _currentStep > 0),
                    _buildStepIndicator(1, 'Delivery', Icons.local_shipping, isActive: _currentStep == 1, isCompleted: hasDelivery),
                  ],
                  _buildStepConnector(isActive: _currentStep > (widget.enableDelivery ? 1 : 0)),
                  _buildStepIndicator(2, 'Discount', Icons.discount, isActive: _currentStep == 2, isCompleted: hasDiscount),
                  _buildStepConnector(isActive: _currentStep > 2),
                  _buildStepIndicator(3, 'Payment', Icons.payment, isActive: _currentStep == 3, isCompleted: hasPayment),
                  _buildStepConnector(isActive: _currentStep > 3),
                  _buildStepIndicator(4, 'Review', Icons.receipt_long, isActive: _currentStep == 4, isCompleted: false),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label, IconData icon, {required bool isActive, required bool isCompleted}) {
    final color = isActive 
        ? const Color(0xFF2563EB) 
        : isCompleted 
            ? const Color(0xFF059669) 
            : Colors.grey.shade400;
            
    final bgColor = isActive 
        ? const Color(0xFF2563EB).withValues(alpha: 0.1) 
        : isCompleted 
            ? const Color(0xFF059669).withValues(alpha: 0.1) 
            : Colors.grey.shade100;

    return InkWell(
      onTap: () => _goToStep(stepIndex),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Ensure inner Row takes minimum necessary width
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: isActive ? color : Colors.transparent, width: 2),
              ),
              child: Icon(isCompleted && !isActive ? Icons.check : icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? Colors.black87 : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector({required bool isActive}) {
    return Container(
        height: 2,
        width: 20, // Give a fixed width for the connector instead of Expanded
        color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade200,
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
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: CUSTOMER ---
  Widget _buildCustomerStep() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Search and List
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
                            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                            suffixIcon: _customerSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Colors.grey.shade500),
                                    onPressed: () {
                                      _customerSearchController.clear();
                                      _filterCustomers('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // List
                      Expanded(child: _buildCustomerList()),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                const VerticalDivider(width: 1),
                const SizedBox(width: 24),
                // Right: Selected Customer & Actions
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSelectedCustomerCard(),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add New Customer'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onPressed: _handleAddNewCustomer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(
          onNext: _nextStep,
          nextLabel: widget.enableDelivery ? 'Proceed to Delivery' : 'Proceed to Discount',
          isNextEnabled: true, // Allow proceeding even without customer (guest) or enforcing it
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
            child: SingleChildScrollView(
              child: Consumer<DeliveryMethodsProvider>(
                builder: (context, provider, child) {
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
                        spacing: 10,
                        runSpacing: 10,
                        children: provider.deliveryMethods.map((method) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _lDeliveryMethod = method.name;
                                _lDeliveryMethodId = method.id;
                              });
                              _handleDeliveryUpdate();
                            },
                            child: BuildBoxShadowContainer(
                              border: _lDeliveryMethod == method.name
                                  ? Border.all(color: ColorManager.kPrimaryColor)
                                  : null,
                              padding: const EdgeInsets.all(12),
                              blurRadius: 4,
                              circleRadius: 5,
                              child: Column(
                                children: [
                                  Icon(
                                    method.name == "Store Takeaway"
                                        ? Icons.store
                                        : method.name == "Car Delivery"
                                            ? Icons.car_rental
                                            : method.name == "Door Delivery"
                                                ? Icons.doorbell_outlined
                                                : Icons.local_shipping,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    method.name.tr, // Using .tr assuming translations work or just name
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.12,
                                      Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (Provider.of<AppSettingsProvider>(context, listen: false)
                          .appSettings!
                          .askDeliveryDate) ...[
                        const SizedBox(height: 20),
                        // Delivery Date
                        Text('billing.enter_car_number'.tr, // Reusing key for Date? Assuming original code intent
                            style: buildCustomStyle(FontWeightManager.medium,
                                FontSize.s12, 0.12, Colors.black)),
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
                        // Delivery Time
                        Text('common.select'.tr,
                            style: buildCustomStyle(FontWeightManager.medium,
                                FontSize.s12, 0.12, Colors.black)),
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
                      const SizedBox(height: 20),
                      if (_lDeliveryMethod == "Car Delivery") ...[
                        buildColumnWidgetForTextFields(
                          controller: _lCarNumberController,
                          size: size,
                          height: 50,
                          hintText: 'Car Number:',
                          width: double.infinity,
                          onTap: () {
                            Provider.of<KeyboardProvider>(context, listen: false)
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
                        onTap: () {
                          Provider.of<KeyboardProvider>(context, listen: false).show(
                              'text', _lCommentController,
                              replaceOnFirstInput: true);
                        },
                        onchanged: (_) => _handleDeliveryUpdate(),
                      ),
                      if (_lDeliveryMethod == "Door Delivery") ...[
                        const SizedBox(height: 10),
                        Consumer<CustomerSelectionProvider>(
                          builder: (context, customerProvider, child) {
                            if (!customerProvider.hasSelectedCustomer ||
                                customerProvider.selectedCustomer!.addresses ==
                                    null ||
                                customerProvider
                                    .selectedCustomer!.addresses!.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                          _lAddressController.text = fullAddress;
                                        });
                                        _handleDeliveryUpdate();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
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
                          onTap: () {
                            Provider.of<KeyboardProvider>(context, listen: false)
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
        ),
        _buildFooter(
          onBack: _previousStep,
          onNext: _nextStep,
          nextLabel: 'Proceed to Discount',
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
            Text('No customers found', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    
    return ListView.separated(
      itemCount: _filteredCustomers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                color: isSelected ? const Color(0xFF2563EB).withOpacity(0.1) : Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade200,
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
                      color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (customer.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (customer.phone != null) Text(customer.phone!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
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
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.person_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No Customer Selected', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              (_localSelectedCustomer!.name ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _localSelectedCustomer!.name ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(_localSelectedCustomer!.phone ?? '', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: (_localSelectedCustomer!.balance ?? 0) >= 0 ? const Color(0xFF059669).withOpacity(0.1) : const Color(0xFFDC2626).withOpacity(0.1),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Text(
               'Balance: ${_localSelectedCustomer!.balance?.toStringAsFixed(2) ?? '0.00'}',
               style: TextStyle(
                 fontWeight: FontWeight.bold,
                 color: (_localSelectedCustomer!.balance ?? 0) >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
               ),
             ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: DISCOUNT ---
  Widget _buildDiscountStep() {
    return Column(
      children: [
        Expanded(
          child: RestaurantCouponModalWrapper(
            orderSubTotal: widget.cartTotal,
            initialCouponCode: _localCouponCode,
            initialFlatDiscount: _localFlatDiscount,
            initialPercentageDiscount: _localPercentageDiscount,
            isCouponApplied: _localIsCouponApplied,
            onCouponAction: (code, applied, {flatDiscount, percentageDiscount}) {
              // Calculate discount logic similar to original file
               final newFlatDiscount = flatDiscount ?? 0.0;
               final newPercentageDiscount = percentageDiscount ?? 0.0;
               final oldDiscountAmount = _localFlatDiscount + (widget.cartTotal * _localPercentageDiscount / 100);
               final oldEffectiveTotal = widget.cartTotal - oldDiscountAmount;
               final newDiscountAmount = newFlatDiscount + (widget.cartTotal * newPercentageDiscount / 100);
               final newEffectiveTotal = widget.cartTotal - newDiscountAmount;

               // Auto-update cash if needed
               String currentCash = _lCashAmount;
               if (_lIsCashSelected && currentCash.isNotEmpty) {
                  final cashVal = double.tryParse(currentCash) ?? 0.0;
                  // If cash was auto-filled (matched old total), update it
                  if ((cashVal - oldEffectiveTotal).abs() < 0.01) {
                    currentCash = newEffectiveTotal.toStringAsFixed(2);
                  }
               }
               
               // Apply discount locally + parent
               _handleDiscountUpdate(code, applied, newFlatDiscount, newPercentageDiscount);
               
               // Update payment amount if auto-adjustment happened
               if (currentCash != _lCashAmount) {
                 _handlePaymentUpdate(
                   _lIsCashSelected, _lIsCardSelected, _lIsUpiSelected, _lIsCodSelected, _lIsDebitSelected,
                   currentCash, _lCardAmount, _lUpiAmount, _lCodAmount, _lDebitAmount, 
                   _lTransactionNumber, _lToCustomerCreditEnabled,
                   cashMethodId: widget.cashMethodId, cardMethodId: widget.cardMethodId, 
                   upiMethodId: widget.upiMethodId, codMethodId: widget.codMethodId
                 );
               }
               
               // Auto-advance to next step
               _nextStep();
            },
          ),
        ),
        _buildFooter(
          onBack: _previousStep,
          onNext: _nextStep,
          nextLabel: 'Proceed to Payment',
        ),
      ],
    );
  }

  // --- STEP 3: PAYMENT ---
  Widget _buildPaymentStep() {
    // Calculate effective total
    final discountAmount = _localFlatDiscount + (widget.cartTotal * _localPercentageDiscount / 100);
    final effectiveTotal = widget.cartTotal - discountAmount;
    
    // Auto-fill logic: If no payment method is selected OR if the selected method(s) have zero amount,
    // we should auto-fill with the effective total.
    final bool anyMethodSelected = _lIsCashSelected || _lIsCardSelected || _lIsUpiSelected || _lIsCodSelected;
    final double totalPaid = (double.tryParse(_lCashAmount) ?? 0) + 
                            (double.tryParse(_lCardAmount) ?? 0) + 
                            (double.tryParse(_lUpiAmount) ?? 0) + 
                            (double.tryParse(_lCodAmount) ?? 0);
    
    final bool needsAutoFill = !anyMethodSelected || totalPaid == 0;
    
    // If nothing is selected, we default to Cash. 
    // If something IS selected but the total is 0, we auto-fill the selected one.
    final bool shouldAutoFillCash = (!anyMethodSelected && _lCashAmount.isEmpty) || (_lIsCashSelected && totalPaid == 0);
    final bool shouldAutoFillCard = _lIsCardSelected && totalPaid == 0 && !shouldAutoFillCash;
    final bool shouldAutoFillUpi = _lIsUpiSelected && totalPaid == 0 && !shouldAutoFillCash && !shouldAutoFillCard;
    final bool shouldAutoFillCod = _lIsCodSelected && totalPaid == 0 && !shouldAutoFillCash && !shouldAutoFillCard && !shouldAutoFillUpi;

    return Column(
      children: [
        Expanded(
          child: PaymentMethodModal(
            initialIsCashSelected: shouldAutoFillCash ? true : _lIsCashSelected,
            initialIsCardSelected: shouldAutoFillCard ? true : _lIsCardSelected,
            initialIsUpiSelected: shouldAutoFillUpi ? true : _lIsUpiSelected,
            initialIsCodSelected: shouldAutoFillCod ? true : _lIsCodSelected,
            initialIsDebitSelected: _lIsDebitSelected,
            initialCashAmount: shouldAutoFillCash ? effectiveTotal.toStringAsFixed(2) : _lCashAmount,
            initialCardAmount: shouldAutoFillCard ? effectiveTotal.toStringAsFixed(2) : _lCardAmount,
            initialUpiAmount: shouldAutoFillUpi ? effectiveTotal.toStringAsFixed(2) : _lUpiAmount,
            initialCodAmount: shouldAutoFillCod ? effectiveTotal.toStringAsFixed(2) : _lCodAmount,
            initialDebitAmount: _lDebitAmount,
            initialTransactionNumber: _lTransactionNumber,
            cartTotal: effectiveTotal,
            customerPrevBalance: _localSelectedCustomer?.balance ?? 0.0,
            isDefaultCustomer: Provider.of<CustomerSelectionProvider>(context, listen: false).isDefaultCustomer,
            customButtonTitle: "Confirm Payment Selection",
            closeOnApply: false, // Don't close, just update state
            onPaymentMethodSelected: (isCash, isCard, isUpi, isCod, isDebit, cash, card, upi, cod, debit, trans, toCredit, {cashMethodId, cardMethodId, upiMethodId, codMethodId}) {
              _handlePaymentUpdate(
                isCash, isCard, isUpi, isCod, isDebit,
                cash, card, upi, cod, debit,
                trans, toCredit,
                cashMethodId: cashMethodId, cardMethodId: cardMethodId, upiMethodId: upiMethodId, codMethodId: codMethodId
              );
              _nextStep(); // Auto-advance on confirm
            },
          ),
        ),
        _buildFooter(
           onBack: _previousStep,
        ),
      ],
    );
  }

  // --- STEP 4: REVIEW ---
  Widget _buildReviewStep() {
    final bool hasCustomer = _localSelectedCustomer != null;
    final bool hasPayment = _hasPaymentMethod();
    final bool hasDiscount = _localIsCouponApplied || _localFlatDiscount > 0 || _localPercentageDiscount > 0;
    final bool hasDelivery = _lDeliveryMethod.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Status Checklist
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ready to Confirm',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please verify the details below before completing the order.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildReviewCheckItem(
                        'Customer Information', 
                        _localSelectedCustomer?.name ?? 'Guest Customer',
                        hasCustomer,
                        Icons.person_outline,
                      ),
                      if (widget.enableDelivery)
                        _buildReviewCheckItem(
                          'Delivery Method', 
                          _lDeliveryMethod,
                          hasDelivery,
                          Icons.local_shipping_outlined,
                        ),
                      _buildReviewCheckItem(
                        'Discounts Applied', 
                        hasDiscount 
                          ? (_localPercentageDiscount > 0 
                              ? '${_localPercentageDiscount.toStringAsFixed(0)}%' 
                              : _localFlatDiscount.toStringAsFixed(2))
                          : 'No Discounts Applied',
                        hasDiscount,
                        Icons.discount_outlined,
                      ),
                      _buildReviewCheckItem(
                        'Payment Selection', 
                        _hasPaymentMethod() ? 'Payment Methods Configured' : 'No Payment Configured',
                        hasPayment,
                        Icons.payment_outlined,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 48),
                
                // Right Side: Summary Card & Actions
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildReviewSummary(),
                      const Spacer(),
                      
                      // Action Buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: CustomRoundButtonWithIconAdvanced(
                                title: 'Print Bill',
                                isLoading: _isPrinting,
                                fct: () async {
                                   setState(() => _isPrinting = true);
                                   try {
                                     await widget.onConfirmAndPrint();
                                   } finally {
                                     if (mounted) setState(() => _isPrinting = false);
                                   }
                                },
                                size: MediaQuery.of(context).size,
                                icon: const Icon(Icons.print, color: Color(0xFFD97706), size: 20),
                                height: 54,
                                width: double.infinity,
                                fontSize: FontSize.s16,
                                boxColor: Colors.white,
                                borderColor: const Color(0xFFD97706),
                                textColor: const Color(0xFFD97706),
                                radius: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomRoundButtonWithIconAdvanced(
                                title: 'Confirm',
                                isLoading: _isConfirming,
                                fct: () async {
                                   setState(() => _isConfirming = true);
                                   try {
                                     await widget.onConfirmOrder();
                                   } finally {
                                     if (mounted) setState(() => _isConfirming = false);
                                   }
                                },
                                size: MediaQuery.of(context).size,
                                icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                height: 54,
                                width: double.infinity,
                                fontSize: FontSize.s16,
                                boxColor: const Color(0xFF2563EB),
                                borderColor: const Color(0xFF2563EB),
                                radius: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildFooter(
          onBack: _previousStep,
          isNextEnabled: false,
        ),
      ],
    );
  }

  Widget _buildReviewCheckItem(String title, String subtitle, bool isCompleted, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF059669).withOpacity(0.1) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : icon, 
              color: isCompleted ? const Color(0xFF059669) : Colors.grey.shade400,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 15,
                    color: isCompleted ? Colors.black87 : Colors.grey.shade500,
                  )
                ),
                Text(
                  subtitle, 
                  style: TextStyle(
                    fontSize: 13, 
                    color: isCompleted ? Colors.grey.shade600 : Colors.grey.shade400,
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSummary() {
    // Reconstruct summary logic locally for display
    final discountAmount = _localFlatDiscount + (widget.cartTotal * _localPercentageDiscount / 100);
    final effectiveTotal = widget.cartTotal - discountAmount;
    final totalPaid = (double.tryParse(_lCashAmount) ?? 0) + 
                      (double.tryParse(_lCardAmount) ?? 0) +
                      (double.tryParse(_lUpiAmount) ?? 0) +
                      (double.tryParse(_lCodAmount) ?? 0);
    
    // Minimal summary rows
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Order Total', widget.cartTotal, Colors.black87),
          const SizedBox(height: 8),
          // Always show Discount even if 0.0
          _buildSummaryRow('Discount', -discountAmount, discountAmount > 0 ? Colors.red.shade700 : Colors.grey.shade600),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildSummaryRow('Net Payable', effectiveTotal, Colors.black, isBold: true, large: true),
          const SizedBox(height: 20),
          _buildSummaryRow('Total Paid', totalPaid, const Color(0xFF059669)),
          const SizedBox(height: 8),
          _buildSummaryRow('Balance', totalPaid - effectiveTotal, 
             (totalPaid - effectiveTotal) >= 0 ? const Color(0xFF059669) : Colors.red.shade700, isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color, {bool isBold = false, bool large = false}) {
    final currency = Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: large ? 18 : 14,
            color: isBold ? Colors.black : Colors.grey.shade700,
          )
        ),
        Text(
          '$currency ${amount.toStringAsFixed(2)}', 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600, 
            fontSize: large ? 20 : 15,
            color: color
          )
        ),
      ],
    );
  }

  bool _hasPaymentMethod() {
    return _lIsCashSelected || _lIsCardSelected || _lIsUpiSelected || _lIsCodSelected || _lIsDebitSelected;
  }

  Widget _buildFooter({VoidCallback? onBack, VoidCallback? onNext, String nextLabel = 'Next', bool isNextEnabled = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              onPressed: onBack,
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            )
          else
            const SizedBox.shrink(),
            
          if (onNext != null)
            CustomRoundButtonWithIconAdvanced(
              title: nextLabel,
              fct: isNextEnabled ? onNext : () {},
              size: MediaQuery.of(context).size,
              icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              height: 45,
              width: 250,
              fontSize: FontSize.s16,
              boxColor: isNextEnabled ? const Color(0xFF2563EB) : Colors.grey.shade400,
              borderColor: isNextEnabled ? const Color(0xFF2563EB) : Colors.grey.shade400,
              radius: 30,
            )
        ],
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
  final Function(String, bool, {double? flatDiscount, double? percentageDiscount}) onCouponAction;

  const RestaurantCouponModalWrapper({
    super.key,
    required this.orderSubTotal,
    required this.initialCouponCode,
    required this.initialFlatDiscount,
    required this.initialPercentageDiscount,
    required this.isCouponApplied,
    required this.onCouponAction,
  });

  @override
  State<RestaurantCouponModalWrapper> createState() => _RestaurantCouponModalWrapperState();
}

class _RestaurantCouponModalWrapperState extends State<RestaurantCouponModalWrapper> {
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
        widget.initialPercentageDiscount != oldWidget.initialPercentageDiscount ||
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
