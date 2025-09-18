import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

// Add this import for the new print functionality
import 'package:pos_machine/screens/reports/customer_transactions_reports/transaction_report_print.dart';

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

  // For dropdown options
  List<String> transactionTypes = ['Credit', 'Debit'];
  List<String> statuses = ['Pending', 'Completed', 'Cancelled'];
  List<String> types = ['Sale', 'Purchase', 'Return'];

  @override
  void initState() {
    super.initState();
    // Set the customer name from the sidebar controller
    searchCustomer = sideBarController.transactionCustomerName.value;
    _customerController.text = searchCustomer;
    loadInitData();
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
        filteredTransactions = List.from(allTransactions ?? []);
        // Apply initial filter for customer
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

    // Transaction type filter
    if (searchTransactionType.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) => (transaction.transactionType ?? '')
              .toLowerCase()
              .contains(searchTransactionType.toLowerCase()))
          .toList();
    }

    // Status filter
    if (searchStatus.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) => (transaction.status ?? '')
              .toLowerCase()
              .contains(searchStatus.toLowerCase()))
          .toList();
    }

    // Type filter
    if (searchType.isNotEmpty) {
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

            if (_fromDateController.text.isNotEmpty) {
              final fromDate = formatter.parse(_fromDateController.text);
              if (transactionDate.isBefore(fromDate)) return false;
            }

            if (_toDateController.text.isNotEmpty) {
              final toDate = formatter.parse(_toDateController.text);
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
    // Clear the text controllers
    _transactionTypeController.clear();
    _statusController.clear();
    _typeController.clear();
    _fromDateController.clear();
    _toDateController.clear();

    // Reset the search variables
    setState(() {
      searchTransactionType = '';
      searchStatus = '';
      searchType = '';
      // Keep the customer filter as it's pre-filled
      searchCustomer = sideBarController.transactionCustomerName.value;
      _customerController.text = searchCustomer;
    });

    // Force a refresh of the filters
    _applyFilters();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        if (isFromDate) {
          _fromDateController.text = formattedDate;
        } else {
          _toDateController.text = formattedDate;
        }
      });
      // Call _applyFilters after setState completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyFilters();
      });
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
        Text(
          "Transaction Details",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        CustomRoundButton(
          title: "Back",
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          borderColor: ColorManager.kPrimaryColor,
          fct: () {
            sideBarController.index.value =
                65; // Navigate back to Customer Transactions Report
          },
          height: 40,
          width: 80,
          fontSize: FontSize.s12,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Filters",
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.25,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 15),
          // First row of filters (4 filters)
          SizedBox(
            height: 90,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildTextFieldWithLabel(
                    "Customer",
                    _customerController,
                    enabled: false,
                    onFilterChanged: (value) {
                      setState(() {
                        searchCustomer = value;
                      });
                    },
                  ),
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
                    },
                  ),
                ),
              ],
            ),
          ),
          // Second row of filters (2 date filters + print button + reset button)
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
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30, left: 10),
                    child: CustomRoundButton(
                      title: "Print",
                      boxColor: ColorManager.kPrimaryColor,
                      textColor: Colors.white,
                      fct: _printReport,
                      height: 45,
                      width: double.infinity,
                      fontSize: FontSize.s12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30, left: 10),
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
      ),
    );
  }

  Widget _buildTextFieldWithLabel(
      String label, TextEditingController controller,
      {bool enabled = true, Function(String)? onFilterChanged}) {
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
            child: TextFormField(
              readOnly: !enabled,
              keyboardType: TextInputType.text,
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              decoration: decoration.copyWith(
                hintText: label,
                hintStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.18,
                  ColorManager.textColor,
                ),
                prefixIconColor: Colors.black,
              ),
              controller: controller,
              onChanged: (value) {
                if (onFilterChanged != null) {
                  onFilterChanged(value);
                }
                _applyFilters();
              },
            ),
          ),
        ],
      ),
    );
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
              value: controller.text.isEmpty ? null : controller.text,
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
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    "All $label",
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s10,
                      0.18,
                      ColorManager.textColor,
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
                  onFilterChanged(value ?? '');
                });
                _applyFilters();
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
            child: TextFormField(
              controller: controller,
              onTap: () => _selectDate(context, isFromDate),
              readOnly: true,
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.18,
                ColorManager.textColor,
              ),
              decoration: decoration.copyWith(
                hintText: "DD/MM/YYYY",
                hintStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.18,
                  ColorManager.textColor,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: ColorManager.kPrimaryColor,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
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
        _buildTableCell(transaction.orderId?.toString() ?? "N/A"),
        _buildTableCell(transaction.transactionType ?? "N/A"),
        _buildTableCell(transaction.amount ?? "0.00"),
        Center(child: _buildTypeCell(transaction.type ?? "N/A")),
        _buildTableCell(transaction.date ?? "N/A"),
        Center(child: _buildStatusChip(transaction.status ?? "N/A")),
      ],
    );
  }

  void _printReport() {
    // Create a list of cart items from the filtered transactions
    List<Map<String, dynamic>> cartItems = [];

    for (var transaction in filteredTransactions ?? []) {
      cartItems.add({
        'productName':
            '${transaction.transactionType ?? "N/A"} - Order #${transaction.orderId ?? "N/A"}',
        'mrp': transaction.amount ?? "0.00",
        'quantity': '1',
        'unitPrice': transaction.amount ?? "0.00",
        'totalPrice': transaction.amount ?? "0.00",
      });
    }

    // Calculate total amount
    double totalAmount = 0.0;
    for (var transaction in filteredTransactions ?? []) {
      totalAmount += double.tryParse(transaction.amount ?? "0.00") ?? 0.0;
    }

    // Calculate saved amount (for this report, we'll set it to 0)
    double savedAmount = 0.0;

    // Get current date and time for the report
    String orderDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    String orderNumber = "TXN-REPORT-${DateTime.now().millisecondsSinceEpoch}";

    // Navigate to the print page with the transaction data
    Get.to(() => TransactionReportPrintPage(
          cartItems: cartItems,
          formattedTotal: totalAmount.toStringAsFixed(2),
          savedTotal: savedAmount.toStringAsFixed(2),
          orderDate: orderDate,
          orderNumber: orderNumber,
          customerName: _customerController.text,
          customerPhone: "", // We don't have customer phone in this screen
          customerEmail: "", // We don't have customer email in this screen
          customerAddress: "", // We don't have customer address in this screen
        ));

    // Show a message that the print process has started
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Preparing transaction report for printing..."),
        backgroundColor: ColorManager.kPrimaryColor,
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
    super.dispose();
  }
}
