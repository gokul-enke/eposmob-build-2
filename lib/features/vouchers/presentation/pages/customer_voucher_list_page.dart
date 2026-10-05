import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/vouchers/domain/models/customer_voucher.dart';
import 'package:pos_machine/features/vouchers/presentation/state/customer_voucher_provider.dart';

import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/screens/transactions/widgets/customer_voucher_print.dart';
import 'package:provider/provider.dart';

import '../actions/customer_voucher_actions.dart';
import '../export/customer_voucher_excel.dart';
import '../navigation/voucher_navigation.dart';
import '../state/voucher_list_controller.dart';
import '../widgets/details/customer_voucher_details.dart';
import '../widgets/list/customer_voucher_filters.dart';
import '../widgets/list/customer_voucher_rows.dart';

class CustomerVoucherListPage extends StatefulWidget {
  const CustomerVoucherListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('customer-voucher-desktop-filters');
  static const filterToggleKey = ValueKey('customer-voucher-filter-toggle');
  static const exportKey = ValueKey('customer-voucher-export');
  static const refreshKey = ValueKey('customer-voucher-refresh');

  @override
  State<CustomerVoucherListPage> createState() =>
      _CustomerVoucherListPageState();
}

class _CustomerVoucherListPageState extends State<CustomerVoucherListPage> {
  late final CustomerVoucherProvider _provider;
  late final AuthModel _auth;
  late final AppSettingsProvider _settings;
  late final VoucherListController _list;

