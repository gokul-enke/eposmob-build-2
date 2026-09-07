import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/screens/transactions/widgets/supplier_auto_complete_search.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../models/transaction_model.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../widgets/common_details_dialog.dart';

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
        SnackBar(
          content: Text(
            'supplier_transactions.error_loading'
                .trParams({'error': '$error'}),
          ),
        ),
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
        UiCodeLabels.status(status),
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
        UiCodeLabels.documentKind(type),
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
      builder: (context) => CommonDetailsDialog(
        title: 'supplier_transactions.dialog_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.supplier_name'.tr, transaction.supplier.user.name),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.date'.tr, DateHelper.formatISODate(transaction.date)),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.type'.tr, UiCodeLabels.documentKind(transaction.type)),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.transaction_type'.tr, UiCodeLabels.documentKind(transaction.transactionType)),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.payment_mode'.tr, UiCodeLabels.payment(transaction.paymentMode)),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.amount'.tr, '${transaction.currency} ${transaction.amount}'),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.tax_amount'.tr, transaction.taxAmount ?? 'supplier_transactions.na'.tr),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.reference'.tr, transaction.reference, copyable: true),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.status'.tr, transaction.status),
            CommonDetailsDialog.buildKeyValueRow('supplier_transactions.comment'.tr, transaction.transactionComment ?? 'supplier_transactions.na'.tr),
          ],
        ],
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
                title,
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
                    UiCodeLabels.documentKind(value),
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

    final isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'supplier_transactions.title'.tr,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s18, 0.25, ColorManager.textColor),
                ),
                const SizedBox(height: 10),
                _buildMobileFilters(size, transactionProvider),
                const SizedBox(height: 8),
                Expanded(
                  child: initLoading || transactionProvider.transactionIsLoading
                      ? const Center(child: CircularProgressIndicator.adaptive())
                      : transactionProvider.listTransactionModelDataList == null ||
                              transactionProvider.listTransactionModelDataList!.isEmpty
                          ? _buildEmptyState(transactionProvider)
                          : _buildMobileList(transactionProvider),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                      'supplier_transactions.title'.tr,
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
                        title: 'supplier_transactions.search'.tr,
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) => searchTransactions(),
                          decoration: InputDecoration(
                            hintText: 'supplier_transactions.hint_search'.tr,
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
                            title: 'supplier_transactions.supplier'.tr,
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
                        title: 'supplier_transactions.trans_type'.tr,
                        controller: transactionTypeController,
                        options: const ["All", "Invoice", "Voucher"],
                        width: size.width,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFilterDropdown(
                        title: 'supplier_transactions.type'.tr,
                        controller: typeController,
                        options: const ["All Types", "Credit", "Debit"],
                        width: size.width,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFilterDropdown(
                        title: 'supplier_transactions.status'.tr,
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
                          title: 'supplier_transactions.btn_reset'.tr,
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
                ? 'supplier_transactions.no_transactions'.tr
                : 'supplier_transactions.no_filter_match'.tr,
            style: const TextStyle(color: Colors.grey),
          ),
          if (hasFilters)
            TextButton(
              onPressed: resetSearch,
              child: Text('supplier_transactions.btn_reset_filters'.tr),
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
                    _buildTableHeader('supplier_transactions.col_si_no'.tr),
                    _buildTableHeader('supplier_transactions.supplier'.tr),
                    _buildTableHeader('supplier_transactions.col_date'.tr),
                    _buildTableHeader('supplier_transactions.type'.tr),
                    _buildTableHeader('supplier_transactions.col_transaction_type'.tr),
                    _buildTableHeader('supplier_transactions.col_payment_mode'.tr),
                    _buildTableHeader('supplier_transactions.col_amount'.tr),
                    _buildTableHeader('supplier_transactions.col_reference'.tr),
                    _buildTableHeader('supplier_transactions.status'.tr),
                    _buildTableHeader('supplier_transactions.col_action'.tr),
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
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: SelectableText(
                transaction.supplier.user.name,
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
        _buildTableCell(DateHelper.formatISODate(transaction.date)),
        Center(child: _buildTypeCell(transaction.type)),
        _buildTableCell(UiCodeLabels.documentKind(transaction.transactionType)),
        _buildTableCell(UiCodeLabels.payment(transaction.paymentMode)),
        _buildTableCell('${transaction.currency} ${transaction.amount}'),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 12.0, horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    transaction.reference,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s9,
                      0.13,
                      Colors.black,
                    ),
                  ),
                ),
                if (transaction.reference.isNotEmpty && transaction.reference != 'N/A') ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text: transaction.reference));
                      showScaffold(
                        context: context,
                        message: 'supplier_transactions.ref_copied'.tr,
                      );
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
  Widget _buildMobileFilters(Size size, TransactionProvider transactionProvider) {
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
        title: Text('supplier_transactions.filters'.tr,
            style: buildCustomStyle(FontWeightManager.medium,
                FontSize.s12, 0.18, ColorManager.textColor)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                // Search
                TextFormField(
                  controller: searchController,
                  onChanged: (_) => searchTransactions(),
                  decoration: _mobileInputDecoration('supplier_transactions.hint_search'.tr),
                ),
                const SizedBox(height: 8),
                // Supplier autocomplete — reuse existing field in a box
                TextFormField(
                  controller: supplierSearchController,
                  onChanged: (_) => searchTransactions(),
                  decoration: _mobileInputDecoration('supplier_transactions.supplier'.tr),
                ),
                const SizedBox(height: 8),
                _mobileDropdown(
                  value: transactionTypeController.text,
                  hint: 'supplier_transactions.trans_type'.tr,
                  items: const ['All', 'Invoice', 'Voucher'],
                  onChanged: (v) {
                    setState(() => transactionTypeController.text = v!);
                    searchTransactions();
                  },
                ),
                const SizedBox(height: 8),
                _mobileDropdown(
                  value: typeController.text,
                  hint: 'supplier_transactions.type'.tr,
                  items: const ['All Types', 'Credit', 'Debit'],
                  onChanged: (v) {
                    setState(() => typeController.text = v!);
                    searchTransactions();
                  },
                ),
                const SizedBox(height: 8),
                _mobileDropdown(
                  value: statusController.text,
                  hint: 'supplier_transactions.status'.tr,
                  items: transactionProvider.getStatusOptions(),
                  onChanged: (v) {
                    setState(() => statusController.text = v!);
                    searchTransactions();
                  },
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
                    child: Text('supplier_transactions.btn_reset_filters'.tr),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              value: s,
              child: Text(UiCodeLabels.documentKind(s),
                  style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: onChanged,
      decoration: _mobileInputDecoration(hint),
      isExpanded: true,
    );
  }

  Widget _buildMobileList(TransactionProvider provider) {
    final transactions = provider.listTransactionModelDataList!;
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return Container(
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
                          child: SelectableText(
                            tx.supplier.user.name,
                            style: buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s13, 0.19, ColorManager.textColor),
                          ),
                        ),
                        _buildStatusChip(tx.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTypeCell(tx.type),
                        const SizedBox(width: 8),
                        Text(UiCodeLabels.documentKind(tx.transactionType),
                            style: buildCustomStyle(FontWeightManager.regular,
                                FontSize.s11, 0.16, Colors.grey)),
                        const Spacer(),
                        Text(
                          '${tx.currency} ${tx.amount}',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.19, ColorManager.kPrimaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(DateHelper.formatISODate(tx.date),
                            style: buildCustomStyle(FontWeightManager.regular,
                                FontSize.s11, 0.16, Colors.grey)),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${'supplier_transactions.ref_prefix'.tr} ${tx.reference}',
                              style: buildCustomStyle(FontWeightManager.regular,
                                  FontSize.s11, 0.16, Colors.grey),
                            ),
                            if (tx.reference.isNotEmpty && tx.reference != 'N/A') ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: tx.reference));
                                  showScaffold(
                                    context: context,
                                    message: 'supplier_transactions.ref_copied'.tr,
                                  );
                                },
                                child: const Icon(
                                  Icons.copy,
                                  size: 14,
                                  color: Colors.black38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => _showTransactionDetails(tx),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color:
                                    ColorManager.kPrimaryColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: 13,
                                  color: ColorManager.kPrimaryColor),
                              const SizedBox(width: 4),
                              Text('supplier_transactions.btn_view'.tr,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: ColorManager.kPrimaryColor)),
                            ],
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
        const SizedBox(height: 8),
        PaginationControl(
          currentPage: provider.transactionCurrentPage,
          totalPages: provider.transactionTotalPages,
          onPageChanged: (page) {
            String? supplierId;
            if (supplierSearchController.text.isNotEmpty) {
              supplierId = provider
                  .lookupSupplierIdByName(supplierSearchController.text)
                  ?.toString();
            }
            provider.fetchTransactionsFromServerV2(
              supplierId: supplierId,
              transactionType: transactionTypeController.text == 'All'
                  ? null
                  : transactionTypeController.text,
              type: typeController.text == 'All Types'
                  ? null
                  : typeController.text,
              page: page,
              perPage: 50,
            );
          },
        ),
      ],
    );
  }


































}

///////////////////////////////////////////////////////////////////////////////------------------------///////////////////////////////////////
