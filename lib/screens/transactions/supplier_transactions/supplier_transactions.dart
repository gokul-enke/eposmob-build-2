import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:provider/provider.dart';

import '../../../helpers/date_helper.dart';
import '../../../helpers/ui_code_labels.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../services/list_excel_export_service.dart';
import '../widgets/common_details_dialog.dart';

/// Supplier transactions (ledger) list on the shared [ListPageScaffold].
///
/// Supplier, transaction type and type are sent to the API. Search, Status
/// and supplier names that do not match a known supplier are applied
/// locally over all matching pages.
class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filterToggleKey =
      ValueKey('supplier-transactions-filter-toggle');
  static const exportKey = ValueKey('supplier-transactions-export');
  static const refreshKey = ValueKey('supplier-transactions-refresh');
  static const filtersKey = ValueKey('supplier-transactions-filters');

  static const pageSize = 50;

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  static const _pageSize = TransactionScreen.pageSize;

  final searchController = TextEditingController();
  final supplierSearchController = TextEditingController();
  final typeController = TextEditingController(text: 'All Types');
  final transactionTypeController = TextEditingController(text: 'All');
  final statusController = TextEditingController(text: 'All Status');
  final _supplierFocus = FocusNode();
  late final SearchDebouncer _search = SearchDebouncer(searchTransactions);
  late final ExportController _export = widget.export ?? ExportController();
  bool initLoading = true;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
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
    _export.setStage('supplier_transactions.exporting'.tr);
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
          _export.setStage('supplier_transactions.export_fetching'
              .trParams({'page': '$page', 'total': '$total'}));
        }
      },
    );
    if (mounted) {
      _export.setStage('supplier_transactions.export_creating'.tr);
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

  Future<void> _runExport() async {
    final exported = await _export.run(
      context,
      createFile: _createExport,
      shareText: 'supplier_transactions.title'.tr,
    );
    if (!exported && mounted) {
      AppToast.error(context, 'supplier_transactions.export_failed'.tr);
    }
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
      // Filters start open on wide screens and closed on phones.
      _showFilters = MediaQuery.sizeOf(context).width >=
          ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _requestRevision++;
    _search.dispose();
    _export.dispose();
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
        perPage: _pageSize,
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
    _search.cancel();
    setState(() {
      searchController.clear();
      supplierSearchController.clear();
      typeController.text = 'All Types';
      transactionTypeController.text = 'All';
      statusController.text = 'All Status';
    });
    searchTransactions();
  }

  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  static Widget _text(String? value) => TableCells.text(_orDash(value));

  Widget _statusBadge(String status) {
    final tone = switch (status.toUpperCase()) {
      'SUCC' || 'SUCCESS' => AppBadgeTone.success,
      'INIT' || 'INITIATED' => AppBadgeTone.warning,
      'FAIL' || 'FAILED' => AppBadgeTone.danger,
      _ => AppBadgeTone.neutral,
    };
    return AppBadge(label: UiCodeLabels.status(status), tone: tone);
  }

  Widget _typeBadge(String type) => AppBadge(
        label: UiCodeLabels.documentKind(type),
        tone: type.toLowerCase() == 'credit'
            ? AppBadgeTone.success
            : AppBadgeTone.danger,
      );

  void _showTransactionDetails(TransactionModel transaction) {
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

  DropdownFilterField<String> _dropdown(
    String label,
    TextEditingController controller,
    List<String> options,
    IconData icon,
    String Function(String value) optionLabel,
  ) {
    return DropdownFilterField<String>(
      label: label,
      icon: icon,
      value: controller.text,
      options: [
        for (final value in options) FilterOption(value, optionLabel(value)),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => controller.text = value);
        searchTransactions();
      },
    );
  }

  /// Supplier name with suggestions; every edit searches right away.
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
          textAlignVertical: TextAlignVertical.center,
          style: AppTextStyles.input,
          decoration: AppInputDecoration.filter(
            label: 'supplier_transactions.supplier'.tr,
            hint: 'supplier_transactions.supplier'.tr,
            icon: Icons.local_shipping_outlined,
          ),
          onChanged: (_) => searchTransactions(),
          onSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, options) => Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: SizedBox(
              width: 280,
              height: 200,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) => ListTile(
                  selected: AutocompleteHighlightedOption.of(context) == index,
                  title: Text(options.elementAt(index)),
                  onTap: () => select(options.elementAt(index)),
                ),
              ),
            ),
          ),
        ),
      );

  FilterPanel _filters(TransactionProvider provider, List<String> statuses) {
    return FilterPanel(
      key: TransactionScreen.filtersKey,
      title: 'supplier_transactions.find'.tr,
      hint: 'supplier_transactions.find_hint'.tr,
      resetLabel: 'list.reset'.tr,
      onSearch: _search.schedule,
      onSubmit: _search.flush,
      onReset: resetSearch,
      fields: [
        TextFilterField(
          controller: searchController,
          label: 'supplier_transactions.search'.tr,
          hint: 'supplier_transactions.hint_search'.tr,
          icon: Icons.search_rounded,
        ),
        CustomFilterField(child: _supplierField(provider)),
        _dropdown(
          'supplier_transactions.trans_type'.tr,
          transactionTypeController,
          const ['All', 'Invoice', 'Voucher'],
          Icons.receipt_long_outlined,
          UiCodeLabels.documentKind,
        ),
        _dropdown(
          'supplier_transactions.type'.tr,
          typeController,
          const ['All Types', 'Credit', 'Debit'],
          Icons.swap_vert_rounded,
          UiCodeLabels.documentKind,
        ),
        _dropdown(
          'supplier_transactions.status'.tr,
          statusController,
          statuses,
          Icons.check_circle_outline,
          UiCodeLabels.status,
        ),
      ],
    );
  }

  void _copyReference(TransactionModel tx) {
    Clipboard.setData(ClipboardData(text: tx.reference));
    AppToast.success(context, 'supplier_transactions.ref_copied'.tr);
  }

  bool _canCopyReference(TransactionModel tx) =>
      tx.reference.isNotEmpty && tx.reference != 'N/A';

  Widget _copyReferenceButton(TransactionModel tx) => IconButton(
        tooltip: 'supplier_transactions.copy_reference'.tr,
        icon: const Icon(Icons.copy_outlined, size: 16),
        color: AppColors.muted,
        onPressed: () => _copyReference(tx),
      );

  Widget _reference(TransactionModel tx) => Row(children: [
        Expanded(
          child: Tooltip(message: tx.reference, child: _text(tx.reference)),
        ),
        if (_canCopyReference(tx)) _copyReferenceButton(tx),
      ]);

  Widget _card(TransactionModel tx, int number) => AppListCard(
        leading: AppAvatar(
          name: tx.supplier.user.name,
          semanticLabel: tx.supplier.user.name,
          size: 42,
        ),
        title: _orDash(tx.supplier.user.name),
        subtitle: '${'supplier_transactions.col_si_no'.tr}: ${tx.siNo}',
        trailing: _statusBadge(tx.status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                icon: Icons.payments_outlined,
                label: 'supplier_transactions.col_amount'.tr,
                value: '${tx.currency} ${tx.amount}',
              ),
              AppMetric(
                icon: Icons.calendar_today_outlined,
                label: 'supplier_transactions.col_date'.tr,
                value: _orDash(DateHelper.formatISODate(tx.date)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
              icon: Icons.swap_vert_rounded,
              label: 'supplier_transactions.type'.tr,
              value: _orDash(UiCodeLabels.documentKind(tx.type)),
              valueColor: tx.type.toLowerCase() == 'credit'
                  ? AppColors.green
                  : AppColors.red,
            ),
            InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'supplier_transactions.col_transaction_type'.tr,
              value: _orDash(UiCodeLabels.documentKind(tx.transactionType)),
            ),
            InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'supplier_transactions.col_payment_mode'.tr,
              value: _orDash(UiCodeLabels.payment(tx.paymentMode)),
            ),
            InfoRow(
              icon: Icons.tag_rounded,
              label: 'supplier_transactions.col_reference'.tr,
              value: _orDash(tx.reference),
              trailing:
                  _canCopyReference(tx) ? _copyReferenceButton(tx) : null,
            ),
          ],
        ),
        actionLabel: 'list.view'.tr,
        actionIcon: Icons.visibility_outlined,
        onAction: () => _showTransactionDetails(tx),
      );

  List<TableColumnDef<TransactionModel>> _columns() => [
        TableColumnDef(
            label: 'supplier_transactions.col_si_no'.tr,
            flex: .5,
            cellBuilder: (tx, _) => _text('${tx.siNo}')),
        TableColumnDef(
            label: 'supplier_transactions.supplier'.tr,
            flex: 2,
            cellBuilder: (tx, _) => TableCells.avatarName(
                  name: _orDash(tx.supplier.user.name),
                  avatar: AppAvatar(
                    name: tx.supplier.user.name,
                    semanticLabel: tx.supplier.user.name,
                    size: 36,
                  ),
                )),
        TableColumnDef(
            label: 'supplier_transactions.col_date'.tr,
            flex: 1.2,
            cellBuilder: (tx, _) => _text(DateHelper.formatISODate(tx.date))),
        TableColumnDef(
            label: 'supplier_transactions.type'.tr,
            cellBuilder: (tx, _) => TableCells.widget(_typeBadge(tx.type))),
        TableColumnDef(
            label: 'supplier_transactions.col_transaction_type'.tr,
            flex: 1.3,
            cellBuilder: (tx, _) =>
                _text(UiCodeLabels.documentKind(tx.transactionType))),
        TableColumnDef(
            label: 'supplier_transactions.col_payment_mode'.tr,
            flex: 1.2,
            cellBuilder: (tx, _) =>
                _text(UiCodeLabels.payment(tx.paymentMode))),
        TableColumnDef(
            label: 'supplier_transactions.col_amount'.tr,
            flex: 1.3,
            cellBuilder: (tx, _) => _text('${tx.currency} ${tx.amount}')),
        TableColumnDef(
            label: 'supplier_transactions.col_reference'.tr,
            flex: 1.6,
            cellBuilder: (tx, _) => _reference(tx)),
        TableColumnDef(
            label: 'supplier_transactions.status'.tr,
            flex: 1.1,
            cellBuilder: (tx, _) => TableCells.widget(_statusBadge(tx.status))),
        TableColumnDef(
            label: 'supplier_transactions.col_action'.tr,
            flex: 1.2,
            cellBuilder: (tx, _) => TableCells.action(
                  label: 'list.view'.tr,
                  icon: Icons.visibility_outlined,
                  onPressed: () => _showTransactionDetails(tx),
                )),
      ];

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> _headerActions({required bool canExport}) => [
        HeaderAction(
          key: TransactionScreen.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters
              ? 'supplier_transactions.hide_filters'.tr
              : 'supplier_transactions.filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: !_showFilters && _hasActiveFilters,
        ),
        HeaderAction(
          key: TransactionScreen.exportKey,
          icon: Icons.ios_share_rounded,
          label: _export.busy
              ? (_export.stage ?? 'supplier_transactions.exporting'.tr)
              : 'supplier_transactions.export'.tr,
          onPressed: canExport ? _runExport : null,
          busy: _export.busy,
        ),
        HeaderAction(
          key: TransactionScreen.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: _onRefresh,
        ),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _export,
        builder: (context, _) => Consumer<TransactionProvider>(
          builder: (context, provider, _) {
            final local = _usesLocalFilters;
            final allLocal = _localItems ?? <TransactionModel>[];
            final localPages = ((allLocal.length + _pageSize - 1) ~/ _pageSize)
                .clamp(1, 1 << 30);
            final currentPage = local
                ? _localPage.clamp(1, localPages)
                : provider.transactionCurrentPage;
            final items = local
                ? allLocal
                    .skip((currentPage - 1) * _pageSize)
                    .take(_pageSize)
                    .toList()
                : provider.listTransactionModelDataList ?? <TransactionModel>[];
            final statuses = <String>{
              'All Status',
              statusController.text,
              ...?provider.listTransactionModelDataList?.map((tx) => tx.status),
              ...allLocal.map((tx) => tx.status)
            }.where((value) => value.isNotEmpty).toList();
            final loading =
                initLoading || provider.transactionIsLoading || _localLoading;
            return ListPageScaffold<TransactionModel>(
              minTableWidth: 1200,
              header: PageHeader(
                icon: Icons.swap_horiz_rounded,
                title: 'supplier_transactions.title'.tr,
                subtitle: 'supplier_transactions.subtitle'.tr,
                actions: _headerActions(
                  canExport: !initLoading &&
                      !provider.transactionIsLoading &&
                      items.isNotEmpty,
                ),
              ),
              showFilters: _showFilters,
              filters: _filters(provider, statuses),
              isLoading: loading,
              items: items,
              onRefresh: _onRefresh,
              onRowTap: _showTransactionDetails,
              cardBuilder: _card,
              columns: _columns(),
              emptyState: AppEmptyState(
                icon: Icons.search_off_rounded,
                title: (_hasActiveFilters
                        ? 'supplier_transactions.no_filter_match'
                        : 'supplier_transactions.no_transactions')
                    .tr,
                action: _hasActiveFilters
                    ? AppOutlinedButton(
                        label: 'supplier_transactions.btn_reset_filters'.tr,
                        icon: Icons.restart_alt_rounded,
                        onPressed: resetSearch,
                      )
                    : null,
              ),
              pagination: ListPagination(
                currentPage: currentPage,
                totalPages: local ? localPages : provider.transactionTotalPages,
                itemsPerPage: _pageSize,
                onPageChanged: _fetchPage,
                countLabel: 'supplier_transactions.count_on_page'
                    .trParams({'count': '${items.length}'}),
              ),
            );
          },
        ),
      );
}