  @override
  void initState() {
    super.initState();
    _provider = context.read<CustomerVoucherProvider>();
    _auth = context.read<AuthModel>();
    _settings = context.read<AppSettingsProvider>();
    _list =
        VoucherListController(search: searchVouchers, export: widget.export);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadVouchers();
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

  Future<void> loadVouchers() async {
    if (_list.isInitialized) return;

    try {
      final String? accessToken = _auth.token;

      if (accessToken == null || accessToken.isEmpty) {
        AppToast.error(context, 'customer_voucher.auth_token_missing'.tr);
        return;
      }

      await _provider.listAllCustomerVouchers(accessToken: accessToken);
      if (!mounted) return;
      final error = _provider.loadError;
      if (error != null) throw error;
      _list.update(() {
        _list.isInitialized = true;
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
          context,
          'customer_voucher.error_loading_vouchers'
              .tr
              .replaceAll('@error', error.toString()));
    }
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? pickedDate = await showAutoDismissDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: ColorManager.kPrimaryColor,
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
            ),
            child: child!,
          );
        },
      );
      if (!mounted) return;
      final TimeOfDay resolvedTime = pickedTime ??
          (isFromDate
              ? const TimeOfDay(hour: 0, minute: 0)
              : const TimeOfDay(hour: 23, minute: 59));
      final DateTime fullDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        resolvedTime.hour,
        resolvedTime.minute,
      );
      final formattedDateTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
      _list.update(() {
        if (isFromDate) {
          _list.dateFromController.text = formattedDateTime;
        } else {
          _list.dateToController.text = formattedDateTime;
        }
      });
      searchVouchers();
    }
  }

  void searchVouchers() {
    debugPrint("Searching with filters");
    CustomerVoucherProvider provider = _provider;
    provider.applyFilters(
      customerName: _list.searchTextController.text,
      voucherNumber: _list.voucherNumberController.text,
      type: _list.selectedType,
      status: _list.selectedStatus,
      dateFrom: _list.dateFromController.text.isEmpty
          ? null
          : _list.dateFromController.text,
      dateTo: _list.dateToController.text.isEmpty
          ? null
          : _list.dateToController.text,
    );
  }

  void resetSearch() {
    _list.debouncer.cancel();
    _list.update(() {
      _list.searchTextController.clear();
      _list.voucherNumberController.clear();
      _list.dateFromController.clear();
      _list.dateToController.clear();
      _list.selectedType = null;
      _list.selectedStatus = null;
    });

    _provider.resetFilters();
  }

  Future<void> refreshData() async {
    _list.isInitialized = false;
    await loadVouchers();
  }

  bool get _hasActiveFilters => _list.hasActiveFilters;
  Future<void> _exportVouchers() async {
    final exported = await _list.export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'customer_voucher.export_failed'.tr);
    }
  }

  Future<File> _createExport() {
    _list.debouncer.cancel();
    final provider = _provider;
    if (provider.isLoading || provider.loadError != null) {
      throw StateError('Refresh vouchers before exporting.');
    }
    // Apply pending edits to the visible list and provider filters as well.
    // Name/number/type/status are local filters, so this makes no extra request.
    provider.applyFilters(
      customerName: _list.searchTextController.text,
      voucherNumber: _list.voucherNumberController.text,
      type: _list.selectedType,
      status: _list.selectedStatus,
      dateFrom: _list.dateFromController.text.isEmpty
          ? null
          : _list.dateFromController.text,
      dateTo: _list.dateToController.text.isEmpty
          ? null
          : _list.dateToController.text,
      page: provider.currentPage,
    );
    final items = provider.filterForExport(
        customerName: _list.searchTextController.text,
        voucherNumber: _list.voucherNumberController.text,
        type: _list.selectedType,
        status: _list.selectedStatus);
    final currency = _settings.appSettings?.currency ?? 'INR';
    return exportCustomerVouchers(items, currency);
  }

  /// Filters, Export, Refresh — left to right, before Add.
  List<HeaderAction> _headerActions(CustomerVoucherProvider provider) {
    final canExport = !provider.isLoading &&
        provider.loadError == null &&
        (provider.allVouchers?.isNotEmpty ?? false);
    return [
      HeaderAction(
        key: CustomerVoucherListPage.filterToggleKey,
        icon: _list.showFilters
            ? Icons.filter_alt_rounded
            : Icons.filter_alt_outlined,
        label: _list.showFilters
            ? 'customer_voucher.hide_filters'.tr
            : 'customer_voucher.show_filters'.tr,
        onPressed: () =>
            _list.update(() => _list.showFilters = !_list.showFilters),
        active: _list.showFilters,
        badge: _hasActiveFilters,
      ),
      HeaderAction(
        key: CustomerVoucherListPage.exportKey,
        icon: Icons.ios_share_rounded,
        label: _list.export.busy
            ? (_list.export.stage ?? 'customer_voucher.export_creating'.tr)
            : 'customer_voucher.export_tooltip'.tr,
        onPressed: canExport ? _exportVouchers : null,
        busy: _list.export.busy,
      ),
      HeaderAction(
        key: CustomerVoucherListPage.refreshKey,
        icon: Icons.refresh_rounded,
        label: 'list.refresh'.tr,
        onPressed: refreshData,
      ),
    ];
  }

  Widget _staleRowsWarning(CustomerVoucherProvider provider) => AppSurface(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('customer_voucher.stale_rows_warning'.tr,
                style: const TextStyle(color: AppColors.red)),
            TextButton.icon(
                onPressed: provider.isLoading ? null : refreshData,
                icon: const Icon(Icons.refresh),
                label: Text('customer_voucher.retry_loading'.tr)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerVoucherProvider>();
    final rows = _rows();
    final vouchers = provider.voucherListDetails ?? const <CustomerVoucher>[];
    return ListenableBuilder(
      // Rebuilds the filter badge while typing and the export progress.
      listenable: Listenable.merge([
        _list,
        _list.export,
        _list.searchTextController,
        _list.voucherNumberController,
        _list.dateFromController,
        _list.dateToController,
      ]),
      builder: (context, _) => ListPageScaffold<CustomerVoucher>(
        header: PageHeader(
          icon: Icons.receipt_long_outlined,
          title: 'customer_voucher.mobile_header_title'.tr,
          subtitle: 'customer_voucher.subtitle'.tr,
          actions: _headerActions(provider),
          onAdd: () {
            VoucherNavigation.openCustomerCreate();
          },
          addLabel: 'customer_voucher.create_voucher_button'.tr,
          addShortLabel: 'customer_voucher.mobile_create_button'.tr,
        ),
        toolbar:
            provider.loadError == null ? null : _staleRowsWarning(provider),
        filters: _filters(provider),
        showFilters: _list.showFilters,
        isLoading: provider.isLoading,
        items: vouchers,
        minTableWidth: 1440,
        tableScrollController: _list.tableScroll,
        columns: rows.columns,
        cardBuilder: rows.card,
        emptyState: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'customer_voucher.no_vouchers_found'.tr,
          subtitle: 'customer_voucher.try_adjusting_filters'.tr,
        ),
        onRefresh: refreshData,
        pagination: ListPagination(
          currentPage: provider.currentPage,
          totalPages: provider.totalPages,
          itemsPerPage: provider.itemsPerPage,
          onPageChanged: provider.goToPage,
          countLabel: 'customer_voucher.page_count'
              .trParams({'count': '${vouchers.length}'}),
        ),
      ),
    );
  }

  String get _currency => _settings.appSettings?.currency ?? 'INR';
  CustomerVoucherRows _rows() => CustomerVoucherRows(
      currency: _currency,
      onView: (v) => CustomerVoucherDetails(context, _currency).show(v),
      onPrint: (v) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CustomerVoucherPrintPage(
                  voucher: v, returnToPreviousRoute: true))),
      onCopy: (v) {
        Clipboard.setData(ClipboardData(text: v.voucherNumber));
        AppToast.success(context, 'customer_voucher.voucher_number_copied'.tr);
      },
      onMore: (v) => CustomerVoucherActions(
              context: context,
              token: () => _auth.token,
              phase2Enabled: () =>
                  _settings.appSettings?.zatcaPhase2Enabled ?? false,
              printVoucher: (id, token) =>
                  _provider.zatcaPhase2VoucherPrint(id: id, accessToken: token))
          .show(v));
  FilterPanel _filters(CustomerVoucherProvider provider) =>
      CustomerVoucherFilters(
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
          searchTextController: _list.searchTextController,
          dateFromController: _list.dateFromController,
          dateToController: _list.dateToController,
          onDate: (from) => _selectDate(context, isFromDate: from)).build();
}
