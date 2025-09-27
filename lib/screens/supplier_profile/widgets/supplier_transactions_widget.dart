import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';

class SupplierTransactionsWidget extends StatefulWidget {
  final Size size;
  final Supplier supplier;

  const SupplierTransactionsWidget({
    Key? key,
    required this.size,
    required this.supplier,
  }) : super(key: key);

  @override
  State<SupplierTransactionsWidget> createState() =>
      _SupplierTransactionsWidgetState();
}

class _SupplierTransactionsWidgetState
    extends State<SupplierTransactionsWidget> {
  late List<SupplierTransaction> transactions;
  late List<SupplierTransaction> filteredTransactions;

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
    transactions = widget.supplier.transactions;
    filteredTransactions = List.from(transactions);
    _applyFilters(); // Apply initial filters
  }

  // Helper method to determine if transaction is credit or debit
  bool _isCreditTransaction(SupplierTransaction transaction) {
    return transaction.type?.toLowerCase() == 'credit';
  }

  // Apply filters to the transactions
  void _applyFilters() {
    setState(() {
      filteredTransactions = transactions.where((transaction) {
        // Reference filter
        if (_filterReference != null && _filterReference!.isNotEmpty) {
          if (transaction.reference == null ||
              !transaction.reference
                  .toLowerCase()
                  .contains(_filterReference!.toLowerCase())) {
            return false;
          }
        }

        // Date range filter
        if (_filterFromDate != null || _filterToDate != null) {
          if (transaction.date == null || transaction.date.isEmpty) return false;

          try {
            final transactionDate =
                DateFormat('yyyy-MM-dd').parse(transaction.date);

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
      filteredTransactions = List.from(transactions);
      _isFilterPanelVisible = false;
    });
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
    _applyFilters();
    setState(() {
      _isFilterPanelVisible = false;
    });
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
        margin: const EdgeInsets.all(24),
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
              child: filteredTransactions.isEmpty
                  ? _buildEmptyState()
                  : _buildTransactionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  color: Color(0xFF3C92F5), size: 28),
              const SizedBox(width: 12),
              Text(
                'Transactions (${filteredTransactions.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: _printTransactions,
                color: const Color(0xFF7F8C8D),
                tooltip: 'Print transactions',
              ),
              IconButton(
                icon: Icon(_isFilterPanelVisible
                    ? Icons.filter_list_off
                    : Icons.filter_list_alt),
                onPressed: _toggleFilterPanel,
                color: const Color(0xFF7F8C8D),
                tooltip: _isFilterPanelVisible
                    ? 'Close filters'
                    : 'Filter transactions',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) =>
          _buildTransactionCard(context, filteredTransactions[index]),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    dynamic transaction,
  ) {
    // Determine if this is a credit or debit transaction
    final bool isCredit = transaction.type == 'Credit';
    final Color amountColor = isCredit ? ColorManager.kSuccessColor : ColorManager.kRed;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildTransactionIcon(transaction.type),
          title: Text(
            transaction.reference ?? 'No Reference',
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s15, 0,
                ColorManager.kTitleTextColor),
          ),
          subtitle: Text(
            transaction.date ?? '',
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s12, 0, ColorManager.kGreyColor),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.currency} ${transaction.amount}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s14,
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
      case 'credit':
        iconData = Icons.add_circle_outline;
        break;
      case 'debit':
        iconData = Icons.remove_circle_outline;
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

  Widget _buildTransactionDetails(dynamic transaction) {
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
          _buildDetailRow('Transaction Type', transaction.transactionType ?? 'N/A'),
          _buildDetailRow('Payment Method', transaction.paymentMethod?.isEmpty == true ? 'N/A' : transaction.paymentMethod),
          _buildDetailRow('Date', transaction.date ?? 'N/A'),
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
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0, ColorManager.kGreyColor),
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
                    const Text(
                      'Reference Number',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        hintText: 'Enter reference number',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                    const Text(
                      'Transaction Type',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _filterType,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        hintText: "Select Type",
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: Colors.white,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("All Types"),
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
                    const Text(
                      'From Date',
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
                        hintText: "Select From Date",
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
                    const Text(
                      'To Date',
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
                        hintText: "Select To Date",
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
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyFiltersAndClose,
                child: const Text('Apply Filters'),
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
          Text('No Transactions Found',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
                  0, ColorManager.kTitleTextColor)),
          const SizedBox(height: 8),
          Text(
            transactions.isEmpty 
                ? 'Transaction data is not available for this supplier.'
                : 'No transactions match your current filters.',
            textAlign: TextAlign.center,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0,
                ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }

  void _printTransactions() async {
    if (widget.supplier.transactions.isEmpty) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "No transactions available to print",
        );
      }
      return;
    }

    // Show loading indicator
    if (mounted) {
      showScaffold(
        context: context,
        message: "Preparing supplier transaction report...",
      );
    }

    try {
      // Get supplier details
      String supplierName = widget.supplier.name ?? '';
      String supplierPhone = widget.supplier.phone ?? '';
      String supplierEmail = widget.supplier.email ?? '';
      String supplierAddress = widget.supplier.address ?? '';

      // Calculate total amount
      double totalAmount = 0.0;
      for (var transaction in widget.supplier.transactions) {
        double amount = double.tryParse(transaction.amount) ?? 0.0;
        totalAmount += amount;
      }

      String formattedTotal = totalAmount.toStringAsFixed(2);

      // Set date range to cover all transactions
      String? fromDate;
      String? toDate;
      
      if (widget.supplier.transactions.isNotEmpty) {
        // Get the earliest and latest transaction dates
        List<DateTime> dates = [];
        for (var transaction in widget.supplier.transactions) {
          try {
            if (transaction.date != null && transaction.date.isNotEmpty) {
              DateTime date = DateFormat('yyyy-MM-dd').parse(transaction.date);
              dates.add(date);
            }
          } catch (e) {
            debugPrint('Error parsing date: ${transaction.date}');
          }
        }
        
        if (dates.isNotEmpty) {
          dates.sort();
          fromDate = DateFormat('yyyy-MM-dd').format(dates.first);
          toDate = DateFormat('yyyy-MM-dd').format(dates.last);
        }
      }

      // Navigate to print screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupplierTransactionReportPrint(
              cartItems: widget.supplier.transactions,
              formattedTotal: formattedTotal,
              savedTotal: formattedTotal,
              orderDate: DateTime.now().toIso8601String(),
              orderNumber: "SUPP-${DateTime.now().millisecondsSinceEpoch}",
              isFromLocalStorage: false,
              supplierName: supplierName,
              supplierPhone: supplierPhone,
              supplierEmail: supplierEmail,
              supplierAddress: supplierAddress,
              fromDate: fromDate,
              toDate: toDate,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error preparing print: $e');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error preparing print: $e",
        );
      }
    }
  }
}
