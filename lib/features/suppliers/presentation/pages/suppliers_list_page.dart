import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../../domain/models/supplier.dart';
import '../navigation/supplier_navigation.dart';
import '../state/supplier_list_controller.dart';
import '../state/supplier_provider.dart';
import '../widgets/form/supplier_form_host.dart';
import '../widgets/list/supplier_filter_fields.dart';
import '../widgets/list/supplier_list_card.dart';
import '../widgets/list/supplier_table_columns.dart';
import '../widgets/supplier_labels.dart';

/// The suppliers list: header, filters, table/cards and pagination, built on
/// the shared [ListPageScaffold].
class SuppliersListPage extends StatefulWidget {
  const SuppliersListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filterToggleKey = ValueKey('supplier-list-filter-toggle');
  static const exportKey = ValueKey('supplier-list-export');
  static const refreshKey = ValueKey('supplier-list-refresh');

  @override
  State<SuppliersListPage> createState() => _SuppliersListPageState();
}

class _SuppliersListPageState extends State<SuppliersListPage> {
  late final SupplierProvider _provider;
  SupplierListController? _controllerOrNull;
  bool _loading = false;

  SupplierListController get _controller => _controllerOrNull!;

  @override
  void initState() {
    super.initState();
    _provider = context.read<SupplierProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Filters start open on wide screens and closed on phones.
    _controllerOrNull ??= SupplierListController(
      _provider,
      filtersVisible: MediaQuery.sizeOf(context).width >=
          ListLayoutBreakpoints.mobileBelow,
      export: widget.export,
    );
  }

  @override
  void dispose() {
    _controllerOrNull?.dispose();
    super.dispose();
  }

  String get _accessToken => context.read<AuthModel>().token ?? '';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _provider.fetchSuppliers(accessToken: _accessToken);
    } catch (error) {
      debugPrint('Supplier listing error: $error');
      if (mounted) AppToast.error(context, 'supplier_list.error_fetching'.tr);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_accessToken.isEmpty) return;
    await _controller.refresh(_accessToken);
  }

  Future<void> _export() async {
    final exported = await _controller.export.run(
      context,
      createFile: _controller.createExportFile,
      shareText: 'supplier_list.share_text'.tr,
    );
    if (!exported && mounted) {
      AppToast.error(context, 'supplier_list.export_failed'.tr);
    }
  }

  Future<void> _addSupplier() async {
    final result = await showAddSupplierDialog(context);
    // The form already reloaded the directory; just keep the typed filters.
    if (mounted && result is Map && result['status'] == 'success') {
      _controller.applyInputsInPlace();
    }
  }

  void _openProfile(Supplier supplier) =>
      SupplierNavigation.openProfile(_provider, supplier);

  /// Filters, Export, Refresh — left to right, before Add.
  List<HeaderAction> _headerActions() {
    final controller = _controller;
    final filtersShown = controller.filtersVisible;
    final export = controller.export;
    return [
      HeaderAction(
        key: SuppliersListPage.filterToggleKey,
        icon: filtersShown
            ? Icons.filter_alt_rounded
            : Icons.filter_alt_outlined,
        label: filtersShown
            ? 'supplier_list_mobile.hide_filters'.tr
            : 'supplier_list_mobile.show_filters'.tr,
        onPressed: controller.toggleFilters,
        active: filtersShown,
        badge: !filtersShown && controller.hasActiveFilter,
      ),
      HeaderAction(
        key: SuppliersListPage.exportKey,
        icon: Icons.ios_share_rounded,
        label: export.busy
            ? (export.stage ?? 'supplier_list.exporting'.tr)
            : 'supplier_list.export'.tr,
        onPressed: controller.canExport ? _export : null,
        busy: export.busy,
      ),
      HeaderAction(
        key: SuppliersListPage.refreshKey,
        icon: Icons.refresh_rounded,
        label: 'list.refresh'.tr,
        onPressed: _refresh,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierProvider>();
    final suppliers = provider.supplierList ?? const <Supplier>[];
    final controller = _controller;

    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.export]),
      builder: (context, _) => ListPageScaffold<Supplier>(
        header: PageHeader(
          icon: Icons.local_shipping_rounded,
          title: 'suppliers.title'.tr,
          subtitle: 'supplier_list.subtitle'.tr,
          actions: _headerActions(),
          addLabel: 'suppliers.add'.tr,
          addShortLabel: 'supplier_list_mobile.btn_add_new'.tr,
          onAdd: _addSupplier,
        ),
        filters: supplierFilterPanel(controller),
        showFilters: controller.filtersVisible,
        isLoading: _loading || provider.isLoading,
        items: suppliers,
        columns: supplierTableColumns(onView: _openProfile),
        cardBuilder: (supplier, rowNumber) => SupplierListCard(
          supplier: supplier,
          rowNumber: rowNumber,
          onView: () => _openProfile(supplier),
        ),
        onRowTap: _openProfile,
        emptyState: AppEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'supplier_list.no_suppliers_desktop'.tr,
          subtitle: 'supplier_list.try_adjusting_search'.tr,
        ),
        pagination: ListPagination(
          currentPage: provider.currentPage,
          totalPages: provider.totalPages,
          itemsPerPage: provider.itemsPerPage,
          onPageChanged: provider.goToPage,
          countLabel: SupplierLabels.countOnPage(suppliers.length),
        ),
        onRefresh: _refresh,
      ),
    );
  }
}
