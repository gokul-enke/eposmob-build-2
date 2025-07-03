import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../models/transaction_model.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  
  TransactionModel? selectedTransaction;
  bool initLoading = false;
  bool isInitialized = false;
  List<String> types = ["All Types"];

  @override
  void initState() {
    super.initState();
    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
    Provider.of<TransactionProvider>(context, listen: false).setAccessToken(accessToken);
    loadInitData();
    typeController.text = "All Types";
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });
      await Provider.of<TransactionProvider>(context, listen: false)
          .fetchAllTransactionsBatch();
      _extractFilters();
      setState(() {
        isInitialized = true;
        initLoading = false;
      });
    } catch (error) {
      debugPrint("Error loading transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading transactions: $error")),
      );
      setState(() {
        initLoading = false;
      });
    }
  }

  void _extractFilters() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    setState(() {
      types = provider.getTypeOptions();
    });
  }

  void searchTransactions() {
    TransactionProvider provider =
        Provider.of<TransactionProvider>(context, listen: false);
    provider.applyTransactionFiltersLocally(
      filterName: searchController.text,
      filterType: typeController.text == "All Types"
          ? null
          : typeController.text,
      page: 1,
    );
  }

  void resetSearch() {
    setState(() {
      searchController.clear();
      typeController.text = "All Types";
    });
    Provider.of<TransactionProvider>(context, listen: false)
        .resetTransactionFilters();
  }

  Future<void> _onRefresh() async {
    await Provider.of<TransactionProvider>(context, listen: false)
        .refreshAllTransactions();
    _extractFilters();
  }

  void _showTransactionDetails(TransactionModel transaction) {
    setState(() {
      selectedTransaction = transaction;
    });

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
                    _buildDetailRow('Supplier Name', transaction.supplier.user.name),
                    _buildDetailRow('Date', DateHelper.formatISODate(transaction.date)),
                    _buildDetailRow('Type', transaction.type),
                    _buildDetailRow('Transaction Type', transaction.transactionType),
                    _buildDetailRow('Payment Mode', transaction.paymentMode),
                    _buildDetailRow('Amount', '${transaction.currency} ${transaction.amount}'),
                    _buildDetailRow('Tax Amount', transaction.taxAmount ?? 'N/A'),
                    _buildDetailRow('Reference', transaction.reference),
                    _buildDetailRow('Status', transaction.status),
                    _buildDetailRow('Comment', transaction.transactionComment ?? 'N/A'),
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
    final bool isSmallScreen = size.width < 600;
    
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Container(
          margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Supplier Transactions",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
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
                                ? size.width * 0.3
                                : size.width * 0.15,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Search",
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
                                  circleRadius: 7,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 15),
                                  height: 45,
                                  child: TextField(
                                    controller: searchController,
                                    onChanged: (value) {
                                      searchTransactions();
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search by name, reference',
                                      hintStyle: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: isSmallScreen
                                ? size.width * 0.3
                                : size.width * 0.15,
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
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 15),
                                  height: 45,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    value: typeController.text,
                                    hint: Text(
                                      'Please Select',
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    items: types
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              value == "All Types"
                                                  ? 'Please Select'
                                                  : value,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.27,
                                                ColorManager.textColor
                                                    .withOpacity(.5),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        typeController.text = newValue!;
                                      });
                                      searchTransactions();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomRoundButton(
                                title: "Reset",
                                boxColor: Colors.white,
                                textColor: ColorManager.kPrimaryColor,
                                borderColor: ColorManager.kPrimaryColor,
                                fct: resetSearch,
                                height: 45,
                                width: isSmallScreen
                                    ? size.width * 0.2
                                    : size.width * 0.08,
                                fontSize: FontSize.s12,
                              ),
                            ],
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
                        child: initLoading ||
                                Provider.of<TransactionProvider>(context,
                                        listen: true)
                                    .transactionIsLoading
                            ? const Center(
                                child: CircularProgressIndicator.adaptive())
                            : Consumer<TransactionProvider>(
                                builder: (context, transactionProvider, child) {
                                  List<TransactionModel>?
                                      listTransactionModelDataList =
                                      transactionProvider
                                          .listTransactionModelDataList;

                                  if (listTransactionModelDataList == null ||
                                      listTransactionModelDataList.isEmpty) {
                                    return const Center(
                                        child: Text("No transaction data available"));
                                  }

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
                                              0: FlexColumnWidth(0.6), // SI No
                                              1: FlexColumnWidth(1.8), // Supplier
                                              2: FlexColumnWidth(1.2), // Date
                                              3: FlexColumnWidth(1.0), // Type
                                              4: FlexColumnWidth(1.5), // Transaction Type
                                              5: FlexColumnWidth(1.2), // Payment Mode
                                              6: FlexColumnWidth(1.2), // Amount
                                              7: FlexColumnWidth(1.5), // Reference
                                              8: FlexColumnWidth(1.0), // Status
                                              9: FlexColumnWidth(1.0), // Action
                                            },
                                            border: null,
                                            defaultVerticalAlignment:
                                                TableCellVerticalAlignment.middle,
                                            children: [
                                              TableRow(
                                                children: [
                                                  _buildTableHeader('SI No'),
                                                  _buildTableHeader('Supplier'),
                                                  _buildTableHeader('Date'),
                                                  _buildTableHeader('Type'),
                                                  _buildTableHeader('Transaction Type'),
                                                  _buildTableHeader('Payment Mode'),
                                                  _buildTableHeader('Amount'),
                                                  _buildTableHeader('Reference'),
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
                                                child: Table(
                                                  columnWidths: const {
                                                    0: FlexColumnWidth(0.6), // SI No
                                                    1: FlexColumnWidth(1.8), // Supplier
                                                    2: FlexColumnWidth(1.2), // Date
                                                    3: FlexColumnWidth(1.0), // Type
                                                    4: FlexColumnWidth(1.5), // Transaction Type
                                                    5: FlexColumnWidth(1.2), // Payment Mode
                                                    6: FlexColumnWidth(1.2), // Amount
                                                    7: FlexColumnWidth(1.5), // Reference
                                                    8: FlexColumnWidth(1.0), // Status
                                                    9: FlexColumnWidth(1.0), // Action
                                                  },
                                                  border: null,
                                                  defaultVerticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  children: [
                                                    // Table Rows
                                                    ...listTransactionModelDataList
                                                        .asMap()
                                                        .entries
                                                        .map((entry) {
                                                      final int index = entry.key;
                                                      final transaction = entry.value;
                                                      return TableRow(
                                                        decoration: BoxDecoration(
                                                          color: index % 2 == 0
                                                              ? Colors.white
                                                              : Colors.grey
                                                                  .withOpacity(0.1),
                                                        ),
                                                        children: [
                                                          _buildTableCell(
                                                              transaction.siNo.toString()),
                                                          _buildTableCell(
                                                              transaction.supplier.user.name),
                                                          _buildTableCell(
                                                              DateHelper.formatISODate(
                                                                  transaction.date)),
                                                          Center(
                                                            child: _buildTypeCell(
                                                                transaction.type),
                                                          ),
                                                          _buildTableCell(
                                                              transaction.transactionType),
                                                          _buildTableCell(
                                                              transaction.paymentMode),
                                                          _buildTableCell(
                                                              '${transaction.currency} ${transaction.amount}'),
                                                          _buildTableCell(
                                                              transaction.reference),
                                                          Center(
                                                            child: _buildStatusChip(
                                                                transaction.status),
                                                          ),
                                                          Center(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child:
                                                                  BuildBoxShadowContainer(
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left: 5,
                                                                        right: 5),
                                                                circleRadius: 5,
                                                                child: IconButton(
                                                                  icon: Icon(
                                                                    Icons
                                                                        .visibility,
                                                                    size: 18,
                                                                    color: ColorManager
                                                                        .kPrimaryColor
                                                                        .withOpacity(
                                                                            0.9),
                                                                  ),
                                                                  onPressed: () =>
                                                                      _showTransactionDetails(
                                                                          transaction),
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                    minWidth: 36,
                                                                    minHeight: 36,
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
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      PaginationControl(
                        currentPage: Provider.of<TransactionProvider>(context,
                                listen: true)
                            .transactionCurrentPage,
                        totalPages: Provider.of<TransactionProvider>(context,
                                listen: true)
                            .transactionTotalPages,
                        onPageChanged: (int page) {
                          Provider.of<TransactionProvider>(context,
                                  listen: false)
                              .goToTransactionPage(page);
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
