part of '../pages/customer_report_details_page.dart';

/// Existing display behavior plus independent export readiness tracking.
mixin CustomerReportDetailsState<T extends StatefulWidget> on State<T> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  bool _showFilters = true;
  // Export eligibility is separate from the legacy display/print behavior.
  bool _exportDataReady = false;
  int _exportRevision = 0;
  ({String id, String name})? _exportLoadedCustomer;
  ({String token, String? tenant, int? store})? _exportLoadedSession;
  SharedPreferences? _exportPreferences;
  List<ListTransaction>? allTransactions = [];
  List<ListTransaction>? filteredTransactions = [];

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  // Controllers for filters
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _transactionTypeController =
      TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Filter variables (like in transaction_list.dart)
  String searchTransactionType = '';
  String searchStatus = '';
  String searchType = '';
  String searchCustomer = '';

  // Customer suggestions for autocomplete
  List<String> customerSuggestions = [];

  // Timer for debouncing customer search
  Timer? _customerSearchTimer;

  // For dropdown options - updated to match actual data values
  List<String> transactionTypes = ['Receipt', 'Invoice', 'Voucher'];
  List<String> statuses = [
    'SUCC',
    'FAIL',
    'INIT',
  ];
  List<String> types = ['Credit', 'Debit'];

  /// Helper function to get translated label for dropdown values
  String _getTranslatedLabel(String value) {
    final labelMap = {
      'Receipt': 'transaction_status_labels.receipt'.tr,
      'Invoice': 'transaction_status_labels.invoice'.tr,
      'Voucher': 'transaction_status_labels.voucher'.tr,
      'SUCC': 'transaction_status_labels.succ'.tr,
      'FAIL': 'transaction_status_labels.fail'.tr,
      'INIT': 'transaction_status_labels.init'.tr,
      'Credit': 'transaction_status_labels.credit'.tr,
      'Debit': 'transaction_status_labels.debit'.tr,
    };
    return labelMap[value] ?? value;
  }

  List<String> getCustomerSuggestions() {
    if (allTransactions == null) return [];
    final suggestions = allTransactions!
        .map((t) => t.customerName ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    // Limit to 100 suggestions for better performance
    if (suggestions.length > 100) {
      return suggestions.take(100).toList();
    }

    return suggestions;
  }

  @override
  void initState() {
    super.initState();
    // Set the customer name from the TransactionProvider instead of sidebar controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final customerName =
          Provider.of<TransactionProvider>(context, listen: false).customerName;
      setState(() {
        searchCustomer = customerName;
        _customerController.text = customerName;
        _showFilters = !_isMobile(context);
      });
      // Set default date values
      _setInitialDateFilters();
      loadInitData(); // This will now work properly
    });
  }

  // Add the missing loadInitData method
  Future<void> loadInitData() async {
    if (!mounted) return;
    setState(() {
      initLoading = true;
      _exportDataReady = false;
      _exportRevision++;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final selectedIdStr = customerProvider.selectedCustomerId;
      final exportCustomer = (
        id: (selectedIdStr ?? '').trim(),
        name: context.read<TransactionProvider>().customerName,
      );
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _exportPreferences = prefs;
      final exportSession = (
        token: accessToken ?? '',
        tenant: prefs.getString('api_key'),
        store: prefs.getInt('active_store_id'),
      );

      final value = await invoiceProvider.listAllTransaction(
        type: null,
        accessToken: accessToken ?? "",
        customerId: selectedIdStr,
        customerName: selectedIdStr == null || selectedIdStr.isEmpty
            ? (searchCustomer.isNotEmpty ? searchCustomer : null)
            : null,
      );

      if (!mounted) return;

      if (value['status'] == 'success') {
        final data = value['data'];
        // If new grouped response, extract the selected customer's transactions
        if (data is Map && data['data'] is List) {
          final groups = (data['data'] as List).cast<dynamic>();
          final selectedName = searchCustomer;

          Map? matchedGroup;
          for (final g in groups) {
            if (g is! Map) continue;
            final idStr = (g['customer_id']?.toString() ?? '').trim();
            final nameStr = (g['customer_name'] ?? '').toString();
            final idMatches = (selectedIdStr != null &&
                selectedIdStr.isNotEmpty &&
                idStr == selectedIdStr);
            final nameMatches =
                (selectedIdStr == null || selectedIdStr.isEmpty) &&
                    selectedName.isNotEmpty &&
                    nameStr.toLowerCase() == selectedName.toLowerCase();
            if (idMatches || nameMatches) {
              matchedGroup = g;
              break;
            }
          }

          // Map group's transactions into ListTransaction model for UI reuse
          final List<ListTransaction> txns = [];
          if (matchedGroup != null && matchedGroup['transactions'] is List) {
            for (final t in (matchedGroup['transactions'] as List)) {
              if (t is Map<String, dynamic>) {
                // Coerce numeric fields that the model expects as String
                final coerced = Map<String, dynamic>.from(t);
                if (coerced.containsKey('amount') &&
                    coerced['amount'] != null) {
                  coerced['amount'] = coerced['amount'].toString();
                }
                if (coerced.containsKey('balance') &&
                    coerced['balance'] != null) {
                  coerced['balance'] = coerced['balance'].toString();
                }
                txns.add(ListTransaction.fromJson({
                  ...coerced,
                  'order_number': coerced['order_number'],
                  'reference_id':
                      coerced['reference_id'] ?? coerced['reference'],
                  'transaction_type': coerced['transaction_type'],
                  'customer_name': matchedGroup['customer_name'],
                  'customer_id': matchedGroup['customer_id'],
                }));
              } else if (t is Map) {
                final m = Map<String, dynamic>.from(t);
                if (m.containsKey('amount') && m['amount'] != null) {
                  m['amount'] = m['amount'].toString();
                }
                if (m.containsKey('balance') && m['balance'] != null) {
                  m['balance'] = m['balance'].toString();
                }
                txns.add(ListTransaction.fromJson({
                  ...m,
                  'order_number': m['order_number'],
                  'reference_id': m['reference_id'] ?? m['reference'],
                  'transaction_type': m['transaction_type'],
                  'customer_name': matchedGroup['customer_name'],
                  'customer_id': matchedGroup['customer_id'],
                }));
              }
            }
          }

          allTransactions = txns;
          // Populate suggestions (optional from groups)
          customerSuggestions = groups
              .map((e) =>
                  (e is Map ? (e['customer_name'] ?? '').toString() : ''))
              .where((s) => s.isNotEmpty)
              .cast<String>()
              .toList();

          // Apply filters on the newly built transactions
          _applyFilters();
        } else {
          // Fallback to old flat response
          ListTransactionModel listTransactionModel =
              ListTransactionModel.fromJson(value);
          allTransactions = listTransactionModel.data?.transactions ?? [];

          // Populate customer suggestions
          customerSuggestions = getCustomerSuggestions();

          // Apply filters immediately to show only transactions for the selected customer
          _applyFilters();
        }
        _exportLoadedCustomer = exportCustomer;
        _exportLoadedSession = exportSession;
        _exportDataReady = true;
      } else {
        if (mounted) {
          AppToast.error(context,
              'customer_transaction_report.failed_load_transaction_data'.tr);
        }
      }
    } catch (error) {
      debugPrint("Error loading transactions: $error");
      if (mounted) {
        AppToast.error(
            context,
            'customer_transaction_report.err_loading_transactions'
                .tr
                .replaceAll('@error', error.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  // Set default date values: empty (no date filter)
  void _setInitialDateFilters() {
    setState(() {
      _fromDateController.text = '';
      _toDateController.text = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
    });
  }

  void _applyFilters() {
    _exportRevision++;
    if (allTransactions == null || allTransactions!.isEmpty) {
      setState(() {
        filteredTransactions = [];
      });
      return;
    }

    // Apply filters
    List<ListTransaction> filteredList = [...allTransactions!];

    // Customer filter not needed on details page; transactions already for the selected customer

    // Transaction type filter - use contains matching instead of exact match
    if (searchTransactionType.isNotEmpty && searchTransactionType != 'All') {
      filteredList = filteredList
          .where((transaction) => (transaction.transactionType ?? '')
              .toLowerCase()
              .contains(searchTransactionType.toLowerCase()))
          .toList();
    }

    // Status filter - use contains matching instead of exact match
    if (searchStatus.isNotEmpty && searchStatus != 'All') {
      filteredList = filteredList
          .where((transaction) => (transaction.status ?? '')
              .toLowerCase()
              .contains(searchStatus.toLowerCase()))
          .toList();
    }

    // Type filter - use contains matching instead of exact match
    if (searchType.isNotEmpty && searchType != 'All') {
      filteredList = filteredList
          .where((transaction) => (transaction.type ?? '')
              .toLowerCase()
              .contains(searchType.toLowerCase()))
          .toList();
    }

    // Date range filter
    if (_fromDateController.text.isNotEmpty ||
        _toDateController.text.isNotEmpty) {
      try {
        final formatter = DateFormat('yyyy-MM-dd');

        filteredList = filteredList.where((transaction) {
          if (transaction.date == null) return false;

          try {
            final transactionDate = formatter.parse(transaction.date!);

            // If from date is set, check that transaction date is not before it
            if (_fromDateController.text.isNotEmpty) {
              final fromDate = formatter.parse(_fromDateController.text);
              if (transactionDate.isBefore(fromDate)) return false;
            }

            // If to date is set, check that transaction date is not after it
            if (_toDateController.text.isNotEmpty) {
              final toDate = formatter.parse(_toDateController.text);
              // Treat the selected end date as inclusive for business users.
              final toDateExclusive = toDate.add(const Duration(days: 1));
              if (!transactionDate.isBefore(toDateExclusive)) return false;
            }

            return true;
          } catch (e) {
            debugPrint('Date parsing error for transaction: $e');
            return false;
          }
        }).toList();
      } catch (e) {
        debugPrint('Date parsing error: $e');
      }
    }

    setState(() {
      filteredTransactions = filteredList;
    });
  }

  void _resetFilters() {
    // Cancel any pending search
    _customerSearchTimer?.cancel();

    // Clear the text controllers for dropdown filters
    _transactionTypeController.clear();
    _statusController.clear();
    _typeController.clear();
    _customerController.clear();

    // Reset the search variables for dropdown filters
    setState(() {
      searchTransactionType = '';
      searchStatus = '';
      searchType = '';
      searchCustomer = '';

      // Reset date filters to default values
      _setInitialDateFilters();
    });

    // Apply filters after resetting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _transactionTypeController.dispose();
    _statusController.dispose();
    _typeController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _customerSearchTimer?.cancel();
    super.dispose();
  }
}
