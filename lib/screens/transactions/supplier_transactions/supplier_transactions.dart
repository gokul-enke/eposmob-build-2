import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pos_machine/screens/transactions/widgets/supplier_auto_complete_search.dart';
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
  final TextEditingController transactionTypeController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController paymentModeController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController supplierSearchController =
      TextEditingController();

  TransactionModel? selectedTransaction;
  bool initLoading = false;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('TransactionScreen:initState');
    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    debugPrint(
        'TransactionScreen:obtainedToken length=${accessToken.length} isEmpty=${accessToken.isEmpty}');
    Provider.of<TransactionProvider>(context, listen: false)
        .setAccessToken(accessToken);
    loadInitData();

    // Initialize controllers with default values
    typeController.text = "All Types";
    transactionTypeController.text = "All";
    statusController.text = "All Status";
    paymentModeController.text = "All Payment Modes";
    supplierController.text = "All Suppliers";
  }

  void loadInitData() async {
    try {
      debugPrint('TransactionScreen:loadInitData start');
      setState(() => initLoading = true);
      // Initial server-side fetch (no filters)
      await Provider.of<TransactionProvider>(context, listen: false)
          .fetchTransactionsFromServerV2(page: 1, perPage: 50);
      setState(() {
        isInitialized = true;
        initLoading = false;
      });
      debugPrint('TransactionScreen:loadInitData success');
    } catch (error) {
      debugPrint("Error loading transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading transactions: $error")),
      );
      setState(() => initLoading = false);
      debugPrint('TransactionScreen:loadInitData error=$error');
    }
  }

  void searchTransactions() {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    String? supplierId;
    if (supplierSearchController.text.isNotEmpty) {
      supplierId = txProvider.lookupSupplierIdByName(supplierSearchController.text)?.toString();
    }

    txProvider.fetchTransactionsFromServerV2(
      supplierId: supplierId,
      transactionType: transactionTypeController.text == "All"
          ? null
          : transactionTypeController.text,
      type: typeController.text == "All Types" ? null : typeController.text,
      // date filters not present in this UI
      page: 1,
      perPage: 50,
    );
  }

  void resetSearch() {
    setState(() {
      searchController.clear();
      typeController.text = "All Types";
      transactionTypeController.text = "All";
      statusController.text = "All Status";
      paymentModeController.text = "All Payment Modes";
      supplierSearchController.clear();
    });
    // Refetch from server with defaults
    Provider.of<TransactionProvider>(context, listen: false)
        .fetchTransactionsFromServerV2(page: 1, perPage: 50);
  }

  Future<void> _onRefresh() async {
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    String? supplierId;
    if (supplierSearchController.text.isNotEmpty) {
      supplierId = txProvider.lookupSupplierIdByName(supplierSearchController.text)?.toString();
    }
    await txProvider.fetchTransactionsFromServerV2(
      supplierId: supplierId,
      transactionType: transactionTypeController.text == "All"
          ? null
          : transactionTypeController.text,
      type: typeController.text == "All Types" ? null : typeController.text,
      page: txProvider.transactionCurrentPage,
      perPage: 50,
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
                    _buildDetailRow(
                        'Supplier Name', transaction.supplier.user.name),
                    _buildDetailRow(
                        'Date', DateHelper.formatISODate(transaction.date)),
                    _buildDetailRow('Type', transaction.type),
                    _buildDetailRow(
                        'Transaction Type', transaction.transactionType),
                    _buildDetailRow('Payment Mode', transaction.paymentMode),
                    _buildDetailRow('Amount',
                        '${transaction.currency} ${transaction.amount}'),
                    _buildDetailRow(
                        'Tax Amount', transaction.taxAmount ?? 'N/A'),
                    _buildDetailRow('Reference', transaction.reference),
                    _buildDetailRow('Status', transaction.status),
                    _buildDetailRow(
                        'Comment', transaction.transactionComment ?? 'N/A'),
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

  Widget _buildFilterDropdown({
    required String title,
    required TextEditingController controller,
    required List<String> options,
    required double width,
    bool isSmallScreen = false,
  }) {
    return SizedBox(
      width: isSmallScreen ? width * 0.3 : width * 0.15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
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
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.white,
              ),
              dropdownColor: Colors.white,
              value: controller.text,
              hint: Text(
                'Select $title',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              items: options.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() => controller.text = newValue!);
                searchTransactions();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('TransactionScreen:build start');
    final transactionProvider = Provider.of<TransactionProvider>(context);
    debugPrint('TransactionScreen:build transactionProvider=not-null isLoading=${transactionProvider.transactionIsLoading}');
    Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _onRefresh,
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
              )
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title
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

                /// First Row (Filters)
                Row(
                  children: [
                    Expanded(
                      child: _buildSearchField(
                        title: "Search",
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) => searchTransactions(),
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
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (ctx) {
                          debugPrint('TransactionScreen:building SupplierAutocomplete');
                          final supplierOptions = transactionProvider.getSupplierOptions();
                          debugPrint('TransactionScreen:supplierOptions length=${supplierOptions.length}');
                          return _buildSearchField(
                            title: "Supplier",
                            child: SupplierAutocomplete(
                              size: size,
                              onSelected: (_) => searchTransactions(),
                              supplierList: supplierOptions,
                              controller: supplierSearchController,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFilterDropdown(
                        title: "Trans. Type",
                        controller: transactionTypeController,
                        options: const ["All", "Invoice", "Voucher"],
                        width: size.width,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFilterDropdown(
                        title: "Type",
                        controller: typeController,
                        options: const ["All Types", "Credit", "Debit"],
                        width: size.width,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFilterDropdown(
                        title: "Status",
                        controller: statusController,
                        options: transactionProvider.getStatusOptions(),
                        width: size.width,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                /// Second Row (Reset button aligned right)

                Row(
                  children: [
                    // Empty space to push reset button to the end
                    Expanded(
                      flex: 3,
                      child: Container(),
                    ),

                    // Reset Button
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0),
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

                const SizedBox(height: 20),

                /// Table + Pagination
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: initLoading ||
                                transactionProvider.transactionIsLoading
                            ? const Center(
                                child: CircularProgressIndicator.adaptive())
                            : transactionProvider
                                            .listTransactionModelDataList ==
                                        null ||
                                    transactionProvider
                                        .listTransactionModelDataList!.isEmpty
                                ? _buildEmptyState(transactionProvider)
                                : _buildTransactionTable(transactionProvider),
                      ),
                      const SizedBox(height: 10),
                      PaginationControl(
                        currentPage: transactionProvider.transactionCurrentPage,
                        totalPages: transactionProvider.transactionTotalPages,
                        onPageChanged: (int page) {
                          final txProvider = Provider.of<TransactionProvider>(context, listen: false);
                          String? supplierId;
                          if (supplierSearchController.text.isNotEmpty) {
                            supplierId = txProvider.lookupSupplierIdByName(supplierSearchController.text)?.toString();
                          }
                          txProvider.fetchTransactionsFromServerV2(
                            supplierId: supplierId,
                            transactionType: transactionTypeController.text == "All"
                                ? null
                                : transactionTypeController.text,
                            type: typeController.text == "All Types" ? null : typeController.text,
                            page: page,
                            perPage: 50,
                          );
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

  /// Helper for consistent fields
  Widget _buildSearchField({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
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
          child: child,
        ),
      ],
    );
  }

  Widget _buildEmptyState(TransactionProvider provider) {
    final hasFilters = searchController.text.isNotEmpty ||
        typeController.text != "All Types" ||
        statusController.text != "All Status" ||
        paymentModeController.text != "All Payment Modes" ||
        supplierController.text != "All Suppliers";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            provider.allTransactions?.isEmpty ?? true
                ? "No transactions available"
                : "No transactions match your filters",
            style: const TextStyle(color: Colors.grey),
          ),
          if (hasFilters)
            TextButton(
              onPressed: resetSearch,
              child: const Text("Reset filters"),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionTable(TransactionProvider provider) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 7,
      offsetValue: const Offset(2, 2),
      blurRadius: 8.0,
      color: Colors.white,
      child: Column(
        children: [
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
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...provider.listTransactionModelDataList!
                          .asMap()
                          .entries
                          .map((entry) =>
                              _buildTransactionRow(entry.key, entry.value))
                          .toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTransactionRow(int index, TransactionModel transaction) {
    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _buildTableCell(transaction.siNo.toString()),
        _buildTableCell(transaction.supplier.user.name),
        _buildTableCell(DateHelper.formatISODate(transaction.date)),
        Center(child: _buildTypeCell(transaction.type)),
        _buildTableCell(transaction.transactionType),
        _buildTableCell(transaction.paymentMode),
        _buildTableCell('${transaction.currency} ${transaction.amount}'),
        _buildTableCell(transaction.reference),
        Center(child: _buildStatusChip(transaction.status)),
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
                onPressed: () => _showTransactionDetails(transaction),
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
}

///////////////////////////////////////////////////////////////////////////////------------------------///////////////////////////////////////
