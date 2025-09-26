import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

// Add this import for the new print functionality
import 'package:pos_machine/screens/reports/customer_transactions_reports/transaction_report_print.dart';
// Add this import for the CustomerAutocomplete widget
import 'package:pos_machine/screens/transactions/widgets/customer_auto_complete.dart';
// Add this import for CalendarPickerTableCell component
import 'package:pos_machine/components/build_calendar_selection.dart';
// Add this import for the CustomBackButton component
import 'package:pos_machine/components/build_back_button.dart';
// Add this import for Timer
import 'dart:async';

class SimpleTransactionDetailsScreen extends StatefulWidget {
  const SimpleTransactionDetailsScreen({super.key});

  @override
  State<SimpleTransactionDetailsScreen> createState() =>
      _SimpleTransactionDetailsScreenState();
}

class _SimpleTransactionDetailsScreenState
    extends State<SimpleTransactionDetailsScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  List<ListTransaction>? allTransactions = [];
  List<ListTransaction>? filteredTransactions = [];

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
      final customerName =
          Provider.of<TransactionProvider>(context, listen: false).customerName;
      setState(() {
        searchCustomer = customerName;
        _customerController.text = customerName;
      });
      // Set default date values
      _setInitialDateFilters();
      loadInitData(); // This will now work properly
    });
  }

  // Add the missing loadInitData method
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
        customerSuggestions = getCustomerSuggestions();

        // Apply filters immediately to show only transactions for the selected customer
        _applyFilters();
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
      debugPrint("Error loading transactions: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading transactions: $error"),
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

    // Apply filters immediately after setting default dates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
    });
  }

  void _applyFilters() {
    if (allTransactions == null || allTransactions!.isEmpty) {
      setState(() {
        filteredTransactions = [];
      });
      return;
    }

    // Apply filters
    List<ListTransaction> filteredList = [...allTransactions!];

    // Customer filter (always applied as it's pre-filled)
    if (searchCustomer.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) => (transaction.customerName ?? '')
              .toLowerCase()
              .contains(searchCustomer.toLowerCase()))
          .toList();
    }

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

  Widget _buildDropdownField(String label, TextEditingController controller,
      List<String> options, Function(String) onFilterChanged) {
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
            child: DropdownButtonFormField<String>(
              value: controller.text.isEmpty || controller.text == 'All'
                  ? null
                  : controller.text,
              decoration: decoration.copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                hintText: "All $label",
                hintStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.18,
                  ColorManager.textColor,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              dropdownColor: Colors.white,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text(
                    "All",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s10,
                        0.18,
                        ColorManager.textColor,
                      ),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (String? value) {
                setState(() {
                  controller.text = value ?? '';
                  // Update the search variable and apply filters
                  onFilterChanged(value ?? '');
                });
              },
            ),
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
                // Apply filters immediately after date selection
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
          : Consumer<InvoiceProvider>(
              builder: (context, invoiceProvider, child) {
                return BuildBoxShadowContainer(
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
                            0: FlexColumnWidth(0.8), // Sl No
                            1: FlexColumnWidth(1.5), // Order Number
                            2: FlexColumnWidth(1.5), // Transaction Type
                            3: FlexColumnWidth(1.2), // Amount
                            4: FlexColumnWidth(1.0), // Type
                            5: FlexColumnWidth(1.5), // Transaction Date
                            6: FlexColumnWidth(1.0), // Status
                          },
                          border: null,
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                _buildTableHeader("Sl No"),
                                _buildTableHeader("Order Number"),
                                _buildTableHeader("Transaction Type"),
                                _buildTableHeader("Amount"),
                                _buildTableHeader("Type"),
                                _buildTableHeader("Transaction Date"),
                                _buildTableHeader("Status"),
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
                            child: (filteredTransactions?.isEmpty ?? true)
                                ? _buildNoDataFoundUI()
                                : SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    scrollDirection: Axis.vertical,
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(0.8), // Sl No
                                        1: FlexColumnWidth(1.5), // Order Number
                                        2: FlexColumnWidth(
                                            1.5), // Transaction Type
                                        3: FlexColumnWidth(1.2), // Amount
                                        4: FlexColumnWidth(1.0), // Type
                                        5: FlexColumnWidth(
                                            1.5), // Transaction Date
                                        6: FlexColumnWidth(1.0), // Status
                                      },
                                      border: null,
                                      defaultVerticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      children: filteredTransactions!
                                          .asMap()
                                          .entries
                                          .map((entry) => _buildTransactionRow(
                                              entry.key + 1, entry.value))
                                          .toList(),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
            'No transactions available',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
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

  TableCell _buildTableCell(String content) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s9,
            0.13,
            Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'SUCC':
      case 'SUCCESS':
      case 'COMPLETED':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'INIT':
      case 'INITIATED':
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'FAIL':
      case 'FAILED':
      case 'CANCELLED':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCell(String type) {
    final isCredit = type.toLowerCase() == 'credit';
    final color = isCredit ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  TableRow _buildTransactionRow(int slNo, ListTransaction transaction) {
    // Alternate row colors for better readability
    final int index = slNo - 1;

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _buildTableCell(slNo.toString()),
        _buildTableCell(transaction.orderNumber?.toString() ?? "N/A"),
        _buildTableCell(transaction.transactionType ?? "N/A"),
        _buildTableCell(transaction.amount ?? "0.00"),
        Center(child: _buildTypeCell(transaction.type ?? "N/A")),
        _buildTableCell(transaction.date ?? "N/A"),
        Center(child: _buildStatusChip(transaction.status ?? "N/A")),
      ],
    );
  }

  void _printReport() async {
    // Show loading indicator
    if (mounted) {
      showScaffold(
        context: context,
        message: "Preparing transaction report...",
      );
    }

    // Show loading state
    setState(() {
      initLoading = true;
    });

    // Fetch customer details
    String customerName = _customerController.text;
    String customerPhone = "";
    String customerEmail = "";
    String customerAddress = "";

    if (customerName.isNotEmpty) {
      try {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null) {
          final customerProvider =
              Provider.of<CustomerProvider>(context, listen: false);

          // Try to find customer by name
          debugPrint("Attempting to fetch customer details for: $customerName");
          final customerResponse = await customerProvider.findCustomerByName(
            accessToken,
            customerName,
            context,
          );
          debugPrint("Customer API response: $customerResponse");

          if (customerResponse['status'] == 'success' &&
              customerResponse['data'] != null &&
              customerResponse['data'].isNotEmpty) {
            // Get the first matching customer
            final customerData = customerResponse['data'][0];
            debugPrint("Raw customer data received: $customerData");
            final customer = CustomerListModelData.fromJson(customerData);

            customerPhone = customer.phone ?? "";
            customerEmail = customer.email ?? "";

            // Debug individual address components
            debugPrint("Address components:");
            debugPrint("  address: ${customer.address}");
            debugPrint("  city: ${customer.city}");
            debugPrint("  state: ${customer.state}");
            debugPrint("  pincode: ${customer.pincode}");
            debugPrint("  country: ${customer.country}");

            // Check if all address components are null
            if (customer.address == null &&
                customer.city == null &&
                customer.state == null &&
                customer.pincode == null &&
                customer.country == null) {
              debugPrint(
                  "WARNING: All address components are NULL for this customer");
            }

            // Build complete address
            List<String> addressParts = [];
            if (customer.address != null && customer.address!.isNotEmpty) {
              addressParts.add(customer.address!);
            }
            if (customer.city != null && customer.city!.isNotEmpty) {
              addressParts.add(customer.city!);
            }
            if (customer.state != null && customer.state!.isNotEmpty) {
              addressParts.add(customer.state!);
            }
            if (customer.pincode != null && customer.pincode!.isNotEmpty) {
              addressParts.add(customer.pincode!);
            }
            if (customer.country != null && customer.country!.isNotEmpty) {
              addressParts.add(customer.country!);
            }

            customerAddress = addressParts.join(", ");
            debugPrint("Final constructed address: '$customerAddress'");
            debugPrint("Is final address empty? ${customerAddress.isEmpty}");
          } else {
            debugPrint("Customer API returned no data or error status");
            if (customerResponse['status'] != 'success') {
              debugPrint("Customer API error: ${customerResponse['message']}");
            }
            if (customerResponse['data'] == null ||
                customerResponse['data'].isEmpty) {
              debugPrint("Customer API returned empty data array");
            }
          }
        } else {
          debugPrint("Access token is null, cannot fetch customer details");
        }
      } catch (e, stackTrace) {
        debugPrint("Error fetching customer details: $e");
        debugPrint("Stack trace: $stackTrace");
        // Continue with just the name if we can't fetch details
      }
    } else {
      debugPrint("Customer name is empty, skipping customer details fetch");
    }

    // Hide loading state
    setState(() {
      initLoading = false;
    });

    // Create a list of cart items from the filtered transactions
    List<ListTransaction> cartItems = filteredTransactions ?? [];

    // Calculate totals
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var transaction in filteredTransactions ?? []) {
      double amount = double.tryParse(transaction.amount ?? "0.00") ?? 0.0;
      String type = transaction.type ?? "";

      if (type.toLowerCase() == 'credit') {
        totalCredit += amount;
      } else if (type.toLowerCase() == 'debit') {
        totalDebit += amount;
      }
    }

    // Calculate total amount (for backwards compatibility)
    double totalAmount = totalCredit - totalDebit;

    // Calculate saved amount (for this report, we'll set it to 0)
    double savedAmount = 0.0;

    // Get current date and time for the report
    String orderDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    String orderNumber = "TXN-REPORT-${DateTime.now().millisecondsSinceEpoch}";

    // Get date range values
    String? fromDate =
        _fromDateController.text.isNotEmpty ? _fromDateController.text : null;
    String? toDate =
        _toDateController.text.isNotEmpty ? _toDateController.text : null;

    // Navigate to the print page with the transaction data
    debugPrint("Customer data being passed to print:");
    debugPrint("  Name: '$customerName'");
    debugPrint("  Phone: '$customerPhone'");
    debugPrint("  Email: '$customerEmail'");
    debugPrint("  Address: '$customerAddress'");
    debugPrint("  From Date: '$fromDate'");
    debugPrint("  To Date: '$toDate'");

    Get.to(() => TransactionReportPrintPage(
          cartItems: cartItems,
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
          isFromLocalStorage: false,
        ));

    // Show a message that the print process has started
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Preparing transaction report for printing..."),
          backgroundColor: ColorManager.kPrimaryColor,
        ),
      );
    }
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
                const SizedBox(height: 20),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomBackButton(
              onPressed: () {
                sideBarController.index.value =
                    65; // Navigate back to Customer Transactions Report
              },
              text: 'All Customers',
            ),
            Text(
              "Transaction Details",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
          ],
        ),
        CustomRoundButton(
          title: "Print",
          boxColor: ColorManager.kPrimaryColor,
          textColor: Colors.white,
          fct: _printReport,
          height: 40,
          width: 120,
          fontSize: FontSize.s12,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   "Filters",
        //   style: buildCustomStyle(
        //     FontWeightManager.semiBold,
        //     FontSize.s16,
        //     0.25,
        //     ColorManager.textColor,
        //   ),
        // ),
        const SizedBox(height: 15),
        // First row of filters (4 filters)
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
                child: _buildDropdownField(
                  "Transaction Type",
                  _transactionTypeController,
                  transactionTypes,
                  (value) {
                    setState(() {
                      searchTransactionType = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildDropdownField(
                  "Status",
                  _statusController,
                  statuses,
                  (value) {
                    setState(() {
                      searchStatus = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildDropdownField(
                  "Type",
                  _typeController,
                  types,
                  (value) {
                    setState(() {
                      searchType = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ),
        // Second row of filters (2 date filters + reset button)
        SizedBox(
          height: 90,
          child: Row(
            children: [
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
                child: Container(), // Empty space to maintain 4-field layout
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 42, left: 10),
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
            customerList: customerSuggestions,
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
