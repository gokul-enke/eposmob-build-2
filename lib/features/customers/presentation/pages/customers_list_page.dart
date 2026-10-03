import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../../domain/models/customer_list.dart';
import '../export/customer_excel_export.dart';
import '../navigation/customer_navigation.dart';
import '../state/customer_list_controller.dart';
import '../state/customer_provider.dart';
import '../widgets/customer_labels.dart';
import '../widgets/form/customer_form_host.dart';
import '../widgets/list/customer_filter_fields.dart';
import '../widgets/list/customer_list_card.dart';
import '../widgets/list/customer_table_columns.dart';

/// The customers list: header, filters, table/cards and pagination, built on
/// the shared [ListPageScaffold].
class CustomersListPage extends StatefulWidget {
  const CustomersListPage({super.key, this.exporter});

  /// Replaces the Excel export + share (tests).
  final CustomerExporter? exporter;

  static const filterToggleKey = ValueKey('customers_filter_toggle');
  static const exportKey = ValueKey('customers_export');
  static const refreshKey = ValueKey('customers_refresh');

  @override
  State<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends State<CustomersListPage> {
  late final CustomerProvider _provider;
  late final CustomerListController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<CustomerProvider>();
    _controller = CustomerListController(
      _provider,
      exporter: widget.exporter ??
          (customers) => CustomerExcelExport.exportAndShare(context, customers),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOnce());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _accessToken {
    final token = context.read<AuthModel>().token;
    return token == null || token.isEmpty ? null : token;
  }

  Future<void> _loadOnce() async {
    if (_loaded || !mounted) return;
    final token = _accessToken;
    if (token == null) {
      _showError('customers.msg_token_missing'.tr);
      return;
    }
    try {
      await _provider.loadAllCustomers(token);
      if (mounted) setState(() => _loaded = true);
    } catch (error) {
      debugPrint('Error loading customers: $error');
      _showError(
        'customers.msg_load_error'.trParams({'error': '$error'}),
      );
    }
  }

  Future<void> _refresh() async {
    final token = _accessToken;
    if (token == null) return;
    await _provider.loadAllCustomers(token);
  }

  void _showError(String message) {
    if (mounted) AppToast.error(context, message);
  }

  void _openProfile(CustomerListModelData customer) =>
      CustomerNavigation.openProfile(_provider, customer);

  Future<void> _export() async {
    final exported = await _controller.export();
    if (!exported) _showError('customers.export_failed'.tr);
  }

  /// Filters, Export, Refresh — left to right, before Add.
  List<HeaderAction> _headerActions() {
    final filtersShown = _controller.filtersVisible;
    return [
      HeaderAction(
        key: CustomersListPage.filterToggleKey,
        icon:
            filtersShown ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
        label: filtersShown
            ? 'customers.hide_filters'.tr
            : 'customers.show_filters'.tr,
        onPressed: _controller.toggleFilters,
        active: filtersShown,
        badge: !filtersShown && _controller.hasActiveFilter,
      ),
      HeaderAction(
        key: CustomersListPage.exportKey,
        icon: Icons.ios_share_rounded,
        label: _controller.isExporting
            ? 'customers.exporting'.tr
            : 'customers.export'.tr,
        onPressed: _controller.canExport ? _export : null,
        busy: _controller.isExporting,
      ),
      HeaderAction(
        key: CustomersListPage.refreshKey,
        icon: Icons.refresh_rounded,
        label: 'customers.refresh'.tr,
        onPressed: _refresh,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final customers = provider.getCustomerList ?? const [];

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => ListPageScaffold<CustomerListModelData>(
        header: PageHeader(
          icon: Icons.people_alt_rounded,
          title: 'customers.title'.tr,
          subtitle: 'customers.subtitle'.tr,
          actions: _headerActions(),
          addLabel: 'customers.add'.tr,
          addShortLabel: 'customers.add_short'.tr,
          onAdd: () => showAddCustomerDialog(context),
        ),
        filters: customerFilterPanel(_controller),
        showFilters: _controller.filtersVisible,
        mobileFilterTexts: customerMobileFilterTexts(),
        isLoading: provider.isLoading,
        items: customers,
        columns: customerTableColumns(onView: _openProfile),
        cardBuilder: (customer, rowNumber) => CustomerListCard(
          customer: customer,
          rowNumber: rowNumber,
          onView: () => _openProfile(customer),
        ),
        onRowTap: _openProfile,
        emptyState: AppEmptyState(
          icon: Icons.person_search_rounded,
          title: 'customers.empty_title'.tr,
          subtitle: 'customers.empty_subtitle'.tr,
        ),
        pagination: ListPagination(
          currentPage: provider.currentPage,
          totalPages: provider.totalPages,
          itemsPerPage: provider.itemsPerPage,
          onPageChanged: provider.goToPage,
          countLabel: CustomerLabels.countOnPage(customers.length),
        ),
        onRefresh: _refresh,
      ),
    );
  }
}
