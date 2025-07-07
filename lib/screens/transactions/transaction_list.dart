import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import '../../models/list_transaction.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

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
  bool initLoading = false;
  List<ListTransaction>? listTransaction = [];
  List<ListTransaction>? allTransactions =
      []; // Store all transactions for filtering
  String searchAmount = '';
  DateTime? selectedDate;
  int currentPage = 1;
  int totalPages = 1;
  final int itemsPerPage = 20;

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
        applyFilters();
      } else {
        showScaffold(context: context, message: "Data Not Found");
      }
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void applyFilters() {
    if (allTransactions == null || allTransactions!.isEmpty) {
      setState(() {
        listTransaction = [];
        totalPages = 1;
      });
      return;
    }

    // Apply filters
    List<ListTransaction> filteredList = [...allTransactions!];

    if (searchAmount.isNotEmpty) {
      filteredList = filteredList
          .where((transaction) =>
              transaction.amount != null &&
              transaction.amount!.contains(searchAmount))
          .toList();
    }

    if (selectedDate != null) {
      // Assuming transactions have a date field that can be compared
      // If you have a createdAt or date field, replace this with the actual field
      filteredList = filteredList.where((transaction) {
        // Implement date filtering logic here
        // Example (assuming transaction.date exists):
        // DateTime transactionDate = DateTime.parse(transaction.date!);
        // return transactionDate.year == selectedDate!.year &&
        //     transactionDate.month == selectedDate!.month &&
        //     transactionDate.day == selectedDate!.day;
        return true; // Replace with actual implementation
      }).toList();
    }

    // Calculate pagination
    totalPages = (filteredList.length / itemsPerPage).ceil();
    totalPages = totalPages == 0 ? 1 : totalPages;

    // Ensure current page is valid
    if (currentPage > totalPages) {
      currentPage = totalPages;
    }

    // Apply pagination
    int startIndex = (currentPage - 1) * itemsPerPage;
    int endIndex = startIndex + itemsPerPage;

    if (startIndex >= filteredList.length) {
      listTransaction = [];
    } else {
      endIndex =
          endIndex > filteredList.length ? filteredList.length : endIndex;
      listTransaction = filteredList.sublist(startIndex, endIndex);
    }

    setState(() {});
  }

  void resetSearch() {
    setState(() {
      amountRefController.clear();
      searchAmount = '';
      selectedDate = null;
      currentPage = 1;
    });
    applyFilters();
  }

  Future<void> refreshData() async {
    resetSearch();
    loadInitData();
  }

  void _showTransactionDetails(ListTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDetailRow(
                        'Customer Name', transaction.customerName ?? 'N/A'),
                    _buildDetailRow('Date', transaction.date ?? 'N/A'),
                    _buildDetailRow('Type', transaction.type ?? 'N/A'),
                    _buildDetailRow('Transaction Type',
                        transaction.transactionType ?? 'N/A'),
                    _buildDetailRow(
                        'Payment Method', transaction.paymentMethod ?? 'N/A'),
                    _buildDetailRow('Amount',
                        '${transaction.currency ?? ''} ${transaction.amount ?? ''}'),
                    _buildDetailRow(
                        'Reference ID', transaction.referenceId ?? 'N/A'),
                    _buildDetailRow(
                        'Reference', transaction.reference ?? 'N/A'),
                    _buildDetailRow('Status', transaction.status ?? 'N/A'),
                    _buildDetailRow(
                        'Comment', transaction.transactionComment ?? 'N/A'),
                    _buildDetailRow(
                        'Created At',
                        transaction.createdAt != null
                            ? DateHelper.formatDate(transaction.createdAt!)
                            : 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Close",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    InvoiceProvider invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final bool isSmallScreen = size.width < 600;

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
                      "Transaction Management",
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s20, 0.30, ColorManager.textColor),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                            width: isSmallScreen
                                ? size.width * 0.8
                                : size.width * 0.15,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Amount ",
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
                                  width: isSmallScreen
                                      ? size.width * 0.8
                                      : size.width * 0.15,
                                  onchanged: (value) {
                                    setState(() {
                                      searchAmount = value!;
                                      currentPage =
                                          1; // Reset to first page on search
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
                          SizedBox(
                            width: isSmallScreen
                                ? size.width * 0.8
                                : size.width * 0.15,
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
                                  width: isSmallScreen
                                      ? size.width * 0.8
                                      : size.width * 0.15,
                                  child: Center(
                                    child: CalendarPickerTableCell(
                                      onDateSelected: (DateTime date) {
                                        setState(() {
                                          selectedDate = date;
                                          currentPage =
                                              1; // Reset to first page on date change
                                        });
                                        applyFilters();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CustomRoundButton(
                            title: "Reset",
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: resetSearch,
                            height: 45,
                            width: isSmallScreen
                                ? size.width * 0.4
                                : size.width * 0.09,
                            fontSize: FontSize.s12,
                          ),
                        ],
                      ),
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
                                          4: FlexColumnWidth(1.0), // Status
                                          5: FlexColumnWidth(1.0), // Type
                                          6: FlexColumnWidth(1.0), // Action
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
                                              _buildTableHeader('Status'),
                                              _buildTableHeader('Type'),
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
                                                          1.0), // Status
                                                      5: FlexColumnWidth(
                                                          1.0), // Type
                                                      6: FlexColumnWidth(
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
                                                            _buildTableCell(
                                                                "${transaction.customerName}"),
                                                            _buildTableCell(
                                                                "${transaction.date ?? 'N/A'}"),
                                                            _buildTableCell(
                                                                "${transaction.currency} ${transaction.amount}"),
                                                            Center(
                                                              child: _buildStatusChip(
                                                                  "${transaction.status}"),
                                                            ),
                                                            Center(
                                                              child: _buildTypeCell(
                                                                  "${transaction.type}"),
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
                          applyFilters();
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
