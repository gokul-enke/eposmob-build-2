import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:provider/provider.dart';

import '../../domain/customer_report.dart';
import '../export/customer_transactions_report_export.dart';
import '../navigation/report_navigation.dart';
import '../state/customer_transactions_report_controller.dart';
import '../state/report_load_error.dart';
import '../widgets/customer_report/customer_report_table.dart';
import '../widgets/report_error_bar.dart';

/// Customer Transactions Report: each customer's debits, credits and
/// balance for a customer and date/time range, with an all-pages Excel
/// export. Built on the shared [ListPageScaffold].
class CustomerTransactionsReportPage extends StatefulWidget {
  const CustomerTransactionsReportPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filterToggleKey =
      ValueKey('customer-transactions-report-filter-toggle');
  static const exportKey = ValueKey('customer-transactions-report-export');
  static const refreshKey = ValueKey('customer-transactions-report-refresh');
  static const filtersKey = ValueKey('customer-transactions-report-filters');
  static const fromKey = ValueKey('customer-report-from');
  static const toKey = ValueKey('customer-report-to');

  @override
  State<CustomerTransactionsReportPage> createState() =>
      _CustomerTransactionsReportPageState();
}

class _CustomerTransactionsReportPageState
    extends State<CustomerTransactionsReportPage> {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  late final CustomerTransactionsReportController _report;
  late final ExportController _export = widget.export ?? ExportController();
  late final CustomerProvider _customers;
  late final AuthModel _auth;
  bool _showFilters = true;
  bool _visibilityInitialized = false;

  String _tr(String key) => 'customer_transaction_report.$key'.tr;

  @override
  void initState() {
    super.initState();
    // Read once: the controller's fetch can finish after this page unmounts.
    _auth = context.read<AuthModel>();
    _customers = context.read<CustomerProvider>();
    final invoices = context.read<InvoiceProvider>();
    // The customer filter is the report's own: it never starts from, or
    // changes, the customer selected in profiles or the details screen.
    _report = CustomerTransactionsReportController(
      fetch: (query, page) => invoices.listAllTransaction(
        accessToken: _auth.token ?? '',
        customerId: query.customerId,
        dateFrom: query.range.apiFrom,
        dateTo: query.range.apiTo,
        page: page,
        // The report keeps its own rows; don't replace the shared list.
        updateState: false,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _report.load();
      _loadCustomers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      // Filters start open on wide screens and closed on phones.
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _report.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      await _customers.fetchCustomers(
          accessToken: _auth.token ?? '', listAll: true);
    } catch (_) {
      if (mounted) AppToast.error(context, _tr('customer_load_error'));
    }
  }

  Future<void> _refresh() =>
      Future.wait([_report.load(), _loadCustomers()]).then((_) {});

  void _selectCustomer(CustomerListModelData? customer) =>
      _report.setCustomer(customer?.id?.toString());

  void _reset() => _report.reset();

  /// Opens the customer's transactions. Selects by ID, so customers with
  /// the same name stay apart.
  void _view(CustomerReportRow row) {
    final name = CustomerTransactionsReportExport.customerName(row);
    _customers.setSelectedCustomerId(row.id);
    _customers.setSelectedCustomerName(name);
    context.read<TransactionProvider>().setCustomerName(name);
    ReportNavigation.openCustomerTransactionDetails();
  }

  Future<File> _createExport() async {
    final rows = await _report.exportRows(progress: (page, total) {
      if (mounted) {
        _export.setStage(_tr('export_fetching')
            .replaceAll('@page', '$page')
            .replaceAll('@total', '$total'));
      }
    });
    return CustomerTransactionsReportExport.build(rows);
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context,
        createFile: _createExport, shareText: _tr('title'));
    if (!exported && mounted) AppToast.error(context, _tr('export_error'));
  }

  String _customerLabel(CustomerListModelData customer) =>
      customer.name?.trim().isNotEmpty == true
          ? customer.name!
          : _tr('unknown_customer');

  Widget _customerPicker(List<CustomerListModelData> customers) {
    CustomerListModelData? selected;
    for (final customer in customers) {
      if (customer.id?.toString() == _report.customerId) selected = customer;
    }
    return DropdownSearch<CustomerListModelData>(
      key: ValueKey(_report.customerId),
      items: (_, __) => customers,
      selectedItem: selected,
      compareFn: (a, b) => a.id == b.id,
      itemAsString: _customerLabel,
      decoratorProps: DropDownDecoratorProps(
        decoration: AppInputDecoration.filter(
            label: _tr('customer'), icon: Icons.person_outline),
      ),
      dropdownBuilder: (_, customer) => Text(
        customer == null ? _tr('all_customers') : _customerLabel(customer),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.input,
      ),
      suffixProps: const DropdownSuffixProps(
          clearButtonProps: ClearButtonProps(isVisible: true)),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: AppInputDecoration.of(
              label: _tr('search_customer_hint'), icon: Icons.search),
        ),
      ),
      onChanged: _selectCustomer,
    );
  }

  FilterPanel _filters(List<CustomerListModelData> customers) => FilterPanel(
        key: CustomerTransactionsReportPage.filtersKey,
        title: _tr('find'),
        hint: _tr('filter_hint'),
        resetLabel: 'list.reset'.tr,
        onSearch: () {},
        onReset: _reset,
        fields: [
          CustomFilterField(child: _customerPicker(customers)),
          DateTimeFilterField(
            key: CustomerTransactionsReportPage.fromKey,
            label: _tr('from_date'),
            value: _report.range.from,
            format: _dateFormat.format,
            onChanged: _report.setFrom,
          ),
          DateTimeFilterField(
            key: CustomerTransactionsReportPage.toKey,
            label: _tr('to_date'),
            value: _report.range.to,
            format: _dateFormat.format,
            onChanged: _report.setTo,
          ),
        ],
      );

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> _headerActions() => [
        HeaderAction(
          key: CustomerTransactionsReportPage.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters ? 'list.hide_filters'.tr : 'list.filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: !_showFilters && _report.hasActiveFilters,
        ),
        HeaderAction(
          key: CustomerTransactionsReportPage.exportKey,
          icon: Icons.ios_share_rounded,
          label: _export.busy
              ? (_export.stage ?? 'list.exporting'.tr)
              : 'list.export'.tr,
          onPressed: _report.canExport && !_export.busy ? _runExport : null,
          busy: _export.busy,
        ),
        HeaderAction(
          key: CustomerTransactionsReportPage.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: _refresh,
        ),
      ];

  Widget? _errorBar() => switch (_report.error) {
        null => null,
        ReportLoadError.invertedRange => ReportErrorBar(
            message: _tr('from_date_after_to_date'),
            retryLabel: _tr('retry'),
            onRetry: _report.retry),
        ReportLoadError.failed => ReportErrorBar(
            message: _tr('load_error'),
            retryLabel: _tr('retry'),
            onRetry: _report.retry),
      };

  @override
  Widget build(BuildContext context) {
    final customers =
        context.select<CustomerProvider, List<CustomerListModelData>?>(
                (p) => p.allCustomers) ??
            const <CustomerListModelData>[];
    return ListenableBuilder(
      listenable: Listenable.merge([_report, _export]),
      builder: (context, _) => ListPageScaffold<CustomerReportRow>(
        minTableWidth: 1050,
        header: PageHeader(
          icon: Icons.people_alt_outlined,
          title: _tr('title'),
          subtitle: _tr('subtitle'),
          actions: _headerActions(),
        ),
        showFilters: _showFilters,
        filters: _filters(customers),
        toolbar: _errorBar(),
        isLoading: _report.loading,
        items: _report.rows,
        onRefresh: _refresh,
        onRowTap: _view,
        columns: customerReportColumns(onView: _view),
        cardBuilder: (row, _) =>
            CustomerReportCard(row: row, onView: () => _view(row)),
        emptyState: AppEmptyState(
          icon: Icons.people_outline_rounded,
          title: _tr('no_customer_transactions'),
          action: _report.hasActiveFilters
              ? AppOutlinedButton(
                  label: 'list.reset'.tr,
                  icon: Icons.restart_alt_rounded,
                  onPressed: _reset,
                )
              : null,
        ),
        pagination: ListPagination(
          currentPage: _report.page,
          totalPages: _report.pages,
          itemsPerPage: _report.perPage,
          onPageChanged: (page) {
            if (!_report.loading) _report.load(page);
          },
          countLabel:
              _tr('count').replaceAll('@count', '${_report.rows.length}'),
        ),
      ),
    );
  }
}
