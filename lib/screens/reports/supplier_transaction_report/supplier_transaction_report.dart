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
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'dart:async';

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

  // For storing API response data
  List<dynamic>? _transactionData = [];
  
  // For grouping supplier transactions
  Map<String, SupplierTransactionSummary> supplierSummary = {};

  // Controllers for filters
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Filter variables
  String searchSupplier = '';
  String? selectedSupplierId;

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

      // Fetch suppliers for autocomplete suggestions
      await supplierProvider.fetchSuppliers(
        accessToken: accessToken ?? "",
        supplierName: null,
      );

      // Get all suppliers for suggestions
      allSuppliers = supplierProvider.allSuppliers ?? [];
      final suggestions = getSupplierSuggestions();

      setState(() {
        supplierSuggestions = suggestions;
      });

      // Load filtered transaction data from API
      await _loadFilteredTransactionData();

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

  // Load filtered transaction data from API
  Future<void> _loadFilteredTransactionData() async {
    debugPrint('🔄 [SUPPLIER_TX_REPORT] Starting _loadFilteredTransactionData');
    debugPrint('📋 [SUPPLIER_TX_REPORT] Search supplier: "${searchSupplier}"');
    debugPrint('📅 [SUPPLIER_TX_REPORT] From date: "${_fromDateController.text}"');
    debugPrint('📅 [SUPPLIER_TX_REPORT] To date: "${_toDateController.text}"');
    debugPrint('👥 [SUPPLIER_TX_REPORT] Total suppliers available: ${allSuppliers?.length ?? 0}');
    
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('🔑 [SUPPLIER_TX_REPORT] Access token: ${accessToken != null ? "Present" : "NULL"}');
      
      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      // Use pre-selected supplierId if available (set on autocomplete selection)
      String? supplierId = selectedSupplierId;
      if (supplierId != null && supplierId.isNotEmpty) {
        debugPrint('✅ [SUPPLIER_TX_REPORT] Using selected supplierId: $supplierId for fetch');
      } else {
        debugPrint('ℹ️ [SUPPLIER_TX_REPORT] No supplier selected, fetching for all suppliers');
      }

      // Call API with filters
      debugPrint('🌐 [SUPPLIER_TX_REPORT] Calling fetchSupplierTransactions API');
      debugPrint('📤 [SUPPLIER_TX_REPORT] API Parameters:');
      debugPrint('   - supplierName: null (using supplierId when selected)');
      debugPrint('   - supplierId: ${supplierId ?? "null"}');
      debugPrint('   - fromDate: ${_fromDateController.text.isNotEmpty ? _fromDateController.text : "null"}');
      debugPrint('   - toDate: ${_toDateController.text.isNotEmpty ? _toDateController.text : "null"}');
      debugPrint('   - listAll: true');
      
      final response = await supplierProvider.fetchSupplierTransactions(
        accessToken: accessToken ?? "",
        supplierName: null, // Always prefer ID for accuracy
        supplierId: supplierId,
        transactionType: null, // Can be added later if needed
        fromDate: _fromDateController.text.isNotEmpty ? _fromDateController.text : null,
        toDate: _toDateController.text.isNotEmpty ? _toDateController.text : null,
        listAll: true,
      );
      
      debugPrint('📥 [SUPPLIER_TX_REPORT] API Response received');
      debugPrint('📊 [SUPPLIER_TX_REPORT] Response keys: ${response.keys.toList()}');
      final dataNode = response['data'];
      debugPrint('🧪 [SUPPLIER_TX_REPORT] data node type: ${dataNode.runtimeType}');

      List<dynamic> transactionList = const [];
      bool extracted = false;

      if (dataNode is List) {
        // API returned data as a top-level list
        transactionList = List<dynamic>.from(dataNode);
        extracted = true;
        debugPrint('🧾 [SUPPLIER_TX_REPORT] Parsed transactions from List at data (count=${transactionList.length})');
      } else if (dataNode is Map) {
        // Common patterns: data: { data: [...]} or data: { transactions: [...] }
        if (dataNode['data'] is List) {
          transactionList = List<dynamic>.from(dataNode['data']);
          extracted = true;
          debugPrint('🧾 [SUPPLIER_TX_REPORT] Parsed transactions from data["data"] (count=${transactionList.length})');
        } else if (dataNode['transactions'] is List) {
          transactionList = List<dynamic>.from(dataNode['transactions']);
          extracted = true;
          debugPrint('🧾 [SUPPLIER_TX_REPORT] Parsed transactions from data["transactions"] (count=${transactionList.length})');
        } else {
          debugPrint('⚠️ [SUPPLIER_TX_REPORT] Unknown Map structure for data node: keys=${dataNode.keys.toList()}');
        }
      } else {
        debugPrint('⚠️ [SUPPLIER_TX_REPORT] data node is null or unsupported');
      }

      if (extracted) {
        setState(() {
          _transactionData = transactionList;
        });
        debugPrint('💾 [SUPPLIER_TX_REPORT] Transaction data saved to state');
      } else {
        debugPrint('⚠️ [SUPPLIER_TX_REPORT] No transaction data in response');
        setState(() {
          _transactionData = [];
        });
      }

      // Process the API response to create supplier summary
      debugPrint('⚙️ [SUPPLIER_TX_REPORT] Starting to process API transaction data');
      _processApiTransactionData();
      debugPrint('✅ [SUPPLIER_TX_REPORT] _loadFilteredTransactionData completed successfully');

    } catch (error) {
      debugPrint('💥 [SUPPLIER_TX_REPORT] ERROR in _loadFilteredTransactionData: $error');
      debugPrint('📍 [SUPPLIER_TX_REPORT] Error stack trace: ${StackTrace.current}');
      setState(() {
        _transactionData = [];
        supplierSummary.clear();
      });
    }
  }

  // Process API transaction data to create supplier summary
  void _processApiTransactionData() {
    debugPrint('⚙️ [SUPPLIER_TX_REPORT] Starting _processApiTransactionData');
    
    if (_transactionData == null || _transactionData!.isEmpty) {
      debugPrint('📭 [SUPPLIER_TX_REPORT] No transaction data to process');
      setState(() {
        supplierSummary.clear();
      });
      return;
    }
    
    debugPrint('📊 [SUPPLIER_TX_REPORT] Processing ${_transactionData!.length} transactions');

    Map<String, SupplierTransactionSummary> processedSummary = {};
    int processedCount = 0;
    int skippedCount = 0;

    for (var transaction in _transactionData!) {
      final supplierData = transaction['supplier'];
      if (supplierData == null) {
        skippedCount++;
        debugPrint('⚠️ [SUPPLIER_TX_REPORT] Transaction ${processedCount + skippedCount} has no supplier data, skipping');
        continue;
      }

      // Supplier name can be either at supplier.name or supplier.user.name based on API
      String supplierName = (supplierData['name'] as String?) ??
          ((supplierData['user'] is Map && (supplierData['user'] as Map)['name'] is String)
              ? ((supplierData['user'] as Map)['name'] as String)
              : 'Unknown');
      double amount = double.tryParse(transaction['amount'].toString()) ?? 0.0;
      String type = transaction['type'] ?? '';
      
      debugPrint('📝 [SUPPLIER_TX_REPORT] Processing transaction ${processedCount + 1}: Supplier="$supplierName", Amount=$amount, Type="$type"');

      // Initialize summary if not exists
      if (!processedSummary.containsKey(supplierName)) {
        debugPrint('➕ [SUPPLIER_TX_REPORT] Creating new summary for supplier: "$supplierName"');
        processedSummary[supplierName] = SupplierTransactionSummary(
          supplierName: supplierName,
          totalDebit: 0.0,
          totalCredit: 0.0,
          balance: 0.0,
          transactionCount: 0,
        );
      }

      final summary = processedSummary[supplierName]!;

      // Update totals based on transaction type
      if (type.toLowerCase() == 'credit') {
        summary.totalCredit += amount;
        debugPrint('💰 [SUPPLIER_TX_REPORT] Added $amount to credit for "$supplierName" (total: ${summary.totalCredit})');
      } else if (type.toLowerCase() == 'debit') {
        summary.totalDebit += amount;
        debugPrint('💸 [SUPPLIER_TX_REPORT] Added $amount to debit for "$supplierName" (total: ${summary.totalDebit})');
      } else {
        debugPrint('❓ [SUPPLIER_TX_REPORT] Unknown transaction type: "$type" for "$supplierName"');
      }

      summary.transactionCount++;
      processedCount++;
    }
    
    debugPrint('📈 [SUPPLIER_TX_REPORT] Processed $processedCount transactions, skipped $skippedCount');

    // Calculate final balance for each supplier
    debugPrint('🧮 [SUPPLIER_TX_REPORT] Calculating final balances');
    processedSummary.forEach((supplierName, summary) {
      summary.balance = summary.totalCredit - summary.totalDebit;
      debugPrint('🏪 [SUPPLIER_TX_REPORT] "$supplierName": Credit=${summary.totalCredit}, Debit=${summary.totalDebit}, Balance=${summary.balance}, Count=${summary.transactionCount}');
    });

    setState(() {
      supplierSummary = processedSummary;
    });
    
    debugPrint('✅ [SUPPLIER_TX_REPORT] _processApiTransactionData completed. ${processedSummary.length} suppliers in summary');
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
      selectedSupplierId = null;
      _transactionData = [];
      supplierSummary.clear();
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
        onRefresh: () async => await _loadFilteredTransactionData(),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
    // Derive currently selected Supplier from selectedSupplierId to show in dropdown
    Supplier? currentSelected;
    if (selectedSupplierId != null && allSuppliers != null && allSuppliers!.isNotEmpty) {
      try {
        currentSelected = allSuppliers!
            .firstWhere((s) => s.id.toString() == selectedSupplierId);
      } catch (_) {
        currentSelected = null;
      }
    }

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
          BuildDropDownWithSearch<Supplier>(
            title: null,
            hintText: "Search Supplier",
            value: currentSelected,
            items: allSuppliers ?? const <Supplier>[],
            displayText: (s) => s.name,
            height: 45,
            margin: EdgeInsets.zero,
            onChanged: (Supplier? s) {
              setState(() {
                selectedSupplierId = s?.id.toString();
                searchSupplier = s?.name ?? '';
              });
              debugPrint('🔗 [SUPPLIER_TX_REPORT] dropdown onChanged: name="${s?.name}", supplierId=${selectedSupplierId ?? 'null'}');
              _loadFilteredTransactionData();
            },
            searchHintText: 'Type to search supplier...',
            // Ensure consistent padding/width like date fields
            width: double.infinity,
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
                _loadFilteredTransactionData();
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