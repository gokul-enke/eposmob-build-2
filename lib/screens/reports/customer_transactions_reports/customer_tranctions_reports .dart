import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
// Use TransactionProvider instead of CustomerTransactionProvider
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

// Import the new simple transaction details screen
import 'customer_transaction_details_screen.dart';
// Add imports for customer autocomplete and date filtering
import 'package:pos_machine/screens/transactions/widgets/customer_auto_complete.dart';
import 'package:pos_machine/components/build_text_fields.dart';
// Import CalendarPickerTableCell component
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'dart:async';

class CustomerTransactionsReportScreen extends StatefulWidget {
  const CustomerTransactionsReportScreen({super.key});

  @override
  State<CustomerTransactionsReportScreen> createState() =>
      _CustomerTransactionsReportScreenState();
}

class _CustomerTransactionsReportScreenState
    extends State<CustomerTransactionsReportScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  List<ListTransaction>? allTransactions = [];

  // For grouping customer transactions
  Map<String, CustomerTransactionSummary> customerSummary = {};

  // Controllers for filters
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Filter variables
  String searchCustomer = '';

  // Customer suggestions for autocomplete
  List<String> customerSuggestions = [];

  // Timer for debouncing customer search
  Timer? _customerSearchTimer;

  @override
  void initState() {
    super.initState();
    // Set default date values
    _setInitialDateFilters();
    loadInitData();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _customerSearchTimer?.cancel();
    super.dispose();
  }

  // Set default date values: 1 month before current date for from_date, current date for to_date
  void _setInitialDateFilters() {
    final now = DateTime.now();
    final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);

    final formatter = DateFormat('yyyy-MM-dd');
    final fromDateStr = formatter.format(oneMonthAgo);
    final toDateStr = formatter.format(now);

    setState(() {
      _fromDateController.text = fromDateStr;
      _toDateController.text = toDateStr;
    });
  }

  Future<void> loadInitData() async {
    setState(() {
      initLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      final value = await invoiceProvider.listAllTransaction(
        type: null,
        accessToken: accessToken ?? "",
      );

      if (value['status'] == 'success') {
        ListTransactionModel listTransactionModel =
            ListTransactionModel.fromJson(value);
        allTransactions = listTransactionModel.data?.transactions ?? [];

        // Populate customer suggestions
        final suggestions = getCustomerSuggestions();

        // Apply filters immediately
        _applyFilters();

        // Update the customer suggestions and trigger a rebuild
        setState(() {
          customerSuggestions = suggestions;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to load transaction data"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('Error loading transaction data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading transaction data: $error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        initLoading = false;
      });
    }
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

  void _applyFilters() {
    if (allTransactions == null || allTransactions!.isEmpty) {
      setState(() {
        customerSummary.clear();
      });
      return;
    }

    // Apply filters
    List<ListTransaction> filteredList = [...allTransactions!];

    // Customer filter
    if (searchCustomer.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) => (transaction.customerName ?? '')
              .toLowerCase()
              .contains(searchCustomer.toLowerCase()))
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
              // Include the to date by adding one day and checking if transaction date is before
              final toDatePlusOne = toDate.add(const Duration(days: 1));
              if (transactionDate.isAfter(toDate)) return false;
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

    // Recalculate customer summary with filtered transactions
    _calculateCustomerSummaryFromFilteredList(filteredList);
  }

  void _calculateCustomerSummaryFromFilteredList(
      List<ListTransaction> filteredList) {
    Map<String, CustomerTransactionSummary> filteredCustomerSummary = {};

    for (var transaction in filteredList) {
      String customerName = transaction.customerName ?? 'Unknown Customer';
      double amount = double.tryParse(transaction.amount ?? '0') ?? 0.0;
      String type = transaction.type ?? 'unknown';
      double transactionBalance = double.tryParse(transaction.balance ?? '0') ?? 0.0;

      if (!filteredCustomerSummary.containsKey(customerName)) {
        filteredCustomerSummary[customerName] = CustomerTransactionSummary(
          customerName: customerName,
          totalDebit: 0.0,
          totalCredit: 0.0,
        );
      }

      // Calculate totals for display purposes
      if (transaction.type?.toLowerCase() == 'credit') {
        filteredCustomerSummary[customerName]!.totalCredit += amount;
      } else if (transaction.type?.toLowerCase() == 'debit') {
        filteredCustomerSummary[customerName]!.totalDebit += amount;
      }

      // Use the API-provided balance for the last transaction of each customer
      // This gives us the running balance from the server
      filteredCustomerSummary[customerName]!.balance = transactionBalance;
    }

    setState(() {
      customerSummary = filteredCustomerSummary;
    });
  }

  void _resetFilters() {
    // Cancel any pending search
    _customerSearchTimer?.cancel();

    // Clear the text controllers
    _customerController.clear();
    _fromDateController.clear();
    _toDateController.clear();

    // Reset the search variables
    setState(() {
      searchCustomer = '';
    });

    // Set default date values
    _setInitialDateFilters();

    // Reload data
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => loadInitData(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 15),
                _buildFilters(),
                const SizedBox(height: 20),
                _buildReportTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Customer Transactions Report",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        // First row of filters
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildCustomerAutocompleteField(),
              ),
              Expanded(
                flex: 1,
                child: _buildDateField(
                  "From Date",
                  _fromDateController,
                  true,
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildDateField(
                  "To Date",
                  _toDateController,
                  false,
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 45, left: 10),
                  child: CustomRoundButton(
                    title: "Reset",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    fct: _resetFilters,
                    height: 45,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerAutocompleteField() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Customer",
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CustomerAutocomplete(
            size: MediaQuery.of(context).size,
            customerList: customerSuggestions, // This will now update properly
            controller: _customerController,
            onSelected: (String selectedCustomer) {
              // Cancel any pending search
              _customerSearchTimer?.cancel();

              setState(() {
                searchCustomer = selectedCustomer;
              });
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
      String label, TextEditingController controller, bool isFromDate) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: CalendarPickerTableCell(
              onDateSelected: (DateTime selectedDate) {
                final formattedDate =
                    DateFormat('yyyy-MM-dd').format(selectedDate);
                setState(() {
                  if (isFromDate) {
                    _fromDateController.text = formattedDate;
                  } else {
                    _toDateController.text = formattedDate;
                  }
                });
                _applyFilters();
              },
              initialDate: controller.text.isNotEmpty
                  ? DateFormat('yyyy-MM-dd').parse(controller.text)
                  : null,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
              hintText: "Select Date",
              isAllowEdit: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable() {
    return Expanded(
      child: initLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : BuildBoxShadowContainer(
              margin: const EdgeInsets.only(top: 5),
              circleRadius: 7,
              offsetValue: const Offset(2, 2),
              blurRadius: 8.0,
              color: Colors.white,
              child: Column(
                children: [
                  // Fixed table header
                  Container(
                    decoration: const BoxDecoration(
                      color: ColorManager.tableBGColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 2.0,
                        ),
                      ],
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.0), // Customer Name
                        1: FlexColumnWidth(1.5), // Total Debit
                        2: FlexColumnWidth(1.5), // Total Credit
                        3: FlexColumnWidth(1.5), // Balance
                        4: FlexColumnWidth(1.0), // Action
                      },
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _buildTableHeader("Customer Name"),
                            _buildTableHeader("Total Debit"),
                            _buildTableHeader("Total Credit"),
                            _buildTableHeader("Balance"),
                            _buildTableHeader("Action"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Scrollable table body
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: customerSummary.isEmpty
                            ? _buildNoDataFoundUI()
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                scrollDirection: Axis.vertical,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.0), // Customer Name
                                    1: FlexColumnWidth(1.5), // Total Debit
                                    2: FlexColumnWidth(1.5), // Total Credit
                                    3: FlexColumnWidth(1.5), // Balance
                                    4: FlexColumnWidth(1.0), // Action
                                  },
                                  border: null,
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: customerSummary.entries
                                      .map((entry) => _buildCustomerRow(
                                          entry.value, context))
                                      .toList(),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNoDataFoundUI() {
    return Container(
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No customer transactions available',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing the data',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  TableRow _buildCustomerRow(
      CustomerTransactionSummary summary, BuildContext context) {
    // Alternate row colors for better readability
    final int index =
        customerSummary.keys.toList().indexOf(summary.customerName);

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _buildTableCell(summary.customerName),
        _buildTableCell(
          summary.totalDebit.toStringAsFixed(2),
        ),
        _buildTableCell(
          summary.totalCredit.toStringAsFixed(2),
        ),
        _buildTableCell(
          summary.balance.toStringAsFixed(2),
          isBalance: true,
          balance: summary.balance,
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: BuildBoxShadowContainer(
              margin: const EdgeInsets.only(left: 5, right: 5),
              circleRadius: 5,
              child: IconButton(
                icon: Icon(
                  Icons.visibility,
                  size: 18,
                  color: ColorManager.kPrimaryColor.withOpacity(0.9),
                ),
                onPressed: () {
                  // Use the TransactionProvider instead of the CustomerTransactionProvider
                  Provider.of<TransactionProvider>(context, listen: false)
                      .setCustomerName(summary.customerName);
                  sideBarController.index.value =
                      66; // Navigate to SimpleTransactionDetailsScreen
                },
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String content,
      {bool isBalance = false, double? balance}) {
    Color textColor = Colors.black;
    if (isBalance && balance != null) {
      textColor = balance < 0 ? Colors.red : Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        content,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          textColor,
        ),
      ),
    );
  }
}

class CustomerTransactionSummary {
  final String customerName;
  double totalDebit;
  double totalCredit;
  double balance;

  CustomerTransactionSummary({
    required this.customerName,
    required this.totalDebit,
    required this.totalCredit,
    this.balance = 0.0,
  });
}
