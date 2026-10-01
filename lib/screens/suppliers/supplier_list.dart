import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../components/build_dialog_box.dart';
import '../../components/export_share_button.dart';
import '../../components/filter_toggle_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/supplier.dart';
import '../../providers/auth_model.dart';
import '../../providers/supplier_provider.dart';
import '../../services/list_excel_export_service.dart';
import '../../core/ui/app_surface.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import 'add_supplier_modal.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController searchEmailController = TextEditingController();
  final TextEditingController searchPhoneController = TextEditingController();
  final _nameFilterKey = GlobalKey<TextFilterFieldState>();
  final _emailFilterKey = GlobalKey<TextFilterFieldState>();
  final _phoneFilterKey = GlobalKey<TextFilterFieldState>();
  String selectedBalanceFilter = 'All';
  bool initLoading = false;
  bool _showFilters = true;
  bool _filterVisibilityInitialized = false;

  bool get _hasActiveFilters =>
      searchTextController.text.isNotEmpty ||
      searchEmailController.text.isNotEmpty ||
      searchPhoneController.text.isNotEmpty ||
      selectedBalanceFilter != 'All';

  Widget _buildFilterToggleButton() {
    return FilterToggleButton(
      key: const ValueKey('supplier-list-filter-toggle'),
      showFilters: _showFilters,
      hasActiveFilters: _hasActiveFilters,
      activeFiltersListenable: Listenable.merge([
        searchTextController,
        searchEmailController,
        searchPhoneController,
      ]),
      activeFiltersBuilder: () => _hasActiveFilters,
      showTooltip: 'supplier_list_mobile.show_filters'.tr,
      hideTooltip: 'supplier_list_mobile.hide_filters'.tr,
      onPressed: () => setState(() => _showFilters = !_showFilters),
    );
  }

  Future<File> _createSupplierExport() {
    _cancelPendingSearches();
    final provider = context.read<SupplierProvider>();
    provider.applyFiltersLocally(
      supplierName: searchTextController.text,
      supplierEmail: searchEmailController.text,
      supplierPhone: searchPhoneController.text,
      filterBalance: selectedBalanceFilter,
      page: provider.currentPage,
    );
    final suppliers = provider.filteredSuppliers;
    return ListExcelExportService.export<Supplier>(
      items: suppliers,
      fileNamePrefix: 'suppliers',
      sheetName: 'suppliers.list'.tr,
      columns: [
        ListExportColumn(
          label: 'suppliers.number'.tr,
          value: (_, index) => index + 1,
        ),
        ListExportColumn(
          label: 'suppliers.name'.tr,
          value: (supplier, _) => supplier.name,
        ),
        ListExportColumn(
          label: 'suppliers.email'.tr,
          value: (supplier, _) => supplier.email,
        ),
        ListExportColumn(
          label: 'suppliers.phone'.tr,
          value: (supplier, _) => supplier.phone,
        ),
        ListExportColumn(
          label: 'suppliers.address'.tr,
          value: (supplier, _) => supplier.address,
        ),
        ListExportColumn(
          label: 'suppliers.current_balance'.tr,
          value: (supplier, _) => supplier.currentBalance,
        ),
      ],
    );
  }

  Widget _buildExportButton({bool compact = false}) {
    return Consumer<SupplierProvider>(
      builder: (context, provider, child) => ExportShareButton(
        key: const ValueKey('supplier-list-export'),
        compact: compact,
        enabled: !provider.isLoading && provider.hasFilteredSuppliers,
        createFile: _createSupplierExport,
        label: 'supplier_list.export'.tr,
        loadingLabel: 'supplier_list.exporting'.tr,
        tooltip: 'supplier_list.export_tooltip'.tr,
        errorMessage: 'supplier_list.export_failed'.tr,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        shareText: 'supplier_list.share_text'.tr,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadInitData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filterVisibilityInitialized) {
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobile;
      _filterVisibilityInitialized = true;
    }
  }

  void loadInitData() async {
    debugPrint("📌 loadInitData started for Suppliers");
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("📌 Access token length: ${accessToken?.length ?? 0}");

      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      debugPrint("📌 Calling supplierProvider.fetchSuppliers");
      await supplierProvider.fetchSuppliers(
        accessToken: accessToken ?? "",
        supplierName: null, // No filter when loading initial data
      );

      debugPrint(
          "📌 Loaded ${supplierProvider.supplierList?.length ?? 0} suppliers");
    } catch (error) {
      debugPrint("❌ Supplier listing error: ${error.toString()}");
      if (mounted)
        showScaffold(
            context: context, message: 'supplier_list.error_fetching'.tr);
    } finally {
      if (!mounted) return;
      setState(() {
        initLoading = false;
      });
      debugPrint("📌 loadInitData finished");
    }
  }

  Future<void> refreshData() async {
    final accessToken = context.read<AuthModel>().token;
    if (accessToken == null || accessToken.isEmpty) return;

    final supplierProvider = context.read<SupplierProvider>();
    await supplierProvider.fetchSuppliers(
      accessToken: accessToken,
      supplierName: null,
    );
    if (!mounted) return;

    supplierProvider.applyFiltersLocally(
      supplierName: searchTextController.text,
      supplierEmail: searchEmailController.text,
      supplierPhone: searchPhoneController.text,
      filterBalance: selectedBalanceFilter,
    );
  }

  void searchSuppliers({
    String name = '',
    String email = '',
    String phone = '',
    String balance = 'All',
  }) {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null || accessToken.isEmpty) return;

      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      // Apply all filters locally
      supplierProvider.applyFiltersLocally(
        supplierName: name,
        supplierEmail: email,
        supplierPhone: phone,
        filterBalance: balance,
      );
    } catch (error) {
      debugPrint("❌ Supplier search error: ${error.toString()}");
      showScaffold(
          context: context, message: 'supplier_list.error_searching'.tr);
    }
  }

  @override
  void dispose() {
    searchTextController.dispose();
    searchEmailController.dispose();
    searchPhoneController.dispose();
    super.dispose();
  }

  void _search() => searchSuppliers(
      name: searchTextController.text,
      email: searchEmailController.text,
      phone: searchPhoneController.text,
      balance: selectedBalanceFilter);

  void _cancelPendingSearches() {
    _nameFilterKey.currentState?.cancelPendingSearch();
    _emailFilterKey.currentState?.cancelPendingSearch();
    _phoneFilterKey.currentState?.cancelPendingSearch();
  }

  void _reset() {
    _cancelPendingSearches();
    setState(() {
      searchTextController.clear();
      searchEmailController.clear();
      searchPhoneController.clear();
      selectedBalanceFilter = 'All';
    });
    context.read<SupplierProvider>().resetFilters();
  }

  void _openSupplier(Supplier supplier) {
    context.read<SupplierProvider>().selectSupplier(supplier);
    sideBarController.index.value = 69;
  }

  Future<void> _addSupplier() async {
    final result =
        await showAddSupplierModal(context, MediaQuery.sizeOf(context));
    if (mounted && result != null && result['status'] == 'success') {
      await refreshData();
    }
  }

  Widget _card(Supplier supplier, int number) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
            onTap: () => _openSupplier(supplier),
            child: TableCells.identity(supplier.name)),
        const SizedBox(height: 12),
        TableCells.text('${'suppliers.number'.tr}: $number'),
        const SizedBox(height: 8),
        TableCells.text('${'suppliers.email'.tr}: ${supplier.email}'),
        const SizedBox(height: 8),
        TableCells.text('${'suppliers.phone'.tr}: ${supplier.phone}'),
        const SizedBox(height: 8),
        Text('${'suppliers.address'.tr}: ${supplier.address}'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TableCells.text('suppliers.current_balance'.tr)),
          TableCells.amount(supplier.currentBalance)
        ]),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: TableCells.viewButton(() => _openSupplier(supplier))),
      ]));

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final mobile = size.maxWidth < ListLayoutBreakpoints.mobile;
        return Consumer<SupplierProvider>(builder: (context, provider, _) {
          final suppliers = provider.supplierList ?? <Supplier>[];
          return ListPageScaffold<Supplier>(
            header: ListPageHeader(
                icon: Icons.local_shipping_rounded,
                title: 'suppliers.title'.tr,
                subtitle: 'supplier_list.subtitle'.tr,
                onRefresh: () => refreshData(),
                onAdd: _addSupplier,
                addLabel: 'suppliers.add'.tr,
                addShortLabel: 'supplier_list_mobile.btn_add_new'.tr,
                extraActions: [
                  _buildFilterToggleButton(),
                  _buildExportButton(
                      compact: size.maxWidth < ListLayoutBreakpoints.actions)
                ]),
            showFilters: _showFilters,
            filters: KeyedSubtree(
                key: ValueKey(mobile
                    ? 'supplier-list-mobile-filters'
                    : 'supplier-list-desktop-filters'),
                child: FilterPanel(
                    title: 'supplier_list.find'.tr,
                    hint: 'supplier_list.find_hint'.tr,
                    onReset: _reset,
                    fields: [
                      TextFilterField(
                          key: _nameFilterKey,
                          controller: searchTextController,
                          label: 'suppliers.name'.tr,
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.name,
                          onSearch: _search),
                      TextFilterField(
                          key: _emailFilterKey,
                          controller: searchEmailController,
                          label: 'suppliers.email'.tr,
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          onSearch: _search),
                      TextFilterField(
                          key: _phoneFilterKey,
                          controller: searchPhoneController,
                          label: 'suppliers.phone'.tr,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          onSearch: _search),
                      DropdownButtonFormField<String>(
                          key: ValueKey(selectedBalanceFilter),
                          initialValue: selectedBalanceFilter,
                          isExpanded: true,
                          decoration: listFilterDecoration(
                              'suppliers.balance'.tr,
                              Icons.account_balance_wallet_outlined),
                          items: const [
                            'All',
                            'Positive (+ve)',
                            'Negative (-ve)',
                            'Zero (0)'
                          ]
                              .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(switch (value) {
                                    'Positive (+ve)' => 'suppliers.positive'.tr,
                                    'Negative (-ve)' => 'suppliers.negative'.tr,
                                    'Zero (0)' => 'suppliers.zero'.tr,
                                    _ => 'suppliers.all'.tr,
                                  })))
                              .toList(),
                          onChanged: (value) {
                            setState(
                                () => selectedBalanceFilter = value ?? 'All');
                            _search();
                          }),
                    ])),
            isLoading: initLoading || provider.isLoading,
            items: suppliers,
            onRefresh: refreshData,
            onItemTap: _openSupplier,
            cardBuilder: _card,
            emptyState: AppSurface(
                child: Column(children: [
              const Icon(Icons.local_shipping_outlined, size: 48),
              const SizedBox(height: 18),
              Text('supplier_list.no_suppliers_desktop'.tr),
              const SizedBox(height: 6),
              Text('supplier_list.try_adjusting_search'.tr),
            ])),
            currentPage: provider.currentPage,
            totalPages: provider.totalPages,
            itemsPerPage: provider.itemsPerPage,
            onPageChanged: provider.goToPage,
            countLabel: 'supplier_list.count_on_page'
                .trParams({'count': '${suppliers.length}'}),
            columns: [
              TableColumnDef(
                  label: 'suppliers.number'.tr,
                  flex: .5,
                  cellBuilder: (_, number) => TableCells.text('$number')),
              TableColumnDef(
                  label: 'suppliers.name'.tr,
                  flex: 2.2,
                  cellBuilder: (item, _) => TableCells.identity(item.name)),
              TableColumnDef(
                  label: 'suppliers.email'.tr,
                  flex: 1.7,
                  cellBuilder: (item, _) => TableCells.text(item.email)),
              TableColumnDef(
                  label: 'suppliers.phone'.tr,
                  flex: 1.3,
                  cellBuilder: (item, _) => TableCells.text(item.phone)),
              TableColumnDef(
                  label: 'suppliers.address'.tr,
                  flex: 1.4,
                  cellBuilder: (item, _) => TableCells.text(item.address)),
              TableColumnDef(
                  label: 'suppliers.current_balance'.tr,
                  flex: 1.3,
                  cellBuilder: (item, _) =>
                      TableCells.amount(item.currentBalance)),
              TableColumnDef(
                  label: 'suppliers.action'.tr,
                  flex: 1.1,
                  cellBuilder: (item, _) =>
                      TableCells.viewButton(() => _openSupplier(item))),
            ],
          );
        });
      });
}
