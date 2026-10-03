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
import '../../helpers/ui_code_labels.dart';
import '../../models/supplier_voucher.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_model.dart';
import '../../providers/supplier_voucher_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../services/list_excel_export_service.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';
import 'widgets/supplier_voucher_print.dart';

/// Supplier vouchers list on the shared [ListPageScaffold]. All vouchers are
/// loaded once; filters and pagination run locally in
/// [SupplierVoucherProvider].
class SupplierVoucherListScreen extends StatefulWidget {
  const SupplierVoucherListScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filterToggleKey = ValueKey('supplier-voucher-filter-toggle');
  static const exportKey = ValueKey('supplier-voucher-export');
  static const refreshKey = ValueKey('supplier-voucher-refresh');
  static const filtersKey = ValueKey('supplier-voucher-desktop-filters');

  @override
  State<SupplierVoucherListScreen> createState() =>
      _SupplierVoucherListScreenState();
}

class _SupplierVoucherListScreenState extends State<SupplierVoucherListScreen> {
  final voucherNumberController = TextEditingController();
  late final SearchDebouncer _search = SearchDebouncer(searchVouchers);
  late final ExportController _export = widget.export ?? ExportController();
  String? selectedType, selectedStatus;
  int? selectedSupplierId;
  bool _showFilters = true;
  bool _visibilityInitialized = false;

