part of '../widgets/invoice_create_dialog.dart';

abstract class _InvoiceCreateController extends State<CreateInvoiceModal> {
  // Controllers
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();

  // Focus Nodes - Flow: Type -> Due Date -> Invoice Date -> Status -> Customer -> Item Fields
  final FocusNode _typeFocus = FocusNode();
  final FocusNode _dueDateFocus = FocusNode();
  final FocusNode _invoiceDateFocus = FocusNode();
  final FocusNode _statusFocus = FocusNode();
  final FocusNode _customerFocus = FocusNode();

  // Selected values
  String? _selectedType;
  String? _selectedStatus;
  String? _selectedCustomer;

  // Loading state
  bool _isSubmitting = false;
  bool _submissionInProgress = false;

  // Customer data
  List<CustomerListModelData> _customerList = [];
  bool _isLoadingCustomers = false;

  // Payment methods
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;
  String? _selectedPaymentMethod;
  final FocusNode _paymentMethodFocus = FocusNode();

  // Invoice items
  final List<InvoiceItemCard> _invoiceItemCards = [];
  late InvoiceItemCard _newItemCard;

  // Financial Summary Totals
  double _netTotal = 0.0;
  double _totalTax = 0.0;
  double _totalPayable = 0.0;
  double _discount = 0.0;
  double _discountPercentage = 0.0;
  String _couponCode = "";
  bool _isCouponApplied = false;

