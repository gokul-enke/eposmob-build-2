import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

// Add this import for the new print functionality
import 'package:pos_machine/screens/reports/customer_transactions_reports/transaction_report_print.dart';
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
  bool _showFilters = true;
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
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final selectedIdStr = customerProvider.selectedCustomerId;

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
      debugPrint("Error loading transactions: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('customer_transaction_report.err_loading_transactions'.tr.replaceAll('@error', error.toString())),
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
                hintText: 'customer_transaction_report.all_prefix'.tr.replaceAll('@label', label),
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
                    'customer_transaction_report.all'.tr,
                    style: const TextStyle(
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
              hintText: 'customer_transaction_report.select_date_hint'.tr,
              isAllowEdit: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionCard(int slNo, ListTransaction tx) {
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
                Text(
                  '#$slNo  ${tx.orderNumber?.toString() ?? 'customer_transaction_report.na'.tr}',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s13, 0.20, ColorManager.textColor),
                ),
                Row(
                  children: [
                    _buildTypeCell(tx.type ?? 'customer_transaction_report.na'.tr),
                    const SizedBox(width: 6),
                    _buildStatusChipInline(tx.status ?? 'customer_transaction_report.na'.tr),
                  ],
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                _buildMobileCardStat('customer_transaction_report.txn_type_stat'.tr, tx.transactionType ?? 'customer_transaction_report.na'.tr),
                _buildMobileCardStat('customer_transaction_report.amount_col'.tr, tx.amount ?? '0.00'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tx.date ?? 'customer_transaction_report.na'.tr,
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s10, 0.15, Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChipInline(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status.toUpperCase()) {
      case 'SUCC':
      case 'SUCCESS':
      case 'COMPLETED':
        bg = Colors.green.withOpacity(0.1);
        fg = Colors.green;
        label = 'customer_transaction_report.success_label'.tr;
        break;
      case 'INIT':
      case 'INITIATED':
      case 'PENDING':
        bg = Colors.orange.withOpacity(0.1);
        fg = Colors.orange;
        label = 'customer_transaction_report.pending_label'.tr;
        break;
      case 'FAIL':
      case 'FAILED':
      case 'CANCELLED':
        bg = Colors.red.withOpacity(0.1);
        fg = Colors.red;
        label = 'customer_transaction_report.failed_label'.tr;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey;
        label = status.isEmpty ? 'customer_transaction_report.na'.tr : status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
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
              style: buildCustomStyle(
                  FontWeightManager.medium, FontSize.s12, 0.18, Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
        child: (filteredTransactions?.isEmpty ?? true)
            ? _buildNoDataFoundUI()
            : ListView.builder(
                itemCount: filteredTransactions!.length,
                itemBuilder: (ctx, i) => _buildMobileTransactionCard(
                    i + 1, filteredTransactions![i]),
              ),
      );
    }

    return Expanded(
      child: Consumer<InvoiceProvider>(
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
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        children: [
                          _buildTableHeader('customer_transaction_report.sl_no_col'.tr),
                          _buildTableHeader('customer_transaction_report.order_number_col'.tr),
                          _buildTableHeader('customer_transaction_report.transaction_type_label'.tr),
                          _buildTableHeader('customer_transaction_report.amount_col'.tr),
                          _buildTableHeader('customer_transaction_report.type_label'.tr),
                          _buildTableHeader('customer_transaction_report.transaction_date_col'.tr),
                          _buildTableHeader('customer_transaction_report.status_label'.tr),
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
                                  2: FlexColumnWidth(1.5), // Transaction Type
                                  3: FlexColumnWidth(1.2), // Amount
                                  4: FlexColumnWidth(1.0), // Type
                                  5: FlexColumnWidth(1.5), // Transaction Date
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
            'customer_transaction_report.no_transactions_available'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'customer_transaction_report.try_adjusting_filters'.tr,
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
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
    // Match styling to _buildTypeCell: radius 8, opacity 0.1, bold, fontSize 12
    Color bg;
    Color fg;
    String label;

    switch (status.toUpperCase()) {
      case 'SUCC':
      case 'SUCCESS':
      case 'COMPLETED':
        bg = Colors.green.withOpacity(0.1);
        fg = Colors.green;
        label = 'customer_transaction_report.success_label'.tr;
        break;
      case 'INIT':
      case 'INITIATED':
      case 'PENDING':
        bg = Colors.orange.withOpacity(0.1);
        fg = Colors.orange;
        label = 'customer_transaction_report.pending_label'.tr;
        break;
      case 'FAIL':
      case 'FAILED':
      case 'CANCELLED':
        bg = Colors.red.withOpacity(0.1);
        fg = Colors.red;
        label = 'customer_transaction_report.failed_label'.tr;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey;
        label = status.isEmpty ? 'customer_transaction_report.na'.tr : status;
    }

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
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
        _buildTableCell(transaction.orderNumber?.toString() ?? 'customer_transaction_report.na'.tr),
        _buildTableCell(transaction.transactionType ?? 'customer_transaction_report.na'.tr),
        _buildTableCell(transaction.amount ?? "0.00"),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Center(child: _buildTypeCell(transaction.type ?? 'customer_transaction_report.na'.tr)),
          ),
        ),
        _buildTableCell(transaction.date ?? 'customer_transaction_report.na'.tr),
        // _buildStatusChip already returns a TableCell. It must not be wrapped in Center.
        _buildStatusChip(transaction.status ?? 'customer_transaction_report.na'.tr),
      ],
    );
  }

  void _printReport() async {
    // Show loading indicator
    if (mounted) {
      showScaffold(
        context: context,
        message: 'customer_transaction_report.preparing_report'.tr,
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
    String orderDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateHelper.now());
    String orderNumber =
        "TXN-REPORT-${DateHelper.now().millisecondsSinceEpoch}";

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
          content: Text('customer_transaction_report.preparing_report_printing'.tr),
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
                const SizedBox(height: 20),
                if (_showFilters) _buildFilters(),
                if (_showFilters) const SizedBox(height: 20),
                _buildReportTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBackButton(
                  onPressed: () {
                    sideBarController.index.value = 65;
                  },
                  text: 'customer_transaction_report.all_customers'.tr,
                ),
                Text(
                  'customer_transaction_report.transaction_details'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s20,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
              ],
            ),
            if (!_isMobile(context))
              CustomRoundButton(
                title: 'customer_transaction_report.print'.tr,
                boxColor: ColorManager.kPrimaryColor,
                textColor: Colors.white,
                fct: _printReport,
                height: 40,
                width: 120,
                fontSize: FontSize.s12,
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
        ),
        if (_isMobile(context)) const SizedBox(height: 8),
        if (_isMobile(context))
          CustomRoundButton(
            title: 'customer_transaction_report.print'.tr,
            boxColor: ColorManager.kPrimaryColor,
            textColor: Colors.white,
            fct: _printReport,
            height: 36,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
      ],
    );
  }

  Widget _buildFilters() {
    if (_isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'customer_transaction_report.type_label'.tr,
                  _transactionTypeController,
                  transactionTypes,
                  (value) {
                    setState(() => searchTransactionType = value);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdownField(
                  'customer_transaction_report.status_label'.tr,
                  _statusController,
                  statuses,
                  (value) {
                    setState(() => searchStatus = value);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'customer_transaction_report.cr_dr_label'.tr,
                  _typeController,
                  types,
                  (value) {
                    setState(() => searchType = value);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateField('customer_transaction_report.from_date'.tr, _fromDateController, true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateField('customer_transaction_report.to_date'.tr, _toDateController, false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 42),
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
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        // First row of filters (4 filters)
        SizedBox(
          height: 90,
          child: Row(
            children: [
              // Customer filter removed as per request
              Expanded(
                flex: 1,
                child: _buildDropdownField(
                  'customer_transaction_report.transaction_type_label'.tr,
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
                  'customer_transaction_report.status_label'.tr,
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
                  'customer_transaction_report.type_label'.tr,
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
                child: Container(), // Empty space to maintain 4-field layout
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 42, left: 10),
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

  // Customer filter UI removed as per request

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
