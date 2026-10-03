import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:provider/provider.dart';

import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import '../../models/master_data.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../services/list_excel_export_service.dart';
import 'widgets/expense_list_responsive.dart';

@visibleForTesting
bool isMeaningfulExpenseFilterSelection(
  String? value, {
  required String allLabel,
}) {
  final normalizedValue = value?.trim().toLowerCase();
  if (normalizedValue == null || normalizedValue.isEmpty) return false;

  final normalizedAllLabel = allLabel.trim().toLowerCase();
  return normalizedValue != 'all' && normalizedValue != normalizedAllLabel;
}

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('expense-desktop-filters');
  static const filterToggleKey = ValueKey('expense-filter-toggle');
  static const exportKey = ValueKey('expense-export');
  static const refreshKey = ValueKey('expense-refresh');

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _reference = TextEditingController();
  late final SearchDebouncer _search = SearchDebouncer(_applyReference);
  late final ExportController _export = widget.export ?? ExportController();
  final _tableController = ScrollController();
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _reference.text = context.read<ExpenseProvider>().filterReference;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    final token = context.read<AuthModel>().token;
    if (token == null || token.isEmpty) return;
    final provider = context.read<ExpenseProvider>();
    await Future.wait([
      provider.fetchGeneralPayments(accessToken: token),
      provider.fetchAccountOptions(accessToken: token),
      _loadCategoriesFromMasterData(),
    ]);
  }

  Future<void> _loadCategoriesFromMasterData() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);

    final categories = await _fetchFirstAvailableMasterData(
      masterDataProvider,
      const ['EXPENSE_CATEGORY', 'EXPENSE_CATEGORIES'],
    );
    if (!mounted) return;
    if (categories != null && categories.isNotEmpty) {
      expenseProvider.setCategoryOptionsFromMasterData(categories);
    }
  }

  Future<List<MasterDataValue>?> _fetchFirstAvailableMasterData(
    MasterDataProvider provider,
    List<String> codes,
  ) async {
    for (final code in codes) {
      try {
        final result = await provider.fetchMasterData(code);
        final data = result?.data;
        if (data != null && data.isNotEmpty) {
          return data;
        }
      } catch (_) {
        // Try next candidate code.
      }
    }
    return null;
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.export == null) _export.dispose();
    _reference.dispose();
    _tableController.dispose();
    super.dispose();
  }

  void _applyReference() {
    if (!mounted) return;
    context.read<ExpenseProvider>().setReference(_reference.text);
  }

  void _reset() {
    _search.cancel();
    _reference.clear();
    context.read<ExpenseProvider>().resetFilters();
  }

  /// Options with "All" first; the current selection is always present.
  static List<String> _options(String selected, Iterable<String> values) =>
      <String>{
        'All',
        ...values.where((v) => v.trim().isNotEmpty),
        selected
      }.toList();

  static String _display(String value) =>
      value == 'All' ? 'common.all'.tr : value;

  /// Category / debit account picker with a search box.
  FilterFieldDef _searchableDropdown(String label, IconData icon,
      String selected, Iterable<String> values, ValueChanged<String> onChanged) {
    return CustomFilterField(
      child: DropdownSearch<String>(
        selectedItem: selected,
        items: (_, __) => _options(selected, values),
        itemAsString: _display,
        decoratorProps: DropDownDecoratorProps(
            decoration: AppInputDecoration.filter(label: label, icon: icon)),
        popupProps: const PopupProps.menu(showSearchBox: true),
        onChanged: (value) => onChanged(value ?? 'All'),
      ),
    );
  }

  FilterPanel _filters(ExpenseProvider provider) => FilterPanel(
        key: ExpenseListScreen.filtersKey,
        title: 'expense.find'.tr,
        hint: 'expense.filter_hint'.tr,
        resetLabel: 'list.reset'.tr,
        onSearch: _search.schedule,
        onSubmit: _search.flush,
        onReset: _reset,
        fields: [
          _searchableDropdown(
              'expense.category'.tr,
              Icons.category_outlined,
              provider.filterCategory,
              provider.categoryOptions.map((v) => v['name']?.toString() ?? ''),
              provider.setCategory),
          TextFilterField(
              controller: _reference,
              label: 'expense.hint_reference_no'.tr,
              hint: 'expense.hint_reference_no'.tr,
              icon: Icons.tag),
          _searchableDropdown(
              'expense.filter_debit_account'.tr,
              Icons.account_balance_outlined,
              provider.filterDebitAccount,
              provider.debitAccountOptions
                  .map((v) => v['name']?.toString() ?? ''),
              provider.setDebitAccount),
          DropdownFilterField<String>(
              label: 'expense.status'.tr,
              icon: Icons.check_circle_outline,
              value: provider.filterStatus,
              options: [
                for (final value in _options(
                    provider.filterStatus, provider.availableStatuses))
                  FilterOption(value, _display(value)),
              ],
              onChanged: (value) => provider.setStatus(value ?? 'All')),
        ],
      );

  Future<void> _exportExpenses() async {
    final exported = await _export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'expense.export_error'.tr);
    }
  }

  Future<File> _createExport() {
    final provider = context.read<ExpenseProvider>();
    if (provider.isLoading || provider.loadError != null) {
      throw StateError('Expense data is unavailable.');
    }
    _search.cancel();
    if (provider.filterReference != _reference.text) {
      provider.setReference(_reference.text);
    }
    final rows = List<Expense>.of(provider.allFiltered);
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? '';
    return ListExcelExportService.export<Expense>(
      items: rows,
      fileNamePrefix: 'expenses',
      sheetName: 'Expenses',
      columns: [
        ListExportColumn(
            label: 'expense.col_reference_number'.tr,
            value: (e, _) => e.referenceNumber),
        ListExportColumn(
            label: 'expense.col_payment_date'.tr,
            value: (e, _) => DateHelper.formatDate(e.paymentDate)),
        ListExportColumn(
            label: 'expense.category'.tr, value: (e, _) => e.category),
        ListExportColumn(
            label: 'expense.col_debit_ac'.tr, value: (e, _) => e.debitAccount),
        ListExportColumn(
            label: 'expense.col_credit_ac'.tr,
            value: (e, _) => e.creditAccount),
        ListExportColumn(label: 'expense.amount'.tr, value: (e, _) => e.amount),
        ListExportColumn(
            label: 'expense.currency'.tr, value: (_, __) => currency),
        ListExportColumn(label: 'expense.status'.tr, value: (e, _) => e.status),
        ListExportColumn(
            label: 'expense.payment_method'.tr,
            value: (e, _) => e.paymentMethod),
        ListExportColumn(
            label: 'expense.label_description_vendor'.tr,
            value: (e, _) => e.description),
        ListExportColumn(
            label: 'expense.label_notes_remarks'.tr, value: (e, _) => e.notes),
      ],
    );
  }

  void _view(Expense expense) {
    Get.find<SideBarController>().index.value = 95;
    Get.put(ExpenseViewController()).selectedRef.value =
        expense.referenceNumber;
  }

  /// Blank values show as a dash, as in the other list columns.
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;

  Widget _copyButton(Expense expense) => IconButton(
      icon: const Icon(Icons.copy_outlined, size: 16),
      tooltip: 'expense.copied_to_clipboard'.tr,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: expense.referenceNumber));
        if (!mounted) return;
        AppToast.success(context, 'expense.copied_to_clipboard'.tr);
      });

  Widget _referenceCell(Expense expense) => Row(children: [
        Expanded(child: TableCells.text(_orDash(expense.referenceNumber))),
        _copyButton(expense),
      ]);

  String _amount(Expense expense, String currency) =>
      '$currency ${expense.amount.toStringAsFixed(2)}';

  Widget _card(Expense expense, String currency) => AppListCard(
        leading: const AppIconTile(
            icon: Icons.payments_outlined,
            size: 42,
            iconSize: 20,
            background: AppColors.softBlue,
            foreground: AppColors.primary),
        title: _orDash(expense.category),
        subtitle: DateHelper.formatDate(expense.paymentDate),
        trailing: ExpenseListStatusPill(status: expense.status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                  icon: Icons.payments_outlined,
                  label: 'expense.amount'.tr,
                  value: _amount(expense, currency)),
              AppMetric(
                  icon: Icons.event_outlined,
                  label: 'expense.col_payment_date'.tr,
                  value: DateHelper.formatDate(expense.paymentDate)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
                icon: Icons.tag,
                label: 'expense.col_reference_number'.tr,
                value: _orDash(expense.referenceNumber),
                trailing: _copyButton(expense)),
            InfoRow(
                icon: Icons.account_balance_outlined,
                label: 'expense.col_debit_ac'.tr,
                value: _orDash(expense.debitAccount)),
            InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'expense.col_credit_ac'.tr,
                value: _orDash(expense.creditAccount)),
          ],
        ),
        actionLabel: 'list.view'.tr,
        actionIcon: Icons.visibility_outlined,
        onAction: () => _view(expense),
      );

  List<TableColumnDef<Expense>> _columns(String currency) => [
        TableColumnDef(
            label: 'expense.col_reference_number'.tr,
            flex: 1.5,
            cellBuilder: (e, _) => _referenceCell(e)),
        TableColumnDef(
            label: 'expense.col_payment_date'.tr,
            cellBuilder: (e, _) => TableCells.text(
                _orDash(DateHelper.formatDate(e.paymentDate)))),
        TableColumnDef(
            label: 'expense.category'.tr,
            flex: 1.4,
            cellBuilder: (e, _) => TableCells.text(_orDash(e.category))),
        TableColumnDef(
            label: 'expense.col_debit_ac'.tr,
            flex: 1.4,
            cellBuilder: (e, _) => TableCells.text(_orDash(e.debitAccount))),
        TableColumnDef(
            label: 'expense.col_credit_ac'.tr,
            flex: 1.4,
            cellBuilder: (e, _) => TableCells.text(_orDash(e.creditAccount))),
        TableColumnDef(
            label: 'expense.amount'.tr,
            flex: 1.1,
            cellBuilder: (e, _) => TableCells.text(_amount(e, currency))),
        TableColumnDef(
            label: 'expense.status'.tr,
            cellBuilder: (e, _) =>
                TableCells.widget(ExpenseListStatusPill(status: e.status))),
        TableColumnDef(
            label: 'expense.breadcrumb_view'.tr,
            cellBuilder: (e, _) => TableCells.action(
                label: 'list.view'.tr,
                icon: Icons.visibility_outlined,
                onPressed: () => _view(e))),
      ];

  bool _hasActiveFilters(ExpenseProvider provider) =>
      provider.filterCategory != 'All' ||
      provider.filterDebitAccount != 'All' ||
      provider.filterStatus != 'All' ||
      _reference.text.trim().isNotEmpty;

  /// Filters, Export, Refresh — left to right, before Add.
  List<HeaderAction> _headerActions(ExpenseProvider provider) => [
        HeaderAction(
          key: ExpenseListScreen.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters
              ? 'expense.hide_filters'.tr
              : 'expense.show_filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: _hasActiveFilters(provider),
        ),
        HeaderAction(
          key: ExpenseListScreen.exportKey,
          icon: Icons.ios_share_rounded,
          label: _export.busy
              ? (_export.stage ?? 'supplier_transactions.export_creating'.tr)
              : 'expense.export_tooltip'.tr,
          onPressed: !provider.isLoading && provider.loadError == null
              ? _exportExpenses
              : null,
          busy: _export.busy,
        ),
        HeaderAction(
          key: ExpenseListScreen.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: provider.isLoading ? null : _refresh,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final currency = context.select<AppSettingsProvider, String>(
        (p) => p.appSettings?.currency ?? '');
    return ListenableBuilder(
      // Rebuilds the filter badge while typing and the export progress.
      listenable: Listenable.merge([_export, _reference]),
      builder: (context, _) => ListPageScaffold<Expense>(
        header: PageHeader(
          icon: Icons.payments_outlined,
          title: 'expense.title'.tr,
          subtitle: 'expense.subtitle'.tr,
          actions: _headerActions(provider),
          onAdd: () => Get.find<SideBarController>().index.value = 94,
          addLabel: 'expense.new_entry'.tr,
          addShortLabel: 'expense.btn_create'.tr,
        ),
        filters: _filters(provider),
        showFilters: _showFilters,
        toolbar: provider.loadError == null
            ? null
            : AppSurface(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(children: [
                  Expanded(child: Text('expense.load_error'.tr)),
                  TextButton(
                      onPressed: provider.isLoading ? null : _refresh,
                      child: Text('expense.retry'.tr)),
                ])),
        isLoading: provider.isLoading,
        items: provider.expenses,
        minTableWidth: 1150,
        tableScrollController: _tableController,
        columns: _columns(currency),
        cardBuilder: (e, _) => _card(e, currency),
        emptyState: AppEmptyState(
          icon: Icons.payments_outlined,
          title: 'expense.no_expenses_found'.tr,
          subtitle: 'expense.no_expenses_hint'.tr,
        ),
        onRefresh: _refresh,
        pagination: ListPagination(
          currentPage: provider.currentPage,
          totalPages: provider.totalPages,
          itemsPerPage: provider.itemsPerPage,
          onPageChanged: provider.setPage,
          countLabel: 'expense.page_count'
              .trParams({'count': '${provider.expenses.length}'}),
        ),
      ),
    );
  }
}

class ExpenseViewController extends GetxController {
  var selectedRef = ''.obs;
}
