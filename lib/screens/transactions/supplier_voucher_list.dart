import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../components/export_share_button.dart';
import '../../components/filter_toggle_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../core/ui/app_surface.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import '../../helpers/ui_code_labels.dart';
import '../../models/supplier_voucher.dart';
import '../../newcomponents/custom_dialog_box.dart';
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

class SupplierVoucherListScreen extends StatefulWidget {
  const SupplierVoucherListScreen({super.key});
  @override
  State<SupplierVoucherListScreen> createState() =>
      _SupplierVoucherListScreenState();
}

class _SupplierVoucherListScreenState extends State<SupplierVoucherListScreen> {
  final voucherNumberController = TextEditingController();
  final _voucherSearchKey = GlobalKey<TextFilterFieldState>();
  String? selectedType, selectedStatus;
  int? selectedSupplierId;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  final _exportProgress = ValueNotifier<String?>(null);

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
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobile;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    voucherNumberController.dispose();
    _exportProgress.dispose();
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
    _voucherSearchKey.currentState?.cancelPendingSearch();
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('supplier_voucher.auth_token_missing'.tr)));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('supplier_voucher.error_loading_vouchers'
              .trParams({'error': '$error'}))));
    }
  }

  Future<File> _createExport() {
    // Cancel the timer, then apply pending edits without changing the page.
    _voucherSearchKey.currentState?.cancelPendingSearch();
    searchVouchers(page: context.read<SupplierVoucherProvider>().currentPage);
    final items = List<SupplierVoucher>.of(
        context.read<SupplierVoucherProvider>().filteredVouchers);
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    _exportProgress.value = 'supplier_voucher.export_creating'.tr;
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

  Widget _filters(SupplierVoucherProvider provider) {
    final suppliers = <int, String>{
      for (final voucher in provider.allVouchers ?? <SupplierVoucher>[])
        voucher.supplier.id: voucher.supplier.name,
    };
    return FilterPanel(
      key: const ValueKey('supplier-voucher-desktop-filters'),
      title: 'supplier_voucher.find'.tr,
      hint: 'supplier_voucher.filter_hint'.tr,
      onReset: resetSearch,
      fields: [
        DropdownSearch<int>(
          key: ValueKey(selectedSupplierId),
          selectedItem: suppliers.containsKey(selectedSupplierId)
              ? selectedSupplierId
              : 0,
          items: (_, __) => [0, ...suppliers.keys],
          itemAsString: (id) => id == 0
              ? 'supplier_voucher.all_suppliers_hint'.tr
              : suppliers[id] ?? '',
          decoratorProps: DropDownDecoratorProps(
              decoration: listFilterDecoration(
                  'supplier_voucher.col_supplier_name'.tr,
                  Icons.local_shipping_outlined)),
          dropdownBuilder: (_, id) => Text(
              id == null || id == 0
                  ? 'supplier_voucher.all_suppliers_hint'.tr
                  : suppliers[id] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                  decoration:
                      listFilterDecoration('general.search'.tr, Icons.search))),
          onChanged: (value) {
            setState(() => selectedSupplierId = value == 0 ? null : value);
            searchVouchers();
          },
        ),
        TextFilterField(
            key: _voucherSearchKey,
            controller: voucherNumberController,
            label: 'supplier_voucher.voucher_no_hint'.tr,
            icon: Icons.receipt_long_outlined,
            onSearch: searchVouchers),
        DropdownButtonFormField<String>(
            key: ValueKey(selectedType),
            initialValue: selectedType,
            isExpanded: true,
            decoration: listFilterDecoration(
                'supplier_voucher.col_type'.tr, Icons.swap_vert),
            items: [
              DropdownMenuItem<String>(
                  value: null,
                  child: Text('supplier_voucher.hint_all_types'.tr)),
              for (final type
                  in provider.getTypeOptions().where((v) => v != 'All Types'))
                DropdownMenuItem(
                    value: type, child: Text(UiCodeLabels.voucherType(type)))
            ],
            onChanged: (value) {
              setState(() => selectedType = value);
              searchVouchers();
            }),
        DropdownButtonFormField<String>(
            key: ValueKey(selectedStatus),
            initialValue: selectedStatus,
            isExpanded: true,
            decoration: listFilterDecoration(
                'supplier_voucher.col_status'.tr, Icons.check_circle_outline),
            items: [
              DropdownMenuItem<String>(
                  value: null,
                  child: Text('supplier_voucher.hint_all_status'.tr)),
              for (final status in provider
                  .getStatusOptions()
                  .where((v) => v != 'All Status'))
                DropdownMenuItem(
                    value: status, child: Text(UiCodeLabels.status(status)))
            ],
            onChanged: (value) {
              setState(() => selectedStatus = value);
              searchVouchers();
            }),
      ],
    );
  }

  Widget _reference(SupplierVoucher voucher) => Row(children: [
        Expanded(child: TableCells.text(voucher.voucherNumber)),
        IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16),
            tooltip: 'supplier_voucher.col_voucher_number'.tr,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: voucher.voucherNumber));
              showScaffold(
                  context: context,
                  message: 'supplier_voucher.voucher_number_copied'.tr);
            }),
      ]);

  Widget _actions(SupplierVoucher voucher) => Wrap(spacing: 6, children: [
        _action(Icons.visibility_outlined, 'list.view'.tr,
            () => _showVoucherDetails(voucher)),
        _action(
            Icons.print_outlined,
            'general.print'.tr,
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SupplierVoucherPrintPage(
                        voucher: voucher, returnToPreviousRoute: true)))),
        _action(
            Icons.share_outlined,
            'supplier_voucher.share_action'.tr,
            () => ShareHelper.showShareSupplierVoucherSheet(
                context: context, voucher: voucher)),
      ]);

  Widget _action(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton.outlined(
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
              foregroundColor: ColorManager.kPrimaryColor,
              side: const BorderSide(color: Color(0xFFE1E3E5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))));

  String _amount(SupplierVoucher voucher) =>
      '${context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR'} ${voucher.amount}';

  Widget _card(SupplierVoucher voucher, int number) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableCells.identity(voucher.supplier.name),
        const SizedBox(height: 10),
        _reference(voucher),
        Text(
            '${'supplier_voucher.col_type'.tr}: ${UiCodeLabels.voucherType(voucher.type)}'),
        Text(
            '${'supplier_voucher.col_voucher_date'.tr}: ${voucher.voucherDate}'),
        Text('${'supplier_voucher.col_due_date'.tr}: ${voucher.dueDate}'),
        Text(
            '${'supplier_voucher.col_payment_method'.tr}: ${UiCodeLabels.payment(voucher.paymentMethod)}'),
        Text('${'supplier_voucher.col_paid_amount'.tr}: ${_amount(voucher)}'),
        const SizedBox(height: 10),
        _buildStatusChip(voucher.status),
        const SizedBox(height: 10),
        _actions(voucher),
      ]));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierVoucherProvider>();
    return LayoutBuilder(
        builder: (context, bounds) => ListPageScaffold<SupplierVoucher>(
              header: ListPageHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'supplier_voucher.mobile_header_title'.tr,
                  subtitle: 'supplier_voucher.subtitle'.tr,
                  onRefresh: refreshData,
                  onAdd: () {
                    final controller = Get.put(SideBarController());
                    controller.index.value =
                        controller.index.value == 75 ? 76 : 73;
                  },
                  addLabel: 'supplier_voucher.create_voucher_button'.tr,
                  addShortLabel: 'supplier_voucher.mobile_create_button'.tr,
                  extraActions: [
                    FilterToggleButton(
                        showFilters: _showFilters,
                        hasActiveFilters: selectedSupplierId != null ||
                            selectedType != null ||
                            selectedStatus != null ||
                            voucherNumberController.text.isNotEmpty,
                        activeFiltersListenable: voucherNumberController,
                        activeFiltersBuilder: () =>
                            selectedSupplierId != null ||
                            selectedType != null ||
                            selectedStatus != null ||
                            voucherNumberController.text.isNotEmpty,
                        showTooltip: 'supplier_voucher.show_filters'.tr,
                        hideTooltip: 'supplier_voucher.hide_filters'.tr,
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters)),
                    ExportShareButton(
                        createFile: _createExport,
                        label: 'supplier_transactions.export'.tr,
                        tooltip: 'supplier_voucher.export_tooltip'.tr,
                        loadingLabel: 'supplier_voucher.export_creating'.tr,
                        progressLabel: _exportProgress,
                        errorMessage: 'supplier_voucher.export_failed'.tr,
                        enabled: !provider.isLoading &&
                            provider.filteredVouchers.isNotEmpty,
                        compact: bounds.maxWidth < ListLayoutBreakpoints.header,
                        mimeType:
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                  ]),
              filters: _filters(provider),
              showFilters: _showFilters,
              isLoading: provider.isLoading,
              items: provider.voucherListDetails ?? [],
              tableMinWidth: 1280,
              columns: [
                TableColumnDef(
                    label: 'supplier_voucher.col_voucher_number'.tr,
                    flex: 1.6,
                    cellBuilder: (v, _) => _reference(v)),
                TableColumnDef(
                    label: 'supplier_voucher.col_supplier_name'.tr,
                    flex: 2,
                    cellBuilder: (v, _) =>
                        TableCells.identity(v.supplier.name)),
                TableColumnDef(
                    label: 'supplier_voucher.col_type'.tr,
                    cellBuilder: (v, _) =>
                        TableCells.text(UiCodeLabels.voucherType(v.type))),
                TableColumnDef(
                    label: 'supplier_voucher.col_voucher_date'.tr,
                    flex: 1.3,
                    cellBuilder: (v, _) => TableCells.text(v.voucherDate)),
                TableColumnDef(
                    label: 'supplier_voucher.col_due_date'.tr,
                    flex: 1.3,
                    cellBuilder: (v, _) => TableCells.text(v.dueDate)),
                TableColumnDef(
                    label: 'supplier_voucher.col_payment_method'.tr,
                    flex: 1.2,
                    cellBuilder: (v, _) =>
                        TableCells.text(UiCodeLabels.payment(v.paymentMethod))),
                TableColumnDef(
                    label: 'supplier_voucher.col_paid_amount'.tr,
                    flex: 1.4,
                    cellBuilder: (v, _) => TableCells.text(_amount(v))),
                TableColumnDef(
                    label: 'supplier_voucher.col_status'.tr,
                    cellBuilder: (v, _) => _buildStatusChip(v.status)),
                TableColumnDef(
                    label: 'supplier_voucher.col_action'.tr,
                    flex: 1.8,
                    cellBuilder: (v, _) => _actions(v)),
              ],
              cardBuilder: _card,
              emptyState:
                  Center(child: Text('supplier_voucher.no_vouchers_found'.tr)),
              onRefresh: refreshData,
              currentPage: provider.currentPage,
              totalPages: provider.totalPages,
              itemsPerPage: provider.itemsPerPage,
              countLabel: 'supplier_voucher.page_count'.trParams(
                  {'count': '${provider.voucherListDetails?.length ?? 0}'}),
              onPageChanged: provider.goToPage,
            ));
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PAID':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        break;
      case 'PENDING':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        break;
      case 'CANCELLED':
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
