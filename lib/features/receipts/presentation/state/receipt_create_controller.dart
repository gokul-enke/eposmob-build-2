part of '../widgets/receipt_create_dialog.dart';

abstract class _ReceiptCreateController extends State<CreateReceiptModal> {
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _paymentReferenceController =
      TextEditingController();

  final FocusNode _paymentMethodFocus = FocusNode();
  final FocusNode _customerFocus = FocusNode();
  final FocusNode _paymentReferenceFocus = FocusNode();

  String? _selectedPaymentMethod;
  String? _selectedCustomer;

  final List<ReceiptItemCard> _receiptItemCards = [];
  late ReceiptItemCard _newItemCard;

  // Customer list for dropdown
  List<CustomerListModelData> _customerList = [];
  bool _isLoadingCustomers = false;

  // Invoice list for dropdown
  List<Invoice> _invoiceList = [];
  bool _isLoadingInvoices = false;

  // Payment methods from API
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  ReceiptEditorRepository get _repository => ReceiptEditorRepository(
        invoices: context.read<InvoiceProvider>(),
        customers: context.read<CustomerProvider>(),
        masterData: context.read<MasterDataProvider>(),
      );

  // Includes retired rows and editor drafts until the dialog is unmounted.
  // This avoids disposing controllers while outgoing widgets still use them.
  final Set<ReceiptItemCard> _ownedCards = {};

