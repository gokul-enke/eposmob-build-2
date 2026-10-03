import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/vouchers/domain/models/supplier_voucher.dart';

import 'package:pos_machine/features/vouchers/presentation/state/supplier_voucher_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/screens/transactions/widgets/share_helper.dart';
import 'package:pos_machine/screens/transactions/widgets/supplier_voucher_print.dart';
import 'package:provider/provider.dart';

/// Supplier vouchers list on the shared [ListPageScaffold]. All vouchers are
/// loaded once; filters and pagination run locally in
/// [SupplierVoucherProvider].
import '../export/supplier_voucher_excel.dart';
import '../navigation/voucher_navigation.dart';
import '../state/voucher_list_controller.dart';
import '../widgets/details/supplier_voucher_details.dart';
import '../widgets/list/supplier_voucher_filters.dart';
import '../widgets/list/supplier_voucher_rows.dart';

class SupplierVoucherListPage extends StatefulWidget {
  const SupplierVoucherListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filterToggleKey = ValueKey('supplier-voucher-filter-toggle');
  static const exportKey = ValueKey('supplier-voucher-export');
  static const refreshKey = ValueKey('supplier-voucher-refresh');
  static const filtersKey = ValueKey('supplier-voucher-desktop-filters');

  @override
  State<SupplierVoucherListPage> createState() =>
      _SupplierVoucherListPageState();
}

class _SupplierVoucherListPageState extends State<SupplierVoucherListPage> {
  late final SupplierVoucherProvider _provider;
  late final AuthModel _auth;
  late final AppSettingsProvider _settings;
  late final VoucherListController _list;
  bool get _hasActiveFilters => _list.hasActiveFilters;
  @override
  void initState() {
    super.initState();
    _provider = context.read<SupplierVoucherProvider>();
    _auth = context.read<AuthModel>();
    _settings = context.read<AppSettingsProvider>();
    _list =
        VoucherListController(search: searchVouchers, export: widget.export);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_list.visibilityInitialized) {
      // Filters start open on wide screens and closed on phones.
      _list.showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _list.visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  void searchVouchers({int page = 1}) => _provider.applyFilters(
        supplierId: _list.selectedSupplierId,
        voucherNumber: _list.voucherNumberController.text,
        type: _list.selectedType,
        status: _list.selectedStatus,
        page: page,
      );

  void resetSearch() {
    _list.debouncer.cancel();
    _list.update(() {
      _list.voucherNumberController.clear();
      _list.selectedSupplierId = null;
      _list.selectedType = null;
      _list.selectedStatus = null;
    });
    _provider.resetFilters();
  }

  Future<void> refreshData() async {
    final token = _auth.token;
    if (token == null || token.isEmpty) {
      AppToast.error(context, 'supplier_voucher.auth_token_missing'.tr);
      return;
    }
    try {
      await _provider.listAllSupplierVouchers(accessToken: token);
      if (!mounted) return;
      final error = _provider.loadError;
      if (error != null) throw error;
      final suppliers = _provider.allVouchers ?? [];
      if (_list.selectedSupplierId != null &&
          !suppliers.any((v) => v.supplier.id == _list.selectedSupplierId)) {
        _list.update(() => _list.selectedSupplierId = null);
      }
      // Keep the controls and the refreshed rows using the same filters.
      searchVouchers();
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
          context,
          'supplier_voucher.error_loading_vouchers'
              .trParams({'error': '$error'}));
    }
  }

  Future<File> _createExport() {
    // Cancel the timer, then apply pending edits without changing the page.
    _list.debouncer.cancel();
    searchVouchers(page: _provider.currentPage);
    final items = List<SupplierVoucher>.of(_provider.filteredVouchers);
    final currency = _settings.appSettings?.currency ?? 'INR';
    _list.export.setStage('supplier_voucher.export_creating'.tr);
    return exportSupplierVouchers(items, currency);
  }

