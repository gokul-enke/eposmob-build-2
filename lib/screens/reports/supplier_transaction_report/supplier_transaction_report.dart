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
import 'package:pos_machine/components/build_pagination_control.dart';

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
  bool _showFilters = true;
  List<Supplier>? allSuppliers = [];

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  // For storing API response data
  List<dynamic>? _groupedData = [];

  // For grouping supplier transactions (keyed by supplierId)
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

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    // Set default date values
    _setInitialDateFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showFilters = !_isMobile(context));
      loadInitData();
    });
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
    // Default to no date filter: leave both fields empty
    setState(() {
      _fromDateController.text = '';
      _toDateController.text = '';
    });
  }

  Future<void> loadInitData() async {
    if (!mounted) return;
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

      if (!mounted) return;

      // Get all suppliers for suggestions
      allSuppliers = supplierProvider.allSuppliers ?? [];
      final suggestions = getSupplierSuggestions();

      if (mounted) {
        setState(() {
          supplierSuggestions = suggestions;
        });
      }

      // Load filtered transaction data from API
      await _loadFilteredTransactionData();
    } catch (error) {
      debugPrint('Error loading supplier data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('supplier_transaction_report.err_loading_supplier_data'.tr.replaceAll('@error', error.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
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

  // Load filtered supplier grouped data from API
  Future<void> _loadFilteredTransactionData({int? page}) async {
    if (!mounted) return;
    if (!_isDateRangeValid()) return;
    debugPrint('🔄 [SUPPLIER_TX_REPORT] Starting _loadFilteredTransactionData');
    debugPrint('📋 [SUPPLIER_TX_REPORT] Search supplier: "${searchSupplier}"');
    debugPrint(
        '📅 [SUPPLIER_TX_REPORT] From date: "${_fromDateController.text}"');
    debugPrint('📅 [SUPPLIER_TX_REPORT] To date: "${_toDateController.text}"');
    debugPrint(
        '👥 [SUPPLIER_TX_REPORT] Total suppliers available: ${allSuppliers?.length ?? 0}');

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '🔑 [SUPPLIER_TX_REPORT] Access token: ${accessToken != null ? "Present" : "NULL"}');

      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      // Use pre-selected supplierId if available (set on autocomplete selection)
      String? supplierId = selectedSupplierId;
      if (supplierId != null && supplierId.isNotEmpty) {
        debugPrint(
            '✅ [SUPPLIER_TX_REPORT] Using selected supplierId: $supplierId for fetch');
      } else {
        debugPrint(
            'ℹ️ [SUPPLIER_TX_REPORT] No supplier selected, fetching for all suppliers');
      }

      // Call API with filters
      debugPrint(
          '🌐 [SUPPLIER_TX_REPORT] Calling fetchSupplierTransactions API');
      debugPrint('📤 [SUPPLIER_TX_REPORT] API Parameters:');
      debugPrint('   - supplierName: null (using supplierId when selected)');
      debugPrint('   - supplierId: ${supplierId ?? "null"}');
      debugPrint(
          '   - fromDate: ${_fromDateController.text.isNotEmpty ? _fromDateController.text : "null"}');
      debugPrint(
          '   - toDate: ${_toDateController.text.isNotEmpty ? _toDateController.text : "null"}');
      debugPrint('   - listAll: false (server-side pagination)');

      final response = await supplierProvider.fetchSupplierTransactions(
        accessToken: accessToken ?? "",
        supplierName: null, // Always prefer ID for accuracy
        supplierId: supplierId,
        transactionType: null, // Can be added later if needed
        fromDate: _fromDateController.text.isNotEmpty
            ? _fromDateController.text
            : null,
        toDate:
            _toDateController.text.isNotEmpty ? _toDateController.text : null,
        // The report has a pagination control; request the backend paginator
        // instead of loading the entire grouped ledger into memory.
        listAll: false,
        page: page ?? _currentPage,
      );

      debugPrint('📥 [SUPPLIER_TX_REPORT] API Response received');
      debugPrint(
          '📊 [SUPPLIER_TX_REPORT] Response keys: ${response.keys.toList()}');
      if (!mounted) return;
      final dataNode = response['data'];
      debugPrint(
          '🧪 [SUPPLIER_TX_REPORT] data node type: ${dataNode.runtimeType}');
      // New grouped response: data is Map with pagination and data list
      if (dataNode is Map && dataNode['data'] is List) {
        // Update pagination
        try {
          _currentPage = (dataNode['current_page'] ?? 1) is num
              ? (dataNode['current_page'] as num).toInt()
              : int.tryParse((dataNode['current_page'] ?? '1').toString()) ?? 1;
          _lastPage = (dataNode['last_page'] ?? 1) is num
              ? (dataNode['last_page'] as num).toInt()
              : int.tryParse((dataNode['last_page'] ?? '1').toString()) ?? 1;
        } catch (_) {}

        final groups = List<dynamic>.from(dataNode['data']);
        debugPrint(
            '🧾 [SUPPLIER_TX_REPORT] Parsed groups from data["data"] (count=${groups.length})');
        setState(() {
          _groupedData = groups;
        });
        _processGroupedData();
      } else if (dataNode is List) {
        // Legacy/alternate response: data is a top-level list of groups
        final groups = List<dynamic>.from(dataNode);
        debugPrint(
            '🧾 [SUPPLIER_TX_REPORT] Parsed groups from top-level List (count=${groups.length})');
        setState(() {
          _groupedData = groups;
          _currentPage = 1;
          _lastPage = 1;
        });
        _processGroupedData();
      } else {
        // Fallback to empty
        setState(() {
          _groupedData = [];
          supplierSummary.clear();
        });
      }
      debugPrint(
          '✅ [SUPPLIER_TX_REPORT] _loadFilteredTransactionData completed successfully');
    } catch (error) {
      debugPrint(
          '💥 [SUPPLIER_TX_REPORT] ERROR in _loadFilteredTransactionData: $error');
      debugPrint(
          '📍 [SUPPLIER_TX_REPORT] Error stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _groupedData = [];
          supplierSummary.clear();
        });
      }
    }
  }

  bool _isDateRangeValid() {
    final from = _fromDateController.text.trim();
    final to = _toDateController.text.trim();
    if (from.isEmpty || to.isEmpty) return true;
    final fromDate = DateTime.tryParse(from);
    final toDate = DateTime.tryParse(to);
    if (fromDate == null || toDate == null || !fromDate.isAfter(toDate)) {
      return true;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('supplier_transaction_report.from_date_after_to_date'.tr),
        backgroundColor: Colors.orange,
      ));
    return false;
  }

  // Process grouped API data to create supplier summary
  void _processGroupedData() {
    debugPrint('⚙️ [SUPPLIER_TX_REPORT] Starting _processApiTransactionData');

    if (_groupedData == null || _groupedData!.isEmpty) {
      debugPrint('📭 [SUPPLIER_TX_REPORT] No transaction data to process');
      setState(() {
        supplierSummary.clear();
      });
      return;
    }

    debugPrint(
        '📊 [SUPPLIER_TX_REPORT] Processing ${_groupedData!.length} supplier groups');

    // Keyed by supplierId
    Map<String, SupplierTransactionSummary> processedSummary = {};
    for (final g in _groupedData!) {
      if (g is! Map) continue;
      final String supplierIdKey = (g['supplier_id']?.toString() ?? '').trim();
      final String displayName = (g['supplier_name'] ?? 'supplier_transaction_report.unknown'.tr).toString();
      final double totalDebit = (g['total_debit'] is num)
          ? (g['total_debit'] as num).toDouble()
          : double.tryParse((g['total_debit'] ?? '0').toString()) ?? 0.0;
      final double totalCredit = (g['total_credit'] is num)
          ? (g['total_credit'] as num).toDouble()
          : double.tryParse((g['total_credit'] ?? '0').toString()) ?? 0.0;
      final double balance = (g['balance'] is num)
          ? (g['balance'] as num).toDouble()
          : double.tryParse((g['balance'] ?? '0').toString()) ?? 0.0;
      final int txnCount =
          (g['transactions'] is List) ? (g['transactions'] as List).length : 0;

      if (supplierIdKey.isEmpty) continue;

      processedSummary[supplierIdKey] = SupplierTransactionSummary(
        supplierId: supplierIdKey,
        displayName: displayName,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        balance: balance,
        transactionCount: txnCount,
      );
    }

    setState(() {
      supplierSummary = processedSummary;
    });

    debugPrint(
        '✅ [SUPPLIER_TX_REPORT] _processApiTransactionData completed. ${processedSummary.length} suppliers in summary');
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
      _groupedData = [];
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
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile(context) ? 5 : 10,
            vertical: _isMobile(context) ? 10 : 20,
          ),
          padding: EdgeInsets.all(_isMobile(context) ? 4 : 8),
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
            padding: EdgeInsets.symmetric(
              vertical: _isMobile(context) ? 12.0 : 20.0,
              horizontal: _isMobile(context) ? 12.0 : 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 15),
                if (_showFilters) _buildFilters(),
                if (_showFilters) const SizedBox(height: 20),
                _buildReportTable(),
                const SizedBox(height: 10),
                _buildPagination(),
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
        Expanded(
          child: Text(
            'supplier_transaction_report.title'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
        ),
        if (_isMobile(context))
          TextButton.icon(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              size: 18,
              color: ColorManager.kPrimaryColor,
            ),
            label: Text(
              _showFilters ? 'supplier_transaction_report.hide'.tr : 'supplier_transaction_report.filters'.tr,
              style: const TextStyle(
                  color: ColorManager.kPrimaryColor, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildFilters() {
    if (_isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupplierAutocompleteField(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child:
                      _buildDateField('supplier_transaction_report.from_date'.tr, _fromDateController, true)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildDateField('supplier_transaction_report.to_date'.tr, _toDateController, false)),
            ],
          ),
          const SizedBox(height: 8),
          CustomRoundButton(
            title: 'supplier_transaction_report.reset'.tr,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: _resetFilters,
            height: 45,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
        ],
      );
    }
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
                'supplier_transaction_report.from_date'.tr,
                _fromDateController,
                true,
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildDateField(
                'supplier_transaction_report.to_date'.tr,
                _toDateController,
                false,
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 45, left: 10),
                child: CustomRoundButton(
                  title: 'supplier_transaction_report.reset'.tr,
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
    if (selectedSupplierId != null &&
        allSuppliers != null &&
        allSuppliers!.isNotEmpty) {
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
              'supplier_transaction_report.supplier'.tr,
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
            hintText: 'supplier_transaction_report.search_supplier_hint'.tr,
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
              debugPrint(
                  '🔗 [SUPPLIER_TX_REPORT] dropdown onChanged: name="${s?.name}", supplierId=${selectedSupplierId ?? 'null'}');
              _loadFilteredTransactionData();
            },
            searchHintText: 'supplier_transaction_report.search_supplier_hint_typing'.tr,
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
              hintText: 'supplier_transaction_report.select_date_hint'.tr,
              isAllowEdit: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSupplierCard(SupplierTransactionSummary summary) {
    final Color balanceColor = summary.balance < 0 ? Colors.red : Colors.green;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SelectableText(
                    summary.displayName,
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s14, 0.20, ColorManager.textColor),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.visibility,
                      size: 18, color: ColorManager.kPrimaryColor),
                  onPressed: () {
                    Provider.of<SupplierProvider>(context, listen: false)
                      ..setSelectedSupplierName(summary.displayName)
                      ..setSelectedSupplierId(summary.supplierId);
                    sideBarController.index.value = 68;
                  },
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                _buildMobileCardStat(
                    'supplier_transaction_report.debit_stat'.tr, summary.totalDebit.toStringAsFixed(2)),
                _buildMobileCardStat(
                    'supplier_transaction_report.credit_stat'.tr, summary.totalCredit.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('supplier_transaction_report.balance'.tr,
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s10, 0.15, Colors.grey)),
                      Text(
                        summary.balance.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMobileCardStat(
                    'supplier_transaction_report.transactions'.tr, summary.transactionCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s10, 0.15, Colors.grey)),
          Text(value,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.18, Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildReportTable() {
    if (initLoading) {
      return const Expanded(
          child: Center(child: CircularProgressIndicator.adaptive()));
    }

    if (_isMobile(context)) {
      return Expanded(
        child: supplierSummary.isEmpty
            ? _buildNoDataFoundUI()
            : ListView.builder(
                itemCount: supplierSummary.length,
                itemBuilder: (ctx, i) {
                  final entry = supplierSummary.entries.elementAt(i);
                  return _buildMobileSupplierCard(entry.value);
                },
              ),
      );
    }

    return Expanded(
      child: BuildBoxShadowContainer(
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
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildTableHeader('supplier_transaction_report.supplier_name_col'.tr),
                      _buildTableHeader('supplier_transaction_report.total_debit_col'.tr),
                      _buildTableHeader('supplier_transaction_report.total_credit_col'.tr),
                      _buildTableHeader('supplier_transaction_report.balance'.tr),
                      _buildTableHeader('supplier_transaction_report.transactions'.tr),
                      _buildTableHeader('supplier_transaction_report.action_col'.tr),
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
                                .map((entry) =>
                                    _buildSupplierRow(entry.value, context))
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
            'supplier_transaction_report.no_supplier_transactions'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'supplier_transaction_report.try_refreshing'.tr,
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
    final int index = supplierSummary.keys.toList().indexOf(summary.supplierId);

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: SelectableText(
                summary.displayName,
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  Colors.black,
                ),
              ),
            ),
          ),
        ),
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
                    ..setSelectedSupplierName(summary.displayName)
                    ..setSelectedSupplierId(summary.supplierId);
                  debugPrint(
                      '👁️ [SUPPLIER_TX_REPORT] View clicked for supplierId=${summary.supplierId}, name="${summary.displayName}"');
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

  Widget _buildPagination() {
    return PaginationControl(
      currentPage: _currentPage,
      totalPages: _lastPage,
      onPageChanged: (int page) {
        if (!initLoading && page >= 1 && page <= _lastPage) {
          _loadFilteredTransactionData(page: page);
        }
      },
    );
  }
}

class SupplierTransactionSummary {
  final String supplierId;
  final String displayName;
  double totalDebit;
  double totalCredit;
  double balance;
  int transactionCount;

  SupplierTransactionSummary({
    required this.supplierId,
    required this.displayName,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
    required this.transactionCount,
  });
}