  @override
  void initState() {
    super.initState();
    // Set default values
    _totalAmountController.text = "0.00";
    // Payment method will be set dynamically in _loadPaymentMethods

    // Initialize new item card
    _newItemCard = ReceiptItemCard(defaultDescription: "");
    _ownedCards.add(_newItemCard);

    // Add listener to new item card's amount controller
    _newItemCard.amountController.addListener(_calculateTotalAmount);

    // Load customers, invoices, and payment methods
    _loadCustomers();
    _loadInvoices();
    _loadPaymentMethods();

    // Focus on Payment Method field on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_paymentMethodFocus);
    });
  }

  @override
  void dispose() {
    for (final card in _ownedCards) {
      card.amountController.removeListener(_calculateTotalAmount);
      card.dispose();
    }
    _ownedCards.clear();
    _totalAmountController.dispose();
    _paymentReferenceController.dispose();
    _paymentMethodFocus.dispose();
    _customerFocus.dispose();
    _paymentReferenceFocus.dispose();
    super.dispose();
  }

  // Calculate total amount from all receipt items
  void _calculateTotalAmount() {
    double total = 0.0;
    for (var card in _receiptItemCards) {
      final amount = double.tryParse(card.amountController.text) ?? 0.0;
      total += amount;
    }
    _totalAmountController.text = total.toStringAsFixed(2);
  }

  // Load customers from API
  void _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);

      if (authModel.token != null && authModel.token!.isNotEmpty) {
        final customers = await _repository.loadCustomers(authModel.token!);
        if (!mounted) return;

        setState(() {
          _customerList = customers;
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading customers: $e');
      setState(() {
        _isLoadingCustomers = false;
      });

      showScaffoldError(
        context: context,
        message: 'receipt.error_loading_customers'
            .tr
            .replaceAll('@error', e.toString()),
      );
    }
  }

  // Load payment methods from API
  void _loadPaymentMethods() async {
    setState(() {
      _isLoadingPaymentMethods = true;
    });

    try {
      final paymentMethods = await _repository.loadPaymentMethods();

      if (mounted && paymentMethods != null) {
        setState(() {
          _paymentMethods = paymentMethods;
          _isLoadingPaymentMethods = false;
          // Set default payment method if available
          if (_paymentMethods.isNotEmpty && _selectedPaymentMethod == null) {
            // Try to set CASH or COD as default, otherwise use first available
            final cashMethod =
                _paymentMethods.where((m) => m.value == 'CASH').firstOrNull;
            final codMethod =
                _paymentMethods.where((m) => m.value == 'COD').firstOrNull;
            if (cashMethod != null) {
              _selectedPaymentMethod = 'CASH';
            } else if (codMethod != null) {
              _selectedPaymentMethod = 'COD';
            } else {
              _selectedPaymentMethod = _paymentMethods.first.value;
            }
          }
        });
        debugPrint(
            '📋 [Receipt Modal] Payment methods loaded: $_paymentMethods');
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading payment methods: $e');
      setState(() {
        _isLoadingPaymentMethods = false;
      });
    }
  }

  // Load invoices from API
  void _loadInvoices() async {
    setState(() {
      _isLoadingInvoices = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);

      if (authModel.token != null && authModel.token!.isNotEmpty) {
        final invoices = await _repository.loadInvoices(authModel.token!);
        if (!mounted) return;

        setState(() {
          _invoiceList = invoices;
          _isLoadingInvoices = false;

          // Debug print invoice list
          debugPrint(
              '📋 [Receipt Modal] Total invoices loaded: ${_invoiceList.length}');
          debugPrint(
              '═══════════════════════════════════════════════════════════════');
          if (_invoiceList.isNotEmpty) {
            debugPrint('📋 [Receipt Modal] Detailed Invoice List:');
            for (var i = 0;
                i < (_invoiceList.length > 10 ? 10 : _invoiceList.length);
                i++) {
              final inv = _invoiceList[i];
              debugPrint('\n🧾 Invoice #$i:');
              debugPrint('  ├─ ID: ${inv.id}');
              debugPrint('  ├─ Invoice Number: ${inv.invoiceNumber}');
              debugPrint('  ├─ Type: ${inv.type}');
              debugPrint('  ├─ Amount: ${inv.amount}');
              debugPrint('  ├─ Status: ${inv.status}');
              debugPrint('  ├─ Invoice Date: ${inv.invoiceDate}');
              debugPrint('  ├─ Due Date: ${inv.dueDate}');
              debugPrint('  ├─ Customer ID: ${inv.customerId}');
              debugPrint('  ├─ Customer Name: ${inv.customer.user.name}');
              debugPrint('  ├─ Customer Email: ${inv.customer.user.email}');
              debugPrint('  ├─ Customer Phone: ${inv.customer.user.phone}');
              debugPrint('  ├─ Company ID: ${inv.companyId}');
              debugPrint('  ├─ Created By: ${inv.createdBy}');
              debugPrint('  ├─ Created At: ${inv.createdAt}');
              debugPrint('  ├─ Updated At: ${inv.updatedAt}');
              debugPrint('  ├─ User ID: ${inv.userId}');
              debugPrint('  └─ ZATCA Status: ${inv.zatcaStatus ?? "null"}');
            }
            if (_invoiceList.length > 10) {
              debugPrint('\n... and ${_invoiceList.length - 10} more invoices');
            }
          } else {
            debugPrint('⚠️ [Receipt Modal] No invoices found!');
          }
          debugPrint(
              '═══════════════════════════════════════════════════════════════');
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading invoices: $e');
      setState(() {
        _isLoadingInvoices = false;
      });

      showScaffoldError(
        context: context,
        message: 'receipt.error_loading_invoices'
            .tr
            .replaceAll('@error', e.toString()),
      );
    }
  }

  void _addNewReceiptItemCard() {
    // Validate inputs
    if (_newItemCard.amountController.text.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'receipt.enter_amount_required'.tr,
      );
      return;
    }

    if (_newItemCard.selectedItemType == "Invoice Payment" &&
        (_newItemCard.selectedInvoice == null ||
            _newItemCard.selectedInvoice!.isEmpty)) {
      showScaffoldError(
        context: context,
        message: 'receipt.select_invoice_required'.tr,
      );
      return;
    }

    // Validation: For invoice payments, paid amount cannot exceed balance amount
    if (_newItemCard.selectedItemType == "Invoice Payment") {
      final paid = double.tryParse(
              _newItemCard.amountController.text.trim().isEmpty
                  ? '0'
                  : _newItemCard.amountController.text.trim()) ??
          0.0;
      final balance = double.tryParse(
              _newItemCard.balanceAmountController.text.trim().isEmpty
                  ? '0'
                  : _newItemCard.balanceAmountController.text.trim()) ??
          0.0;
      if (paid > balance) {
        showScaffoldError(
          context: context,
          message: 'receipt.paid_exceeds_balance'
              .tr
              .replaceAll('@paid', paid.toStringAsFixed(2))
              .replaceAll('@balance', balance.toStringAsFixed(2)),
        );
        return;
      }
    }

    setState(() {
      // Add a copy of the new item card to the list
      final addedCard = ReceiptItemCard(
        defaultDescription: _newItemCard.descriptionController.text,
      );
      addedCard.selectedItemType = _newItemCard.selectedItemType;
      addedCard.selectedInvoice = _newItemCard.selectedInvoice;
      addedCard.itemTypeController.text = _newItemCard.itemTypeController.text;
      addedCard.invoiceController.text = _newItemCard.invoiceController.text;
      addedCard.invoiceAmountController.text =
          _newItemCard.invoiceAmountController.text;
      addedCard.balanceAmountController.text =
          _newItemCard.balanceAmountController.text;
      addedCard.paymentDateController.text =
          _newItemCard.paymentDateController.text;
      addedCard.amountController.text = _newItemCard.amountController.text;
      addedCard.descriptionController.text =
          _newItemCard.descriptionController.text;

      // Add listener to the new card's amount controller
      addedCard.amountController.addListener(_calculateTotalAmount);

      _ownedCards.add(addedCard);
      _receiptItemCards.add(addedCard);

      // Reset the new item card
      _newItemCard.amountController.clear();
      _newItemCard.descriptionController.text =
          "Item ${_receiptItemCards.length + 1}";
      _newItemCard.selectedItemType = "General Payment";
      _newItemCard.selectedInvoice = null;
      _newItemCard.invoiceAmountController.text = "0.00";
      _newItemCard.balanceAmountController.text = "0.00";
      _newItemCard.paymentDateController.text =
          DateTime.now().toIso8601String().split('T')[0];

      // Recalculate total
      _calculateTotalAmount();

      // Refocus on Item Type field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_newItemCard.itemTypeFocus);
      });
    });
  }

  void _removeReceiptItemCard(int index) {
    setState(() {
      // Remove listener before removing card
      _receiptItemCards[index]
          .amountController
          .removeListener(_calculateTotalAmount);
      _receiptItemCards.removeAt(index);
      // Recalculate total after removing
      _calculateTotalAmount();
    });
  }

  // Reset all items and change customer
  void _resetItemsAndChangeCustomer(String? newCustomer) {
    setState(() {
      // Remove listeners and dispose all existing cards
      for (var card in _receiptItemCards) {
        card.amountController.removeListener(_calculateTotalAmount);
      }
      _receiptItemCards.clear();

      // Reset the new item card
      _newItemCard.selectedInvoice = null;
      _newItemCard.invoiceAmountController.text = "0.00";
      _newItemCard.balanceAmountController.text = "0.00";
      _newItemCard.amountController.clear();
      _newItemCard.descriptionController.text = "Item 1";
      _newItemCard.selectedItemType = "General Payment";

      // Update customer
      _selectedCustomer = newCustomer;

      // Recalculate total (will be 0)
      _calculateTotalAmount();
    });

    // Move focus to payment reference
    FocusScope.of(context).requestFocus(_paymentReferenceFocus);
  }

  // Submit the receipt data
  void _submitReceipt() async {
    // Get the InvoiceProvider and AuthModel instances
    final repository = _repository;
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final accessToken = authModel.token;

    // Check if we have an access token
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'receipt.not_authenticated'.tr,
        );
      }
      return;
    }

    // Validate required fields
    if (_selectedCustomer == null || _selectedCustomer!.isEmpty) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'receipt.select_customer_required'.tr,
        );
      }
      return;
    }

    // Create receipt items list from the form data
    List<Map<String, dynamic>> receiptItems = [];
    for (var card in _receiptItemCards) {
      // Validate item fields
      if (card.selectedItemType == null || card.selectedItemType!.isEmpty) {
        if (mounted) {
          showScaffoldError(
            context: context,
            message: 'receipt.select_item_type_required'.tr,
          );
        }
        return;
      }

      final itemType = card.selectedItemType?.toLowerCase() ?? 'general';

      // Map dropdown values to backend expected values
      String apiItemType;
      if (itemType.contains('invoice')) {
        apiItemType = 'invoice';
      } else {
        apiItemType = 'general';
      }

      // Validation: For invoice payments, paid amount cannot exceed balance amount
      if (apiItemType == 'invoice') {
        final paid = double.tryParse(card.amountController.text.trim().isEmpty
                ? '0'
                : card.amountController.text.trim()) ??
            0.0;
        final balance = double.tryParse(
                card.balanceAmountController.text.trim().isEmpty
                    ? '0'
                    : card.balanceAmountController.text.trim()) ??
            0.0;
        if (paid > balance) {
          if (mounted) {
            showScaffoldError(
              context: context,
              message: 'receipt.paid_exceeds_balance_currency'
                  .tr
                  .replaceAll('@paid', paid.toStringAsFixed(2))
                  .replaceAll('@balance', balance.toStringAsFixed(2)),
            );
          }
          return;
        }
      }

      receiptItems.add(card.snapshot.toApi(
        paymentMethodId: _getPaymentMethodId(_selectedPaymentMethod),
      ));
    }

    try {
      debugPrint(
          '🧾 Submitting receipt for customer $_selectedCustomer with ${receiptItems.length} item(s) and status paid');
      debugPrint(
          '📦 Receipt payload preview: ${receiptItems.map((item) => '{type: ${item['item_type']}, paid_amount: ${item['paid_amount']}, payment_date: ${item['payment_date']}}').toList()}');
      if (_paymentReferenceController.text.isNotEmpty) {
        debugPrint('💳 Payment Reference: ${_paymentReferenceController.text}');
      }

      // Call the addReceipt method
      final result = await repository.createReceipt(
        customerId: _selectedCustomer!,
        receiptStatus: 'paid',
        receiptItems: receiptItems,
        accessToken: accessToken,
        paymentReference: _paymentReferenceController.text.isNotEmpty
            ? _paymentReferenceController.text
            : null,
      );

      // Handle success
      debugPrint('✅ Receipt created successfully: $result');
      if (mounted) {
        showScaffold(
          context: context,
          message: 'receipt.created_successfully'.tr,
        );
        Navigator.pop(context, true); // Close the modal and return success
      }
    } catch (e) {
      // Handle error
      debugPrint('❌ Error creating receipt: $e');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'receipt.error_creating_receipt'
              .tr
              .replaceAll('@error', e.toString()),
        );
      }
    }
  }

  String _getInvoiceNumber(String? invoiceId) {
    if (invoiceId == null) return "-";
    try {
      final invoice = _invoiceList.firstWhere(
        (inv) => inv.id.toString() == invoiceId,
      );
      return invoice.invoiceNumber;
    } catch (e) {
      return "-";
    }
  }

  // Helper method to get payment method ID for API
  // Finds the ID for the given payment method value
  int? _getPaymentMethodId(String? paymentMethodValue) {
    if (paymentMethodValue == null || _paymentMethods.isEmpty) return null;
    try {
      return _paymentMethods
          .firstWhere((m) => m.value == paymentMethodValue)
          .id;
    } catch (e) {
      return null;
    }
  }

  void _saveItemEditor(
      ReceiptItemCard tempCard, ReceiptItemCard? item, int? index) {
    if (!mounted) return;
    setState(() {
      if (item != null && index != null) {
        final existing = _receiptItemCards[index];
        existing.selectedItemType = tempCard.selectedItemType;
        existing.selectedInvoice = tempCard.selectedInvoice;
        existing.descriptionController.text =
            tempCard.descriptionController.text;
        existing.paymentDateController.text =
            tempCard.paymentDateController.text;
        existing.amountController.text = tempCard.amountController.text;
        existing.invoiceAmountController.text =
            tempCard.invoiceAmountController.text;
      } else {
        _receiptItemCards.add(tempCard);
        tempCard.amountController.addListener(_calculateTotalAmount);
      }
      _calculateTotalAmount();
    });
  }
}
