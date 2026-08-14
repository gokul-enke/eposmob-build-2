import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/reports/customer_transactions_reports/transaction_report_print.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
// Add this import for CalendarPickerTableCell component
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:intl/intl.dart';

class CustomerTransactionsWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData customer;

  const CustomerTransactionsWidget({
    super.key,
    required this.size,
    required this.customer,
  });

  @override
  State<CustomerTransactionsWidget> createState() =>
      _CustomerTransactionsWidgetState();
}

class _CustomerTransactionsWidgetState
    extends State<CustomerTransactionsWidget> {
  List<CustomerTransaction> transactions = [];
  List<CustomerTransaction> filteredTransactions = [];

  bool _isLoading = false;
  int _currentPage = 1;
  int _lastPage = 1;
  final int _perPage = 20;

  // Controllers for filters
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Filter values
  String? _filterReference;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String? _filterType; // Credit/Debit filter

  // For dropdown options
  List<String> transactionTypes = ['Credit', 'Debit'];

  // Filter panel visibility
  bool _isFilterPanelVisible = false;

  @override
  void initState() {
    super.initState();
    transactions = widget.customer.transactions ?? [];
    filteredTransactions = List.from(transactions);
    _applyFilters();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions(page: 1, showLoader: true);
    });
  }

  @override
  void didUpdateWidget(covariant CustomerTransactionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.id != widget.customer.id) {
      _loadTransactions(page: 1, showLoader: true);
    }
  }

  // Helper method to determine if transaction is credit or debit
  bool _isCreditTransaction(CustomerTransaction transaction) {
    return transaction.type?.toLowerCase() == 'credit' ||
        (transaction.amount != null && transaction.amount!.contains('+'));
  }

  Future<void> _loadTransactions({
    required int page,
    bool showLoader = false,
  }) async {
    final token = Provider.of<AuthModel>(context, listen: false).token;
    final customerId = widget.customer.id?.toString();

    if (token == null ||
        token.isEmpty ||
        customerId == null ||
        customerId.isEmpty) {
      return;
    }

    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      final response = await invoiceProvider.listCustomerTransactions(
        accessToken: token,
        customerId: customerId,
        dateFrom: _filterFromDate != null
            ? DateFormat('yyyy-MM-dd').format(_filterFromDate!)
            : null,
        dateTo: _filterToDate != null
            ? DateFormat('yyyy-MM-dd').format(_filterToDate!)
            : null,
        type: _filterType?.toLowerCase(),
        perPage: _perPage,
        page: page,
      );

      final data = response['data'];
      final rows = (data is Map && data['data'] is List)
          ? data['data'] as List
          : const [];

      final parsedTransactions = rows
          .whereType<Map>()
          .map((row) =>
              CustomerTransaction.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      if (!mounted) return;

      setState(() {
        transactions = parsedTransactions;
        _currentPage = (data is Map && data['current_page'] is num)
            ? (data['current_page'] as num).toInt()
            : page;
        _lastPage = (data is Map && data['last_page'] is num)
            ? (data['last_page'] as num).toInt()
            : 1;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('Failed to load customer transactions: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Apply local filters on top of API results
  void _applyFilters() {
    setState(() {
      filteredTransactions = transactions.where((transaction) {
        // Reference filter
        if (_filterReference != null && _filterReference!.isNotEmpty) {
          if (transaction.reference == null ||
              !transaction.reference!
                  .toLowerCase()
                  .contains(_filterReference!.toLowerCase())) {
            return false;
          }
        }

        // Date range filter
        if (_filterFromDate != null || _filterToDate != null) {
          if (transaction.date == null) return false;

          try {
            final transactionDate =
                DateFormat('yyyy-MM-dd').parse(transaction.date!);

            // If from date is set, check that transaction date is not before it
            if (_filterFromDate != null &&
                transactionDate.isBefore(_filterFromDate!)) {
              return false;
            }

            // If to date is set, check that transaction date is not after it
            if (_filterToDate != null &&
                transactionDate.isAfter(_filterToDate!)) {
              return false;
            }
          } catch (e) {
            debugPrint('Date parsing error for transaction: $e');
            return false;
          }
        }

        // Type filter (Credit/Debit)
        if (_filterType != null && _filterType!.isNotEmpty) {
          bool isCredit = _isCreditTransaction(transaction);
          if (_filterType == 'Credit' && !isCredit) {
            return false;
          }
          if (_filterType == 'Debit' && isCredit) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  // Reset all filters
  void _resetFilters() {
    _referenceController.clear();
    _fromDateController.clear();
    _toDateController.clear();

    setState(() {
      _filterReference = null;
      _filterFromDate = null;
      _filterToDate = null;
      _filterType = null;
      _isFilterPanelVisible = false;
    });

    _loadTransactions(page: 1, showLoader: true);
  }

  // Toggle filter panel visibility
  void _toggleFilterPanel() {
    setState(() {
      _isFilterPanelVisible = !_isFilterPanelVisible;
      // Set initial values for the controllers when panel opens
      if (_isFilterPanelVisible) {
        _referenceController.text = _filterReference ?? '';
        _fromDateController.text = _filterFromDate != null
            ? DateFormat('yyyy-MM-dd').format(_filterFromDate!)
            : '';
        _toDateController.text = _filterToDate != null
            ? DateFormat('yyyy-MM-dd').format(_filterToDate!)
            : '';
      }
    });
  }

  // Apply filters and close panel
  void _applyFiltersAndClose() {
    _loadTransactions(page: 1, showLoader: true);
    setState(() {
      _isFilterPanelVisible = false;
    });
  }

  void _onPageChanged(int page) {
    if (page < 1 || page > _lastPage || page == _currentPage) return;
    _loadTransactions(page: page, showLoader: true);
  }

  // Print function similar to the one in simple_transaction_details_screen
  void _printReport() async {
    debugPrint("===== CUSTOMER TRANSACTIONS WIDGET - PRINT REPORT DEBUG =====");
    debugPrint("Starting print report generation...");
    debugPrint("Total transactions: ${transactions.length}");
    debugPrint("Filtered transactions: ${filteredTransactions.length}");

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('customer_transactions.msg_preparing_report'.tr),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }

    // Fetch customer details
    String customerName = widget.customer.name ?? "";
    String customerPhone = widget.customer.phone ?? "";
    String customerEmail = widget.customer.email ?? "";

    debugPrint("\n--- Customer Details ---");
    debugPrint("Customer Name: '$customerName'");
    debugPrint("Customer Phone: '$customerPhone'");
    debugPrint("Customer Email: '$customerEmail'");

    // Build complete address
    List<String> addressParts = [];
    if (widget.customer.address != null &&
        widget.customer.address!.isNotEmpty) {
      addressParts.add(widget.customer.address!);
    }
    if (widget.customer.city != null && widget.customer.city!.isNotEmpty) {
      addressParts.add(widget.customer.city!);
    }
    if (widget.customer.state != null && widget.customer.state!.isNotEmpty) {
      addressParts.add(widget.customer.state!);
    }
    if (widget.customer.pincode != null &&
        widget.customer.pincode!.isNotEmpty) {
      addressParts.add(widget.customer.pincode!);
    }
    if (widget.customer.country != null &&
        widget.customer.country!.isNotEmpty) {
      addressParts.add(widget.customer.country!);
    }

    String customerAddress = addressParts.join(", ");
    debugPrint("Customer Address: '$customerAddress'");

    // Convert CustomerTransaction objects to the format expected by the print page
    debugPrint("\n--- Converting Transactions to Map Format ---");
    List<Map<String, dynamic>> cartItems =
        filteredTransactions.asMap().entries.map((entry) {
      int index = entry.key;
      var transaction = entry.value;

      debugPrint("Transaction $index:");
      debugPrint("  - ID: ${transaction.id}");
      debugPrint("  - Order ID: ${transaction.orderId}");
      debugPrint("  - Order Number: '${transaction.orderNumber}'");
      debugPrint("  - Date: ${transaction.date}");
      debugPrint("  - Type: ${transaction.type}");
      debugPrint("  - Transaction Type: ${transaction.transactionType}");
      debugPrint("  - Amount: ${transaction.amount}");
      debugPrint("  - Status: ${transaction.status}");

      return {
        'id': transaction.id,
        'order_id': transaction.orderId,
        'order_number': transaction.orderNumber,
        'payment_method': transaction.paymentMethod,
        'date': transaction.date,
        'type': transaction.type,
        'reference_id': transaction.referenceId,
        'transaction_type': transaction.transactionType,
        'amount': transaction.amount,
        'currency': transaction.currency,
        'reference': transaction.reference,
        'transaction_comment': transaction.transactionComment,
        'status': transaction.status,
      };
    }).toList();

    // Calculate totals
    debugPrint("\n--- Calculating Totals ---");
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var transaction in filteredTransactions) {
      double amount = double.tryParse(
              transaction.amount?.replaceAll('+', '').replaceAll('-', '') ??
                  "0.00") ??
          0.0;
      bool isCredit = _isCreditTransaction(transaction);

      if (isCredit) {
        totalCredit += amount;
      } else {
        totalDebit += amount;
      }
    }

    // Calculate total amount (for backwards compatibility)
    double totalAmount = totalCredit - totalDebit;

    debugPrint("Total Credit: ${totalCredit.toStringAsFixed(2)}");
    debugPrint("Total Debit: ${totalDebit.toStringAsFixed(2)}");
    debugPrint("Balance: ${totalAmount.toStringAsFixed(2)}");

    // Calculate saved amount (for this report, we'll set it to 0)
    double savedAmount = 0.0;

    // Get current date and time for the report
    String orderDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateHelper.now());
    String orderNumber =
        "TXN-REPORT-${DateHelper.now().millisecondsSinceEpoch}";

    // Get date range values
    String? fromDate =
        _fromDateController.text.isNotEmpty ? _fromDateController.text : null;
    String? toDate =
        _toDateController.text.isNotEmpty ? _toDateController.text : null;

    debugPrint("\n--- Date Range ---");
    debugPrint("From Date: ${fromDate ?? 'Not set'}");
    debugPrint("To Date: ${toDate ?? 'Not set'}");

    debugPrint("\n--- Navigating to Print Page ---");
    debugPrint("Cart Items Count: ${cartItems.length}");
    debugPrint("Total Amount: ${totalAmount.toStringAsFixed(2)}");
    debugPrint("Order Number: $orderNumber");
    debugPrint("===== END CUSTOMER TRANSACTIONS WIDGET DEBUG =====\n");

    // Navigate to the print page with the transaction data
    Get.to(() => TransactionReportPrintPage(
          cartItems: cartItems, // Pass the converted data
          formattedTotal: totalAmount.toStringAsFixed(2),
          savedTotal: savedAmount.toStringAsFixed(2),
          orderDate: orderDate,
          orderNumber: orderNumber,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: customerEmail,
          customerAddress: customerAddress,
          fromDate: fromDate,
          toDate: toDate,
          isFromLocalStorage:
              false, // Set to false since we're converting to Map format
          // Ensure we return to the previous route (Customer Profile > Transactions)
          returnToPreviousRoute: true,
        ));

    // Show a message that the print process has started
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('customer_transactions.msg_preparing_print'.tr),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: EdgeInsets.all(widget.size.width < 600 ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: widget.size.width / 1.8,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            // Filter panel that shows/hides below header
            if (_isFilterPanelVisible) _buildFilterPanel(),
            Expanded(
              child: _isLoading && filteredTransactions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTransactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.all(
                              widget.size.width < 600 ? 10 : 16),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) =>
                              _buildTransactionCard(
                                  context, filteredTransactions[index]),
                        ),
            ),
            if (_isLoading && filteredTransactions.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_lastPage > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PaginationControl(
                  currentPage: _currentPage,
                  totalPages: _lastPage,
                  onPageChanged: _onPageChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = widget.size.width < 600;
    return Container(
      decoration: const BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 16,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: Color(0xFF3C92F5), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'customer_transactions.title'.tr,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, size: 20),
                      onPressed: _printReport,
                      color: const Color(0xFF7F8C8D),
                      tooltip: 'customer_transactions.tooltip_print'.tr,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isFilterPanelVisible
                            ? Icons.filter_list_off
                            : Icons.filter_list_alt,
                        size: 20,
                      ),
                      onPressed: _toggleFilterPanel,
                      color: const Color(0xFF7F8C8D),
                      tooltip: _isFilterPanelVisible
                          ? 'customer_transactions.tooltip_close_filters'.tr
                          : 'customer_transactions.tooltip_filter'.tr,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    '(${filteredTransactions.length}) · Page $_currentPage/$_lastPage',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: Color(0xFF3C92F5), size: 28),
                    const SizedBox(width: 12),
                    Text(
                      '${'customer_transactions.title'.tr} (${filteredTransactions.length})  Page $_currentPage/$_lastPage',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print),
                      onPressed: _printReport,
                      color: const Color(0xFF7F8C8D),
                      tooltip: 'customer_transactions.tooltip_print'.tr,
                    ),
                    IconButton(
                      icon: Icon(_isFilterPanelVisible
                          ? Icons.filter_list_off
                          : Icons.filter_list_alt),
                      onPressed: _toggleFilterPanel,
                      color: const Color(0xFF7F8C8D),
                      tooltip: _isFilterPanelVisible
                          ? 'customer_transactions.tooltip_close_filters'.tr
                          : 'customer_transactions.tooltip_filter'.tr,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'customer_transactions.label_reference_number'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _referenceController,
                      decoration: InputDecoration(
                        hintText: 'customer_transactions.hint_reference'.tr,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterReference = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'customer_transactions.label_transaction_type'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _filterType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        hintText: 'customer_transactions.hint_select_type'.tr,
                        border: const OutlineInputBorder(),
                      ),
                      dropdownColor: Colors.white,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('customer_transactions.label_all_types'.tr),
                        ),
                        ...transactionTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _filterType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'customer_transactions.label_from_date'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BuildBoxShadowContainer(
                      height: 45,
                      width: double.infinity,
                      circleRadius: 7,
                      child: CalendarPickerTableCell(
                        onDateSelected: (DateTime selectedDate) {
                          setState(() {
                            _filterFromDate = selectedDate;
                            _fromDateController.text =
                                DateFormat('yyyy-MM-dd').format(selectedDate);
                          });
                        },
                        initialDate: _filterFromDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        hintText: 'customer_transactions.hint_from_date'.tr,
                        isAllowEdit: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'customer_transactions.label_to_date'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BuildBoxShadowContainer(
                      height: 45,
                      width: double.infinity,
                      circleRadius: 7,
                      child: CalendarPickerTableCell(
                        onDateSelected: (DateTime selectedDate) {
                          setState(() {
                            _filterToDate = selectedDate;
                            _toDateController.text =
                                DateFormat('yyyy-MM-dd').format(selectedDate);
                          });
                        },
                        initialDate: _filterToDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        hintText: 'customer_transactions.hint_to_date'.tr,
                        isAllowEdit: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _resetFilters,
                child: Text('customer_transactions.btn_reset'.tr),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyFiltersAndClose,
                child: Text('customer_transactions.btn_apply_filters'.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 60, color: ColorManager.kPrimaryColor.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text('customer_transactions.title_empty'.tr,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
                  0, ColorManager.kTitleTextColor)),
          const SizedBox(height: 8),
          Text(
            'customer_transactions.msg_empty'.tr,
            textAlign: TextAlign.center,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0,
                ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    CustomerTransaction transaction,
  ) {
    final bool isCredit = _isCreditTransaction(transaction);
    final Color amountColor =
        isCredit ? ColorManager.kSuccessColor : ColorManager.kRed;
    final isMobile = widget.size.width < 600;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(color: ColorManager.kBgDarkColor),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: isMobile ? 4 : 8,
          ),
          leading: _buildTransactionIcon(transaction.type),
          title: Text(
            transaction.referenceId ?? 'customer_transactions.label_no_reference'.tr,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(FontWeightManager.semiBold,
                isMobile ? FontSize.s13 : FontSize.s15, 0,
                ColorManager.kTitleTextColor),
          ),
          subtitle: Text(
            DateHelper.formatISODate(transaction.date ?? ''),
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0,
                ColorManager.kGreyColor),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.amount} ${transaction.currency ?? ''}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  isMobile ? FontSize.s12 : FontSize.s14,
                  0,
                  amountColor,
                ),
              ),
              const SizedBox(height: 2),
              _buildStatusBadge(transaction.status),
            ],
          ),
          children: [_buildTransactionDetails(transaction)],
        ),
      ),
    );
  }

  Widget _buildTransactionIcon(String? type) {
    IconData iconData;
    switch (type?.toLowerCase()) {
      case 'sale':
        iconData = Icons.shopping_cart_checkout;
        break;
      case 'refund':
        iconData = Icons.replay_circle_filled_outlined;
        break;
      case 'payment':
        iconData = Icons.payment;
        break;
      default:
        iconData = Icons.receipt_long;
    }
    return CircleAvatar(
      backgroundColor: ColorManager.kPrimaryWithOpacity10,
      child: Icon(iconData, color: ColorManager.kPrimaryColor, size: 22),
    );
  }

  Widget _buildStatusBadge(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? 'N/A',
        style: buildCustomStyle(
            FontWeightManager.medium, FontSize.s10, 0, _getStatusColor(status)),
      ),
    );
  }

  Widget _buildTransactionDetails(CustomerTransaction transaction) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: ColorManager.kBgLightColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
              'customer_transactions.label_transaction_id'.tr, transaction.id?.toString() ?? 'N/A'),
          _buildDetailRow('customer_transactions.label_reference'.tr, transaction.reference ?? 'N/A'),
          _buildDetailRow('customer_transactions.label_type'.tr, transaction.type ?? 'N/A'),
          _buildDetailRow('customer_transactions.label_payment_method'.tr, transaction.paymentMethod ?? 'N/A'),
          if (transaction.transactionComment != null)
            _buildDetailRow('customer_transactions.label_comment'.tr, transaction.transactionComment!),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0,
                  ColorManager.kGreyColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                  0, ColorManager.kTitleTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'succ':
      case 'completed':
        return ColorManager.kSuccessColor;
      case 'fail':
      case 'failed':
        return ColorManager.kRed;
      case 'init':
      case 'pending':
        return ColorManager.kOrange;
      default:
        return ColorManager.kGreyColor;
    }
  }
}
