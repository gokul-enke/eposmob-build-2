import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

import '../state/expense_list_controller.dart';
import '../navigation/expense_navigation.dart';
import '../export/expense_excel_export.dart';
import '../widgets/list/expense_list_rows.dart';
import '../widgets/list/expense_list_filters.dart';

class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('expense-desktop-filters');
  static const filterToggleKey = ValueKey('expense-filter-toggle');
  static const exportKey = ValueKey('expense-export');
  static const refreshKey = ValueKey('expense-refresh');

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  late final ExpenseProvider _provider;
  late final AuthModel _auth;
  late final MasterDataProvider _masterData;
  late final AppSettingsProvider _settings;
  late final ExpenseListController _controller;
  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseProvider>();
    _auth = context.read<AuthModel>();
    _masterData = context.read<MasterDataProvider>();
    _settings = context.read<AppSettingsProvider>();
    _controller = ExpenseListController(
        reference: _provider.filterReference,
        applyReference: _provider.setReference,
        resetFilters: _provider.resetFilters,
        fetch: _refresh,
        export: widget.export);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refresh();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final token = _auth.token;
    if (token == null || token.isEmpty) return;
    final provider = _provider;
    await Future.wait([
      provider.fetchGeneralPayments(accessToken: token),
      provider.fetchAccountOptions(accessToken: token),
      _loadCategoriesFromMasterData(),
    ]);
  }

  Future<void> _loadCategoriesFromMasterData() async {
    final masterDataProvider = _masterData;
    final expenseProvider = _provider;

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

  Future<void> _exportExpenses() async {
    final exported = await _controller.export.run(context, createFile: () {
      if (_provider.isLoading || _provider.loadError != null) {
        throw StateError('Expense data is unavailable.');
      }
      _controller.prepareExport(_provider.filterReference);
      return exportExpenseExcel(List<Expense>.of(_provider.allFiltered),
          _settings.appSettings?.currency ?? '');
    });
    if (!exported && mounted) {
      AppToast.error(context, 'expense.export_error'.tr);
    }
  }

  Future<void> _copy(Expense expense) async {
    await Clipboard.setData(ClipboardData(text: expense.referenceNumber));
    if (mounted) AppToast.success(context, 'expense.copied_to_clipboard'.tr);
  }

  Widget _filters(ExpenseProvider provider) => ExpenseListFilters(
      reference: _controller.referenceController,
      filterCategory: provider.filterCategory,
      filterDebitAccount: provider.filterDebitAccount,
      filterStatus: provider.filterStatus,
      categoryOptions: provider.categoryOptions,
      debitAccountOptions: provider.debitAccountOptions,
      availableStatuses: provider.availableStatuses,
      setCategory: provider.setCategory,
      setDebitAccount: provider.setDebitAccount,
      setStatus: provider.setStatus,
      onSearch: _controller.scheduleSearch,
      onSubmit: _controller.flushSearch,
      onReset: _controller.reset);
  bool _hasActiveFilters(ExpenseProvider provider) =>
      provider.filterCategory != 'All' ||
      provider.filterDebitAccount != 'All' ||
      provider.filterStatus != 'All' ||
      _controller.referenceController.text.trim().isNotEmpty;

  /// Filters, Export, Refresh — left to right, before Add.
  List<HeaderAction> _headerActions(ExpenseProvider provider) => [
        HeaderAction(
          key: ExpenseListPage.filterToggleKey,
          icon: _controller.filtersVisible
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _controller.filtersVisible
              ? 'expense.hide_filters'.tr
              : 'expense.show_filters'.tr,
          onPressed: _controller.toggleFilters,
          active: _controller.filtersVisible,
          badge: _hasActiveFilters(provider),
        ),
        HeaderAction(
          key: ExpenseListPage.exportKey,
          icon: Icons.ios_share_rounded,
          label: _controller.export.busy
              ? (_controller.export.stage ??
                  'supplier_transactions.export_creating'.tr)
              : 'expense.export_tooltip'.tr,
          onPressed: !provider.isLoading && provider.loadError == null
              ? _exportExpenses
              : null,
          busy: _controller.export.busy,
        ),
        HeaderAction(
          key: ExpenseListPage.refreshKey,
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
      listenable: _controller,
      builder: (context, _) => ListPageScaffold<Expense>(
        header: PageHeader(
          icon: Icons.payments_outlined,
          title: 'expense.title'.tr,
          subtitle: 'expense.subtitle'.tr,
          actions: _headerActions(provider),
          onAdd: ExpenseNavigation.openCreate,
          addLabel: 'expense.new_entry'.tr,
          addShortLabel: 'expense.btn_create'.tr,
        ),
        filters: _filters(provider),
        showFilters: _controller.filtersVisible,
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
        tableScrollController: _controller.tableController,
        columns: ExpenseListRows(
                onCopy: _copy, onView: ExpenseNavigation.openDetails)
            .columns(currency),
        cardBuilder: (e, _) => ExpenseListRows(
                onCopy: _copy, onView: ExpenseNavigation.openDetails)
            .card(e, currency),
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