  @override
  void initState() {
    super.initState();
    // Set default values
    _totalAmountController.text = "0";
    _dueDateController.text = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String()
        .split('T')[0];
    _invoiceDateController.text = DateTime.now().toIso8601String().split(
          'T',
        )[0];
    _selectedType = "other";
    _selectedStatus = "Pending";

    // Initialize new item card for inline form
    _newItemCard = InvoiceItemCard();
    _newItemCard.totalController.addListener(_calculateInvoiceTotal);

    // Load customers and payment methods
    _loadCustomers();
    _loadPaymentMethods();

    // Auto-focus on Type dropdown when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_typeFocus);
    });
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _dueDateController.dispose();
    _invoiceDateController.dispose();

    _typeFocus.dispose();
    _dueDateFocus.dispose();
    _invoiceDateFocus.dispose();
    _statusFocus.dispose();
    _customerFocus.dispose();
    _paymentMethodFocus.dispose();

    _newItemCard.totalController.removeListener(_calculateInvoiceTotal);
    _newItemCard.dispose();

    for (var card in _invoiceItemCards) {
      card.totalController.removeListener(_calculateInvoiceTotal);
      card.dispose();
    }

    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final customerProvider = Provider.of<CustomerProvider>(
        context,
        listen: false,
      );
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final customers = await customerProvider.fetchAllCustomersSnapshot(
        accessToken: authModel.token ?? '',
      );
      if (mounted) {
        setState(() {
          _customerList = customers;
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
      debugPrint("Error loading customers: $e");
    }
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoadingPaymentMethods = true;
    });

    try {
      final masterDataProvider = Provider.of<MasterDataProvider>(
        context,
        listen: false,
      );

      final paymentMethods = await masterDataProvider.fetchPaymentMethods();

      if (!mounted) return;
      if (paymentMethods == null) {
        setState(() => _isLoadingPaymentMethods = false);
        return;
      }
      if (mounted) {
        setState(() {
          _paymentMethods = paymentMethods;
          _isLoadingPaymentMethods = false;
          // Set default payment method if available
          if (_paymentMethods.isNotEmpty && _selectedPaymentMethod == null) {
            // Try to set CASH as default, otherwise use first available
            final cashMethod =
                _paymentMethods.where((m) => m.value == 'CASH').firstOrNull;
            if (cashMethod != null) {
              _selectedPaymentMethod = 'CASH';
            } else {
              _selectedPaymentMethod = _paymentMethods.first.value;
            }
          }
        });
        debugPrint(
          '📋 [Invoice Modal] Payment methods loaded: $_paymentMethods',
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading payment methods: $e');
      setState(() {
        _isLoadingPaymentMethods = false;
      });
    }
  }

  // Get payment method ID from value
  int? _getPaymentMethodId(String? paymentMethodValue) {
    if (paymentMethodValue == null) return null;
    try {
      return _paymentMethods
          .firstWhere((m) => m.value == paymentMethodValue)
          .id;
    } catch (e) {
      return null;
    }
  }

  // Get customer balance by ID
  double _getCustomerBalance(String? customerId) {
    if (customerId == null) return 0.0;
    final customer = _customerList.firstWhere(
      (c) => c.id?.toString() == customerId,
      orElse: () => CustomerListModelData(id: 0, name: 'general.unknown'.tr),
    );
    return customer.balance ?? 0.0;
  }

  void _calculateInvoiceTotal() {
    final totals = InvoiceFormTotals.calculate(
      _invoiceItemCards.map((card) => card.snapshot),
      flatDiscount: _discount,
      percentageDiscount: _discountPercentage,
    );
    setState(() {
      _netTotal = totals.net;
      _totalTax = totals.tax;
      _discount = totals.discount;
      _totalPayable = totals.payable;

      _totalAmountController.text = _totalPayable.toStringAsFixed(2);
    });
  }

  void _addNewInvoiceItemCard() {
    // Validate new item
    if (_newItemCard.itemNameController.text.isEmpty) {
      showScaffold(context: context, message: 'invoice.enter_item_name'.tr);
      return;
    }

    setState(() {
      // Create new card and copy values
      final newCard = InvoiceItemCard();
      newCard.itemNameController.text = _newItemCard.itemNameController.text;
      newCard.unitAmountController.text =
          _newItemCard.unitAmountController.text;
      newCard.taxController.text = _newItemCard.taxController.text;
      newCard.quantityController.text = _newItemCard.quantityController.text;
      newCard.totalController.text = _newItemCard.totalController.text;

      // Add listener for total calculation
      newCard.totalController.addListener(_calculateInvoiceTotal);

      _invoiceItemCards.add(newCard);

      // Reset new item card
      _newItemCard.itemNameController.clear();
      _newItemCard.unitAmountController.text = "0";
      _newItemCard.taxController.text = "0";
      _newItemCard.quantityController.text = "1";
      _newItemCard.totalController.text = "0";

      // Recalculate total
      _calculateInvoiceTotal();
    });

    // Refocus on item name for next entry
    FocusScope.of(context).requestFocus(_newItemCard.itemNameFocus);
  }

  void _removeInvoiceItemCard(int index) {
    setState(() {
      _invoiceItemCards[index].totalController.removeListener(
            _calculateInvoiceTotal,
          );
      _invoiceItemCards[index].dispose();
      _invoiceItemCards.removeAt(index);
      _calculateInvoiceTotal();
    });
  }

  Future<void> _submitInvoice() async {
    if (_submissionInProgress) return;
    _submissionInProgress = true;
    try {
      await _submitInvoiceOnce();
    } finally {
      _submissionInProgress = false;
    }
  }

  Future<void> _submitInvoiceOnce() async {
    if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(context)) {
      return;
    }
    if (!mounted) return;
    // Validate
    if (_selectedCustomer == null) {
      showScaffoldError(
        context: context,
        message: 'invoice.select_customer_required'.tr,
      );
      return;
    }
    if (_invoiceItemCards.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'invoice.add_at_least_one_item'.tr,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final repository = InvoiceEditorRepository(
        Provider.of<InvoiceProvider>(context, listen: false),
      );

      // Build invoice_items array
      final invoiceItems =
          _invoiceItemCards.map((card) => card.snapshot.toJson()).toList();

      final response = await repository.createInvoice(
        customerId: int.tryParse(_selectedCustomer!) ?? 0,
        type: _selectedType?.toLowerCase() ?? "other",
        dueDate: _dueDateController.text,
        invoiceDate: _invoiceDateController.text,
        amount: double.tryParse(_totalAmountController.text) ?? 0.0,
        status: _selectedStatus?.toLowerCase() ?? "pending",
        paymentMethod: _getPaymentMethodId(_selectedPaymentMethod) ??
            206, // Use selected or default
        invoiceItems: invoiceItems,
        accessToken: authModel.token ?? "",
        // Discount data
        couponId: _isCouponApplied ? _couponCode : null,
        flatDiscount: _discountPercentage == 0 ? _discount : null,
        percentageDiscount:
            _discountPercentage > 0 ? _discountPercentage : null,
        discountAmount: _discount,
      );

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      if (await SubscriptionActionGuard.handleBackendResponse(
        context,
        response,
      )) {
        return;
      }

      if (!mounted) return;

      // Check for both boolean true and string "success"
      final isSuccess = response != null &&
          (response["status"] == true || response["status"] == "success");

      if (isSuccess) {
        Navigator.pop(context, true);
        showScaffold(
          context: context,
          message: response["message"] ?? 'invoice.created_successfully'.tr,
        );
      } else {
        showScaffoldError(
          context: context,
          message: response?["message"] ?? 'invoice.create_failed'.tr,
        );
      }
    } catch (e) {
      debugPrint("Error submitting invoice: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        showScaffoldError(
          context: context,
          message: 'invoice.error_generic'.tr.replaceAll(
                '@error',
                e.toString(),
              ),
        );
      }
    }
  }
}
