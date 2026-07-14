import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/screens/transactions/widgets/customer_auto_complete.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart' hide showScaffold, showScaffoldError, showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import '../../models/list_transaction.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/common_details_dialog.dart';

class CustomerTransactionListScreen extends StatefulWidget {
  const CustomerTransactionListScreen({super.key});

  @override
  State<CustomerTransactionListScreen> createState() =>
      _CustomerTransactionListScreenState();
}

class _CustomerTransactionListScreenState
    extends State<CustomerTransactionListScreen> {
  final TextEditingController amountRefController = TextEditingController();
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController referenceSearchController =
      TextEditingController();
  String searchReference = '';
  // Add this with your other controllers
  final TextEditingController customerSearchController =
      TextEditingController();
  // final TextEditingController customerPhoneController =
  //     TextEditingController(); // Commented out - no backend API field yet
  String searchCustomer = '';
  // String searchCustomerPhone = ''; // Commented out - no backend API field yet
  String searchType = '';
  String searchTransactionType = '';
  List<String> customerSuggestions =
      []; // This should be populated with your customer names
  List<String> filteredSuggestions = [];
  bool initLoading = false;
  List<ListTransaction>? listTransaction = [];
  List<ListTransaction>? allTransactions =
      []; // Store all transactions for filtering
  String searchAmount = '';
  DateTime? selectedDate;
  int currentPage = 1;
  int totalPages = 1;
  int _calendarKey = 0;
  final int itemsPerPage = 20;
  String? selectedCustomerId; // for API param

  List<String> getCustomerSuggestions() {
    if (allTransactions == null) return [];
    return allTransactions!
        .map((t) => t.customerName ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  void initState() {
    super.initState();
    loadInitData();
  }

  Future<void> loadInitData() async {
    setState(() {
      initLoading = true;
    });

    try {
      await _fetchServer(page: 1);
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  Future<void> _fetchServer({int? page}) async {
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);

    final String? dateStr = selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(selectedDate!)
        : null;

    final String? typeParam =
        (searchType.isNotEmpty && searchType != 'All') ? searchType.toLowerCase() : null;

    String? transactionTypeParam;
    if (searchTransactionType.isNotEmpty && searchTransactionType != 'All') {
      // API expects lowercase with underscores
      transactionTypeParam = searchTransactionType.toLowerCase().replaceAll(' ', '_');
    }

    final value = await invoiceProvider.listCustomerTransactions(
      accessToken: accessToken ?? '',
      customerId: selectedCustomerId,
      dateFrom: dateStr,
      dateTo: dateStr,
      transactionType: transactionTypeParam,
      type: typeParam,
      perPage: itemsPerPage,
      page: page ?? currentPage,
    );

    if (value != null && value['status'] == 'success') {
      final model = ListTransactionModel.fromJson(value);
      currentPage = model.data?.currentPage ?? 1;
      totalPages = model.data?.lastPage ?? 1;
      allTransactions = model.data?.transactions ?? [];
      applyFilters(); // apply local amount/reference filters
    } else {
      setState(() {
        allTransactions = [];
        listTransaction = [];
        totalPages = 1;
      });
      showScaffold(context: context, message: 'Data Not Found');
    }
  }

  void applyFilters() {
    if (allTransactions == null || allTransactions!.isEmpty) {
      setState(() {
        listTransaction = [];
        // totalPages managed by server
      });
      return;
    }

    // Apply filters
    List<ListTransaction> filteredList = [...allTransactions!];

    // Filter by amount
    if (searchAmount.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) =>
              transaction.amount != null &&
              transaction.amount!.contains(searchAmount))
          .toList();
    }
// Filter by reference ID
    if (searchReference.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) =>
              transaction.referenceId != null &&
              transaction.referenceId!
                  .toLowerCase()
                  .contains(searchReference.toLowerCase()))
          .toList();
    }
    // Filter by customer name
    if (searchCustomer.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) =>
              transaction.customerName != null &&
              transaction.customerName!
                  .toLowerCase()
                  .contains(searchCustomer.toLowerCase()))
          .toList();
    }

    // Filter by customer phone - Commented out: no backend API field
    // if (searchCustomerPhone.isNotEmpty) {
    //   filteredList = filteredList
    //       .where((transaction) =>
    //           transaction.customerPhone != null &&
    //           transaction.customerPhone!
    //               .toLowerCase()
    //               .contains(searchCustomerPhone.toLowerCase()))
    //       .toList();
    // }

    // Filter by type
    if (searchType.isNotEmpty && searchType != 'All') {
      filteredList = filteredList
          .where((transaction) =>
              transaction.type != null &&
              transaction.type!.toLowerCase() == searchType.toLowerCase())
          .toList();
    }

    // Filter by date
    if (selectedDate != null) {
      filteredList = filteredList.where((transaction) {
        if (transaction.date == null) return false;

        try {
          // Parse the transaction date - adjust this based on your date format
          DateTime transactionDate =
              DateFormat('yyyy-MM-dd').parse(transaction.date!);
          return transactionDate.year == selectedDate!.year &&
              transactionDate.month == selectedDate!.month &&
              transactionDate.day == selectedDate!.day;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Server already paginates. Just set the filtered list for current page.
    listTransaction = filteredList;

    setState(() {});
  }

  void resetSearch() {
    // Clear the text controllers
    amountRefController.clear();
    customerSearchController.clear();
    // customerPhoneController.clear(); // Commented out - no backend API field
    referenceSearchController.clear();

    // Reset the search variables
    setState(() {
      searchAmount = '';
      searchCustomer = '';
      selectedCustomerId = null;
      // searchCustomerPhone = ''; // Commented out - no backend API field
      searchReference = '';
      searchType = '';
      selectedDate = null;
      currentPage = 1;
      _calendarKey++;
    });

    // Reload from server
    _fetchServer(page: 1);
  }

  Future<void> refreshData() async {
    resetSearch();
    loadInitData();
  }

  void _showTransactionDetails(ListTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'Transaction Details',
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow('Customer Name', transaction.customerName ?? 'No Name'),
            CommonDetailsDialog.buildKeyValueRow('Date', transaction.date ?? 'N/A'),
            CommonDetailsDialog.buildKeyValueRow('Type', transaction.type ?? 'N/A'),
            CommonDetailsDialog.buildKeyValueRow('Transaction Type', transaction.transactionType ?? 'N/A'),
            CommonDetailsDialog.buildKeyValueRow('Payment Method', transaction.paymentMethod ?? 'N/A'),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('Amount', '${transaction.currency ?? ''} ${transaction.amount ?? ''}'),
            CommonDetailsDialog.buildKeyValueRow('Reference ID', transaction.referenceId ?? 'N/A', copyable: true),
            CommonDetailsDialog.buildKeyValueRow('Reference', transaction.reference ?? 'N/A', copyable: true),
            CommonDetailsDialog.buildKeyValueRow('Status', transaction.status ?? 'N/A'),
            CommonDetailsDialog.buildKeyValueRow('Comment', transaction.transactionComment ?? 'N/A'),
            CommonDetailsDialog.buildKeyValueRow(
              'Created At',
              transaction.createdAt != null
                  ? DateHelper.formatDate(transaction.createdAt!)
                  : 'N/A',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label: ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
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

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          Colors.black,
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
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'INIT':
      case 'INITIATED':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'FAIL':
      case 'FAILED':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
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

  InputDecoration _mobileInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: buildCustomStyle(
          FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide:
              const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2)),
      isDense: true,
    );
  }

  Widget _mobileDropdown({
    required String value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((s) => DropdownMenuItem(
              value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: onChanged,
      decoration: _mobileInputDecoration(hint),
      isExpanded: true,
    );
  }

  Widget _buildMobileFilters(Size size) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.filter_list, size: 18),
        title: Text('Filters',
            style: buildCustomStyle(FontWeightManager.medium,
                FontSize.s12, 0.18, ColorManager.textColor)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                TextFormField(
                  controller: amountRefController,
                  onChanged: (value) {
                    setState(() {
                      searchAmount = value;
                      currentPage = 1;
                    });
                    applyFilters();
                  },
                  decoration: _mobileInputDecoration('Amount'),
                ),
                const SizedBox(height: 8),
                CustomerAutocomplete(
                  size: size,
                  customerList: getCustomerSuggestions(),
                  controller: customerSearchController,
                  onSelected: (String selectedCustomer) {
                    setState(() {
                      searchCustomer = selectedCustomer;
                      final match = allTransactions?.firstWhere(
                        (t) => (t.customerName ?? '').toLowerCase() ==
                            selectedCustomer.toLowerCase(),
                        orElse: () => ListTransaction(),
                      );
                      if (match != null && match.customerId != null) {
                        selectedCustomerId = match.customerId.toString();
                      }
                      currentPage = 1;
                    });
                    _fetchServer(page: 1);
                  },
                ),
                const SizedBox(height: 8),
                _mobileDropdown(
                  value: searchType.isEmpty ? 'All' : searchType,
                  hint: 'Select Type',
                  items: const ['All', 'Credit', 'Debit'],
                  onChanged: (String? value) {
                    setState(() {
                      searchType = value == 'All' ? '' : (value ?? '');
                      currentPage = 1;
                    });
                    _fetchServer(page: 1);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: referenceSearchController,
                  onChanged: (value) {
                    setState(() {
                      searchReference = value;
                      currentPage = 1;
                    });
                    applyFilters();
                  },
                  decoration: _mobileInputDecoration('Reference ID'),
                ),
                const SizedBox(height: 8),
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  height: 45,
                  width: double.infinity,
                  child: Center(
                    child: CalendarPickerTableCell(
                      key: ValueKey(_calendarKey),
                      onDateSelected: (DateTime date) {
                        setState(() {
                          selectedDate = date;
                          currentPage = 1;
                        });
                        _fetchServer(page: 1);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: resetSearch,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      side: const BorderSide(color: ColorManager.kPrimaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Reset Filters'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
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
            'No transactions found',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
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

  Widget _buildMobileList() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: listTransaction!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = listTransaction![index];
              return InkWell(
                onTap: () => _showTransactionDetails(tx),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  tx.customerName ?? 'No Name',
                                  style: buildCustomStyle(FontWeightManager.semiBold,
                                      FontSize.s13, 0.19, ColorManager.textColor),
                                ),
                                if (tx.referenceId != null && tx.referenceId!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Ref: ${tx.referenceId}',
                                          style: buildCustomStyle(FontWeightManager.regular,
                                              FontSize.s10, 0.15, Colors.grey),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(
                                              text: tx.referenceId!));
                                          showScaffold(
                                            context: context,
                                            message:
                                                'Reference ID copied to clipboard',
                                          );
                                        },
                                        child: const Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _buildStatusChip(tx.status ?? ''),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${tx.currency ?? ''} ${tx.amount ?? ''}',
                            style: buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s13, 0.19, ColorManager.kPrimaryColor),
                          ),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                tx.date ?? 'N/A',
                                style: buildCustomStyle(FontWeightManager.regular,
                                    FontSize.s11, 0.16, Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        PaginationControl(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) {
            setState(() {
              currentPage = page;
            });
            _fetchServer(page: page);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshData,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Transaction',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s18, 0.25, ColorManager.textColor),
                ),
                const SizedBox(height: 10),
                _buildMobileFilters(size),
                const SizedBox(height: 8),
                Expanded(
                  child: initLoading
                      ? const Center(child: CircularProgressIndicator.adaptive())
                      : listTransaction == null || listTransaction!.isEmpty
                          ? _buildEmptyState()
                          : _buildMobileList(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Customer Transaction",
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s20, 0.30, ColorManager.textColor),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Column(
                  children: [
                    // First row with 4 filters
                    Row(
                      children: [
                        // Amount Search Field
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Amount",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                width: double.infinity,
                                onchanged: (value) {
                                  setState(() {
                                    searchAmount = value!;
                                    currentPage = 1;
                                  });
                                  applyFilters();
                                },
                                controller: amountRefController,
                                size: size,
                                hintText: 'Amount',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 15),

                        // Customer Name Search Field
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Customer Name",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              CustomerAutocomplete(
                                size: size,
                                customerList: getCustomerSuggestions(),
                                controller: customerSearchController,
                                onSelected: (String selectedCustomer) {
                                  setState(() {
                                    searchCustomer = selectedCustomer;
                                    // try to derive customer_id from current page data
                                    final match = allTransactions?.firstWhere(
                                      (t) => (t.customerName ?? '').toLowerCase() ==
                                          selectedCustomer.toLowerCase(),
                                      orElse: () => ListTransaction(),
                                    );
                                    if (match != null && match.customerId != null) {
                                      selectedCustomerId = match.customerId.toString();
                                    }
                                    currentPage = 1;
                                  });
                                  _fetchServer(page: 1);
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 15),

                        // Type Filter (Credit/Debit)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Type",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                height: 45,
                                width: double.infinity,
                                color: Colors.white,
                                child: DropdownButtonFormField<String>(
                                  value: searchType.isEmpty ? null : searchType,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 15, vertical: 12),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  dropdownColor: Colors.white,
                                  hint: Text(
                                    'Select Type',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s11,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                  ),
                                  items: ['All', 'Credit', 'Debit']
                                      .map((String type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s11,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? value) {
                                    setState(() {
                                      searchType = value ?? '';
                                      currentPage = 1;
                                    });
                                    _fetchServer(page: 1);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 15),

                        // Reference ID Search Field
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Reference ID",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                width: double.infinity,
                                onchanged: (value) {
                                  setState(() {
                                    searchReference = value!;
                                    currentPage = 1;
                                  });
                                  applyFilters();
                                },
                                controller: referenceSearchController,
                                size: size,
                                hintText: 'Reference ID',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Second row with Date filter and Reset button
                    Row(
                      children: [
                        // Date Picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Date",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                height: 45,
                                width: double.infinity,
                                child: Center(
                                  child: CalendarPickerTableCell(
                                    key: ValueKey(_calendarKey),
                                    onDateSelected: (DateTime date) {
                                      setState(() {
                                        selectedDate = date;
                                        currentPage = 1;
                                      });
                                      _fetchServer(page: 1);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 15),

                        // Empty space to push reset button to the end
                        Expanded(
                          flex: 2,
                          child: Container(),
                        ),

                        const SizedBox(width: 15),

                        // Reset Button
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: CustomRoundButton(
                              title: "Reset",
                              boxColor: Colors.white,
                              textColor: ColorManager.kPrimaryColor,
                              fct: resetSearch,
                              height: 45,
                              width: double.infinity,
                              fontSize: FontSize.s12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: initLoading
                            ? const Center(
                                child: CircularProgressIndicator.adaptive())
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
                                          0: FlexColumnWidth(0.5), // No
                                          1: FlexColumnWidth(2.0), // Name
                                          2: FlexColumnWidth(1.2), // Date
                                          3: FlexColumnWidth(1.5), // Amount
                                          4: FlexColumnWidth(
                                              1.5), // Reference ID
                                          5: FlexColumnWidth(1.0), // Type
                                          6: FlexColumnWidth(1.0), // Status
                                          7: FlexColumnWidth(1.0), // Action
                                        },
                                        border: null,
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        children: [
                                          TableRow(
                                            children: [
                                              _buildTableHeader('No'),
                                              _buildTableHeader('Name'),
                                              _buildTableHeader('Date'),
                                              _buildTableHeader('Amount'),
                                              _buildTableHeader('Reference ID'),
                                              _buildTableHeader('Type'),
                                              _buildTableHeader('Status'),
                                              _buildTableHeader('Action'),
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
                                          behavior:
                                              ScrollConfiguration.of(context)
                                                  .copyWith(
                                            dragDevices: {
                                              PointerDeviceKind.mouse,
                                              PointerDeviceKind.touch,
                                              PointerDeviceKind.stylus,
                                              PointerDeviceKind.trackpad,
                                            },
                                          ),
                                          child: SingleChildScrollView(
                                            physics:
                                                const BouncingScrollPhysics(),
                                            scrollDirection: Axis.vertical,
                                            child: listTransaction == null ||
                                                    listTransaction!.isEmpty
                                                ? Container(
                                                    height: 300,
                                                    width: double.infinity,
                                                    alignment: Alignment.center,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.receipt_long,
                                                          size: 60,
                                                          color: ColorManager
                                                              .kPrimaryColor
                                                              .withOpacity(0.7),
                                                        ),
                                                        const SizedBox(
                                                            height: 15),
                                                        Text(
                                                          'No transactions found',
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .medium,
                                                            FontSize.s18,
                                                            0.27,
                                                            ColorManager
                                                                .textColor,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          'Try adjusting your search criteria',
                                                          style:
                                                              buildCustomStyle(
                                                            FontWeightManager
                                                                .regular,
                                                            FontSize.s14,
                                                            0.20,
                                                            Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Table(
                                                    columnWidths: const {
                                                      0: FlexColumnWidth(
                                                          0.5), // No
                                                      1: FlexColumnWidth(
                                                          2.0), // Name
                                                      2: FlexColumnWidth(
                                                          1.2), // Date
                                                      3: FlexColumnWidth(
                                                          1.5), // Amount
                                                      4: FlexColumnWidth(
                                                          1.5), // Reference ID
                                                      5: FlexColumnWidth(
                                                          1.0), // Type
                                                      6: FlexColumnWidth(
                                                          1.0), // Status
                                                      7: FlexColumnWidth(
                                                          1.0), // Action
                                                    },
                                                    border: null,
                                                    defaultVerticalAlignment:
                                                        TableCellVerticalAlignment
                                                            .middle,
                                                    children: [
                                                      // Table Rows
                                                      ...listTransaction!
                                                          .asMap()
                                                          .entries
                                                          .map((entry) {
                                                        final int index =
                                                            entry.key;
                                                        final transaction =
                                                            entry.value;
                                                        return TableRow(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: index % 2 ==
                                                                    0
                                                                ? Colors.white
                                                                : Colors.grey
                                                                    .withOpacity(
                                                                        0.1),
                                                          ),
                                                          children: [
                                                            _buildTableCell(
                                                                '${index + 1 + (currentPage - 1) * itemsPerPage}'),
                                                             TableCell(
                                                               verticalAlignment: TableCellVerticalAlignment.middle,
                                                               child: Padding(
                                                                 padding: const EdgeInsets.all(8.0),
                                                                 child: Center(
                                                                   child: SelectableText(
                                                                     "${transaction.customerName ?? 'No Name'}",
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
                                                                "${transaction.date ?? 'N/A'}"),
                                                            _buildTableCell(
                                                                "${transaction.currency} ${transaction.amount}"),
                                                            TableCell(
                                                              verticalAlignment:
                                                                  TableCellVerticalAlignment
                                                                      .middle,
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        8.0),
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      transaction.referenceId ?? 'N/A',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style:
                                                                          buildCustomStyle(
                                                                        FontWeightManager
                                                                            .medium,
                                                                        FontSize
                                                                            .s9,
                                                                        0.13,
                                                                        Colors
                                                                            .black,
                                                                      ),
                                                                    ),
                                                                    if (transaction.referenceId != null && transaction.referenceId!.isNotEmpty) ...[
                                                                      const SizedBox(
                                                                          width:
                                                                              6),
                                                                      GestureDetector(
                                                                        onTap:
                                                                            () {
                                                                          Clipboard.setData(
                                                                              ClipboardData(
                                                                                  text: transaction.referenceId!));
                                                                          showScaffold(
                                                                            context:
                                                                                context,
                                                                            message:
                                                                                'Reference ID copied to clipboard',
                                                                          );
                                                                        },
                                                                        child:
                                                                            const Icon(
                                                                          Icons
                                                                              .copy,
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              Colors.black38,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Center(
                                                              child: _buildTypeCell(
                                                                  "${transaction.type}"),
                                                            ),
                                                            Center(
                                                              child: _buildStatusChip(
                                                                  "${transaction.status}"),
                                                            ),
                                                            Center(
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        8.0),
                                                                child:
                                                                    BuildBoxShadowContainer(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              5,
                                                                          right:
                                                                              5),
                                                                  circleRadius:
                                                                      5,
                                                                  child:
                                                                      IconButton(
                                                                    icon: Icon(
                                                                      Icons
                                                                          .visibility,
                                                                      size: 18,
                                                                      color: ColorManager
                                                                          .kPrimaryColor
                                                                          .withOpacity(
                                                                              0.9),
                                                                    ),
                                                                    onPressed:
                                                                        () {
                                                                      _showTransactionDetails(
                                                                          transaction);
                                                                    },
                                                                    constraints:
                                                                        const BoxConstraints(
                                                                      minWidth:
                                                                          36,
                                                                      minHeight:
                                                                          36,
                                                                    ),
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }).toList(),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),
                      PaginationControl(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        onPageChanged: (int page) {
                          setState(() {
                            currentPage = page;
                          });
                          _fetchServer(page: page);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
