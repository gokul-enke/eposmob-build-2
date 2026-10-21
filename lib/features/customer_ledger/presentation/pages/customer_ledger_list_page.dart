import '../../data/customer_ledger_repository.dart';
import '../state/customer_ledger_list_controller.dart';
import '../widgets/customer_ledger_filters.dart';
import '../widgets/customer_ledger_rows.dart';
import '../export/customer_ledger_excel.dart';
import '../state/customer_ledger_details_action.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

class CustomerLedgerListPage extends StatefulWidget {
  const CustomerLedgerListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const desktopFiltersKey =
      ValueKey('customer-transactions-desktop-filters');
  static const mobileFiltersKey =
      ValueKey('customer-transactions-mobile-filters');
  static const filterToggleKey =
      ValueKey('customer-transactions-filter-toggle');
  static const exportKey = ValueKey('customer-transactions-export');
  static const refreshKey = ValueKey('customer-transactions-refresh');
  static const dateFieldKey = ValueKey('customer-transactions-date');

  @override
  State<CustomerLedgerListPage> createState() => _CustomerLedgerListPageState();
}

class _CustomerLedgerListPageState extends State<CustomerLedgerListPage>
    with CustomerLedgerRowActions<CustomerLedgerListPage> {
  late final CustomerLedgerListController controller;
  late final ExportController _exporter = widget.export ?? ExportController();
  final _table = ScrollController();
  bool _showFilters = true;
  @override
  void initState() {
    super.initState();
    controller = CustomerLedgerListController(
        CustomerLedgerRepository(context.read<InvoiceProvider>()),
        readToken: () => context.read<AuthModel>().token ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.fetch();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    if (widget.export == null) _exporter.dispose();
    _table.dispose();
    super.dispose();
  }

  Future<void> _runExport() async {
    final exported = await _exporter.run(context, createFile: _export);
    if (!exported && mounted) {
      AppToast.error(context, 'party_accounts.export_error'.tr);
    }
  }

  Future<File> _export() async {
    final master = context.read<MasterDataProvider>();
    // Materialize payment labels before handing rows to the workbook encoder.
    final paymentLabels = <String, String>{};
    String payment(ListTransaction r) => paymentLabels.putIfAbsent(
        r.paymentMethod ?? '',
        () =>
            master.getPaymentMethodValue(
                int.tryParse(r.paymentMethod ?? '') ?? -1) ??
            r.paymentMethod ??
            '');
    final rows = await controller.exportRows(onProgress: (p, last) {
      if (mounted) {
        _exporter.setStage('party_accounts.export_fetching'
            .trParams({'page': '$p', 'total': '$last'}));
      }
    });
    for (final row in rows) {
      payment(row);
    }
    _exporter.setStage('supplier_transactions.export_creating'.tr);
    return exportCustomerLedgerExcel(rows, paymentLabels);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: controller.date ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100));
    if (!mounted || picked == null) return;
    controller.selectDate(picked);
  }

  FilterPanel _filtersPanel(bool mobile) => CustomerLedgerFilters(controller,
          onPickDate: _pickDate,
          dateFieldKey: CustomerLedgerListPage.dateFieldKey,
          mobileKey: CustomerLedgerListPage.mobileFiltersKey,
          desktopKey: CustomerLedgerListPage.desktopFiltersKey)
      .build(mobile);
  CustomerLedgerRows get _listRows => CustomerLedgerRows(
      onView: showCustomerLedgerDetails,
      onCopy: (text) async {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) AppToast.success(context, 'party_accounts.ref_copied'.tr);
      });
  bool get _hasActiveFilters =>
      controller.amount.text.trim().isNotEmpty ||
      controller.name.text.trim().isNotEmpty ||
      controller.reference.text.trim().isNotEmpty ||
      controller.date != null ||
      controller.type != 'All';

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> get _headerActions => [
        HeaderAction(
          key: CustomerLedgerListPage.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters
              ? 'party_accounts.hide_filters'.tr
              : 'party_accounts.filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: _hasActiveFilters,
        ),
        HeaderAction(
          key: CustomerLedgerListPage.exportKey,
          icon: Icons.ios_share_rounded,
          label: _exporter.busy
              ? (_exporter.stage ?? 'supplier_transactions.export_creating'.tr)
              : 'party_accounts.export_tooltip'.tr,
          onPressed: !controller.loading &&
                  controller.error == null &&
                  controller.hasLoaded
              ? _runExport
              : null,
          busy: _exporter.busy,
        ),
        HeaderAction(
          key: CustomerLedgerListPage.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: controller.refresh,
        ),
      ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, size) => ListenableBuilder(
            // Rebuilds the filter badge while typing and the export progress.
            listenable: Listenable.merge([
              controller,
              _exporter,
              controller.amount,
              controller.name,
              controller.reference
            ]),
            builder: (context, _) => ListPageScaffold<ListTransaction>(
              header: PageHeader(
                icon: Icons.swap_horiz,
                title: 'party_accounts.title'.tr,
                subtitle: 'party_accounts.subtitle'.tr,
                actions: _headerActions,
              ),
              filters: _filtersPanel(
                  size.maxWidth < ListLayoutBreakpoints.mobileBelow),
              showFilters: _showFilters,
              toolbar: controller.error == null
                  ? null
                  : Row(children: [
                      Expanded(
                          child: Text(controller.error!,
                              style: const TextStyle(color: AppColors.red))),
                      TextButton(
                          onPressed: controller.refresh,
                          child: Text('party_accounts.retry'.tr))
                    ]),
              tableScrollController: _table,
              minTableWidth: 1080,
              isLoading: controller.loading,
              items: controller.rows,
              columns: _listRows.columns,
              cardBuilder: _listRows.card,
              emptyState: AppEmptyState(
                icon: Icons.swap_horiz,
                title: 'party_accounts.no_transactions'.tr,
                subtitle: 'party_accounts.no_transactions_hint'.tr,
              ),
              onRefresh: controller.refresh,
              pagination: ListPagination(
                currentPage: controller.currentPage,
                totalPages: controller.totalPages,
                itemsPerPage: 20,
                countLabel: 'party_accounts.page_count'
                    .trParams({'count': '${controller.rows.length}'}),
                onPageChanged: controller.goToPage,
              ),
            ),
          ));
}
