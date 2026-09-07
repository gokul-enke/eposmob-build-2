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
import 'package:pos_machine/components/build_pagination_control.dart';

// Add imports for customer autocomplete and date filtering
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/providers/customer_provider.dart';
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
  bool _showFilters = true;
  List<ListTransaction>? allTransactions = [];

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  // For grouping customer transactions (keyed by customerId when available)
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

  // Pagination state
  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    // Set default date values
    _setInitialDateFilters();
    loadInitData();
    // Preload customers for dropdown (listAll)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) setState(() => _showFilters = !_isMobile(context));
      try {
        final accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        await Provider.of<CustomerProvider>(context, listen: false)
            .fetchCustomers(accessToken: accessToken ?? '', listAll: true);
      } catch (e) {
        debugPrint('Error preloading customers for dropdown: $e');
      }
    });
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
    // Default to no date filter: leave both fields empty (align with supplier report)
    setState(() {
      _fromDateController.text = '';
      _toDateController.text = '';
    });
  }

  Future<void> loadInitData() async {
    // Use default date filters when called without parameters
    await loadInitDataWithFilters(
      dateFrom: _fromDateController.text,
      dateTo: _toDateController.text,
    );
  }

  Future<void> loadInitDataWithFilters({
    String? customerId,
    String? customerName,
    String? type,
    String? transactionType,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {
    if (!mounted) return;
    if (!_isDateRangeValid(dateFrom, dateTo)) return;
    setState(() {
      initLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      final value = await invoiceProvider.listAllTransaction(
        type: type,
        accessToken: accessToken ?? "",
        customerId: customerId,
        customerName: customerName,
        transactionType: transactionType,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      if (value['status'] == 'success') {
        // Update pagination state from response
        try {
          final data = value['data'];
          if (data is Map) {
            _currentPage = (data['current_page'] ?? 1) is num
                ? (data['current_page'] as num).toInt()
                : int.tryParse((data['current_page'] ?? '1').toString()) ?? 1;
            _lastPage = (data['last_page'] ?? 1) is num
                ? (data['last_page'] as num).toInt()
                : int.tryParse((data['last_page'] ?? '1').toString()) ?? 1;
          }
        } catch (_) {}
        // Detect new grouped response: value.data.data is a list of customer groups
        final data = value['data'];
        if (data is Map && data['data'] is List) {
          final groups = (data['data'] as List).cast<dynamic>();
          final Map<String, CustomerTransactionSummary> summaries = {};

          for (final g in groups) {
            if (g is! Map) continue;
            final String displayName =
                (g['customer_name'] ?? 'customer_transaction_report.unknown_customer'.tr).toString();
            final String idStr = (g['customer_id']?.toString() ?? '').trim();
            final String key = idStr.isNotEmpty ? idStr : displayName;

            final double totalDebit = (g['total_debit'] is num)
                ? (g['total_debit'] as num).toDouble()
                : double.tryParse((g['total_debit'] ?? '0').toString()) ?? 0.0;
            final double totalCredit = (g['total_credit'] is num)
                ? (g['total_credit'] as num).toDouble()
                : double.tryParse((g['total_credit'] ?? '0').toString()) ?? 0.0;
            final double balanceVal = (g['balance'] is num)
                ? (g['balance'] as num).toDouble()
                : double.tryParse((g['balance'] ?? '0').toString()) ?? 0.0;
            final int txnCount = g['transaction_count'] is num
                ? (g['transaction_count'] as num).toInt()
                : (g['transactions'] is List)
                    ? (g['transactions'] as List).length
                    : int.tryParse(
                            (g['transactions_count'] ?? '0').toString()) ??
                        0;

            summaries[key] = CustomerTransactionSummary(
              customerId: idStr.isNotEmpty ? idStr : null,
              displayName: displayName,
              totalDebit: totalDebit,
              totalCredit: totalCredit,
              balance: balanceVal,
              transactionCount: txnCount,
            );
          }

          // Update state from grouped response
          setState(() {
            customerSummary = summaries;
            // Suggestions from grouped names
            customerSuggestions = groups
                .map((e) =>
                    (e is Map ? (e['customer_name'] ?? '').toString() : ''))
                .where((s) => s.isNotEmpty)
                .cast<String>()
                .toList();
          });
        } else {
          // Fallback to old flat response
          ListTransactionModel listTransactionModel =
              ListTransactionModel.fromJson(value);
          allTransactions = listTransactionModel.data?.transactions ?? [];
          final suggestions = getCustomerSuggestions();
          _calculateCustomerSummary();
          setState(() {
            customerSuggestions = suggestions;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('customer_transaction_report.failed_load_transaction_data'.tr),
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
            content: Text('customer_transaction_report.err_loading_transaction_data'.tr.replaceAll('@error', error.toString())),
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

  bool _isDateRangeValid(String? from, String? to) {
    if (from == null || to == null || from.isEmpty || to.isEmpty) return true;
    final fromDate = DateTime.tryParse(from);
    final toDate = DateTime.tryParse(to);
    if (fromDate == null || toDate == null || !fromDate.isAfter(toDate)) {
      return true;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('customer_transaction_report.from_date_after_to_date'.tr),
        backgroundColor: Colors.orange,
      ));
    return false;
  }

  void _loadPage(int page) {
    final customerProvider =
        Provider.of<CustomerProvider>(context, listen: false);
    loadInitDataWithFilters(
      customerId: (customerProvider.selectedCustomerId != null &&
              customerProvider.selectedCustomerId!.isNotEmpty)
          ? customerProvider.selectedCustomerId
          : null,
      customerName: (customerProvider.selectedCustomerId == null ||
              customerProvider.selectedCustomerId!.isEmpty)
          ? (searchCustomer.isNotEmpty ? searchCustomer : null)
          : null,
      dateFrom:
          _fromDateController.text.isNotEmpty ? _fromDateController.text : null,
      dateTo: _toDateController.text.isNotEmpty ? _toDateController.text : null,
      page: page,
    );
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

  // Combined Date and Time selection method
  Future<void> _selectDateTime(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? pickedDate = await showAutoDismissDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: ColorManager.kPrimaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        final formattedDateTime =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
        setState(() {
          if (isFromDate) {
            _fromDateController.text = formattedDateTime;
          } else {
            _toDateController.text = formattedDateTime;
          }
        });
        _applyFilters();
      }
    }
  }

  void _applyFilters() {
    // Use API filtering instead of client-side filtering
    final customerProvider =
        Provider.of<CustomerProvider>(context, listen: false);
    loadInitDataWithFilters(
      customerId: (customerProvider.selectedCustomerId != null &&
              customerProvider.selectedCustomerId!.isNotEmpty)
          ? customerProvider.selectedCustomerId
          : null,
      // Fallback by name if needed
      customerName: (customerProvider.selectedCustomerId == null ||
              customerProvider.selectedCustomerId!.isEmpty)
          ? (searchCustomer.isNotEmpty ? searchCustomer : null)
          : null,
      dateFrom:
          _fromDateController.text.isNotEmpty ? _fromDateController.text : null,
      dateTo: _toDateController.text.isNotEmpty ? _toDateController.text : null,
    );
  }

  void _calculateCustomerSummary() {
    if (allTransactions == null || allTransactions!.isEmpty) {
      setState(() {
        customerSummary.clear();
      });
      return;
    }

    Map<String, CustomerTransactionSummary> filteredCustomerSummary = {};

    for (var transaction in allTransactions!) {
      final String displayName = transaction.customerName ?? 'customer_transaction_report.unknown_customer'.tr;
      final String idStr = (transaction.customerId?.toString() ?? '').trim();
      final String key = idStr.isNotEmpty
          ? idStr
          : displayName; // Fallback to name if ID missing

      final double amount = double.tryParse(transaction.amount ?? '0') ?? 0.0;
      final String type = transaction.type ?? 'unknown';
      final double transactionBalance =
          double.tryParse(transaction.balance ?? '0') ?? 0.0;

      if (!filteredCustomerSummary.containsKey(key)) {
        filteredCustomerSummary[key] = CustomerTransactionSummary(
          customerId: idStr.isNotEmpty ? idStr : null,
          displayName: displayName,
          totalDebit: 0.0,
          totalCredit: 0.0,
          balance: transactionBalance,
          transactionCount: 0,
        );
      }

      // Calculate totals for display purposes
      final normalizedType = type.trim().toLowerCase();
      if (normalizedType == 'credit' || normalizedType == 'cr') {
        filteredCustomerSummary[key]!.totalCredit += amount;
      } else if (normalizedType == 'debit' || normalizedType == 'dr') {
        filteredCustomerSummary[key]!.totalDebit += amount;
      }

      // Increment transaction count
      filteredCustomerSummary[key]!.transactionCount++;
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

    // Reload data with default filters
    loadInitDataWithFilters(
      dateFrom: _fromDateController.text,
      dateTo: _toDateController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => loadInitDataWithFilters(
          customerName: searchCustomer.isNotEmpty ? searchCustomer : null,
          dateFrom: _fromDateController.text.isNotEmpty
              ? _fromDateController.text
              : null,
          dateTo:
              _toDateController.text.isNotEmpty ? _toDateController.text : null,
        ),
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
            'customer_transaction_report.title'.tr,
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
              _showFilters ? 'customer_transaction_report.hide'.tr : 'customer_transaction_report.filters'.tr,
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
          _buildCustomerAutocompleteField(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateField('customer_transaction_report.from_date'.tr, _fromDateController, true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateField('customer_transaction_report.to_date'.tr, _toDateController, false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomRoundButton(
            title: 'customer_transaction_report.reset'.tr,
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
                  'customer_transaction_report.from_date'.tr,
                  _fromDateController,
                  true,
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildDateField(
                  'customer_transaction_report.to_date'.tr,
                  _toDateController,
                  false,
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 45, left: 10),
                  child: CustomRoundButton(
                    title: 'customer_transaction_report.reset'.tr,
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
    // Replace autocomplete with dropdown bound to IDs (parity with supplier report)
    final customerProvider = Provider.of<CustomerProvider>(context);
    final allCustomers = customerProvider.allCustomers ?? const <dynamic>[];

    // Derive selected value from selectedCustomerId
    dynamic currentSelected;
    if ((customerProvider.selectedCustomerId ?? '').isNotEmpty &&
        allCustomers.isNotEmpty) {
      try {
        currentSelected = allCustomers.firstWhere(
          (c) =>
              (c.id?.toString() ?? '') == customerProvider.selectedCustomerId,
        );
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
              'customer_transaction_report.customer'.tr,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          BuildDropDownWithSearch<dynamic>(
            title: null,
            hintText: 'customer_transaction_report.search_customer_hint'.tr,
            value: currentSelected,
            items: allCustomers,
            displayText: (c) => (c.name ?? '').toString(),
            height: 45,
            margin: EdgeInsets.zero,
            onChanged: (dynamic c) {
              // Update provider selection, then refetch
              final idStr = c?.id?.toString();
              customerProvider.setSelectedCustomerId(idStr);
              customerProvider.setSelectedCustomerName(c?.name ?? '');
              // Clear legacy text controller and search string
              _customerController.clear();
              _customerSearchTimer?.cancel();
              setState(() {
                searchCustomer = '';
              });
              _applyFilters();
            },
            searchHintText: 'customer_transaction_report.search_customer_hint_typing'.tr,
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
            child: TextFormField(
              controller: controller,
              onTap: () => _selectDateTime(context, isFromDate: isFromDate),
              readOnly: true,
              cursorColor: ColorManager.kPrimaryColor,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: InputDecoration(
                hintText: 'general.datetime_format_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: ColorManager.kPrimaryColor,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCustomerCard(
      CustomerTransactionSummary summary, BuildContext context) {
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
                    Provider.of<TransactionProvider>(context, listen: false)
                        .setCustomerName(summary.displayName);
                    sideBarController.index.value = 66;
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
                    'customer_transaction_report.debit_stat'.tr, summary.totalDebit.toStringAsFixed(2)),
                _buildMobileCardStat(
                    'customer_transaction_report.credit_stat'.tr, summary.totalCredit.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('customer_transaction_report.balance'.tr,
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
                    'customer_transaction_report.transactions'.tr, summary.transactionCount.toString()),
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
        child: customerSummary.isEmpty
            ? _buildNoDataFoundUI()
            : ListView.builder(
                itemCount: customerSummary.length,
                itemBuilder: (ctx, i) {
                  final entry = customerSummary.entries.elementAt(i);
                  return _buildMobileCustomerCard(entry.value, context);
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
                  0: FlexColumnWidth(2.0), // Customer Name
                  1: FlexColumnWidth(1.5), // Total Debit
                  2: FlexColumnWidth(1.5), // Total Credit
                  3: FlexColumnWidth(1.5), // Balance
                  4: FlexColumnWidth(1.2), // Transactions
                  5: FlexColumnWidth(1.0), // Action
                },
                border: null,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildTableHeader('customer_transaction_report.customer_name_col'.tr),
                      _buildTableHeader('customer_transaction_report.total_debit_col'.tr),
                      _buildTableHeader('customer_transaction_report.total_credit_col'.tr),
                      _buildTableHeader('customer_transaction_report.balance'.tr),
                      _buildTableHeader('customer_transaction_report.transactions'.tr),
                      _buildTableHeader('customer_transaction_report.action_col'.tr),
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
                              4: FlexColumnWidth(1.2), // Transactions
                              5: FlexColumnWidth(1.0), // Action
                            },
                            border: null,
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: customerSummary.entries
                                .map((entry) =>
                                    _buildCustomerRow(entry.value, context))
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

  Widget _buildPagination() {
    return PaginationControl(
      currentPage: _currentPage,
      totalPages: _lastPage,
      onPageChanged: (int page) {
        if (!initLoading && page >= 1 && page <= _lastPage) {
          _loadPage(page);
        }
      },
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
            'customer_transaction_report.no_customer_transactions'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'customer_transaction_report.try_refreshing'.tr,
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
    final List<String> keys = customerSummary.keys.toList();
    final String lookupKey = summary.customerId ?? summary.displayName;
    final int index = keys.indexOf(lookupKey);

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
                  // Use the TransactionProvider instead of the CustomerTransactionProvider
                  Provider.of<TransactionProvider>(context, listen: false)
                      .setCustomerName(summary.displayName);
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
  final String?
      customerId; // string form of ID; can be null if API didn't provide
  final String displayName;
  double totalDebit;
  double totalCredit;
  double balance;
  int transactionCount;

  CustomerTransactionSummary({
    required this.customerId,
    required this.displayName,
    required this.totalDebit,
    required this.totalCredit,
    this.balance = 0.0,
    this.transactionCount = 0,
  });
}
