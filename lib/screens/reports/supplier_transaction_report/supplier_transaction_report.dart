import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

// Import the supplier autocomplete and date filtering components
import 'package:pos_machine/screens/suppliers/widgets/supplier_auto_complete.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'dart:async';

// Import the supplier transaction details screen
import 'supplier_transaction_details_screen.dart';

class SupplierTransactionReportScreen extends StatefulWidget {
  const SupplierTransactionReportScreen({super.key});

  @override
  State<SupplierTransactionReportScreen> createState() =>
      _SupplierTransactionReportScreenState();
}

class _SupplierTransactionReportScreenState
    extends State<SupplierTransactionReportScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  List<Supplier>? allSuppliers = [];

  // For grouping supplier transactions
  Map<String, SupplierTransactionSummary> supplierSummary = {};

  // Controllers for filters
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Filter variables
  String searchSupplier = '';

  // Supplier suggestions for autocomplete
  List<String> supplierSuggestions = [];

  // Timer for debouncing supplier search
  Timer? _supplierSearchTimer;

  @override
  void initState() {
    super.initState();
    // Set default date values
    _setInitialDateFilters();
    loadInitData();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _supplierSearchTimer?.cancel();
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
      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      // Fetch all suppliers with their transaction data
      await supplierProvider.fetchSuppliers(
        accessToken: accessToken ?? "",
        supplierName: null,
      );

      // Get all suppliers from the provider's allSuppliers list (not the paginated supplierList)
      allSuppliers = supplierProvider.allSuppliers ?? [];

      // Populate supplier suggestions
      final suggestions = getSupplierSuggestions();

      // Apply filters immediately
      _applyFilters();

      // Update the supplier suggestions and trigger a rebuild
      setState(() {
        supplierSuggestions = suggestions;
      });
    } catch (error) {
      debugPrint('Error loading supplier data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading supplier data: $error"),
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

  List<String> getSupplierSuggestions() {
    if (allSuppliers == null) return [];
    final suggestions = allSuppliers!
        .map((s) => s.name)
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
    if (allSuppliers == null || allSuppliers!.isEmpty) {
      setState(() {
        supplierSummary.clear();
      });
      return;
    }

    // Apply filters
    List<Supplier> filteredList = [...allSuppliers!];

    // Supplier filter
    if (searchSupplier.isNotEmpty) {
      filteredList = filteredList
          .where((supplier) => supplier.name
              .toLowerCase()
              .contains(searchSupplier.toLowerCase()))
          .toList();
    }

    // Date range filter for transactions - similar to customer report logic
    if (_fromDateController.text.isNotEmpty ||
        _toDateController.text.isNotEmpty) {
      try {
        final formatter = DateFormat('yyyy-MM-dd');

        filteredList = filteredList.map((supplier) {
          // Filter transactions within date range
          List<SupplierTransaction> filteredTransactions = supplier.transactions.where((transaction) {
            if (transaction.date.isEmpty) return false;

            try {
              final transactionDate = formatter.parse(transaction.date);

              // If from date is set, check that transaction date is not before it
              if (_fromDateController.text.isNotEmpty) {
                final fromDate = formatter.parse(_fromDateController.text);
                if (transactionDate.isBefore(fromDate)) return false;
              }

              // If to date is set, check that transaction date is not after it
              if (_toDateController.text.isNotEmpty) {
                final toDate = formatter.parse(_toDateController.text);
                // Include the to date by adding one day and checking if transaction date is before
                if (transactionDate.isAfter(toDate)) return false;
              }

              return true;
            } catch (e) {
              debugPrint('Date parsing error for transaction: $e');
              return false;
            }
          }).toList();

          // Return supplier with filtered transactions
          return Supplier(
            id: supplier.id,
            name: supplier.name,
            email: supplier.email,
            phone: supplier.phone,
            altPhone: supplier.altPhone,
            productCategories: supplier.productCategories,
            address: supplier.address,
            balance: supplier.balance,
            paymentType: supplier.paymentType,
            companyId: supplier.companyId,
            currentBalance: supplier.currentBalance,
            balanceStatus: supplier.balanceStatus,
            createdAt: supplier.createdAt,
            updatedAt: supplier.updatedAt,
            userId: supplier.userId,
            transactions: filteredTransactions,
            purchases: supplier.purchases,
          );
        }).toList();
      } catch (e) {
        debugPrint('Date parsing error: $e');
      }
    }

    // Recalculate supplier summary with filtered suppliers
    _calculateSupplierSummaryFromFilteredList(filteredList);
  }

  void _calculateSupplierSummaryFromFilteredList(List<Supplier> filteredList) {
    Map<String, SupplierTransactionSummary> filteredSupplierSummary = {};

    for (var supplier in filteredList) {
      String supplierName = supplier.name;
      double totalDebit = 0.0;
      double totalCredit = 0.0;

      // Calculate totals from filtered transactions (similar to customer report logic)
      for (var transaction in supplier.transactions) {
        double amount = double.tryParse(transaction.amount) ?? 0.0;

        // Assuming "Credit" type increases balance and "Debit" type decreases balance
        if (transaction.type.toLowerCase() == 'credit') {
          totalCredit += amount;
        } else if (transaction.type.toLowerCase() == 'debit') {
          totalDebit += amount;
        }
      }

      // Calculate balance from transactions (similar to customer report)
      double calculatedBalance = totalCredit - totalDebit;

      // Only add suppliers that have transactions or non-zero balances
      if (supplier.transactions.isNotEmpty || supplier.currentBalance != 0.0) {
        filteredSupplierSummary[supplierName] = SupplierTransactionSummary(
          supplierName: supplierName,
          totalDebit: totalDebit,
          totalCredit: totalCredit,
          balance: calculatedBalance, // Use calculated balance from transactions
          transactionCount: supplier.transactions.length,
        );
      }
    }

    setState(() {
      supplierSummary = filteredSupplierSummary;
    });
  }

  void _resetFilters() {
    // Cancel any pending search
    _supplierSearchTimer?.cancel();

    // Clear the text controllers
    _supplierController.clear();
    _fromDateController.clear();
    _toDateController.clear();

    // Reset the search variables
    setState(() {
      searchSupplier = '';
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
          "Supplier Transactions Report",
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
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildSupplierAutocompleteField(),
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
      ],
    );
  }

  Widget _buildSupplierAutocompleteField() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Supplier",
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupplierAutocomplete(
            size: MediaQuery.of(context).size,
            supplierList: supplierSuggestions, // This will now update properly
            controller: _supplierController,
            onSelected: (String selectedSupplier) {
              // Cancel any pending search
              _supplierSearchTimer?.cancel();

              setState(() {
                searchSupplier = selectedSupplier;
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
                        0: FlexColumnWidth(2.0), // Supplier Name
                        1: FlexColumnWidth(1.5), // Total Debit
                        2: FlexColumnWidth(1.5), // Total Credit
                        3: FlexColumnWidth(1.5), // Balance
                        4: FlexColumnWidth(1.2), // Transaction Count
                        5: FlexColumnWidth(1.0), // Action
                      },
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _buildTableHeader("Supplier Name"),
                            _buildTableHeader("Total Debit"),
                            _buildTableHeader("Total Credit"),
                            _buildTableHeader("Balance"),
                            _buildTableHeader("Transactions"),
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
                        child: supplierSummary.isEmpty
                            ? _buildNoDataFoundUI()
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                scrollDirection: Axis.vertical,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.0), // Supplier Name
                                    1: FlexColumnWidth(1.5), // Total Debit
                                    2: FlexColumnWidth(1.5), // Total Credit
                                    3: FlexColumnWidth(1.5), // Balance
                                    4: FlexColumnWidth(1.2), // Transaction Count
                                    5: FlexColumnWidth(1.0), // Action
                                  },
                                  border: null,
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: supplierSummary.entries
                                      .map((entry) => _buildSupplierRow(
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
            Icons.business,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No supplier transactions available',
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

  TableRow _buildSupplierRow(
      SupplierTransactionSummary summary, BuildContext context) {
    // Alternate row colors for better readability
    final int index =
        supplierSummary.keys.toList().indexOf(summary.supplierName);

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _buildTableCell(summary.supplierName),
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
        _buildTableCell(
          summary.transactionCount.toString(),
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
                  // Set the selected supplier and navigate to details
                  Provider.of<SupplierProvider>(context, listen: false)
                      .setSelectedSupplierName(summary.supplierName);
                  sideBarController.index.value =
                      68; // Navigate to SupplierTransactionDetailsScreen
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

class SupplierTransactionSummary {
  final String supplierName;
  double totalDebit;
  double totalCredit;
  double balance;
  int transactionCount;

  SupplierTransactionSummary({
    required this.supplierName,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
    required this.transactionCount,
  });
}