  bool get _hasActiveFilters =>
      selectedSupplierId != null ||
      selectedType != null ||
      selectedStatus != null ||
      voucherNumberController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshData();
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
    _search.dispose();
    _export.dispose();
    voucherNumberController.dispose();
    super.dispose();
  }

  void searchVouchers({int page = 1}) =>
      context.read<SupplierVoucherProvider>().applyFilters(
            supplierId: selectedSupplierId,
            voucherNumber: voucherNumberController.text,
            type: selectedType,
            status: selectedStatus,
            page: page,
          );

  void resetSearch() {
    _search.cancel();
    setState(() {
      voucherNumberController.clear();
      selectedSupplierId = null;
      selectedType = null;
      selectedStatus = null;
    });
    context.read<SupplierVoucherProvider>().resetFilters();
  }

  Future<void> refreshData() async {
    final token = context.read<AuthModel>().token;
    if (token == null || token.isEmpty) {
      AppToast.error(context, 'supplier_voucher.auth_token_missing'.tr);
      return;
    }
    try {
      await context
          .read<SupplierVoucherProvider>()
          .listAllSupplierVouchers(accessToken: token);
      if (!mounted) return;
      final error = context.read<SupplierVoucherProvider>().loadError;
      if (error != null) throw error;
      final suppliers =
          context.read<SupplierVoucherProvider>().allVouchers ?? [];
      if (selectedSupplierId != null &&
          !suppliers.any((v) => v.supplier.id == selectedSupplierId)) {
        setState(() => selectedSupplierId = null);
      }
      // Keep the controls and the refreshed rows using the same filters.
      searchVouchers();
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, 'supplier_voucher.error_loading_vouchers'
          .trParams({'error': '$error'}));
    }
  }

  Future<File> _createExport() {
    // Cancel the timer, then apply pending edits without changing the page.
    _search.cancel();
    searchVouchers(page: context.read<SupplierVoucherProvider>().currentPage);
    final items = List<SupplierVoucher>.of(
        context.read<SupplierVoucherProvider>().filteredVouchers);
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    _export.setStage('supplier_voucher.export_creating'.tr);
    return ListExcelExportService.export<SupplierVoucher>(
      items: items,
      fileNamePrefix: 'supplier-vouchers',
      sheetName: 'supplier_voucher.mobile_header_title'.tr,
      columns: [
        ListExportColumn(
            label: 'supplier_voucher.col_voucher_number'.tr,
            value: (v, _) => v.voucherNumber),
        ListExportColumn(
            label: 'supplier_voucher.col_supplier_name'.tr,
            value: (v, _) => v.supplier.name),
        ListExportColumn(
            label: 'supplier_voucher.col_type'.tr,
            value: (v, _) => UiCodeLabels.voucherType(v.type)),
        ListExportColumn(
            label: 'supplier_voucher.col_voucher_date'.tr,
            value: (v, _) => v.voucherDate),
        ListExportColumn(
            label: 'supplier_voucher.col_due_date'.tr,
            value: (v, _) => v.dueDate),
        ListExportColumn(
            label: 'supplier_voucher.col_payment_method'.tr,
            value: (v, _) => UiCodeLabels.payment(v.paymentMethod)),
        ListExportColumn(
            label: 'supplier_voucher.col_paid_amount'.tr,
            value: (v, _) => ListExcelExportService.numericValue(v.amount)),
        ListExportColumn(
            label: 'supplier_transactions.currency'.tr,
            value: (_, __) => currency),
        ListExportColumn(
            label: 'supplier_voucher.col_status'.tr,
            value: (v, _) => UiCodeLabels.status(v.status)),
      ],
    );
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'supplier_voucher.export_failed'.tr);
    }
  }

  void _openCreateVoucher() {
    final controller = Get.put(SideBarController());
    controller.index.value = controller.index.value == 75 ? 76 : 73;
  }

  /// Supplier picker with search; picking one searches right away.
  Widget _supplierPicker(Map<int, String> suppliers) => DropdownSearch<int>(
        key: ValueKey(selectedSupplierId),
        selectedItem:
            suppliers.containsKey(selectedSupplierId) ? selectedSupplierId : 0,
        items: (_, __) => [0, ...suppliers.keys],
        itemAsString: (id) => id == 0
            ? 'supplier_voucher.all_suppliers_hint'.tr
            : suppliers[id] ?? '',
        decoratorProps: DropDownDecoratorProps(
          decoration: AppInputDecoration.filter(
            label: 'supplier_voucher.col_supplier_name'.tr,
            icon: Icons.local_shipping_outlined,
          ),
        ),
        dropdownBuilder: (_, id) => Text(
          id == null || id == 0
              ? 'supplier_voucher.all_suppliers_hint'.tr
              : suppliers[id] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.input,
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: AppInputDecoration.of(
              label: 'general.search'.tr,
              icon: Icons.search,
            ),
          ),
        ),
        onChanged: (value) {
          setState(() => selectedSupplierId = value == 0 ? null : value);
          searchVouchers();
        },
      );

  FilterPanel _filters(SupplierVoucherProvider provider) {
    final suppliers = <int, String>{
      for (final voucher in provider.allVouchers ?? <SupplierVoucher>[])
        voucher.supplier.id: voucher.supplier.name,
    };
    return FilterPanel(
      key: SupplierVoucherListScreen.filtersKey,
      title: 'supplier_voucher.find'.tr,
      hint: 'supplier_voucher.filter_hint'.tr,
      resetLabel: 'list.reset'.tr,
      onSearch: _search.schedule,
      onSubmit: _search.flush,
      onReset: resetSearch,
      fields: [
        CustomFilterField(child: _supplierPicker(suppliers)),
        TextFilterField(
          controller: voucherNumberController,
          label: 'supplier_voucher.voucher_no_hint'.tr,
          hint: 'supplier_voucher.voucher_no_hint'.tr,
          icon: Icons.receipt_long_outlined,
        ),
        DropdownFilterField<String?>(
          label: 'supplier_voucher.col_type'.tr,
          icon: Icons.swap_vert,
          value: selectedType,
          options: [
            FilterOption(null, 'supplier_voucher.hint_all_types'.tr),
            for (final type
                in provider.getTypeOptions().where((v) => v != 'All Types'))
              FilterOption(type, UiCodeLabels.voucherType(type)),
          ],
          onChanged: (value) {
            setState(() => selectedType = value);
            searchVouchers();
          },
        ),
        DropdownFilterField<String?>(
          label: 'supplier_voucher.col_status'.tr,
          icon: Icons.check_circle_outline,
          value: selectedStatus,
          options: [
            FilterOption(null, 'supplier_voucher.hint_all_status'.tr),
            for (final status in provider
                .getStatusOptions()
                .where((v) => v != 'All Status'))
              FilterOption(status, UiCodeLabels.status(status)),
          ],
          onChanged: (value) {
            setState(() => selectedStatus = value);
            searchVouchers();
          },
        ),
      ],
    );
  }

  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  static Widget _text(String? value) => TableCells.text(_orDash(value));

  void _copyVoucherNumber(SupplierVoucher voucher) {
    Clipboard.setData(ClipboardData(text: voucher.voucherNumber));
    AppToast.success(context, 'supplier_voucher.voucher_number_copied'.tr);
  }

  Widget _copyButton(SupplierVoucher voucher) => IconButton(
        icon: const Icon(Icons.copy_outlined, size: 16),
        color: AppColors.muted,
        tooltip: 'supplier_voucher.col_voucher_number'.tr,
        onPressed: () => _copyVoucherNumber(voucher),
      );

  Widget _reference(SupplierVoucher voucher) => Row(children: [
        Expanded(child: _text(voucher.voucherNumber)),
        _copyButton(voucher),
      ]);

  void _openPrint(SupplierVoucher voucher) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SupplierVoucherPrintPage(
              voucher: voucher, returnToPreviousRoute: true)));

  Widget _actions(SupplierVoucher voucher) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        _action(Icons.visibility_outlined, 'list.view'.tr,
            () => _showVoucherDetails(voucher)),
        _action(Icons.print_outlined, 'general.print'.tr,
            () => _openPrint(voucher)),
        _action(
            Icons.share_outlined,
            'supplier_voucher.share_action'.tr,
            () => ShareHelper.showShareSupplierVoucherSheet(
                context: context, voucher: voucher)),
      ]);

  Widget _action(IconData icon, String tooltip, VoidCallback onPressed) =>
      AppSquareIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed,
        size: AppSizes.compactControl,
        iconSize: 18,
        radius: AppRadius.control,
        foreground: AppColors.primary,
      );

  String _amount(SupplierVoucher voucher) =>
      '${context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR'} ${voucher.amount}';

  Widget _statusBadge(String status) {
    final tone = switch (status.toUpperCase()) {
      'PAID' => AppBadgeTone.success,
      'PENDING' => AppBadgeTone.warning,
      'CANCELLED' => AppBadgeTone.danger,
      _ => AppBadgeTone.neutral,
    };
    return AppBadge(label: UiCodeLabels.status(status), tone: tone);
  }

  Widget _card(SupplierVoucher voucher, int number) => AppListCard(
        leading: AppAvatar(
          name: voucher.supplier.name,
          semanticLabel: voucher.supplier.name,
          size: 42,
        ),
        title: _orDash(voucher.supplier.name),
        subtitle: UiCodeLabels.voucherType(voucher.type),
        trailing: _statusBadge(voucher.status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                icon: Icons.payments_outlined,
                label: 'supplier_voucher.col_paid_amount'.tr,
                value: _amount(voucher),
              ),
              AppMetric(
                icon: Icons.account_balance_wallet_outlined,
                label: 'supplier_voucher.col_payment_method'.tr,
                value: _orDash(UiCodeLabels.payment(voucher.paymentMethod)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'supplier_voucher.col_voucher_number'.tr,
              value: _orDash(voucher.voucherNumber),
              trailing: _copyButton(voucher),
            ),
            InfoRow(
              icon: Icons.event_outlined,
              label: 'supplier_voucher.col_voucher_date'.tr,
              value: _orDash(voucher.voucherDate),
            ),
            InfoRow(
              icon: Icons.event_available_outlined,
              label: 'supplier_voucher.col_due_date'.tr,
              value: _orDash(voucher.dueDate),
            ),
            const SizedBox(height: AppSpacing.sm),
            _actions(voucher),
          ],
        ),
      );

  List<TableColumnDef<SupplierVoucher>> _columns() => [
        TableColumnDef(
            label: 'supplier_voucher.col_voucher_number'.tr,
            flex: 1.6,
            cellBuilder: (v, _) => _reference(v)),
        TableColumnDef(
            label: 'supplier_voucher.col_supplier_name'.tr,
            flex: 2,
            cellBuilder: (v, _) => TableCells.avatarName(
                  name: _orDash(v.supplier.name),
                  avatar: AppAvatar(
                    name: v.supplier.name,
                    semanticLabel: v.supplier.name,
                    size: 36,
                  ),
                )),
        TableColumnDef(
            label: 'supplier_voucher.col_type'.tr,
            cellBuilder: (v, _) => _text(UiCodeLabels.voucherType(v.type))),
        TableColumnDef(
            label: 'supplier_voucher.col_voucher_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) => _text(v.voucherDate)),
        TableColumnDef(
            label: 'supplier_voucher.col_due_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) => _text(v.dueDate)),
        TableColumnDef(
            label: 'supplier_voucher.col_payment_method'.tr,
            flex: 1.2,
            cellBuilder: (v, _) =>
                _text(UiCodeLabels.payment(v.paymentMethod))),
        TableColumnDef(
            label: 'supplier_voucher.col_paid_amount'.tr,
            flex: 1.4,
            cellBuilder: (v, _) => _text(_amount(v))),
        TableColumnDef(
            label: 'supplier_voucher.col_status'.tr,
            cellBuilder: (v, _) => TableCells.widget(_statusBadge(v.status))),
        TableColumnDef(
            label: 'supplier_voucher.col_action'.tr,
            flex: 1.8,
            cellBuilder: (v, _) => TableCells.widget(_actions(v))),
      ];

  /// Filters, Export, Refresh — left to right, before Create.
  List<HeaderAction> _headerActions(SupplierVoucherProvider provider) => [
        HeaderAction(
          key: SupplierVoucherListScreen.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters
              ? 'supplier_voucher.hide_filters'.tr
              : 'supplier_voucher.show_filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: !_showFilters && _hasActiveFilters,
        ),
        HeaderAction(
          key: SupplierVoucherListScreen.exportKey,
          icon: Icons.ios_share_rounded,
          label: _export.busy
              ? (_export.stage ?? 'supplier_voucher.export_creating'.tr)
              : 'supplier_transactions.export'.tr,
          onPressed: !provider.isLoading && provider.filteredVouchers.isNotEmpty
              ? _runExport
              : null,
          busy: _export.busy,
        ),
        HeaderAction(
          key: SupplierVoucherListScreen.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: refreshData,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierVoucherProvider>();
    final vouchers = provider.voucherListDetails ?? const <SupplierVoucher>[];
    return ListenableBuilder(
      listenable: _export,
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
        showFilters: _showFilters,
        isLoading: provider.isLoading,
        items: vouchers,
        minTableWidth: 1280,
        columns: _columns(),
        cardBuilder: _card,
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

  void _showVoucherDetails(SupplierVoucher voucher) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'supplier_voucher.details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_voucher_number'.tr, voucher.voucherNumber,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_supplier_name'.tr, voucher.supplier.name),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.field_supplier_phone'.tr,
                voucher.supplier.phone,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_type'.tr,
                UiCodeLabels.voucherType(voucher.type)),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_voucher_date'.tr, voucher.voucherDate),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_due_date'.tr, voucher.dueDate),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_status'.tr, voucher.status),
            CommonDetailsDialog.buildKeyValueRow(
                'supplier_voucher.col_payment_method'.tr,
                UiCodeLabels.payment(voucher.paymentMethod)),
          ],
        ],
        sectionTitle: 'supplier_voucher.items_section_title'.tr,
        tableContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header
            Container(
              decoration: BoxDecoration(
                color: ColorManager.tableBGColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    children: [
                      _buildTableHeaderCell('supplier_voucher.col_voucher'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_item_name'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_quantity_upper'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_unit_amount_upper'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_tax_upper'.tr),
                      _buildTableHeaderCell(
                          'supplier_voucher.col_total_amount_upper'.tr),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Table Body
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1.5),
              },
              children: voucher.items.asMap().entries.map((entry) {
                final item = entry.value;
                final index = entry.key;
                return TableRow(
                  decoration: BoxDecoration(
                    color: index % 2 == 0
                        ? Colors.white
                        : Colors.grey.withValues(alpha: 0.05),
                  ),
                  children: [
                    _buildTableBodyCell(voucher.voucherNumber),
                    _buildTableBodyCell(item.itemName),
                    _buildTableBodyCell(item.quantity),
                    _buildTableBodyCell(item.unitAmount),
                    _buildTableBodyCell(item.tax),
                    _buildTableBodyCell(item.totalAmount),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
        totalsContent: Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'supplier_voucher.grand_total_label'.tr,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.27,
                  Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${voucher.amount}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s18,
                  0.27,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }

  Widget _buildTableBodyCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s10,
          0.15,
          Colors.black,
        ),
      ),
    );
  }
}
