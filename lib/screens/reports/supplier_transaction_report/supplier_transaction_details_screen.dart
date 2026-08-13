import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
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

// Import date filtering components
import 'package:pos_machine/components/build_calendar_selection.dart';
// Import print functionality
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart';
import 'dart:async';

class SupplierTransactionDetailsScreen extends StatefulWidget {
  const SupplierTransactionDetailsScreen({super.key});

  @override
  State<SupplierTransactionDetailsScreen> createState() =>
      _SupplierTransactionDetailsScreenState();
}

class _SupplierTransactionDetailsScreenState
    extends State<SupplierTransactionDetailsScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  bool _showFilters = true;
  List<SupplierTransaction> filteredTransactions = [];
  String selectedSupplierName = '';

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  // Controllers for filters
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Filter variables
  String selectedTransactionType = 'All';
  String selectedPaymentMethod = 'All';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Set default date values
    _setInitialDateFilters();
    loadInitData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showFilters = !_isMobile(context));
    });
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _searchController.dispose();
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
    if (!mounted) return;
    setState(() {
      initLoading = true;
    });

    try {
      final supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      final String? supplierId = supplierProvider.selectedSupplierId;
      selectedSupplierName = supplierProvider.selectedSupplierName ?? '';

      debugPrint('🔎 [SUPP_TX_DETAILS] loadInitData start');
      debugPrint(
          '🔖 [SUPP_TX_DETAILS] selectedSupplierId: ${supplierId ?? 'null'}');
      debugPrint(
          '🔖 [SUPP_TX_DETAILS] selectedSupplierName: ${selectedSupplierName.isEmpty ? '(empty)' : selectedSupplierName}');

      if ((supplierId == null || supplierId.isEmpty) &&
          selectedSupplierName.isEmpty) {
        // No context, go back to report
        sideBarController.index.value = 67; // Supplier Transaction Report
        return;
      }

      // Fetch grouped transactions from API filtered by supplierId and date range
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '🌐 [SUPP_TX_DETAILS] Calling fetchSupplierTransactions with:');
      debugPrint(
          '    supplierId=${supplierId ?? 'null'} fromDate=${_fromDateController.text} toDate=${_toDateController.text}');
      final response = await supplierProvider.fetchSupplierTransactions(
        accessToken: accessToken ?? '',
        supplierId: supplierId,
        fromDate: _fromDateController.text.isNotEmpty
            ? _fromDateController.text
            : null,
        toDate:
            _toDateController.text.isNotEmpty ? _toDateController.text : null,
        listAll: true,
      );

      if (!mounted) return;

      final dataNode = response['data'];
      debugPrint(
          '📬 [SUPP_TX_DETAILS] Response received. data node type: ${dataNode.runtimeType}');
      List<SupplierTransaction> txns = [];
      if (dataNode is Map && dataNode['data'] is List) {
        final groups = (dataNode['data'] as List).cast<dynamic>();
        debugPrint(
            '🧾 [SUPP_TX_DETAILS] Parsed groups from data["data"], count=${groups.length}');
        // Find the group for our supplier
        Map? group;
        if (supplierId != null && supplierId.isNotEmpty) {
          group = groups.cast<Map?>().firstWhere(
                (g) => (g?['supplier_id']?.toString() ?? '') == supplierId,
                orElse: () => null,
              );
          debugPrint(
              '🔗 [SUPP_TX_DETAILS] Group lookup by supplierId ${group == null ? 'failed' : 'succeeded'}');
        }
        group ??= groups.cast<Map?>().firstWhere(
              (g) => (g?['supplier_name'] ?? '') == selectedSupplierName,
              orElse: () => null,
            );
        if (group == null)
          debugPrint('❗ [SUPP_TX_DETAILS] Group lookup by name also failed');

        if (group != null) {
          // Update title name if needed
          if (selectedSupplierName.isEmpty) {
            selectedSupplierName = (group['supplier_name'] ?? '').toString();
          }
          final List<dynamic> list =
              (group['transactions'] as List?) ?? const [];
          debugPrint(
              '🧮 [SUPP_TX_DETAILS] Transactions in group: ${list.length}');
          txns = list
              .whereType<Map<String, dynamic>>()
              .map((m) => SupplierTransaction.fromJson(m))
              .toList();
        }
      } else if (dataNode is List) {
        // Rare case: top-level list; try to find group similarly
        final groups = dataNode.cast<Map?>();
        debugPrint(
            '🧾 [SUPP_TX_DETAILS] Parsed groups from top-level List, count=${groups.length}');
        Map? group;
        if (supplierId != null && supplierId.isNotEmpty) {
          group = groups.firstWhere(
            (g) => (g?['supplier_id']?.toString() ?? '') == supplierId,
            orElse: () => null,
          );
        }
        group ??= groups.firstWhere(
          (g) => (g?['supplier_name'] ?? '') == selectedSupplierName,
          orElse: () => null,
        );
        if (group != null) {
          final List<dynamic> list =
              (group['transactions'] as List?) ?? const [];
          debugPrint(
              '🧮 [SUPP_TX_DETAILS] Transactions in group (top-level): ${list.length}');
          txns = list
              .whereType<Map<String, dynamic>>()
              .map((m) => SupplierTransaction.fromJson(m))
              .toList();
        } else {
          debugPrint(
              '❗ [SUPP_TX_DETAILS] No matching group found in top-level list');
        }
      }

      debugPrint(
          '✅ [SUPP_TX_DETAILS] Parsed transactions count: ${txns.length}');
      _applyFilters(txns);
    } catch (error) {
      debugPrint('Error loading supplier transaction data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('supplier_transaction_report.err_loading_transaction_data'.tr.replaceAll('@error', error.toString())),
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

  void _applyFilters(List<SupplierTransaction> allTransactions) {
    debugPrint('🔧 [SUPP_TX_DETAILS] Applying filters:');
    debugPrint(
        '    type=$selectedTransactionType payment=$selectedPaymentMethod search="$searchQuery"');
    debugPrint(
        '    from=${_fromDateController.text} to=${_toDateController.text}');
    List<SupplierTransaction> filtered = [...allTransactions];

    // Date range filter
    if (_fromDateController.text.isNotEmpty ||
        _toDateController.text.isNotEmpty) {
      try {
        final formatter = DateFormat('yyyy-MM-dd');

        filtered = filtered.where((transaction) {
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

    // Transaction type filter
    if (selectedTransactionType != 'All') {
      filtered = filtered
          .where((transaction) =>
              transaction.type.toLowerCase() ==
              selectedTransactionType.toLowerCase())
          .toList();
    }

    // Payment method filter
    if (selectedPaymentMethod != 'All') {
      filtered = filtered
          .where((transaction) =>
              transaction.paymentMethod.toLowerCase() ==
              selectedPaymentMethod.toLowerCase())
          .toList();
    }

    // Search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((transaction) =>
              transaction.reference
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) ||
              transaction.transactionType
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) ||
              transaction.amount
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
          .toList();
    }

    debugPrint(
        '📊 [SUPP_TX_DETAILS] Filtered transactions count: ${filtered.length}');
    setState(() {
      filteredTransactions = filtered;
    });
  }

  void _resetFilters() {
    // Clear the text controllers
    _fromDateController.clear();
    _toDateController.clear();
    _searchController.clear();

    // Reset the filter variables
    setState(() {
      selectedTransactionType = 'All';
      selectedPaymentMethod = 'All';
      searchQuery = '';
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
                _buildTransactionTable(),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'supplier_transaction_report.transaction_details_title'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'supplier_transaction_report.supplier_prefix'.tr.replaceAll('@name', selectedSupplierName),
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s14,
                      0.27,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isMobile(context))
              Row(
                children: [
                  CustomRoundButton(
                    title: 'supplier_transaction_report.print'.tr,
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                    fct: _printReport,
                    height: 40,
                    width: 80,
                    fontSize: FontSize.s12,
                  ),
                  const SizedBox(width: 10),
                  CustomRoundButton(
                    title: 'supplier_transaction_report.back_to_report'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    fct: () {
                      sideBarController.index.value = 67;
                    },
                    height: 40,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
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
        ),
        if (_isMobile(context)) const SizedBox(height: 8),
        if (_isMobile(context))
          Row(
            children: [
              Expanded(
                child: CustomRoundButton(
                  title: 'supplier_transaction_report.print'.tr,
                  boxColor: ColorManager.kPrimaryColor,
                  textColor: Colors.white,
                  fct: _printReport,
                  height: 36,
                  width: double.infinity,
                  fontSize: FontSize.s12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomRoundButton(
                  title: 'supplier_transaction_report.back'.tr,
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: () => sideBarController.index.value = 67,
                  height: 36,
                  width: double.infinity,
                  fontSize: FontSize.s12,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFilters() {
    if (_isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(),
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
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'supplier_transaction_report.type_label'.tr,
                  selectedTransactionType,
                  ['All', 'Credit', 'Debit'],
                  (value) {
                    setState(() => selectedTransactionType = value!);
                    _applyFiltersFromCurrentData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdownField(
                  'supplier_transaction_report.payment_label'.tr,
                  selectedPaymentMethod,
                  ['All', 'Cash', 'Card', 'Bank Transfer', 'Cheque', 'UPI'],
                  (value) {
                    setState(() => selectedPaymentMethod = value!);
                    _applyFiltersFromCurrentData();
                  },
                ),
              ),
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
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildSearchField(),
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
                child: _buildDropdownField(
                  'supplier_transaction_report.transaction_type_label'.tr,
                  selectedTransactionType,
                  ['All', 'Credit', 'Debit'],
                  (value) {
                    setState(() {
                      selectedTransactionType = value!;
                    });
                    _applyFiltersFromCurrentData();
                  },
                ),
              ),
            ],
          ),
        ),
        // Second row of filters
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildDropdownField(
                  'supplier_transaction_report.payment_method_label'.tr,
                  selectedPaymentMethod,
                  ['All', 'Cash', 'Card', 'Bank Transfer', 'Cheque', 'UPI'],
                  (value) {
                    setState(() {
                      selectedPaymentMethod = value!;
                    });
                    _applyFiltersFromCurrentData();
                  },
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(), // Empty space
              ),
              Expanded(
                flex: 1,
                child: Container(), // Empty space
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
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'supplier_transaction_report.search'.tr,
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
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                _applyFiltersFromCurrentData();
              },
              decoration: InputDecoration(
                hintText: 'supplier_transaction_report.search_hint'.tr,
                hintStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                suffixIcon: const Icon(
                  Icons.search,
                  color: ColorManager.kPrimaryColor,
                  size: 18,
                ),
              ),
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.27,
                ColorManager.textColor,
              ),
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
                _applyFiltersFromCurrentData();
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

  Widget _buildDropdownField(String label, String selectedValue,
      List<String> options, Function(String?) onChanged) {
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
              value: selectedValue == 'All' ? null : selectedValue,
              decoration: decoration.copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                hintText: 'supplier_transaction_report.all_prefix'.tr.replaceAll('@label', label),
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
                    'supplier_transaction_report.all'.tr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...options
                    .where((option) => option != 'All')
                    .map((String option) {
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
                onChanged(value ?? 'All');
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyFiltersFromCurrentData() {
    SupplierProvider supplierProvider =
        Provider.of<SupplierProvider>(context, listen: false);

    final supplier = supplierProvider.supplierList?.firstWhere(
      (s) => s.name == selectedSupplierName,
      orElse: () => Supplier(
        id: 0,
        name: '',
        email: '',
        phone: '',
        productCategories: '',
        address: '',
        balance: 0.0,
        paymentType: '',
        companyId: 0,
        currentBalance: 0.0,
        balanceStatus: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 0,
        transactions: [],
        purchases: [],
      ),
    );

    if (supplier != null && supplier.name.isNotEmpty) {
      _applyFilters(supplier.transactions);
    }
  }

  Widget _buildMobileTransactionCard(SupplierTransaction tx, int index) {
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
                  tx.date,
                  style: buildCustomStyle(FontWeightManager.regular,
                      FontSize.s11, 0.15, Colors.grey),
                ),
                Row(
                  children: [
                    _buildTypeCell(tx.type),
                    const SizedBox(width: 6),
                    _buildStatusChipInline(tx.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tx.reference.isNotEmpty ? tx.reference : '-',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s13,
                  0.20, ColorManager.textColor),
            ),
            const Divider(height: 12),
            Row(
              children: [
                _buildMobileCardStat('supplier_transaction_report.amount_col'.tr,
                    '${tx.currency} ${double.tryParse(tx.amount)?.toStringAsFixed(2) ?? tx.amount}'),
                _buildMobileCardStat('supplier_transaction_report.payment_label'.tr, tx.paymentMethod),
              ],
            ),
            if (tx.transactionType.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tx.transactionType,
                style: buildCustomStyle(
                    FontWeightManager.regular, FontSize.s10, 0.15, Colors.grey),
              ),
            ],
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
        label = 'supplier_transaction_report.success_label'.tr;
        break;
      case 'INIT':
      case 'INITIATED':
      case 'PENDING':
        bg = Colors.orange.withOpacity(0.1);
        fg = Colors.orange;
        label = 'supplier_transaction_report.pending_label'.tr;
        break;
      case 'FAIL':
      case 'FAILED':
      case 'CANCELLED':
        bg = Colors.red.withOpacity(0.1);
        fg = Colors.red;
        label = 'supplier_transaction_report.failed_label'.tr;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey;
        label = status.isEmpty ? 'supplier_transaction_report.na'.tr : status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
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

  Widget _buildTransactionTable() {
    if (initLoading) {
      return const Expanded(
          child: Center(child: CircularProgressIndicator.adaptive()));
    }

    if (_isMobile(context)) {
      return Expanded(
        child: filteredTransactions.isEmpty
            ? _buildNoDataFoundUI()
            : ListView.builder(
                itemCount: filteredTransactions.length,
                itemBuilder: (ctx, i) =>
                    _buildMobileTransactionCard(filteredTransactions[i], i),
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
                  0: FlexColumnWidth(0.8), // Date
                  1: FlexColumnWidth(1.2), // Reference
                  2: FlexColumnWidth(1.0), // Type
                  3: FlexColumnWidth(1.2), // Transaction Type
                  4: FlexColumnWidth(1.0), // Amount
                  5: FlexColumnWidth(1.2), // Payment Method
                  6: FlexColumnWidth(0.8), // Status
                },
                border: null,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildTableHeader('supplier_transaction_report.date_col'.tr),
                      _buildTableHeader('supplier_transaction_report.reference_col'.tr),
                      _buildTableHeader('supplier_transaction_report.type_label'.tr),
                      _buildTableHeader('supplier_transaction_report.transaction_type_label'.tr),
                      _buildTableHeader('supplier_transaction_report.amount_col'.tr),
                      _buildTableHeader('supplier_transaction_report.payment_method_label'.tr),
                      _buildTableHeader('supplier_transaction_report.status_col'.tr),
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
                  child: filteredTransactions.isEmpty
                      ? _buildNoDataFoundUI()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(0.8), // Date
                              1: FlexColumnWidth(1.2), // Reference
                              2: FlexColumnWidth(1.0), // Type
                              3: FlexColumnWidth(1.2), // Transaction Type
                              4: FlexColumnWidth(1.0), // Amount
                              5: FlexColumnWidth(1.2), // Payment Method
                              6: FlexColumnWidth(0.8), // Status
                            },
                            border: null,
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: filteredTransactions
                                .asMap()
                                .entries
                                .map((entry) => _buildTransactionRow(
                                    entry.value, entry.key))
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
            Icons.receipt_long,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'supplier_transaction_report.no_transactions_found'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'supplier_transaction_report.try_adjusting_filters'.tr,
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

  TableRow _buildTransactionRow(SupplierTransaction transaction, int index) {
    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _buildTableCell(transaction.date),
        _buildTableCell(transaction.reference),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Center(child: _buildTypeCell(transaction.type)),
          ),
        ),
        _buildTableCell(transaction.transactionType),
        _buildTableCell(
          "${transaction.currency} ${double.tryParse(transaction.amount)?.toStringAsFixed(2) ?? transaction.amount}",
        ),
        _buildTableCell(transaction.paymentMethod),
        _buildStatusChip(transaction.status),
      ],
    );
  }

  Widget _buildTableCell(String content) {
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
        label = 'supplier_transaction_report.success_label'.tr;
        break;
      case 'INIT':
      case 'INITIATED':
      case 'PENDING':
        bg = Colors.orange.withOpacity(0.1);
        fg = Colors.orange;
        label = 'supplier_transaction_report.pending_label'.tr;
        break;
      case 'FAIL':
      case 'FAILED':
      case 'CANCELLED':
        bg = Colors.red.withOpacity(0.1);
        fg = Colors.red;
        label = 'supplier_transaction_report.failed_label'.tr;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey;
        label = status.isEmpty ? 'supplier_transaction_report.na'.tr : status;
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

  void _printReport() async {
    // Show loading indicator
    if (mounted) {
      showScaffold(
        context: context,
        message: 'supplier_transaction_report.preparing_supplier_report'.tr,
      );
    }

    // Show loading state
    setState(() {
      initLoading = true;
    });

    // Fetch supplier details
    String supplierName = selectedSupplierName;
    String supplierPhone = "";
    String supplierEmail = "";
    String supplierAddress = "";

    if (supplierName.isNotEmpty) {
      try {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null) {
          final supplierProvider =
              Provider.of<SupplierProvider>(context, listen: false);

          // Find supplier by name
          debugPrint("Attempting to fetch supplier details for: $supplierName");
          final supplier = supplierProvider.supplierList?.firstWhere(
            (s) => s.name == supplierName,
            orElse: () => Supplier(
              id: 0,
              name: '',
              email: '',
              phone: '',
              productCategories: '',
              address: '',
              balance: 0.0,
              paymentType: '',
              companyId: 0,
              currentBalance: 0.0,
              balanceStatus: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              userId: 0,
              transactions: [],
              purchases: [],
            ),
          );

          if (supplier != null && supplier.name.isNotEmpty) {
            supplierPhone = supplier.phone ?? "";
            supplierEmail = supplier.email ?? "";
            supplierAddress = supplier.address ?? "";

            debugPrint("Supplier details found:");
            debugPrint("  Name: $supplierName");
            debugPrint("  Phone: $supplierPhone");
            debugPrint("  Email: $supplierEmail");
            debugPrint("  Address: $supplierAddress");
          } else {
            debugPrint("Supplier not found in provider list");
          }
        } else {
          debugPrint("Access token is null, cannot fetch supplier details");
        }
      } catch (e, stackTrace) {
        debugPrint("Error fetching supplier details: $e");
        debugPrint("Stack trace: $stackTrace");
        // Continue with just the name if we can't fetch details
      }
    } else {
      debugPrint("Supplier name is empty, skipping supplier details fetch");
    }

    // Hide loading state
    setState(() {
      initLoading = false;
    });

    // Create a list of cart items from the filtered transactions
    List<SupplierTransaction> cartItems = filteredTransactions;

    // Calculate total amount
    double totalAmount = 0.0;
    for (var transaction in cartItems) {
      double amount = double.tryParse(transaction.amount) ?? 0.0;
      totalAmount += amount;
    }

    String formattedTotal = totalAmount.toStringAsFixed(2);

    // Navigate to print screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SupplierTransactionReportPrint(
            cartItems: cartItems,
            formattedTotal: formattedTotal,
            savedTotal: formattedTotal,
            orderDate: DateTime.now().toIso8601String(),
            orderNumber: "SUPP-${DateTime.now().millisecondsSinceEpoch}",
            isFromLocalStorage: false,
            supplierName: supplierName,
            supplierPhone: supplierPhone,
            supplierEmail: supplierEmail,
            supplierAddress: supplierAddress,
            fromDate: _fromDateController.text,
            toDate: _toDateController.text,
          ),
        ),
      );
    }
  }
}
