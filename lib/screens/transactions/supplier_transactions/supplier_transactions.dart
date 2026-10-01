import 'dart:io';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/app_surface.dart';
import '../../../core/ui/list_page/filter_panel.dart';
import '../../../core/ui/list_page/list_page_header.dart';
import '../../../core/ui/list_page/list_page_scaffold.dart';
import '../../../components/filter_toggle_button.dart';
import '../../../components/export_share_button.dart';
import '../../../services/list_excel_export_service.dart';
import '../../../helpers/date_helper.dart';
import '../../../helpers/ui_code_labels.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../newcomponents/custom_dialog_box.dart';
import '../widgets/common_details_dialog.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final searchController = TextEditingController();
  final supplierSearchController = TextEditingController();
  final typeController = TextEditingController(text: 'All Types');
  final transactionTypeController = TextEditingController(text: 'All');
  final statusController = TextEditingController(text: 'All Status');
  final _supplierFocus = FocusNode();
  bool initLoading = true;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  TransactionModel? selectedTransaction;
  final _exportProgress = ValueNotifier<String?>(null);
  List<TransactionModel>? _localItems;
  Future<List<TransactionModel>>? _localSource;
  String? _localSourceKey;
  int _localPage = 1;
  bool _localLoading = false;
  int _requestRevision = 0;
  bool get _usesLocalFilters =>
      searchController.text.trim().isNotEmpty ||
      statusController.text != 'All Status' ||
      (supplierSearchController.text.trim().isNotEmpty &&
          context
                  .read<TransactionProvider>()
                  .lookupSupplierIdByName(supplierSearchController.text) ==
              null);

  bool get _hasActiveFilters =>
      searchController.text.isNotEmpty ||
      supplierSearchController.text.isNotEmpty ||
      typeController.text != 'All Types' ||
      transactionTypeController.text != 'All' ||
      statusController.text != 'All Status';

  Future<File> _createExport() async {
    _exportProgress.value = 'supplier_transactions.exporting'.tr;
    final provider = context.read<TransactionProvider>();
    // Capture the applied API filter values before awaiting the export fetch.
    final items = await provider.fetchTransactionsForExport(
      supplierId: provider
          .lookupSupplierIdByName(supplierSearchController.text)
          ?.toString(),
      transactionType: transactionTypeController.text == 'All'
          ? null
          : transactionTypeController.text,
      type: typeController.text == 'All Types' ? null : typeController.text,
      search: searchController.text,
      status:
          statusController.text == 'All Status' ? null : statusController.text,
      supplierName: supplierSearchController.text,
      onProgress: (page, total) {
        if (mounted) {
          _exportProgress.value = 'supplier_transactions.export_fetching'
              .trParams({'page': '$page', 'total': '$total'});
        }
      },
    );
    if (mounted) {
      _exportProgress.value = 'supplier_transactions.export_creating'.tr;
    }
    return ListExcelExportService.export<TransactionModel>(
      items: items,
      fileNamePrefix: 'supplier-transactions',
      sheetName: 'supplier_transactions.title'.tr,
      columns: [
        ListExportColumn(
            label: 'supplier_transactions.col_si_no'.tr,
            value: (_, index) => index + 1),
        ListExportColumn(
            label: 'supplier_transactions.supplier'.tr,
            value: (tx, _) => tx.supplier.user.name),
        ListExportColumn(
            label: 'supplier_transactions.col_date'.tr,
            value: (tx, _) => DateHelper.formatISODate(tx.date)),
        ListExportColumn(
            label: 'supplier_transactions.type'.tr,
            value: (tx, _) => UiCodeLabels.documentKind(tx.type)),
        ListExportColumn(
            label: 'supplier_transactions.col_transaction_type'.tr,
            value: (tx, _) => UiCodeLabels.documentKind(tx.transactionType)),
        ListExportColumn(
            label: 'supplier_transactions.col_payment_mode'.tr,
            value: (tx, _) => UiCodeLabels.payment(tx.paymentMode)),
        ListExportColumn(
            label: 'supplier_transactions.col_amount'.tr,
            value: (tx, _) => ListExcelExportService.numericValue(tx.amount)),
        ListExportColumn(
            label: 'supplier_transactions.currency'.tr,
            value: (tx, _) => tx.currency),
        ListExportColumn(
            label: 'supplier_transactions.tax_amount'.tr,
            value: (tx, _) =>
                ListExcelExportService.numericValue(tx.taxAmount)),
        ListExportColumn(
            label: 'supplier_transactions.col_reference'.tr,
            value: (tx, _) => tx.reference),
        ListExportColumn(
            label: 'supplier_transactions.status'.tr,
            value: (tx, _) => UiCodeLabels.status(tx.status)),
        ListExportColumn(
            label: 'supplier_transactions.comment'.tr,
            value: (tx, _) => tx.transactionComment),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context
          .read<TransactionProvider>()
          .setAccessToken(context.read<AuthModel>().token ?? '');
      await _fetchPage(1);
      if (mounted) setState(() => initLoading = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobile;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _requestRevision++;
    _exportProgress.dispose();
    searchController.dispose();
    supplierSearchController.dispose();
    typeController.dispose();
    transactionTypeController.dispose();
    statusController.dispose();
    _supplierFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    final provider = context.read<TransactionProvider>();
    final supplierId = provider
        .lookupSupplierIdByName(supplierSearchController.text)
        ?.toString();
    final revision = ++_requestRevision;
    try {
      if (_usesLocalFilters) {
        if (_localItems == null) {
          setState(() => _localLoading = true);
          final key =
              '$supplierId|${transactionTypeController.text}|${typeController.text}';
          if (_localSourceKey != key) {
            _localSource = null;
            _localSourceKey = key;
          }
          final result =
              await (_localSource ??= provider.fetchTransactionsForExport(
            supplierId: supplierId,
            transactionType: transactionTypeController.text == 'All'
                ? null
                : transactionTypeController.text,
            type:
                typeController.text == 'All Types' ? null : typeController.text,
          ));
          if (!mounted || revision != _requestRevision) return;
          _localItems = TransactionProvider.filterTransactions(result,
              search: searchController.text,
              status: statusController.text == 'All Status'
                  ? null
                  : statusController.text,
              supplierName: supplierSearchController.text);
        }
        if (mounted && revision == _requestRevision) {
          setState(() => _localPage = page);
        }
        return;
      }
      _localItems = null;
      await provider.fetchTransactionsFromServerV2(
        supplierId: supplierId,
        transactionType: transactionTypeController.text == 'All'
            ? null
            : transactionTypeController.text,
        type: typeController.text == 'All Types' ? null : typeController.text,
        page: page,
        perPage: 50,
      );
    } catch (error) {
      if (revision == _requestRevision) _localSource = null;
      if (!mounted || revision != _requestRevision) return;
      AppToast.error(context, 'supplier_transactions.error_loading'
          .trParams({'error': '$error'}));
    } finally {
      if (mounted && revision == _requestRevision) {
        setState(() => _localLoading = false);
      }
    }
  }

  void searchTransactions() {
    _localItems = null;
    _fetchPage(1);
  }

  Future<void> _onRefresh() {
    final page = _usesLocalFilters
        ? _localPage
        : context.read<TransactionProvider>().transactionCurrentPage;
    _localItems = null;
    _localSource = null;
    return _fetchPage(page);
  }

  void resetSearch() {
    setState(() {
      searchController.clear();
      supplierSearchController.clear();
      typeController.text = 'All Types';
      transactionTypeController.text = 'All';
      statusController.text = 'All Status';
    });
    searchTransactions();
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'SUCC':
      case 'SUCCESS':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        break;
      case 'INIT':
      case 'INITIATED':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        break;
      case 'FAIL':
      case 'FAILED':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
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
        color: color.withValues(alpha: 0.1),
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
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.supplier_name'.tr,
                transaction.supplier.user.name),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.date'.tr,
                DateHelper.formatISODate(transaction.date)),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.type'.tr,
                UiCodeLabels.documentKind(transaction.type)),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.transaction_type'.tr,
                UiCodeLabels.documentKind(transaction.transactionType)),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.payment_mode'.tr,
                UiCodeLabels.payment(transaction.paymentMode)),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.amount'.tr,
                '${transaction.currency} ${transaction.amount}'),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.tax_amount'.tr,
                transaction.taxAmount ?? 'supplier_transactions.na'.tr),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.reference'.tr, transaction.reference,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.status'.tr, transaction.status),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_transactions.comment'.tr,
                transaction.transactionComment ??
                    'supplier_transactions.na'.tr),
          ],
        ],
      ),
    );
  }

  Widget _dropdown(String label, TextEditingController controller,
      List<String> options, IconData icon) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:${controller.text}'),
      initialValue: controller.text,
      isExpanded: true,
      decoration: listFilterDecoration(label, icon),
      items: options
          .map((value) => DropdownMenuItem(
              value: value,
              child: Text(
                  controller == statusController
                      ? UiCodeLabels.status(value)
                      : UiCodeLabels.documentKind(value),
                  overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => controller.text = value);
        searchTransactions();
      },
    );
  }

  Widget _supplierField(TransactionProvider provider) =>
      RawAutocomplete<String>(
        textEditingController: supplierSearchController,
        focusNode: _supplierFocus,
        optionsBuilder: (value) => value.text.isEmpty
            ? const Iterable<String>.empty()
            : provider.getSupplierOptions().where((name) =>
                name.toLowerCase().contains(value.text.toLowerCase())),
        onSelected: (_) => searchTransactions(),
        fieldViewBuilder: (context, controller, focus, submit) => TextField(
          controller: controller,
          focusNode: focus,
          decoration: listFilterDecoration('supplier_transactions.supplier'.tr,
              Icons.local_shipping_outlined),
          onChanged: (_) => searchTransactions(),
          onSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                  width: 280,
                  height: 200,
                  child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) => ListTile(
                            selected:
                                AutocompleteHighlightedOption.of(context) ==
                                    index,
                            title: Text(options.elementAt(index)),
                            onTap: () => select(options.elementAt(index)),
                          )))),
        ),
      );

  Widget _reference(TransactionModel tx) => Row(children: [
        Expanded(
            child: Tooltip(
                message: tx.reference, child: TableCells.text(tx.reference))),
        if (tx.reference.isNotEmpty && tx.reference != 'N/A')
          IconButton(
              tooltip: 'supplier_transactions.copy_reference'.tr,
              icon: const Icon(Icons.copy_outlined, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: tx.reference));
                showScaffold(
                    context: context,
                    message: 'supplier_transactions.ref_copied'.tr);
              }),
      ]);

  Widget _card(TransactionModel tx, int number) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableCells.identity(tx.supplier.user.name),
        const SizedBox(height: 12),
        Text('${'supplier_transactions.col_si_no'.tr}: ${tx.siNo}'),
        Text(
            '${'supplier_transactions.col_date'.tr}: ${DateHelper.formatISODate(tx.date)}'),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_buildTypeCell(tx.type), _buildStatusChip(tx.status)]),
        const SizedBox(height: 8),
        Text(
            '${'supplier_transactions.col_transaction_type'.tr}: ${UiCodeLabels.documentKind(tx.transactionType)}'),
        Text(
            '${'supplier_transactions.col_payment_mode'.tr}: ${UiCodeLabels.payment(tx.paymentMode)}'),
        Text(
            '${'supplier_transactions.col_amount'.tr}: ${tx.currency} ${tx.amount}'),
        _reference(tx),
        SizedBox(
            width: double.infinity,
            child: TableCells.viewButton(() => _showTransactionDetails(tx))),
      ]));

  @override
  Widget build(BuildContext context) =>
      Consumer<TransactionProvider>(builder: (context, provider, _) {
        final local = _usesLocalFilters;
        final allLocal = _localItems ?? <TransactionModel>[];
        final localPages = ((allLocal.length + 49) ~/ 50).clamp(1, 1 << 30);
        final currentPage = local
            ? _localPage.clamp(1, localPages)
            : provider.transactionCurrentPage;
        final items = local
            ? allLocal.skip((currentPage - 1) * 50).take(50).toList()
            : provider.listTransactionModelDataList ?? <TransactionModel>[];
        final statuses = <String>{
          'All Status',
          statusController.text,
          ...?provider.listTransactionModelDataList?.map((tx) => tx.status),
          ...allLocal.map((tx) => tx.status)
        }.where((value) => value.isNotEmpty).toList();
        return ListPageScaffold<TransactionModel>(
          tableMinWidth: 1200,
          header: ListPageHeader(
              icon: Icons.swap_horiz_rounded,
              title: 'supplier_transactions.title'.tr,
              subtitle: 'supplier_transactions.subtitle'.tr,
              onRefresh: _onRefresh,
              extraActions: [
                FilterToggleButton(
                  key: const ValueKey('supplier-transactions-filter-toggle'),
                  showFilters: _showFilters,
                  hasActiveFilters: _hasActiveFilters,
                  activeFiltersListenable: Listenable.merge(
                      [searchController, supplierSearchController]),
                  activeFiltersBuilder: () => _hasActiveFilters,
                  showTooltip: 'supplier_transactions.filters'.tr,
                  hideTooltip: 'supplier_transactions.hide_filters'.tr,
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
                ExportShareButton(
                  key: const ValueKey('supplier-transactions-export'),
                  compact: MediaQuery.sizeOf(context).width <
                      ListLayoutBreakpoints.actions,
                  enabled: !initLoading &&
                      !provider.transactionIsLoading &&
                      items.isNotEmpty,
                  createFile: _createExport,
                  progressLabel: _exportProgress,
                  label: 'supplier_transactions.export'.tr,
                  loadingLabel: 'supplier_transactions.exporting'.tr,
                  tooltip: 'supplier_transactions.export_tooltip'.tr,
                  errorMessage: 'supplier_transactions.export_failed'.tr,
                  mimeType:
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  shareText: 'supplier_transactions.title'.tr,
                ),
              ]),
          showFilters: _showFilters,
          filters: FilterPanel(
              key: const ValueKey('supplier-transactions-filters'),
              title: 'supplier_transactions.find'.tr,
              hint: 'supplier_transactions.find_hint'.tr,
              onReset: resetSearch,
              fields: [
                TextFilterField(
                    controller: searchController,
                    label: 'supplier_transactions.search'.tr,
                    icon: Icons.search_rounded,
                    onSearch: searchTransactions),
                _supplierField(provider),
                _dropdown(
                    'supplier_transactions.trans_type'.tr,
                    transactionTypeController,
                    const ['All', 'Invoice', 'Voucher'],
                    Icons.receipt_long_outlined),
                _dropdown(
                    'supplier_transactions.type'.tr,
                    typeController,
                    const ['All Types', 'Credit', 'Debit'],
                    Icons.swap_vert_rounded),
                _dropdown('supplier_transactions.status'.tr, statusController,
                    statuses, Icons.check_circle_outline),
              ]),
          isLoading:
              initLoading || provider.transactionIsLoading || _localLoading,
          items: items,
          onRefresh: _onRefresh,
          onItemTap: _showTransactionDetails,
          cardBuilder: _card,
          emptyState: AppSurface(
              child: Column(children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text((_hasActiveFilters
                    ? 'supplier_transactions.no_filter_match'
                    : 'supplier_transactions.no_transactions')
                .tr),
            if (_hasActiveFilters)
              TextButton(
                  onPressed: resetSearch,
                  child: Text('supplier_transactions.btn_reset_filters'.tr)),
          ])),
          currentPage: currentPage,
          totalPages: local ? localPages : provider.transactionTotalPages,
          itemsPerPage: 50,
          onPageChanged: _fetchPage,
          countLabel: 'supplier_transactions.count_on_page'
              .trParams({'count': '${items.length}'}),
          columns: [
            TableColumnDef(
                label: 'supplier_transactions.col_si_no'.tr,
                flex: .5,
                cellBuilder: (tx, _) => TableCells.text('${tx.siNo}')),
            TableColumnDef(
                label: 'supplier_transactions.supplier'.tr,
                flex: 2,
                cellBuilder: (tx, _) =>
                    TableCells.identity(tx.supplier.user.name)),
            TableColumnDef(
                label: 'supplier_transactions.col_date'.tr,
                flex: 1.2,
                cellBuilder: (tx, _) =>
                    TableCells.text(DateHelper.formatISODate(tx.date))),
            TableColumnDef(
                label: 'supplier_transactions.type'.tr,
                cellBuilder: (tx, _) => _buildTypeCell(tx.type)),
            TableColumnDef(
                label: 'supplier_transactions.col_transaction_type'.tr,
                flex: 1.3,
                cellBuilder: (tx, _) => TableCells.text(
                    UiCodeLabels.documentKind(tx.transactionType))),
            TableColumnDef(
                label: 'supplier_transactions.col_payment_mode'.tr,
                flex: 1.2,
                cellBuilder: (tx, _) =>
                    TableCells.text(UiCodeLabels.payment(tx.paymentMode))),
            TableColumnDef(
                label: 'supplier_transactions.col_amount'.tr,
                flex: 1.3,
                cellBuilder: (tx, _) =>
                    TableCells.text('${tx.currency} ${tx.amount}')),
            TableColumnDef(
                label: 'supplier_transactions.col_reference'.tr,
                flex: 1.6,
                cellBuilder: (tx, _) => _reference(tx)),
            TableColumnDef(
                label: 'supplier_transactions.status'.tr,
                flex: 1.1,
                cellBuilder: (tx, _) => _buildStatusChip(tx.status)),
            TableColumnDef(
                label: 'supplier_transactions.col_action'.tr,
                flex: 1.2,
                cellBuilder: (tx, _) =>
                    TableCells.viewButton(() => _showTransactionDetails(tx))),
          ],
        );
      });
}