  Future<void> _runExport() async {
    final exported = await _list.export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'supplier_voucher.export_failed'.tr);
    }
  }

  void _openCreateVoucher() {
    VoucherNavigation.openSupplierCreate();
  }

  /// Filters, Export, Refresh — left to right, before Create.
  List<HeaderAction> _headerActions(SupplierVoucherProvider provider) => [
        HeaderAction(
          key: SupplierVoucherListPage.filterToggleKey,
          icon: _list.showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _list.showFilters
              ? 'supplier_voucher.hide_filters'.tr
              : 'supplier_voucher.show_filters'.tr,
          onPressed: () =>
              _list.update(() => _list.showFilters = !_list.showFilters),
          active: _list.showFilters,
          badge: !_list.showFilters && _hasActiveFilters,
        ),
        HeaderAction(
          key: SupplierVoucherListPage.exportKey,
          icon: Icons.ios_share_rounded,
          label: _list.export.busy
              ? (_list.export.stage ?? 'supplier_voucher.export_creating'.tr)
              : 'supplier_transactions.export'.tr,
          onPressed: !provider.isLoading && provider.filteredVouchers.isNotEmpty
              ? _runExport
              : null,
          busy: _list.export.busy,
        ),
        HeaderAction(
          key: SupplierVoucherListPage.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: refreshData,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierVoucherProvider>();
    final rows = _rows();
    final vouchers = provider.voucherListDetails ?? const <SupplierVoucher>[];
    return ListenableBuilder(
      listenable: Listenable.merge([_list, _list.export]),
      builder: (context, _) => ListPageScaffold<SupplierVoucher>(
        header: PageHeader(
          icon: Icons.receipt_long_outlined,
          title: 'supplier_voucher.mobile_header_title'.tr,
          subtitle: 'supplier_voucher.subtitle'.tr,
          actions: _headerActions(provider),
          onAdd: _openCreateVoucher,
          addLabel: 'supplier_voucher.create_voucher_button'.tr,
          addShortLabel: 'supplier_voucher.mobile_create_button'.tr,
        ),
        filters: _filters(provider),
        showFilters: _list.showFilters,
        isLoading: provider.isLoading,
        items: vouchers,
        minTableWidth: 1280,
        columns: rows.columns(),
        cardBuilder: rows.card,
        emptyState: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'supplier_voucher.no_vouchers_found'.tr,
          subtitle: 'supplier_voucher.try_adjusting_filters'.tr,
        ),
        onRefresh: refreshData,
        pagination: ListPagination(
          currentPage: provider.currentPage,
          totalPages: provider.totalPages,
          itemsPerPage: provider.itemsPerPage,
          onPageChanged: provider.goToPage,
          countLabel: 'supplier_voucher.page_count'
              .trParams({'count': '${vouchers.length}'}),
        ),
      ),
    );
  }

  String get _currency => _settings.appSettings?.currency ?? 'INR';
  SupplierVoucherRows _rows() => SupplierVoucherRows(
      currency: _currency,
      onView: (v) => SupplierVoucherDetails(context, _currency).show(v),
      onPrint: (v) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SupplierVoucherPrintPage(
                  voucher: v, returnToPreviousRoute: true))),
      onCopy: (v) {
        Clipboard.setData(ClipboardData(text: v.voucherNumber));
        AppToast.success(context, 'supplier_voucher.voucher_number_copied'.tr);
      },
      onMore: (v) => ShareHelper.showShareSupplierVoucherSheet(
          context: context, voucher: v));
  FilterPanel _filters(SupplierVoucherProvider provider) =>
      SupplierVoucherFilters(
          voucherNumberController: _list.voucherNumberController,
          selectedType: _list.selectedType,
          selectedStatus: _list.selectedStatus,
          typeOptions: provider.getTypeOptions(),
          statusOptions: provider.getStatusOptions(),
          onSearch: _list.debouncer.schedule,
          onSubmit: _list.debouncer.flush,
          onReset: resetSearch,
          onType: (v) {
            _list.update(() => _list.selectedType = v);
            searchVouchers();
          },
          onStatus: (v) {
            _list.update(() => _list.selectedStatus = v);
            searchVouchers();
          },
          selectedSupplierId: _list.selectedSupplierId,
          suppliers: {
            for (final v in provider.allVouchers ?? <SupplierVoucher>[])
              v.supplier.id: v.supplier.name
          },
          onSupplier: (id) {
            _list.update(() => _list.selectedSupplierId = id);
            searchVouchers();
          }).build();
}
