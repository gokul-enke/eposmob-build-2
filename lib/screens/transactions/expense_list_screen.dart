import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../components/export_share_button.dart';
import '../../components/filter_toggle_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../core/ui/app_surface.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import '../../helpers/date_helper.dart';
import '../../models/expense.dart';
import '../../newcomponents/custom_dialog_box.dart';
import '../../models/master_data.dart';
import '../../providers/auth_model.dart';
import '../../providers/app_settings_provider.dart';
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
  const ExpenseListScreen({super.key});
  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _reference = TextEditingController();
  final _referenceKey = GlobalKey<TextFilterFieldState>();
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
    _reference.dispose();
    _tableController.dispose();
    super.dispose();
  }

  void _reset() {
    _referenceKey.currentState?.cancelPendingSearch();
    _reference.clear();
    context.read<ExpenseProvider>().resetFilters();
  }

  Widget _dropdown(String label, IconData icon, String selected,
      Iterable<String> values, ValueChanged<String> onChanged,
      {bool searchable = false}) {
    final options = <String>{
      'All',
      ...values.where((v) => v.trim().isNotEmpty),
      selected
    }.toList();
    String display(String value) => value == 'All' ? 'common.all'.tr : value;
    if (searchable) {
      return DropdownSearch<String>(
        selectedItem: selected,
        items: (_, __) => options,
        itemAsString: display,
        decoratorProps: DropDownDecoratorProps(
            decoration: listFilterDecoration(label, icon)),
        popupProps: const PopupProps.menu(showSearchBox: true),
        onChanged: (value) => onChanged(value ?? 'All'),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$selected'),
      initialValue: selected,
      isExpanded: true,
      decoration: listFilterDecoration(label, icon),
      items: [
        for (final value in options)
          DropdownMenuItem(
              value: value,
              child: Text(display(value), overflow: TextOverflow.ellipsis))
      ],
      onChanged: (value) => onChanged(value ?? 'All'),
    );
  }

  Widget _filters(ExpenseProvider provider) => FilterPanel(
        key: const ValueKey('expense-desktop-filters'),
        title: 'expense.find'.tr,
        hint: 'expense.filter_hint'.tr,
        onReset: _reset,
        fields: [
          _dropdown(
              'expense.category'.tr,
              Icons.category_outlined,
              provider.filterCategory,
              provider.categoryOptions.map((v) => v['name']?.toString() ?? ''),
              provider.setCategory,
              searchable: true),
          TextFilterField(
              key: _referenceKey,
              controller: _reference,
              label: 'expense.hint_reference_no'.tr,
              icon: Icons.tag,
              onSearch: () => provider.setReference(_reference.text)),
          _dropdown(
              'expense.filter_debit_account'.tr,
              Icons.account_balance_outlined,
              provider.filterDebitAccount,
              provider.debitAccountOptions
                  .map((v) => v['name']?.toString() ?? ''),
              provider.setDebitAccount,
              searchable: true),
          _dropdown(
              'expense.status'.tr,
              Icons.check_circle_outline,
              provider.filterStatus,
              provider.availableStatuses,
              provider.setStatus),
        ],
      );

  Future<File> _export() {
    final provider = context.read<ExpenseProvider>();
    if (provider.isLoading || provider.loadError != null) {
      throw StateError('Expense data is unavailable.');
    }
    _referenceKey.currentState?.cancelPendingSearch();
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

  Widget _referenceCell(Expense expense) => Row(children: [
        Expanded(child: TableCells.text(expense.referenceNumber)),
        IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16),
            tooltip: 'expense.copied_to_clipboard'.tr,
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: expense.referenceNumber));
              if (!mounted) return;
              showScaffold(
                  context: context, message: 'expense.copied_to_clipboard'.tr);
            }),
      ]);

  Widget _card(Expense expense, int index, String currency) => AppSurface(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _referenceCell(expense),
          const SizedBox(height: 8),
          Text(
              '${'expense.col_payment_date'.tr}: ${DateHelper.formatDate(expense.paymentDate)}'),
          Text('${'expense.category'.tr}: ${expense.category}'),
          Text('${'expense.col_debit_ac'.tr}: ${expense.debitAccount}'),
          Text('${'expense.col_credit_ac'.tr}: ${expense.creditAccount}'),
          Text(
              '${'expense.amount'.tr}: $currency ${expense.amount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExpenseListStatusPill(status: expense.status)),
          const SizedBox(height: 8),
          TableCells.viewButton(() => _view(expense)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final currency = context.select<AppSettingsProvider, String>(
        (p) => p.appSettings?.currency ?? '');
    return LayoutBuilder(
        builder: (context, constraints) => ListPageScaffold<Expense>(
              header: ListPageHeader(
                  icon: Icons.payments_outlined,
                  title: 'expense.title'.tr,
                  subtitle: 'expense.subtitle'.tr,
                  onRefresh: provider.isLoading ? null : _refresh,
                  onAdd: () => Get.find<SideBarController>().index.value = 94,
                  addLabel: 'expense.new_entry'.tr,
                  addShortLabel: 'expense.btn_create'.tr,
                  extraActions: [
                    FilterToggleButton(
                        showFilters: _showFilters,
                        hasActiveFilters: provider.filterCategory != 'All' ||
                            provider.filterDebitAccount != 'All' ||
                            provider.filterStatus != 'All' ||
                            _reference.text.trim().isNotEmpty,
                        activeFiltersListenable: _reference,
                        activeFiltersBuilder: () =>
                            provider.filterCategory != 'All' ||
                            provider.filterDebitAccount != 'All' ||
                            provider.filterStatus != 'All' ||
                            _reference.text.trim().isNotEmpty,
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters)),
                    ExportShareButton(
                        createFile: _export,
                        enabled:
                            !provider.isLoading && provider.loadError == null,
                        compact:
                            constraints.maxWidth < ListLayoutBreakpoints.header,
                        label: 'supplier_transactions.export'.tr,
                        loadingLabel:
                            'supplier_transactions.export_creating'.tr,
                        tooltip: 'expense.export_tooltip'.tr,
                        errorMessage: 'expense.export_error'.tr,
                        mimeType:
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                  ]),
              filters: _filters(provider),
              showFilters: _showFilters,
              toolbar: provider.loadError == null
                  ? null
                  : AppSurface(
                      child: Row(children: [
                      Expanded(child: Text('expense.load_error'.tr)),
                      TextButton(
                          onPressed: provider.isLoading ? null : _refresh,
                          child: Text('expense.retry'.tr)),
                    ])),
              isLoading: provider.isLoading,
              items: provider.expenses,
              tableMinWidth: 1150,
              tableScrollController: _tableController,
              columns: [
                TableColumnDef(
                    label: 'expense.col_reference_number'.tr,
                    flex: 1.5,
                    cellBuilder: (e, _) => _referenceCell(e)),
                TableColumnDef(
                    label: 'expense.col_payment_date'.tr,
                    cellBuilder: (e, _) =>
                        TableCells.text(DateHelper.formatDate(e.paymentDate))),
                TableColumnDef(
                    label: 'expense.category'.tr,
                    flex: 1.4,
                    cellBuilder: (e, _) => TableCells.text(e.category)),
                TableColumnDef(
                    label: 'expense.col_debit_ac'.tr,
                    flex: 1.4,
                    cellBuilder: (e, _) => TableCells.text(e.debitAccount)),
                TableColumnDef(
                    label: 'expense.col_credit_ac'.tr,
                    flex: 1.4,
                    cellBuilder: (e, _) => TableCells.text(e.creditAccount)),
                TableColumnDef(
                    label: 'expense.amount'.tr,
                    flex: 1.1,
                    cellBuilder: (e, _) => TableCells.text(
                        '$currency ${e.amount.toStringAsFixed(2)}')),
                TableColumnDef(
                    label: 'expense.status'.tr,
                    cellBuilder: (e, _) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ExpenseListStatusPill(status: e.status))),
                TableColumnDef(
                    label: 'expense.breadcrumb_view'.tr,
                    cellBuilder: (e, _) =>
                        TableCells.viewButton(() => _view(e))),
              ],
              cardBuilder: (e, i) => _card(e, i, currency),
              emptyState: Center(child: Text('expense.no_expenses_found'.tr)),
              onRefresh: _refresh,
              currentPage: provider.currentPage,
              totalPages: provider.totalPages,
              itemsPerPage: provider.itemsPerPage,
              countLabel: 'expense.page_count'
                  .trParams({'count': '${provider.expenses.length}'}),
              onPageChanged: provider.setPage,
            ));
  }
}

class ExpenseViewController extends GetxController {
  var selectedRef = ''.obs;
}
